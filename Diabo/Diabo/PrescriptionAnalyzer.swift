// PrescriptionAnalyzer.swift
// Vision LLM-based prescription analysis for handwritten doctor's notes

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Represents a medication extracted from a prescription
struct ExtractedMedication: Codable, Identifiable {
    var id: UUID = UUID()
    let name: String
    let dosage: String?
    let frequency: String?
    let duration: String?
    let route: String?
    let instructions: String?
    let confidence: Double // 0.0 to 1.0
    let rawText: String? // Original text before normalization
    
    // After validation
    var validatedName: String?
    var drugClass: String?
    var isValidated: Bool { validatedName != nil }
}

/// Represents the full prescription analysis result
struct PrescriptionAnalysisResult: Codable {
    let patientName: String?
    let doctorName: String?
    let date: String?
    let medications: [ExtractedMedication]
    let labTestsOrdered: [String]?
    let diagnosis: String?
    let notes: String?
    let overallConfidence: Double
    let warnings: [String]
}

/// Service for analyzing handwritten prescriptions using Vision LLMs
@MainActor
final class PrescriptionAnalyzer {
    static let shared = PrescriptionAnalyzer()
    
    private let openRouterKey = "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"
    
    private init() {}
    
    // MARK: - Main Analysis Method
    
    #if canImport(UIKit)
    /// Analyze a handwritten prescription image using GPT-4 Vision
    func analyzePrescription(image: UIImage) async throws -> PrescriptionAnalysisResult {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw PrescriptionError.invalidImage
        }
        
        let base64Image = imageData.base64EncodedString()
        
        print("📋 [PrescriptionAnalyzer] Analyzing prescription image...")
        print("📋 [PrescriptionAnalyzer] Image size: \(image.size), Data: \(imageData.count) bytes")
        
        // Call Vision API
        let rawAnalysis = try await analyzeWithVision(base64Image: base64Image)
        
        // Parse the structured response
        var result = try parseAnalysisResponse(rawAnalysis)
        
        // Validate medications against database
        result = validateMedications(result)
        
        // Expand abbreviations
        result = expandAbbreviations(result)
        
        print("✅ [PrescriptionAnalyzer] Analysis complete: \(result.medications.count) medications found")
        
        return result
    }
    #endif
    
    // MARK: - Vision API Integration
    
    private func analyzeWithVision(base64Image: String) async throws -> String {
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openRouterKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://medisync.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("MediSync Prescription Analyzer", forHTTPHeaderField: "X-Title")
        
        let systemPrompt = """
        You are a specialized medical prescription reader with expertise in deciphering doctor's handwriting.
        
        ## YOUR TASK
        Analyze the prescription image and extract ALL medications, dosages, frequencies, and instructions.
        
        ## HANDWRITING INTERPRETATION RULES
        1. Use medical context to predict unclear words - if something looks like "Metf___in" it's likely "Metformin"
        2. Common diabetes medications: Metformin, Glimepiride, Sitagliptin, Insulin (various types), Empagliflozin, Dapagliflozin
        3. Common abbreviations to recognize:
           - OD/QD = once daily, BD/BID = twice daily, TDS/TID = three times daily
           - AC = before meals, PC = after meals, HS = at bedtime
           - Tab = tablet, Cap = capsule, Inj = injection
           - mg = milligrams, ml = milliliters, IU = international units
        4. If a character is ambiguous, choose the interpretation that makes medical sense
        5. Numbers: distinguish between 1/l, 0/O, 5/S carefully based on context
        
        ## OUTPUT FORMAT (JSON)
        Return ONLY valid JSON in this exact format:
        {
            "patientName": "string or null",
            "doctorName": "string or null", 
            "date": "string or null",
            "medications": [
                {
                    "name": "medication name",
                    "dosage": "e.g., 500mg",
                    "frequency": "e.g., twice daily",
                    "duration": "e.g., 30 days",
                    "route": "oral/injection/topical",
                    "instructions": "special instructions",
                    "confidence": 0.95,
                    "rawText": "original text as read"
                }
            ],
            "labTestsOrdered": ["test1", "test2"] or null,
            "diagnosis": "string or null",
            "notes": "any other notes",
            "overallConfidence": 0.85,
            "warnings": ["list of uncertain readings or warnings"]
        }
        
        ## IMPORTANT
        - Set confidence LOW (< 0.7) for uncertain readings
        - Include rawText to show what you actually read before interpretation
        - Add warnings for anything that needs human verification
        """
        
        let payload: [String: Any] = [
            "model": "openai/gpt-4o", // GPT-4 Vision model
            "messages": [
                ["role": "system", "content": systemPrompt],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Please analyze this prescription and extract all medications with their dosages. Pay special attention to handwritten text and use medical context to interpret unclear characters."
                        ]
                    ]
                ] as [String: Any]
            ],
            "max_tokens": 2000,
            "temperature": 0.2 // Low temperature for more consistent interpretation
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PrescriptionError.networkError
        }
        
        print("📋 [PrescriptionAnalyzer] API Response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [PrescriptionAnalyzer] API Error: \(errorText)")
            throw PrescriptionError.apiError(errorText)
        }
        
        // Parse OpenRouter response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw PrescriptionError.invalidResponse
        }
        
        print("📋 [PrescriptionAnalyzer] Raw response: \(content.prefix(500))...")
        
        return content
    }
    
    // MARK: - Response Parsing
    
    private func parseAnalysisResponse(_ response: String) throws -> PrescriptionAnalysisResult {
        // Extract JSON from response (may be wrapped in markdown code blocks)
        var jsonString = response
        
        // Remove markdown code blocks if present
        if let jsonStart = response.range(of: "{"),
           let jsonEnd = response.range(of: "}", options: .backwards) {
            jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
        }
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw PrescriptionError.parsingError
        }
        
        do {
            let result = try JSONDecoder().decode(PrescriptionAnalysisResult.self, from: jsonData)
            return result
        } catch {
            print("❌ [PrescriptionAnalyzer] JSON parsing error: \(error)")
            
            // Fallback: Try to extract medications manually
            return createFallbackResult(from: response)
        }
    }
    
    private func createFallbackResult(from response: String) -> PrescriptionAnalysisResult {
        // Basic fallback parsing if JSON fails
        var medications: [ExtractedMedication] = []
        
        // Look for common medication patterns in the text
        let commonMeds = MedicationDatabase.shared.getAllMedications()
        let lowercased = response.lowercased()
        
        for med in commonMeds.prefix(50) { // Check top 50 common meds
            if lowercased.contains(med.lowercased()) {
                medications.append(ExtractedMedication(
                    name: med,
                    dosage: nil,
                    frequency: nil,
                    duration: nil,
                    route: nil,
                    instructions: nil,
                    confidence: 0.6,
                    rawText: med
                ))
            }
        }
        
        return PrescriptionAnalysisResult(
            patientName: nil,
            doctorName: nil,
            date: nil,
            medications: medications,
            labTestsOrdered: nil,
            diagnosis: nil,
            notes: "Parsed using fallback method - please verify manually",
            overallConfidence: 0.5,
            warnings: ["Could not parse structured response - results may be incomplete"]
        )
    }
    
    // MARK: - Medication Validation
    
    private func validateMedications(_ result: PrescriptionAnalysisResult) -> PrescriptionAnalysisResult {
        var validatedMeds: [ExtractedMedication] = []
        
        for med in result.medications {
            var validatedMed = med
            
            // Try to match against medication database
            if let match = MedicationDatabase.shared.findBestMatch(for: med.name) {
                validatedMed.validatedName = match.name
                validatedMed.drugClass = match.drugClass
                print("✅ [PrescriptionAnalyzer] Validated: '\(med.name)' → '\(match.name)' (\(match.drugClass))")
            } else {
                print("⚠️ [PrescriptionAnalyzer] No validation match for: '\(med.name)'")
            }
            
            validatedMeds.append(validatedMed)
        }
        
        return PrescriptionAnalysisResult(
            patientName: result.patientName,
            doctorName: result.doctorName,
            date: result.date,
            medications: validatedMeds,
            labTestsOrdered: result.labTestsOrdered,
            diagnosis: result.diagnosis,
            notes: result.notes,
            overallConfidence: result.overallConfidence,
            warnings: result.warnings
        )
    }
    
    // MARK: - Abbreviation Expansion
    
    private func expandAbbreviations(_ result: PrescriptionAnalysisResult) -> PrescriptionAnalysisResult {
        var expandedMeds: [ExtractedMedication] = []
        
        for med in result.medications {
            var expandedMed = med
            
            // Expand frequency abbreviations
            if let freq = med.frequency {
                expandedMed = ExtractedMedication(
                    id: med.id,
                    name: med.name,
                    dosage: med.dosage,
                    frequency: MedicalAbbreviationParser.expandFrequency(freq),
                    duration: med.duration,
                    route: med.route != nil ? MedicalAbbreviationParser.expandRoute(med.route!) : nil,
                    instructions: med.instructions,
                    confidence: med.confidence,
                    rawText: med.rawText,
                    validatedName: med.validatedName,
                    drugClass: med.drugClass
                )
            }
            
            expandedMeds.append(expandedMed)
        }
        
        return PrescriptionAnalysisResult(
            patientName: result.patientName,
            doctorName: result.doctorName,
            date: result.date,
            medications: expandedMeds,
            labTestsOrdered: result.labTestsOrdered,
            diagnosis: result.diagnosis,
            notes: result.notes,
            overallConfidence: result.overallConfidence,
            warnings: result.warnings
        )
    }
}

// MARK: - Errors

enum PrescriptionError: LocalizedError {
    case invalidImage
    case networkError
    case apiError(String)
    case invalidResponse
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image"
        case .networkError: return "Network connection failed"
        case .apiError(let msg): return "API Error: \(msg)"
        case .invalidResponse: return "Invalid response from analysis service"
        case .parsingError: return "Could not parse the analysis results"
        }
    }
}
