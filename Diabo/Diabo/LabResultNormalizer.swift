import Foundation
import SwiftData

/// Utility for normalizing and deduplicating lab results
class LabResultNormalizer {
    
    /// Normalizes parameter names and combines composite values (like BP)
    /// Returns a cleaned list of LabResultModel ready for insertion
    static func normalize(_ results: [LabResultModel]) -> [LabResultModel] {
        var processed = [LabResultModel]()
        
        // Trackers for composite values
        var systolic: LabResultModel?
        var diastolic: LabResultModel?
        
        // Track unique keys to prevent exact duplicates (Name only to be aggressive against duplicates)
        var seenKeys = Set<String>()
        
        for result in results {
            // Normalize the name first
            let normalizedName = normalizeName(result.testName)
            result.testName = normalizedName
            result.parameter = normalizedName // Keep consistent
            
            let lowerName = normalizedName.lowercased()
            
            // 1. Identify BP Components
            if isSystolic(lowerName) {
                // If we found a better systolic (later date or exists), update
                if systolic == nil { systolic = result }
                else if result.testDate > systolic!.testDate { systolic = result }
                continue
            }
            if isDiastolic(lowerName) {
                if diastolic == nil { diastolic = result }
                else if result.testDate > diastolic!.testDate { diastolic = result }
                continue
            }
            
            // 2. Deduplication for other parameters
            // Only keep the first occurrence of a normalized name in this batch
            if !seenKeys.contains(normalizedName) {
                processed.append(result)
                seenKeys.insert(normalizedName)
            }
        }
        
        // 3. Handle Blood Pressure Combination
        if let sys = systolic, let dia = diastolic {
            // Create Composite BP
            let bpValue = "\(Int(sys.value))/\(Int(dia.value))"
            let bp = LabResultModel(
                testName: "Blood Pressure",
                parameter: "Blood Pressure",
                value: 0, // Placeholder, UI should use stringValue
                stringValue: bpValue,
                unit: "mmHg",
                normalRange: "120/80 mmHg",
                status: determineBPStatus(sys: sys.value, dia: dia.value),
                testDate: sys.testDate,
                category: "Heart" // Force correct category
            )
            processed.append(bp)
        } else {
            // Restore orphans if incomplete
            if let sys = systolic { processed.append(sys) }
            if let dia = diastolic { processed.append(dia) }
        }
        
        return processed
    }
    
    private static func isSystolic(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("systolic") || (lower.contains("blood pressure") && !lower.contains("diastolic") && !lower.contains("map"))
    }
    
    private static func isDiastolic(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("diastolic")
    }
    
    private static func normalizeName(_ name: String) -> String {
        var clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Common cleanup
        if clean.lowercased().hasPrefix("s.") || clean.lowercased().hasPrefix("s ") {
            clean = String(clean.dropFirst(2))
        }
        
        let lower = clean.lowercased()
        
        // Canonical mapping
        if lower.contains("hba1c") || lower.contains("glycated") { return "HbA1c" }
        if lower.contains("fasting glucose") || lower == "fbs" || lower == "fbg" { return "Fasting Glucose" }
        if lower.contains("post prandial") || lower == "ppbs" { return "PP Glucose" }
        if lower.contains("total cholesterol") { return "Total Cholesterol" }
        if lower.contains("ldl") { return "LDL Cholesterol" }
        if lower.contains("hdl") { return "HDL Cholesterol" }
        if lower.contains("triglyceride") { return "Triglycerides" }
        if lower.contains("creatinine") { return "Creatinine" }
        if lower.contains("tsh") { return "TSH" }
        
        // If mostly uppercase, capitalize
        if lower.count > 3 && clean == clean.uppercased() {
            return clean.capitalized
        }
        
        return clean
    }
    
    private static func determineBPStatus(sys: Double, dia: Double) -> String {
        if sys > 140 || dia > 90 { return "High" }
        if sys > 120 || dia > 80 { return "Borderline" }
        if sys < 90 || dia < 60 { return "Low" }
        return "Normal"
    }
}
