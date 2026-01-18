// MLService.swift
import Foundation
import CoreML
import SwiftData

/// Service for on-device medical text analysis and organ detection
public class MLService {
    // MARK: - Singleton
    public static let shared = MLService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Extract health metrics from text using the advanced parser and provide ML-driven analysis
    func extractMetrics(from text: String) async throws -> [String: Any] {
        print("🤖 [MLService] Starting offline extraction and analysis...")
        
        // 1. Use the advanced regex parser for structured data
        let labResults = MedicalDataParser.parseLabResults(from: text)
        let medications = MedicalDataParser.parseMedications(from: text)
        let reportType = MedicalDataParser.detectReportType(from: text)
        
        // 2. Perform deep analysis on the results
        var result: [String: Any] = [:]
        
        // Convert LabResultModel array to dictionaries for the pipeline
        let metricsDicts = labResults.map { [
            "name": $0.testName,
            "value": $0.value,
            "unit": $0.unit,
            "status": $0.status,
            "normalRange": $0.normalRange,
            "category": $0.category
        ]}
        
        result["metrics"] = metricsDicts
        result["medications"] = medications // Now returning full models
        result["reportType"] = reportType
        
        // 3. Smart Organ Detection
        result["organ"] = detectPrimaryOrgan(from: text, results: labResults)
        
        // 4. Generate AI-like insights offline
        result["insights"] = generateOfflineInsights(results: labResults, medications: medications)
        
        print("✅ [MLService] Offline analysis complete. Found \(labResults.count) parameters.")
        return result
    }
    
    // MARK: - Organ Detection
    
    public func detectPrimaryOrgan(from text: String, results: [LabResultModel]) -> String {
        let lowercased = text.lowercased()
        
        // Count category occurrences from results for weighted detection
        var categoryCounts: [String: Int] = [:]
        for result in results {
            categoryCounts[result.category, default: 0] += 1
        }
        
        // Priority 1: Direct keywords in text
        if lowercased.contains("heart") || lowercased.contains("cardiac") || lowercased.contains("ecg") { return "Heart" }
        if lowercased.contains("kidney") || lowercased.contains("renal") { return "Kidney" }
        if lowercased.contains("liver") || lowercased.contains("hepatic") { return "Liver" }
        if lowercased.contains("lung") || lowercased.contains("pulmonary") || lowercased.contains("respiratory") { return "Lungs" }
        if lowercased.contains("thyroid") { return "Thyroid" }
        
        // Priority 2: Most frequent category from parsed results
        if let topCategory = categoryCounts.max(by: { $0.value < $1.value })?.key {
            switch topCategory {
            case "Blood Count": return "Blood"
            case "Lipid Panel": return "Heart"
            case "Liver": return "Liver"
            case "Kidney": return "Kidney"
            case "Thyroid": return "Thyroid"
            case "Glucose": return "Pancreas"
            case "Vitals": return "General"
            default: return "General"
            }
        }
        
        return "General"
    }
    
    private func generateOfflineInsights(results: [LabResultModel], medications: [MedicationModel]) -> String {
        var insights: [String] = []
        
        // 1. Analyze abnormal results
        let abnormals = results.filter { $0.status.lowercased() != "normal" && $0.status.lowercased() != "optimal" }
        
        if !abnormals.isEmpty {
            let names = abnormals.map { $0.testName }.joined(separator: ", ")
            insights.append("Detected abnormal levels for: \(names).")
            
            // Specific analysis for common markers
            for result in abnormals {
                switch result.testName {
                case "Total Cholesterol", "LDL":
                    insights.append("Total cholesterol/LDL is above range. Consider heart-healthy dietary changes.")
                case "Fasting Glucose", "HbA1c":
                    insights.append("Blood sugar levels indicate a risk of hyperglycemia. Monitor Intake.")
                case "Hemoglobin":
                    if result.value < 12 { insights.append("Hemoglobin is low, which may indicate anemia.") }
                case "eGFR":
                    if result.value < 60 { insights.append("eGFR is reduced, suggesting the need to monitor kidney function.") }
                default: break
                }
            }
        } else if !results.isEmpty {
            insights.append("All extracted lab parameters are within the normal reference ranges.")
        }
        
        // 2. Medication context
        if !medications.isEmpty {
            let names = medications.map { $0.name }.joined(separator: ", ")
            insights.append("Extracted medications: \(names). Ensure consistency with previous prescriptions.")
        }
        
        // 3. Trends (Future: comparison with historical data)
        
        if insights.isEmpty {
            return "No specific medical markers were identified for analysis."
        }
        
        return insights.joined(separator: " ")
    }
}
