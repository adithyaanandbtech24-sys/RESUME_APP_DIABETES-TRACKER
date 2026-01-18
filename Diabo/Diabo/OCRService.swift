import Foundation
import Vision
#if canImport(UIKit)
import UIKit
#endif
#if canImport(PDFKit)
import PDFKit
#endif

/// Service for extracting text from medical documents using Vision framework
public class OCRService {
    // MARK: - Singleton
    public static let shared = OCRService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    #if canImport(UIKit)
    /// Extract text from image using Vision OCR
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                if recognizedText.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: recognizedText)
                }
            }
            
            // Configure for accurate medical text recognition
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
    #endif
    
    /// Extract specific medical values from text
    func extractMedicalValues(from text: String) -> [String: String] {
        var values: [String: String] = [:]
        
        // Common medical patterns
        let patterns: [String: String] = [
            "cholesterol": #"cholesterol[:\s]+(\d+\.?\d*)\s*(mg/dL)?"#,
            "glucose": #"glucose[:\s]+(\d+\.?\d*)\s*(mg/dL)?"#,
            "hemoglobin": #"hemoglobin[:\s]+(\d+\.?\d*)\s*(g/dL)?"#,
            "blood_pressure": #"(\d{2,3})/(\d{2,3})\s*mmHg"#,
            "heart_rate": #"heart rate[:\s]+(\d+)\s*bpm"#,
            "vitamin_d": #"vitamin\s*d[:\s]+(\d+\.?\d*)\s*(ng/mL)?"#
        ]
        
        for (key, pattern) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range) {
                    if let valueRange = Range(match.range(at: 1), in: text) {
                        values[key] = String(text[valueRange])
                    }
                }
            }
        }
        
        return values
    }
    
    /// Detect report type from extracted text
    func detectReportType(from text: String) -> String {
        let lowercasedText = text.lowercased()
        
        if lowercasedText.contains("blood test") || lowercasedText.contains("cbc") || lowercasedText.contains("hemoglobin") {
            return "Blood Test"
        } else if lowercasedText.contains("x-ray") || lowercasedText.contains("radiograph") {
            return "X-Ray"
        } else if lowercasedText.contains("mri") || lowercasedText.contains("magnetic resonance") {
            return "MRI"
        } else if lowercasedText.contains("prescription") || lowercasedText.contains("rx:") {
            return "Prescription"
        } else if lowercasedText.contains("lab") || lowercasedText.contains("laboratory") {
            return "Lab Report"
        } else {
            return "General Report"
        }
    }
    
    #if canImport(PDFKit)
    /// Extract text from PDF document using Vision (Handles scanned PDFs)
    func extractText(from pdfURL: URL) async throws -> String {
        guard let document = PDFDocument(url: pdfURL) else {
            throw OCRError.invalidPDF
        }
        
        guard document.pageCount > 0 else {
            throw OCRError.noTextFound
        }
        
        var fullText = ""
        
        print("📄 [OCRService] Processing PDF with \(document.pageCount) pages...")
        
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            
            // 1. Try to get text directly (fastest, for native PDFs)
            // We combine this with OCR to ensure we don't miss "images inside native PDFs"
            // But for now, let's rely on Vision for consistency if the plan is "Scanned PDF" support.
            // Actually, mixed PDFs exist.
            // Let's ALWAYS render to image for maximum reliability as requested.
            
            // Render page to image
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(pageRect)
                ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            
            // Extract text from the rendered page image
            do {
                let pageText = try await extractText(from: image)
                fullText += pageText + "\n\n"
                print("✅ [OCRService] Page \(pageIndex + 1) processed (\(pageText.count) chars)")
            } catch {
                print("⚠️ [OCRService] Failed to extract text from page \(pageIndex + 1): \(error)")
            }
        }
        
        let cleanedText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanedText.isEmpty {
            throw OCRError.noTextFound
        }
        
        return cleanedText
    }
    #endif
}

// MARK: - Errors

enum OCRError: LocalizedError {
    case invalidImage
    case invalidPDF
    case noTextFound
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .invalidPDF:
            return "Invalid PDF format or unable to read PDF"
        case .noTextFound:
            return "No text found in document"
        case .processingFailed:
            return "OCR processing failed"
        }
    }
}
