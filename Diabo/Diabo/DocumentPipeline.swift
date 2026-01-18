import Foundation
import SwiftData
import UIKit
import PDFKit
import Vision

/// Complete pipeline for processing medical documents to timeline
@MainActor
class DocumentPipeline {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Main Pipeline
    
    /// Process document (image or PDF) through complete pipeline
    func processDocument(
        image: UIImage? = nil,
        pdfURL: URL? = nil,
        title: String
    ) async throws -> MedicalReportModel {
        
        // Step 1: Extract text using Vision OCR
        let extractedText: String
        let documentURL: String?
        
        if let image = image {
            extractedText = try await extractTextFromImage(image)
            documentURL = try saveImage(image)
        } else if let pdfURL = pdfURL {
            extractedText = try await extractTextFromPDF(pdfURL)
            documentURL = pdfURL.absoluteString
        } else {
            throw PipelineError.noDocumentProvided
        }
        
        // Step 2: Analyze document with AI (Deep Thinking)
        let analysisResult = try await ChatService.shared.analyzeMedicalText(extractedText)
        
        // Step 3: Map AI results to models
        let reportType = analysisResult.reportType
        
        var labResults: [LabResultModel] = []
        for dto in analysisResult.labResults {
            // clean value string to double if possible
            let valueDouble = Double(dto.value.filter("0123456789.".contains)) ?? 0.0
            
            let result = LabResultModel(
                testName: dto.testName,
                value: valueDouble,
                unit: dto.unit,
                normalRange: dto.normalRange,
                status: dto.status,
                category: dto.category
            )
            labResults.append(result)
        }
        
        var medications: [MedicationModel] = []
        for dto in analysisResult.medications {
            let med = MedicationModel(
                name: dto.name,
                dosage: dto.dosage,
                frequency: dto.frequency,
                instructions: dto.instructions
            )
            medications.append(med)
        }
        
        // Step 4: Use AI generated summary
        let insights = analysisResult.summary
        
        // Step 5: Create MedicalReport model
        let report = MedicalReportModel(
            title: title,
            reportType: reportType,
            imageURL: image != nil ? documentURL : nil,
            pdfURL: pdfURL != nil ? documentURL : nil,
            extractedText: extractedText,
            aiInsights: insights
        )
        
        // Step 6: Save to SwiftData
        modelContext.insert(report)
        
        // Save lab results with relationship
        for labResult in labResults {
            modelContext.insert(labResult)
            if report.labResults == nil {
                report.labResults = []
            }
            report.labResults?.append(labResult)
        }
        
        // Save medications with relationship
        for medication in medications {
            modelContext.insert(medication)
            if report.medications == nil {
                report.medications = []
            }
            report.medications?.append(medication)
        }
        
        //Step 7: Auto-categorize medications (move missing meds to Past)
        // Check existing active medications and mark as inactive if not in current report
        let existingActiveMeds = try? fetchActiveMedications()
        if let existingActiveMeds = existingActiveMeds, !existingActiveMeds.isEmpty {
            let newMedicationNames = Set(medications.map { $0.name.lowercased() })
            
            for existingMed in existingActiveMeds {
                // If medication is not in the new report, mark it as inactive
                if !newMedicationNames.contains(existingMed.name.lowercased()) {
                    existingMed.isActive = false
                    existingMed.endDate = Date() // Set last use date to today
                }
            }
        }
        
        // Step 8: Create timeline entry
        let timelineEntry = createTimelineEntry(for: report)
        modelContext.insert(timelineEntry)
        
        // Step 9: Save context
        try modelContext.save()
        
        return report
    }
    
    // MARK: - OCR Processing
    
    /// Extract text from image using Vision
    private func extractTextFromImage(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw PipelineError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: PipelineError.ocrFailed)
                    return
                }
                
                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                if text.isEmpty {
                    continuation.resume(throwing: PipelineError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            }
            
            // Configure for medical documents
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Extract text from PDF
    private func extractTextFromPDF(_ url: URL) async throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw PipelineError.invalidPDF
        }
        
        var fullText = ""
        
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        
        if fullText.isEmpty {
            throw PipelineError.noTextFound
        }
        
        return fullText
    }
    
    // MARK: - Storage
    
    /// Save image to documents directory
    private func saveImage(_ image: UIImage) throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw PipelineError.imageSaveFailed
        }
        
        let fileName = "\(UUID().uuidString).jpg"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        try imageData.write(to: fileURL)
        
        return fileURL.absoluteString
    }
    
    // MARK: - AI Insights
    
    /// Generate AI insights from parsed data
    private func generateInsights(
        text: String,
        labResults: [LabResultModel],
        medications: [MedicationModel]
    ) async -> String {
        var insights = "📊 Report Summary:\n\n"
        
        // Lab results insights
        if !labResults.isEmpty {
            insights += "Lab Results:\n"
            
            let abnormalResults = labResults.filter { $0.status != "Normal" && $0.status != "Optimal" }
            
            if abnormalResults.isEmpty {
                insights += "✅ All test results are within normal range.\n\n"
            } else {
                insights += "⚠️ Attention needed for:\n"
                for result in abnormalResults {
                    insights += "• \(result.testName): \(result.value) \(result.unit) (\(result.status))\n"
                }
                insights += "\n"
            }
            
            // Specific recommendations
            for result in abnormalResults {
                switch result.testName {
                case "Total Cholesterol":
                    if result.value > 200 {
                        insights += "💡 High cholesterol detected. Consider:\n"
                        insights += "  - Reducing saturated fats\n"
                        insights += "  - Increasing fiber intake\n"
                        insights += "  - Regular exercise\n\n"
                    }
                case "Fasting Glucose", "HbA1c":
                    if result.value > 100 {
                        insights += "💡 Elevated blood sugar. Consider:\n"
                        insights += "  - Limiting refined carbohydrates\n"
                        insights += "  - Regular blood sugar monitoring\n"
                        insights += "  - Consulting with your doctor\n\n"
                    }
                case "Vitamin D":
                    if result.value < 30 {
                        insights += "💡 Low Vitamin D. Consider:\n"
                        insights += "  - Vitamin D supplementation\n"
                        insights += "  - More sun exposure\n"
                        insights += "  - Vitamin D rich foods\n\n"
                    }
                default:
                    break
                }
            }
        }
        
        // Medication insights
        if !medications.isEmpty {
            insights += "💊 Medications:\n"
            for med in medications {
                insights += "• \(med.name) - \(med.dosage) (\(med.frequency))\n"
            }
            insights += "\n"
        }
        
        insights += "⚕️ Always consult your healthcare provider for personalized medical advice."
        
        return insights
    }
    
    // MARK: - Timeline Entry
    
    /// Create timeline entry for report
    private func createTimelineEntry(for report: MedicalReportModel) -> TimelineEntryModel {
        let iconName: String
        let color: String
        
        switch report.reportType {
        case "Blood Test", "Lipid Panel":
            iconName = "drop.fill"
            color = "#FF6B6B"
        case "X-Ray", "MRI", "CT Scan":
            iconName = "xmark.circle.fill"
            color = "#4ECDC4"
        case "Prescription":
            iconName = "pills.fill"
            color = "#95E1D3"
        case "Liver Function Test":
            iconName = "cross.case.fill"
            color = "#FFB84D"
        case "Kidney Function Test":
            iconName = "drop.triangle.fill"
            color = "#A8E6CF"
        default:
            iconName = "doc.text.fill"
            color = "#B4A7D6"
        }
        
        let description = report.labResults?.isEmpty == false
            ? "\(report.labResults!.count) lab results"
            : "Medical report uploaded"
        
        return TimelineEntryModel(
            date: report.uploadDate,
            type: "Report",
            title: report.title,
            summary: description,
            relatedReportId: report.id,
            iconName: iconName,
            color: color
        )
    }
    
    // MARK: - Fetch Methods
    
    /// Fetch all reports
    func fetchAllReports() throws -> [MedicalReportModel] {
        let descriptor = FetchDescriptor<MedicalReportModel>(
            sortBy: [SortDescriptor(\.uploadDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetch timeline entries
    func fetchTimelineEntries() throws -> [TimelineEntryModel] {
        let descriptor = FetchDescriptor<TimelineEntryModel>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetch all lab results
    func fetchAllLabResults() throws -> [LabResultModel] {
        let descriptor = FetchDescriptor<LabResultModel>(
            sortBy: [SortDescriptor(\.testDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetch active medications
    func fetchActiveMedications() throws -> [MedicationModel] {
        let descriptor = FetchDescriptor<MedicationModel>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
}

// MARK: - Errors

enum PipelineError: LocalizedError {
    case noDocumentProvided
    case invalidImage
    case invalidPDF
    case ocrFailed
    case noTextFound
    case imageSaveFailed
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .noDocumentProvided:
            return "No image or PDF provided"
        case .invalidImage:
            return "Invalid image format"
        case .invalidPDF:
            return "Invalid PDF document"
        case .ocrFailed:
            return "OCR processing failed"
        case .noTextFound:
            return "No text found in document"
        case .imageSaveFailed:
            return "Failed to save image"
        case .parsingFailed:
            return "Failed to parse medical data"
        }
    }
}
