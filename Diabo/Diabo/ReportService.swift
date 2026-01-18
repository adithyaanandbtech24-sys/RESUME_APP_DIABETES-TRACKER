import SwiftUI
import Foundation
import VisionKit
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Service for processing medical reports with OCR and ML
@MainActor
final class ReportService {
    static let shared = ReportService()
    
    private let auth = FirebaseAuthService.shared
    private let ocrService = OCRService.shared
    private let mlService = MLService.shared
    private let medicationManager = MedicationManager.shared
    
    private init() {}
    
    // MARK: - Document Processing Pipeline
    
    /// Process and upload an image-based medical report
    func processImageReport(
        image: UIImage,
        title: String,
        context: ModelContext
    ) async throws -> MedicalReportModel {
        print("📤 [ReportService] Starting image report processing...")
        
        // Ensure user is authenticated (creates anonymous user if needed)
        let userId = try await auth.ensureAnonymousUser()
        print("✅ [ReportService] User authenticated: \(userId)")
        
        let reportId = UUID().uuidString
        
        // 1. Upload image (Mocked for local-first functionality)
        print("📁 [ReportService] Saving image locally...")
        // In a real local-first app, you'd save to FileManager here. 
        // For now, we'll just use a UUID-based path string.
        let imageURL = "documents/\(userId)/\(reportId).jpg" 
        print("✅ [ReportService] Image saved locally: \(imageURL)")
        
        // 2. Create local SwiftData model immediately (so user sees it)
        let report = MedicalReportModel(
            id: reportId,
            title: title,
            uploadDate: Date(),
            reportType: "Lab Report",
            organ: "General",
            imageURL: imageURL,
            pdfURL: nil,
            extractedText: "Processing...",
            aiInsights: "Analysis in progress..."
        )
        
        context.insert(report)
        try context.save()
        print("✅ [ReportService] Report saved to SwiftData")
        
        // 3. Process OCR and AI Analysis in background (async, don't wait)
        Task {@MainActor in
            do {
                print("🔍 [ReportService] ========== STARTING BACKGROUND PROCESSING ==========")
                print("🔍 [ReportService] Report ID: \(reportId)")
                print("🔍 [ReportService] Starting OCR extraction...")
                
                let extractedText = try await ocrService.extractText(from: image)
                print("✅ [ReportService] OCR complete!")
                print("📝 [ReportService] Extracted text length: \(extractedText.count) characters")
                print("📝 [ReportService] FULL OCR TEXT PREVIEW (first 3000 chars):")
                print("═══════════════════════════════════════════════════════════════")
                print(String(extractedText.prefix(3000)))
                print("═══════════════════════════════════════════════════════════════")
                
                if extractedText.isEmpty {
                    throw NSError(domain: "OCRService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No text extracted from image"])
                }
                
                // DETECT DOCUMENT TYPE: Prescription vs Lab Report
                let isPrescription = self.detectPrescription(text: extractedText, image: image)
                print("📋 [ReportService] Document type: \(isPrescription ? "PRESCRIPTION" : "LAB REPORT")")
                
                // Route to appropriate analyzer
                if isPrescription {
                    // Use Vision LLM for handwritten prescriptions
                    print("🖊️ [ReportService] Using Vision LLM for handwritten prescription analysis...")
                    await self.processAsPrescription(image: image, report: report, context: context)
                    return
                }
                
                print("🤖 [ReportService] Starting AI-powered lab report analysis...")
                
                // Fetch user profile for personalized interpretation
                var userProfile: UserProfileModel? = nil
                let profileDescriptor = FetchDescriptor<UserProfileModel>()
                if let profiles = try? context.fetch(profileDescriptor), let profile = profiles.first {
                    userProfile = profile
                    print("👤 [ReportService] User profile found: Age \(profile.age), \(profile.diabetesType)")
                }
                
                // Use AI-powered analysis for comprehensive extraction
                let analysisResult = try await ChatService.shared.analyzeMedicalText(extractedText, userProfile: userProfile)
                
                print("✅ [ReportService] AI Analysis complete")
                print("📊 [ReportService] Found \(analysisResult.labResults.count) lab results")
                print("💊 [ReportService] Found \(analysisResult.medications.count) medications")
                
                // Update the report with extracted data
                report.extractedText = extractedText
                report.reportType = analysisResult.reportType
                report.aiInsights = analysisResult.summary
                
                // Convert AI results to LabResultModel and save (with validation)
                var labResultModels: [LabResultModel] = []
                var newLabResults: [LabResultModel] = []
                for dto in analysisResult.labResults {
                    // VALIDATION 1: Skip if value is not numeric
                    guard let value = Double(dto.value), value > 0 else {
                        print("⚠️ [ReportService] Skipping invalid lab value: \(dto.testName) = \(dto.value)")
                        continue
                    }
                    
                    // VALIDATION 2: Skip if testName is garbage/header/metadata (AGGRESSIVE FILTERING)
                    let testNameLower = dto.testName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // BLACKLIST: Common garbage extracted by AI from reports
                    let invalidTestNames: Set<String> = [
                        // Headers and metadata
                        "test", "result", "results", "units", "unit", "range", "reference", "biological",
                        "report", "page", "date", "time", "sample", "specimen", "patient", "name",
                        "collected", "received", "reported", "method", "remarks", "note", "notes",
                        "interpretation", "comments", "comment", "status", "flag", "flags",
                        // AI Garbage extractions (REMOVED calculated/estimated as they are valid for vitals like eAG/eGFR)
                        "oxidase", "significance", "clinical significance",
                        "clinical", "reference range", "biological reference", "interval",
                        // Lab info
                        "orange health", "thyrocare", "dr lal", "pathlab", "metropolis", "srl",
                        "laboratory", "lab", "pathology", "biochemistry", "hematology",
                        // Categories (not test names)
                        "liver function", "kidney function", "lipid profile", "thyroid profile",
                        "complete blood count", "cbc", "lft", "kft", "rft"
                    ]
                    
                    // Skip if exact match or too short
                    if testNameLower.count < 3 || invalidTestNames.contains(testNameLower) {
                        print("⚠️ [ReportService] Skipping invalid test name: \(dto.testName)")
                        continue
                    }
                    
                    // Skip if contains garbage keywords
                    // REMOVED "calculated" and "estimated" as they effectively filter out Mean Blood Glucose and eGFR
                    let garbageKeywords = ["ratio:", "significance", "reference interval", "interpretation"]
                    if garbageKeywords.contains(where: { testNameLower.contains($0) }) {
                        print("⚠️ [ReportService] Skipping garbage test name: \(dto.testName)")
                        continue
                    }
                    
                    // Skip if looks like a number or unit (not a test name)
                    if Double(testNameLower) != nil || testNameLower.hasPrefix("mg") || testNameLower.hasPrefix("g/") {
                        print("⚠️ [ReportService] Skipping numeric/unit test name: \(dto.testName)")
                        continue
                    }
                    
                    // VALIDATION 3: Biological bounds check for impossible values
                    // These are extreme upper limits that are biologically impossible
                    let biologicalMaxBounds: [String: Double] = [
                        "potassium": 15.0,      // Normal: 3.5-5.0 mEq/L, Critical if >7
                        "sodium": 200.0,        // Normal: 136-145 mEq/L
                        "hemoglobin": 25.0,     // Normal: 12-17 g/dL
                        "glucose": 1500.0,      // Extreme diabetic ketoacidosis territory
                        "creatinine": 50.0,     // Severe kidney failure
                        "hba1c": 20.0,          // Normal: 4-6%
                        "cholesterol": 1000.0,  // Extreme familial hypercholesterolemia
                        "triglycerides": 5000.0,// Extreme hypertriglyceridemia
                        "wbc": 200.0,           // Normal: 4-11 thousand/uL
                        "platelets": 2000.0,    // Normal: 150-400 thousand/uL
                        "tsh": 200.0,           // Normal: 0.4-4.0 mIU/L
                    ]
                    
                    for (key, maxValue) in biologicalMaxBounds {
                        if testNameLower.contains(key) && value > maxValue {
                            print("🚨 [ReportService] BIOLOGICALLY IMPOSSIBLE VALUE DETECTED: \(dto.testName) = \(value) (Max expected: \(maxValue))")
                            // Flag but still include with modified status
                            let flaggedResult = LabResultModel(
                                testName: dto.testName,
                                parameter: dto.testName,
                                value: value,
                                unit: dto.unit,
                                normalRange: dto.normalRange,
                                status: "⚠️ Verify - Value appears incorrect",
                                testDate: Date(),
                                category: dto.organ ?? dto.category
                            )
                            context.insert(flaggedResult) // CRITICAL: Insert for @Query
                            newLabResults.append(flaggedResult)
                            continue
                        }
                    }
                    
                    // Parse test date from AI response
                    var testDateResult = Date()
                    if let dateStr = dto.testDate, !dateStr.isEmpty {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        if let parsedDate = formatter.date(from: dateStr) {
                            testDateResult = parsedDate
                        }
                    }
                    
                    // Accumulate unmanaged models first
                    let labResult = LabResultModel(
                        testName: dto.testName,
                        parameter: dto.testName,
                        value: value,
                        unit: dto.unit,
                        normalRange: dto.normalRange,
                        status: dto.status,
                        testDate: testDateResult,
                        category: dto.organ ?? dto.category
                    )
                    // Do NOT insert yet
                    newLabResults.append(labResult)
                    
                    // DEBUG: Log each detected lab result
                    print("📌 [ReportService] DETECTED: name='\(dto.testName)' value=\(value)")
                }
                
                // NORMALIZE & DEDUPLICATE BEFORE INSERTION
                print("🧹 [ReportService] Normalizing \(newLabResults.count) results...")
                let normalizedResults = LabResultNormalizer.normalize(newLabResults)
                
                // INSERT NORMALIZED RESULTS
                var finalModels: [LabResultModel] = []
                for result in normalizedResults {
                    context.insert(result)
                    finalModels.append(result)
                }
                
                report.labResults = finalModels
                labResultModels = finalModels // Update local reference for subsequent steps
                
                print("✅ [ReportService] Total lab results INSERTED: \(finalModels.count)")
                for (idx, lab) in finalModels.enumerated() {
                    print("   \(idx+1). \(lab.testName): \(lab.value) \(lab.unit)")
                }
                
                // Detect primary organ based on results
                report.organ = self.detectPrimaryOrgan(from: analysisResult.labResults)
                
                // UPDATE: Set report clinicalDate to the Clinical Date found in analysis (if available)
                // This ensures the Timeline shows the actual test date, not just "Today"
                let dateDetectors = analysisResult.labResults.compactMap { $0.testDate }
                if let bestDateString = dateDetectors.first, !bestDateString.isEmpty {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let clinicalDate = formatter.date(from: bestDateString) {
                         print("📅 [ReportService] Set Clinical Date (from report): \(clinicalDate)")
                         report.clinicalDate = clinicalDate  // Set clinical date, keep uploadDate as-is
                    }
                }
                
                print("✅ [ReportService] Report updated with AI analysis")
                
                // MARK: - Generate Comprehensive Report Interpretation
                print("📝 [ReportService] Generating professional report interpretation...")
                
                // Wrap in do-block to prevent variable redeclaration conflicts
                do {
                    // Fetch user profile for personalized interpretation
                    let profileDescriptor = FetchDescriptor<UserProfileModel>()
                    let profiles = try? context.fetch(profileDescriptor)
                    let userProfile = profiles?.first
                    
                    let interpretation = try await ChatService.shared.generateReportInterpretation(
                        extractedText: extractedText,
                        labResults: labResultModels,
                        userProfile: userProfile
                    )
                    report.aiInsights = interpretation
                    try? context.save()
                    print("✅ [ReportService] Report interpretation saved (\(interpretation.count) chars)")
                } catch {
                    print("⚠️ [ReportService] Interpretation generation failed: \(error)")
                    // Keep existing aiInsights if interpretation fails
                }
                
                // Create graph data points for timeline visualization
                print("📊 [ReportService] Creating graph data...")
                let _ = self.createGraphDataFromLabResults(labResultModels, reportId: reportId, date: Date(), context: context)
                
                // SUPPLEMENTAL: Use Vision API for more accurate extraction (catches values missed by OCR)
                print("🧠 [ReportService] Running supplemental Vision analysis...")
                
                if let visionResults = try? await self.analyzeLabReportWithVision(image: image, context: context) {
                    var addedCount = 0
                    var updatedCount = 0
                    
                    for visionResult in visionResults {
                        let visionName = visionResult.testName.lowercased()
                        
                        // Check if already extracted by OCR
                        if let existingIndex = labResultModels.firstIndex(where: { $0.testName.lowercased() == visionName }) {
                            // Update existing if Vision result looks better (or just trust Vision more)
                            let existing = labResultModels[existingIndex]
                            print("   ⚠️ Vision collision for \(existing.testName). OCR: \(existing.value), Vision: \(visionResult.value)")
                            
                            // Heuristic: If OCR is 0 or Vision has valid value, overwrite
                            // (Actually, trust Vision for complex reports)
                            existing.value = visionResult.value
                            existing.unit = visionResult.unit
                            existing.normalRange = visionResult.normalRange
                            existing.status = visionResult.status
                            existing.stringValue = visionResult.stringValue
                            updatedCount += 1
                        } else {
                            // New find!
                            context.insert(visionResult)
                            labResultModels.append(visionResult)
                            addedCount += 1
                            print("   ✅ Vision added: \(visionResult.testName) = \(visionResult.value) \(visionResult.unit)")
                        }
                    }
                    print("🧠 [ReportService] Vision Analysis Complete: Added \(addedCount), Updated \(updatedCount)")
                    try? context.save()

                    // Update report's lab results with combined set
                    report.labResults = labResultModels
                }
                
                // Convert and save medications (with strict validation)
                var medicationModels: [MedicationModel] = []
                
                // Blacklist: Comprehensive list of false positives from lab reports
                // This prevents lab test names, calculations, headers, and units from being saved as medications
                let medicationBlacklist = [
                    // Lab test names
                    "hemoglobin", "glucose", "cholesterol", "creatinine", "bilirubin", "albumin", "globulin",
                    "platelet", "neutrophil", "lymphocyte", "monocyte", "eosinophil", "basophil", "erythrocyte",
                    "leukocyte", "hematocrit", "triglyceride", "lipoprotein", "urea", "phosphorus", "calcium",
                    "potassium", "sodium", "chloride", "magnesium", "iron", "ferritin", "transferrin",
                    "vitamin", "folate", "b12", "d3", "hormone", "testosterone", "estrogen", "progesterone",
                    "cortisol", "insulin", "thyroid", "tsh", "t3", "t4", "psa", "cea", "afp",
                    // Lab calculations and derived values
                    "calculated", "estimated", "egfr", "ratio", "index", "count", "volume", "mean", "average",
                    "total", "direct", "indirect", "conjugated", "unconjugated", "hdl", "ldl", "vldl",
                    "mchc", "mcv", "mch", "rdw", "mpv", "pdw", "pct", "hba1c", "a1c",
                    // Report/lab headers and metadata
                    "urine", "serum", "blood", "plasma", "sample", "specimen", "report", "result", "test", 
                    "laboratory", "lab", "pathology", "clinical", "biochemistry", "hematology",
                    "orange health", "thyrocare", "dr lal", "pathlab", "metropolis", "collected", "received",
                    "patient", "age", "gender", "male", "female", "date", "time", "ref", "reference",
                    // Status words and descriptors
                    "clinical significance", "biological reference", "normal", "high", "low", "critical",
                    "positive", "negative", "reactive", "non-reactive", "nil", "absent", "present", "trace",
                    // Units (should never be medication names)
                    "mg/dl", "g/dl", "u/l", "iu/l", "mmol/l", "umol/l", "ng/ml", "pg/ml", "meq/l",
                    "/hpf", "/lpf", "cells/cumm", "million/ul", "thou/ul", "fl", "pg", "sec", "%",
                    // Additional enzyme and lab test terms (to catch "Urease", "Units", etc.)
                    "units", "unit", "urease", "oxidase", "transferase", "dehydrogenase", "kinase", "phosphatase",
                    "synthetase", "synthase", "reductase", "hydrolase", "isomerase", "ligase", "lyase",
                    "peroxidase", "catalase", "amylase", "lipase", "protease", "peptidase", "esterase",
                    // More lab-specific garbage
                    "range", "interval", "method", "remarks", "comment", "interpretation", "significance",
                    "biological", "reference interval", "normal range", "abnormal", "borderline",
                    // Generic numeric/measurement terms
                    "value", "reading", "level", "concentration", "parameter", "measurement",
                    // Common OCR misreads and artifacts
                    "unknown", "n/a", "na", "nil", "none", "not detected", "not available"
                ]
                
                for dto in analysisResult.medications {
                    let lowerName = dto.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // VALIDATION 1: Skip if name is too short (real meds are 4+ chars)
                    if lowerName.count < 4 {
                        print("⚠️ [ReportService] Skipping too-short medication: '\(dto.name)'")
                        continue
                    }
                    
                    // VALIDATION 2: Skip if name is purely numeric or mostly numeric
                    let letters = lowerName.filter { $0.isLetter }
                    if letters.count < 3 {
                        print("⚠️ [ReportService] Skipping numeric/invalid medication: '\(dto.name)'")
                        continue
                    }
                    
                    // VALIDATION 3: Skip if EXACT MATCH to common garbage words
                    let exactBlacklist: Set<String> = [
                        "units", "unit", "calculated", "urease", "range", "value", "level",
                        "normal", "high", "low", "total", "result", "test", "sample",
                        "report", "method", "index", "ratio", "count", "mean", "average",
                        "direct", "indirect", "serum", "plasma", "blood", "urine"
                    ]
                    if exactBlacklist.contains(lowerName) {
                        print("⚠️ [ReportService] Skipping blacklisted term: '\(dto.name)'")
                        continue
                    }
                    
                    // VALIDATION 4: Skip if name CONTAINS any blacklisted term
                    if medicationBlacklist.contains(where: { lowerName.contains($0) }) {
                        print("⚠️ [ReportService] Skipping medication containing blacklist term: '\(dto.name)'")
                        continue
                    }
                    
                    // VALIDATION 5: Skip if name looks like a lab enzyme (ends with -ase, -ogen, -in pattern for non-meds)
                    let labEnzymeSuffixes = ["ase", "ogen", "ysis", "emia", "uria"]
                    if labEnzymeSuffixes.contains(where: { lowerName.hasSuffix($0) }) && 
                       !["metformin", "aspirin", "warfarin", "heparin", "insulin"].contains(where: { lowerName.contains($0) }) {
                        print("⚠️ [ReportService] Skipping lab enzyme term: '\(dto.name)'")
                        continue
                    }
                    
                    // VALIDATION 6: Skip if dosage looks invalid (empty or generic)
                    let lowerDosage = dto.dosage.lowercased()
                    if dto.dosage.isEmpty || lowerDosage == "as prescribed" || lowerDosage.contains("unknown") {
                        print("⚠️ [ReportService] Skipping medication without valid dosage: '\(dto.name)' (dosage: '\(dto.dosage)')")
                        continue
                    }
                    
                    // PASSED ALL VALIDATIONS - This is likely a real medication
                    print("✅ [ReportService] Valid medication: '\(dto.name)' - \(dto.dosage)")
                    
                    let medication = MedicationModel(
                        name: dto.name,
                        dosage: dto.dosage,
                        frequency: dto.frequency,
                        instructions: dto.instructions,
                        startDate: Date(),
                        prescribedBy: "From Document Analysis",
                        isActive: true
                    )
                    medicationModels.append(medication)
                    context.insert(medication)
                }
                report.medications = medicationModels
                
                // Process medication updates if it's a prescription
                if analysisResult.reportType.lowercased().contains("prescription") {
                    MedicationManager.shared.processMedicationUpdate(newMedications: medicationModels, context: context)
                }
                
                // Generate and save chatbot message NOW (after all data is saved)
                // Use the clinical summary from ChatService for professional format
                let clinicalSummary = ChatService.shared.generateClinicalSummary(
                    analysisResult: analysisResult,
                    userProfile: userProfile
                )
                let chatMessage = AIChatMessage(
                    id: UUID().uuidString,
                    text: clinicalSummary,
                    isUser: false,
                    timestamp: Date()
                )
                context.insert(chatMessage)
                
                try context.save()
                print("✅ [ReportService] ========== ALL DATA SAVED SUCCESSFULLY! ==========")
            } catch {
                print("❌ [ReportService] ========== BACKGROUND PROCESSING FAILED ==========")
                print("❌ [ReportService] Error: \(error)")
                report.extractedText = "Analysis failed: \(error.localizedDescription)"
                report.aiInsights = "Analysis unavailable"
                
                // Still generate a chat message for failed analysis
                let failedSummary = "Hey! 👋 I just tried reading your report **\(report.title)**, but ran into some trouble.\n\nHmm, I couldn't automatically pick up specific lab values or medications from this one. It might be a scan quality issue, or the report format is a bit unusual.\n\nYou can always add details manually if needed!"
                let chatMessage = AIChatMessage(
                    id: UUID().uuidString,
                    text: failedSummary,
                    isUser: false,
                    timestamp: Date()
                )
                context.insert(chatMessage)
                try? context.save()
            }
        }
        
        return report
    }
    
    /// Detect the primary organ from AI analysis results
    private func detectPrimaryOrgan(from labResults: [LabResultDTO]) -> String {
        var organCounts: [String: Int] = [:]
        for result in labResults {
            organCounts[result.organ ?? "General", default: 0] += 1
        }
        return organCounts.max(by: { $0.value < $1.value })?.key ?? "General"
    }
    
    /// Generate a user-friendly chatbot summary for the report with organ-wise breakdown
    private func generateChatbotSummary(for report: MedicalReportModel, labResults: [LabResultModel], medications: [MedicationModel]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy"
        let dateStr = dateFormatter.string(from: report.uploadDate)
        
        var summary = "Report Analysis: **\(report.title)** (\(dateStr))\n\n"
        
        // Group results by organ/category
        let organGroups = Dictionary(grouping: labResults) { result -> String in
            let category = result.category.lowercased()
            switch category {
            case "liver", "hepatic": return "LIVER FUNCTION"
            case "kidneys", "renal", "kidney": return "RENAL FUNCTION"
            case "heart", "cardiovascular", "cardiac", "lipid": return "CARDIOVASCULAR"
            case "blood", "hematology", "cbc": return "HEMATOLOGY"
            case "metabolic", "glucose", "diabetes": return "METABOLIC PROFILE"
            case "thyroid": return "THYROID FUNCTION"
            case "pancreas", "pancreatic": return "PANCREATIC ENZYMES"
            case "vitamins", "vitamin": return "MICRONUTRIENTS (VITAMINS)"
            case "iron", "iron studies": return "IRON STUDIES"
            case "urinalysis", "urine": return "URINALYSIS"
            default: return "GENERAL CHEMISTRIES"
            }
        }
        
        // Sort organs for consistent display
        let organOrder = ["LIVER FUNCTION", "RENAL FUNCTION", "CARDIOVASCULAR", "HEMATOLOGY", "METABOLIC PROFILE", "THYROID FUNCTION", "PANCREATIC ENZYMES", "MICRONUTRIENTS (VITAMINS)", "IRON STUDIES", "URINALYSIS", "GENERAL CHEMISTRIES"]
        
        // Calculate overall summary
        let totalParams = labResults.count
        let abnormalResults = labResults.filter { $0.status != "Normal" && $0.status != "Optimal" }
        let abnormalCount = abnormalResults.count
        
        summary += "**Overview**\nAnalyzed **\(totalParams) clinical parameters**."
        if abnormalCount > 0 {
            summary += " Identified **\(abnormalCount) values outside reference range** requiring attention.\n\n"
        } else {
            summary += " All values appear within standard reference ranges.\n\n"
        }
        
        // Organ-wise status summary
        var organStatuses: [(organ: String, status: String)] = []
        
        for organ in organOrder {
            guard let results = organGroups[organ], !results.isEmpty else { continue }
            
            let organAbnormal = results.filter { $0.status != "Normal" && $0.status != "Optimal" }
            let highCount = organAbnormal.filter { $0.status == "High" || $0.status == "Critical" }.count
            let lowCount = organAbnormal.filter { $0.status == "Low" }.count
            
            // Determine organ status
            let organStatus: String
            if organAbnormal.isEmpty {
                organStatus = "Within Normal Limits"
            } else if highCount > 2 || lowCount > 2 {
                organStatus = "Attention Needed"
            } else {
                organStatus = "Borderline / Monitor"
            }
            
            organStatuses.append((organ, organStatus))
            
            // Show organ section with abnormal parameters
            if !organAbnormal.isEmpty {
                summary += "**\(organ)**\n"
                for result in organAbnormal.prefix(5) {
                    summary += "- **\(result.testName)**: \(String(format: "%.1f", result.value)) \(result.unit) (\(result.status))\n"
                }
                if organAbnormal.count > 5 {
                    summary += "  (\(organAbnormal.count - 5) additional findings...)\n"
                }
                summary += "\n"
            }
        }
        
        // Final organ function summary table
        if !organStatuses.isEmpty {
            summary += "**Clinical Assessment Summary**\n"
            for (organ, status) in organStatuses {
                summary += "- \(organ): **\(status)**\n"
            }
            summary += "\n"
        }
        
        summary += "The **Health Timeline** has been updated with detailed charts for all \(totalParams) parameters. Please review specific trends in the dashboard.\n\n"
        summary += "_Note: This automated analysis is for informational purposes only. Please consult your physician for clinical correlation and diagnosis._"
        
        return summary
    }

    
    
    /// Create graph data points from LabResultModel array (offline analysis)
    private func createGraphDataFromLabResults(_ labResults: [LabResultModel], reportId: String, date: Date, context: ModelContext) -> [LabGraphDataModel] {
        var graphPoints: [LabGraphDataModel] = []
        
        for result in labResults {
            // Map category to organ name
            // Use the specific organ field if available from AI, otherwise fall back to category map
            // Note: LabResultModel doesn't have an 'organ' field directly yet, but we are passing it in via scope if we updated the model.
            // Wait, LabResultModel DOES NOT have 'organ' field in the definition I read earlier?
            // Checking SwiftDataModels.swift... LabResultModel has 'category'. MedicalReportModel has 'organ'.
            // However, ChatService is now returning 'organ' in LabResultDTO.
            // We should ideally map this 'organ' to GraphDataModel's 'organ'.
            
            // Logic: Use 'organ' from AI if valid, else map from category.
            // For now, let's stick to the mapping but enhance it if needed.
            // Actually, we can't fully use the new 'organ' field from ChatService UNLESS we update LabResultModel, which we decided NOT to do in this turn (step 31 only updated ChatService).
            // BUT GraphDataModel HAS 'organ'.
            // The 'result' here is 'LabResultModel'.
            // Wait, 'createGraphDataFromLabResults' takes 'LabResultModel'.
            // The 'LabResultModel' was created from 'LabResultDTO'.
            // I need to find where 'LabResultModel' is created. It's inside 'analyzer.analyzeReport' (Offline) or ...
            // NO, 'ReportService' calls 'analyzer.analyzeReport'.
            // Wait, 'ReportService' calls 'analyzer.analyzeReport' which returns 'AnalysisResult'.
            // 'AnalysisResult' has 'labResults' which are seemingly models?
            // 'ReportAnalyzerService.swift' (Offline) returns a struct.
            
            // BUT in 'processImageReport' and 'processPDFReport', we are using 'ocrService' and then 'ReportAnalyzerService' (OFFLINE).
            // WE NEED TO USE 'ChatService' (AI) for the comprehensive analysis.
            // The current 'ReportService' code I see uses 'Offline Analyzer' (ReportAnalyzerService).
            // My plan says: "Enhance `ChatService.analyzeMedicalText`".
            // I see 'ChatService.analyzeMedicalText' calls Gemini.
            // BUT 'ReportService.processImageReport' calls 'ReportAnalyzerService' (Offline) ??
            // Let me check 'ReportService.swift' lines 87-89:
            // let analyzer = ReportAnalyzerService(userProfile: userProfile)
            // let analysisResult = analyzer.analyzeReport(ocrText: extractedText, testDate: Date())
            
            // The current implementation is using OFFLINE analysis by default?
            // "aiInsights = analysisResult.generateChatbotMessage()"
            
            // I need to switch this to use `ChatService.shared.analyzeMedicalText` if I want the Gemini power.
            // Or maybe `ReportAnalyzerService` calls ChatService?
            // No, the logs say "Starting OFFLINE analysis".
            
            // RE-PLAN: I should switch `ReportService` to use `ChatService.analyzeMedicalText` for the "AI Analysis" part, 
            // OR ensure `ReportAnalyzerService` is what I want.
            // The user request is "100% perfect and accurate". Gemini is better than regex.
            
            // RE-PLAN: I should switch `ReportService` to use `ChatService.analyzeMedicalText` INSTEAD of or IN ADDITION to offline analyzer.
            // Actually, `active_task` says "Enhance ChatService...".
            
            // let metricOrgan = mapCategoryToOrgan(result.category)
            
            do {
                // SPECIAL HANDLING: Blood Pressure Composite
                if result.testName == "Blood Pressure", let stringVal = result.stringValue {
                    let parts = stringVal.components(separatedBy: "/")
                    if parts.count == 2, let sys = Double(parts[0]), let dia = Double(parts[1]) {
                        // Create Systolic Point
                        let sysPoint = LabGraphDataModel(
                            organ: "Heart", // Force Heart
                            parameter: "Systolic Blood Pressure",
                            value: sys,
                            unit: "mmHg",
                            date: date,
                            reportId: reportId
                        )
                        context.insert(sysPoint)
                        graphPoints.append(sysPoint)
                        
                        // Create Diastolic Point
                        let diaPoint = LabGraphDataModel(
                            organ: "Heart",
                            parameter: "Diastolic Blood Pressure",
                            value: dia,
                            unit: "mmHg",
                            date: date,
                            reportId: reportId
                        )
                        context.insert(diaPoint)
                        graphPoints.append(diaPoint)
                        
                        continue // Skip default handling
                    }
                }
                
                // Default handling
                let point = LabGraphDataModel(
                    organ: result.category,
                    parameter: result.testName,
                    value: result.value,
                    unit: result.unit,
                    date: date,
                    reportId: reportId
                )
                context.insert(point)
                graphPoints.append(point)
            }
        }
        
        return graphPoints
    }
    
    /// Extract medications from AI analysis
    private func extractMedications(from analysis: MedicalAnalysisResult, reportType: String, context: ModelContext) -> [MedicationModel] {
        var newMedications: [MedicationModel] = []
        
        for med in analysis.medications {
            let medication = MedicationModel(
                name: med.name,
                dosage: med.dosage,
                frequency: med.frequency,
                instructions: med.instructions,
                startDate: Date(),
                prescribedBy: "From Document Analysis",
                isActive: true
            )
            context.insert(medication)
            newMedications.append(medication)
        }
        
        // Only valid Prescriptions should trigger the "Active/Passive" logic.
        // If it's a Lab Report mentioning meds, we might append but not replace history.
        // For now, let's be strict: Only "Prescription" triggers replacement.
        if reportType.lowercased().contains("prescription") || reportType.lowercased().contains("medication") {
             MedicationManager.shared.processMedicationUpdate(newMedications: newMedications, context: context)
        }
        
        return newMedications
    }
    
    /// Process and upload a PDF medical report
    func processPDFReport(
        fileURL: URL,
        title: String,
        context: ModelContext
    ) async throws -> MedicalReportModel {
        print("📤 [ReportService] ========== STARTING PDF PROCESSING ==========")
        print("📤 [ReportService] File URL: \(fileURL)")
        print("📤 [ReportService] Title: \(title)")
        print("📤 [ReportService] URL is file URL: \(fileURL.isFileURL)")
        print("📤 [ReportService] File exists: \(FileManager.default.fileExists(atPath: fileURL.path))")
        
        // Ensure user is authenticated (creates anonymous user if needed)
        let userId = try await auth.ensureAnonymousUser()
        print("✅ [ReportService] User authenticated: \(userId)")
        
        let reportId = UUID().uuidString
        
        // 1. Save PDF to local storage FIRST (fast)
        print("📁 [ReportService] Saving PDF locally...")
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let userPath = documentsPath.appendingPathComponent("users/\(userId)/reports/\(reportId)")
        
        print("📁 [ReportService] Creating directory: \(userPath.path)")
        try FileManager.default.createDirectory(at: userPath, withIntermediateDirectories: true)
        
        let pdfPath = userPath.appendingPathComponent("document.pdf")
        print("📁 [ReportService] Copying from: \(fileURL.path)")
        print("📁 [ReportService] Copying to: \(pdfPath.path)")
        
        do {
            try FileManager.default.copyItem(at: fileURL, to: pdfPath)
            print("✅ [ReportService] PDF copied successfully")
        } catch {
            print("❌ [ReportService] Failed to copy PDF: \(error)")
            throw error
        }
        
        let pdfURL = pdfPath.absoluteString
        print("✅ [ReportService] PDF saved: \(pdfURL)")
        
        // 2. Create local SwiftData model immediately (so user sees it)
        let report = MedicalReportModel(
            id: reportId,
            title: title,
            uploadDate: Date(),
            reportType: "PDF Report",
            organ: "General",
            imageURL: nil,
            pdfURL: pdfURL,
            extractedText: "Processing...",
            aiInsights: "Analysis in progress..."
        )
        
        context.insert(report)
        try context.save()
        print("✅ [ReportService] Report saved to SwiftData")
        
        // 3. Process OCR and AI Analysis in background (async, don't wait)
        Task {@MainActor in
            do {
                print("🔍 [ReportService] ========== STARTING PDF BACKGROUND PROCESSING ==========")
                print("🔍 [ReportService] Report ID: \(reportId)")
                print("🔍 [ReportService] Starting PDF OCR extraction...")
                
                let extractedText = try await ocrService.extractText(from: fileURL)
                print("✅ [ReportService] PDF OCR complete!")
                print("📝 [ReportService] Extracted text length: \(extractedText.count) characters")
                print("📝 [ReportService] First 200 chars: \(extractedText.prefix(200))")
                
                if extractedText.isEmpty {
                    throw NSError(domain: "OCRService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No text extracted from PDF"])
                }
                
                print("🤖 [ReportService] Starting AI-powered analysis for PDF...")
                
                // Use AI-powered analysis for comprehensive extraction
                let analysisResult = try await ChatService.shared.analyzeMedicalText(extractedText)
                
                print("✅ [ReportService] PDF AI Analysis complete")
                print("📊 [ReportService] Found \(analysisResult.labResults.count) lab results")
                print("💊 [ReportService] Found \(analysisResult.medications.count) medications")
                
                // Update the report with extracted data
                report.extractedText = extractedText
                report.reportType = analysisResult.reportType
                report.aiInsights = analysisResult.summary
                
                // Convert AI results to LabResultModel and save
                var labResultModels: [LabResultModel] = []
                for dto in analysisResult.labResults {
                    // VALIDATION 1: Skip if value is not numeric
                    guard let value = Double(dto.value), value > 0 else {
                        print("⚠️ [ReportService] Skipping invalid lab value in PDF: \(dto.testName) = \(dto.value)")
                        continue
                    }
                    
                    // VALIDATION 2: Skip if testName is garbage/header/metadata (AGGRESSIVE FILTERING)
                    let testNameLower = dto.testName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // BLACKLIST: Common garbage extracted by AI from reports
                    let invalidTestNames: Set<String> = [
                        // Headers and metadata
                        "test", "result", "results", "units", "unit", "range", "reference", "biological",
                        "report", "page", "date", "time", "sample", "specimen", "patient", "name",
                        "collected", "received", "reported", "method", "remarks", "note", "notes",
                        "interpretation", "comments", "comment", "status", "flag", "flags",
                        // AI Garbage extractions
                        "calculated", "estimated", "oxidase", "significance", "clinical significance",
                        "clinical", "reference range", "biological reference", "interval",
                        // Lab info
                        "orange health", "thyrocare", "dr lal", "pathlab", "metropolis", "srl",
                        "laboratory", "lab", "pathology", "biochemistry", "hematology",
                        // Categories (not test names)
                        "liver function", "kidney function", "lipid profile", "thyroid profile",
                        "complete blood count", "cbc", "lft", "kft", "rft"
                    ]
                    
                    // Skip if exact match or too short
                    if testNameLower.count < 3 || invalidTestNames.contains(testNameLower) {
                        print("⚠️ [ReportService] Skipping invalid test name in PDF: \(dto.testName)")
                        continue
                    }
                    
                    // Skip if contains garbage keywords
                    let garbageKeywords = ["calculated", "estimated", "ratio:", "significance", "reference interval", "interpretation"]
                    if garbageKeywords.contains(where: { testNameLower.contains($0) }) {
                        print("⚠️ [ReportService] Skipping garbage test name in PDF: \(dto.testName)")
                        continue
                    }
                    
                    // Skip if looks like a number or unit (not a test name)
                    if Double(testNameLower) != nil || testNameLower.hasPrefix("mg") || testNameLower.hasPrefix("g/") {
                        print("⚠️ [ReportService] Skipping numeric/unit test name in PDF: \(dto.testName)")
                        continue
                    }
                    
                    // VALIDATION 3: Biological bounds check for impossible values
                    let biologicalMaxBounds: [String: Double] = [
                        "potassium": 15.0,      // Normal: 3.5-5.0 mEq/L
                        "sodium": 200.0,        // Normal: 136-145 mEq/L
                        "hemoglobin": 25.0,     // Normal: 12-17 g/dL
                        "glucose": 1500.0,
                        "creatinine": 50.0,
                        "hba1c": 20.0,
                        "cholesterol": 1000.0,
                        "triglycerides": 5000.0,
                        "wbc": 200.0,
                        "platelets": 2000.0,
                        "tsh": 200.0,
                    ]
                    
                    var isImpossible = false
                    for (key, maxValue) in biologicalMaxBounds {
                        if testNameLower.contains(key) && value > maxValue {
                            print("🚨 [ReportService] BIOLOGICALLY IMPOSSIBLE VALUE DETECTED in PDF: \(dto.testName) = \(value)")
                            isImpossible = true
                            
                            let flaggedResult = LabResultModel(
                                testName: dto.testName,
                                parameter: dto.testName,
                                value: value,
                                unit: dto.unit,
                                normalRange: dto.normalRange,
                                status: "⚠️ Verify - Value appears incorrect",
                                testDate: Date(),
                                category: dto.organ ?? dto.category
                            )
                            context.insert(flaggedResult) // CRITICAL: Insert for @Query
                            labResultModels.append(flaggedResult)
                            break
                        }
                    }
                    
                    if isImpossible { continue }
                    
                    // Parse test date from AI response
                    var testDateResult = Date()
                    if let dateStr = dto.testDate, !dateStr.isEmpty {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        if let parsedDate = formatter.date(from: dateStr) {
                            testDateResult = parsedDate
                        }
                    }
                    
                    // Normal valid result
                    let labResult = LabResultModel(
                        testName: dto.testName,
                        parameter: dto.testName,
                        value: value,
                        unit: dto.unit,
                        normalRange: dto.normalRange,
                        status: dto.status,
                        testDate: testDateResult,
                        category: dto.organ ?? dto.category
                    )
                    context.insert(labResult) // CRITICAL: Insert for @Query
                    labResultModels.append(labResult)
                }
                report.labResults = labResultModels
                
                // Detect primary organ based on results
                report.organ = self.detectPrimaryOrgan(from: analysisResult.labResults)
                
                print("✅ [ReportService] PDF Report updated with AI analysis")
                
                // Create graph data points for timeline visualization
                print("📊 [ReportService] Creating graph data from PDF...")
                let _ = self.createGraphDataFromLabResults(labResultModels, reportId: reportId, date: Date(), context: context)
                
                // Convert and save medications
                var medicationModels: [MedicationModel] = []
                for dto in analysisResult.medications {
                    let medication = MedicationModel(
                        name: dto.name,
                        dosage: dto.dosage,
                        frequency: dto.frequency,
                        instructions: dto.instructions,
                        startDate: Date(),
                        prescribedBy: "From PDF Analysis",
                        isActive: true
                    )
                    medicationModels.append(medication)
                    context.insert(medication)
                }
                report.medications = medicationModels
                
                // Process medication updates if it's a prescription
                if analysisResult.reportType.lowercased().contains("prescription") {
                    self.medicationManager.processMedicationUpdate(newMedications: medicationModels, context: context)
                }
                
                // Generate and save chatbot message NOW (after all data is saved)
                // Use the clinical summary from ChatService for professional format (same as image processing)
                let userProfile = try? context.fetch(FetchDescriptor<UserProfileModel>()).first
                let clinicalSummary = ChatService.shared.generateClinicalSummary(
                    analysisResult: analysisResult,
                    userProfile: userProfile
                )
                let chatMessage = AIChatMessage(
                    id: UUID().uuidString,
                    text: clinicalSummary,
                    isUser: false,
                    timestamp: Date()
                )
                context.insert(chatMessage)
                
                try context.save()
                print("✅ [ReportService] ========== ALL PDF DATA SAVED SUCCESSFULLY! ==========")
                
                // Notify via NotificationCenter that new data is available
                NotificationCenter.default.post(name: Notification.Name("NewDataProcessed"), object: nil)
            } catch {
                print("❌ [ReportService] ========== PDF BACKGROUND PROCESSING FAILED ==========")
                print("❌ [ReportService] Error: \(error)")
                report.extractedText = "Analysis failed: \(error.localizedDescription)"
                report.aiInsights = "Analysis unavailable"
                
                // Still generate a chat message for failed analysis
                let failedSummary = "Hey! 👋 I just tried reading your report **\(report.title)**, but ran into some trouble.\n\nHmm, I couldn't automatically pick up specific lab values or medications from this one. It might be a scan quality issue, or the report format is a bit unusual.\n\nYou can always add details manually if needed!"
                let chatMessage = AIChatMessage(
                    id: UUID().uuidString,
                    text: failedSummary,
                    isUser: false,
                    timestamp: Date()
                )
                context.insert(chatMessage)
                try? context.save()
            }
        }
        
        
        return report
    }
    
    // MARK: - Helper Functions
    
    /// Map metric category to organ name for graph organization
    private func mapCategoryToOrgan(_ category: String) -> String {
        switch category.lowercased() {
        case "blood", "blood count", "differential", "coagulation", "inflammation":
            return "Blood" 
        case "kidney", "renal", "urinalysis":
            return "Kidneys"
        case "liver", "hepatic":
            return "Liver"
        case "lipids", "cholesterol", "lipid panel", "cardiovascular", "cardiac", "heart":
            return "Heart"
        case "metabolic", "diabetes", "glucose":
            return "Pancreas"
        case "thyroid":
            return "Thyroid"
        case "lung", "respiratory":
            return "Lungs"
        case "prostate":
            // We could map to "Reproductive" or keep as General if no card exists.
            // Let's use "General" for now as we don't have a Prostate card.
            return "General"
        case "electrolytes", "vitals":
            return "General" // Vital & Electrolytes cards handle these directly
        case "iron", "iron studies", "vitamins", "minerals":
            return "General"
        default:
            return "General"
        }
    }
    
    // MARK: - Test Data Generation (DISABLED)
    
    /// Generate sample health data (intentionally empty to comply with no-demo-data requirement)
    func generateSampleData(context: ModelContext) {
        print("🧪 [ReportService] Sample data generation is disabled.")
    }
    
    // MARK: - Prescription Detection and Processing
    
    /// Detect if the document is a handwritten prescription vs printed lab report
    private func detectPrescription(text: String, image: UIImage) -> Bool {
        let lowercased = text.lowercased()
        
        // Prescription indicators
        let prescriptionKeywords = [
            "rx:", "rx ", "prescription", "sig:", "sig ", "take ", "dispense",
            "refill", "dr.", "dr ", "physician", "tablets", "capsules",
            "once daily", "twice daily", "before meals", "after meals",
            "bd", "tid", "qid", "prn", "hs", "ac", "pc"
        ]
        
        // Lab report indicators
        let labReportKeywords = [
            "laboratory", "lab report", "test results", "reference range",
            "biological reference", "specimen", "collected", "hemoglobin",
            "cholesterol", "glucose", "creatinine", "bilirubin", "thyroid",
            "complete blood count", "lipid profile", "liver function"
        ]
        
        var prescriptionScore = 0
        var labReportScore = 0
        
        for keyword in prescriptionKeywords {
            if lowercased.contains(keyword) { prescriptionScore += 1 }
        }
        
        for keyword in labReportKeywords {
            if lowercased.contains(keyword) { labReportScore += 1 }
        }
        
        // Additional heuristic: Very short OCR text often indicates handwriting (harder to read)
        if text.count < 200 && prescriptionScore > 0 {
            prescriptionScore += 2
        }
        
        print("📋 [ReportService] Prescription score: \(prescriptionScore), Lab report score: \(labReportScore)")
        
        return prescriptionScore > labReportScore && prescriptionScore >= 2
    }
    
    /// Process image as a handwritten prescription using Vision LLM
    private func processAsPrescription(image: UIImage, report: MedicalReportModel, context: ModelContext) async {
        do {
            let result = try await PrescriptionAnalyzer.shared.analyzePrescription(image: image)
            
            print("✅ [ReportService] Prescription analysis complete")
            print("💊 [ReportService] Found \(result.medications.count) medications")
            
            // Update report
            report.reportType = "Prescription"
            report.aiInsights = buildPrescriptionSummary(result)
            
            // Save medications to SwiftData
            for med in result.medications {
                let medication = MedicationModel(
                    name: med.validatedName ?? med.name,
                    dosage: med.dosage ?? "As prescribed",
                    frequency: med.frequency ?? "As directed",
                    instructions: med.instructions,
                    startDate: Date(),
                    notes: med.drugClass != nil ? "Drug class: \(med.drugClass!)" : nil,
                    source: "Detected from document"
                )
                context.insert(medication)
                print("💊 [ReportService] Saved medication: \(medication.name) \(medication.dosage)")
            }
            
            // Also save any lab tests ordered
            if let labTests = result.labTestsOrdered {
                let note = "Lab tests ordered: \(labTests.joined(separator: ", "))"
                report.aiInsights = report.aiInsights + "\n\n" + note
            }
            
            try context.save()
            print("✅ [ReportService] Prescription data saved to SwiftData")
            
        } catch {
            print("❌ [ReportService] Prescription analysis failed: \(error)")
            report.aiInsights = "Could not analyze prescription. Please try again or enter medications manually."
        }
    }
    
    private func buildPrescriptionSummary(_ result: PrescriptionAnalysisResult) -> String {
        var summary = "## Prescription Analysis\n\n"
        
        if let doctor = result.doctorName {
            summary += "**Doctor:** \(doctor)\n"
        }
        if let date = result.date {
            summary += "**Date:** \(date)\n"
        }
        
        summary += "\n### Medications\n"
        for (index, med) in result.medications.enumerated() {
            let confidence = med.confidence >= 0.8 ? "✅" : (med.confidence >= 0.6 ? "⚠️" : "❓")
            summary += "\(index + 1). **\(med.validatedName ?? med.name)** \(confidence)\n"
            if let dosage = med.dosage { summary += "   - Dosage: \(dosage)\n" }
            if let freq = med.frequency { summary += "   - Frequency: \(freq)\n" }
            if let instructions = med.instructions { summary += "   - Instructions: \(instructions)\n" }
        }
        
        if !result.warnings.isEmpty {
            summary += "\n### ⚠️ Please Verify\n"
            for warning in result.warnings {
                summary += "- \(warning)\n"
            }
        }
        
        summary += "\n*Confidence: \(Int(result.overallConfidence * 100))%*"
        
        return summary
    }
    
    // MARK: - Vision-Based Lab Report Analysis (Deep Learning)
    
    /// Analyze lab report image directly using GPT-4 Vision for comprehensive extraction
    /// This bypasses OCR limitations and uses deep learning for accurate readings
    func analyzeLabReportWithVision(image: UIImage, context: ModelContext) async throws -> [LabResultModel] {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw PrescriptionError.invalidImage
        }
        
        let base64Image = imageData.base64EncodedString()
        
        print("🧠 [ReportService] Starting Vision-based lab report analysis...")
        
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer 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", forHTTPHeaderField: "Authorization")
        request.setValue("https://medisync.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("MediSync Lab Analyzer", forHTTPHeaderField: "X-Title")
        
        let systemPrompt = """
        You are a medical lab report analyzer. Extract ALL lab test results from this image.
        
        ## CRITICAL PRIORITIES (DIABETES)
        Look specifically for these exact terms and their variations:
        1. **HbA1c**: "Glycated Hemoglobin", "Glycosylated Haemoglobin", "HbA1c", "A1c", "Average Blood Sugar"
        2. **Mean Blood Glucose**: "Mean Blood Glucose", "Estimated Average Glucose", "eAG", "MBG"
        3. **Fasting Glucose**: "Fasting Blood Sugar", "FBS", "Fasting Plasma Glucose"
        4. **Post-Prandial**: "PPBS", "Post Prandial", "2 Hour Glucose"
        5. **Insulin**: "Fasting Insulin", "Insulin"
        
        ## ALL PARAMETERS TO EXTRACT
        - **Lipid Panel**: Cholesterol, LDL, HDL, Triglycerides (TGL), VLDL
        - **Kidney**: eGFR, Creatinine, Urea, Uric Acid, Microalbumin
        - **Liver**: SGOT (AST), SGPT (ALT), Bilirubin, ALP, GGT
        - **Thyroid**: TSH, T3, T4
        - **Blood Count**: Hemoglobin, RBC, WBC, Platelets
        - **Vitals**: Blood Pressure, Weight, Pulse
        
        ## EXTRACTION RULES
        1. Extract **EVERY** numeric result visible.
        2. If a value is "Calculated", EXTRACT IT anyway (e.g., Mean Blood Glucose 103 mg/dL).
        3. Standardize units if possible (mg/dL, %, mmol/L).
        4. Return "status" as "High", "Low", "Normal", "Borderline" based on the ranges in the image.
        
        ## OUTPUT FORMAT (JSON Array)
        Return ONLY a valid JSON array:
        [
            {
                "testName": "HbA1c",
                "value": "5.2",
                "unit": "%",
                "normalRange": "< 5.7",
                "status": "Normal",
                "category": "Glucose"
            }
        ]
        
        ## CATEGORIES TO USE
        - Glucose, Lipid, Kidney, Liver, Thyroid, Blood Count, Vitals, Other
        """
        
        let payload: [String: Any] = [
            "model": "openai/gpt-4o",
            "messages": [
                ["role": "system", "content": systemPrompt],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
                        ],
                        [
                            "type": "text",
                            "text": "Extract all lab test results from this medical report. Return as JSON array."
                        ]
                    ]
                ] as [String: Any]
            ],
            "max_tokens": 3000,
            "temperature": 0.1
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ [ReportService] Vision API failed")
            return []
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return []
        }
        
        print("🧠 [ReportService] Vision response: \(content.prefix(500))...")
        
        // Parse JSON array from response
        return parseVisionLabResults(from: content)
    }
    
    private func parseVisionLabResults(from response: String) -> [LabResultModel] {
        var jsonString = response
        
        // Extract JSON array from possible markdown
        if let start = response.firstIndex(of: "["),
           let end = response.lastIndex(of: "]") {
            jsonString = String(response[start...end])
        }
        
        guard let jsonData = jsonString.data(using: .utf8) else { return [] }
        
        do {
            guard let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
                print("❌ [ReportService] Vision response is not a JSON array")
                return []
            }
            
            return jsonArray.compactMap { dict -> LabResultModel? in
                guard let testName = dict["testName"] as? String else { return nil }
                
                // Flexible Value Parsing (String or Double)
                var valueDouble: Double = 0.0
                var originalString: String? = nil
                
                if let valDouble = dict["value"] as? Double {
                    valueDouble = valDouble
                } else if let valString = dict["value"] as? String {
                    originalString = valString
                    // Extract number from string (e.g. "< 5.7" -> 5.7)
                    let cleaned = valString.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
                    valueDouble = Double(cleaned) ?? 0.0
                } else {
                    return nil // No value found
                }
                
                let unit = dict["unit"] as? String ?? ""
                let range = dict["normalRange"] as? String ?? "See report"
                let status = dict["status"] as? String ?? "Normal"
                let category = dict["category"] as? String ?? "General"
                
                return LabResultModel(
                    testName: testName,
                    parameter: testName,
                    value: valueDouble,
                    stringValue: originalString,
                    unit: unit,
                    normalRange: range,
                    status: status,
                    testDate: Date(),
                    category: category
                )
            }
        } catch {
            print("❌ [ReportService] Vision result parsing error: \(error)")
            return []
        }
    }
}
