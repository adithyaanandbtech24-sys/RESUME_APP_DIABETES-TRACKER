import Foundation
import SwiftData
import SwiftUI

/// Parser for extracting medical data from OCR text using advanced local pattern matching
public class MedicalDataParser {
    
    // MARK: - Lab Result Metadata
    struct LabTestMetadata {
        let name: String
        let aliases: [String]
        let unit: String
        let category: String
        let normalRange: String
        let pattern: String // Base regex pattern for the value
    }
    
    private static let labMetadata: [LabTestMetadata] = [
        // Blood Count (CBC)
        LabTestMetadata(name: "Hemoglobin", aliases: ["hb", "hgb", "hemoglobin", "haemoglobin"], unit: "g/dL", category: "Blood Count", normalRange: "12-16 g/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "WBC", aliases: ["wbc", "white blood cell", "leukocytes", "total leucocyte"], unit: "×10³/µL", category: "Blood Count", normalRange: "4-11 ×10³/µL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "RBC", aliases: ["rbc", "red blood cell", "erythrocytes", "total rbc"], unit: "million/µL", category: "Blood Count", normalRange: "4.5-5.5 million/µL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Platelets", aliases: ["plt", "platelet", "thrombocytes", "plt count"], unit: "×10³/µL", category: "Blood Count", normalRange: "150-450 ×10³/µL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Hematocrit", aliases: ["hct", "pcv", "hematocrit", "packed cell volume"], unit: "%", category: "Blood Count", normalRange: "37-47%", pattern: #"\d+\.?\d*"#),
        
        // Lipid Panel
        LabTestMetadata(name: "Total Cholesterol", aliases: ["cholesterol", "total cholesterol", "chol", "s.cholesterol"], unit: "mg/dL", category: "Lipid Panel", normalRange: "< 200 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "LDL", aliases: ["ldl", "ldl-c", "low density lipoprotein", "bad cholesterol"], unit: "mg/dL", category: "Lipid Panel", normalRange: "< 100 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "HDL", aliases: ["hdl", "hdl-c", "high density lipoprotein", "good cholesterol"], unit: "mg/dL", category: "Lipid Panel", normalRange: "> 50 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Triglycerides", aliases: ["tg", "trig", "triglycerides", "triacyl"], unit: "mg/dL", category: "Lipid Panel", normalRange: "< 150 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Non-HDL Cholesterol", aliases: ["non-hdl", "non-high density lipoprotein"], unit: "mg/dL", category: "Lipid Panel", normalRange: "< 130 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "VLDL", aliases: ["vldl", "very low density lipoprotein"], unit: "mg/dL", category: "Lipid Panel", normalRange: "< 30 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Chol/HDL Ratio", aliases: ["chol/hdl", "cholesterol/hdl ratio", "cholesterol high density lipoprotein ratio"], unit: "", category: "Lipid Panel", normalRange: "3.3-4.4", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "LDL/HDL Ratio", aliases: ["ldl/hdl", "ldl/hdl ratio", "low density/high density"], unit: "", category: "Lipid Panel", normalRange: "0.5-3.0", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "HDL/LDL Ratio", aliases: ["hdl/ldl", "hdl/ldl ratio"], unit: "", category: "Lipid Panel", normalRange: "> 0.4", pattern: #"\d+\.?\d*"#),
        
        // Glucose & Diabetes - EXPANDED FOR OCR VARIATIONS
        LabTestMetadata(name: "Fasting Glucose", aliases: ["glucose", "fasting glucose", "blood sugar", "fbs", "sugar (f)", "f.b.s", "fbg", "fasting blood sugar", "fasting blood glucose", "blood glucose fasting"], unit: "mg/dL", category: "Glucose", normalRange: "70-100 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "HbA1c", aliases: ["hba1c", "hbaic", "a1c", "glycated hb", "glyco hb", "glycosylated haemoglobin", "glycated hemoglobin", "glycated haemoglobin", "hba 1c", "hb a1c", "glycated hémoglobin", "hemoglobin a1c", "haemoglobin a1c", "glycohemoglobin"], unit: "%", category: "Glucose", normalRange: "< 5.7%", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "PP Glucose", aliases: ["pp glucose", "post prandial glucose", "ppbs", "ppbg", "post prandial blood sugar", "glucose pp", "2 hour glucose", "2hr glucose", "post meal glucose"], unit: "mg/dL", category: "Glucose", normalRange: "< 140 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Random Glucose", aliases: ["random glucose", "rbs", "random blood sugar"], unit: "mg/dL", category: "Glucose", normalRange: "< 200 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Insulin Fasting", aliases: ["insulin fasting", "fasting insulin"], unit: "µIU/mL", category: "Glucose", normalRange: "2.6-24.9 µIU/mL", pattern: #"\d+\.?\d*"#),
        
        // Liver Function
        LabTestMetadata(name: "ALT", aliases: ["alt", "sgpt", "alanine aminotransferase", "alanine trans"], unit: "U/L", category: "Liver", normalRange: "7-56 U/L", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "AST", aliases: ["ast", "sgot", "aspartate aminotransferase", "aspartate trans"], unit: "U/L", category: "Liver", normalRange: "10-40 U/L", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Total Bilirubin", aliases: ["bilirubin", "total bilirubin", "bili", "s.bilirubin"], unit: "mg/dL", category: "Liver", normalRange: "0.1-1.2 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Direct Bilirubin", aliases: ["direct bilirubin", "conjugated bilirubin"], unit: "mg/dL", category: "Liver", normalRange: "0-0.3 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Indirect Bilirubin", aliases: ["indirect bilirubin", "unconjugated bilirubin"], unit: "mg/dL", category: "Liver", normalRange: "0.1-1.1 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Albumin", aliases: ["albumin", "alb", "s.albumin"], unit: "g/dL", category: "Liver", normalRange: "3.5-5.5 g/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Globulin", aliases: ["globulin", "s.globulin"], unit: "g/dL", category: "Liver", normalRange: "2.3-3.5 g/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "A/G Ratio", aliases: ["a/g ratio", "albumin/globulin", "albumin globulin ratio"], unit: "", category: "Liver", normalRange: "0.8-2.0", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "GGT", aliases: ["ggt", "gamma-glutamyl", "gamma gt"], unit: "U/L", category: "Liver", normalRange: "12-43 U/L", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Alkaline Phosphatase", aliases: ["alp", "alkaline phosphatase", "alk phos"], unit: "U/L", category: "Liver", normalRange: "38-126 U/L", pattern: #"\d+\.?\d*"#),

        // Pancreas
        LabTestMetadata(name: "Amylase", aliases: ["amylase", "s.amylase"], unit: "U/L", category: "Pancreas", normalRange: "30-110 U/L", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Lipase", aliases: ["lipase", "s.lipase"], unit: "U/L", category: "Pancreas", normalRange: "23-300 U/L", pattern: #"\d+\.?\d*"#),
        
        // Kidney Function
        LabTestMetadata(name: "Creatinine", aliases: ["creatinine", "creat", "cr", "s.creatinine"], unit: "mg/dL", category: "Kidney", normalRange: "0.6-1.2 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "eGFR", aliases: ["egfr", "gfr", "estimated gfr", "mdrd"], unit: "mL/min/1.73m²", category: "Kidney", normalRange: "> 90 mL/min", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "BUN", aliases: ["bun", "urea nitrogen", "blood urea"], unit: "mg/dL", category: "Kidney", normalRange: "7-20 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "BUN/Creatinine Ratio", aliases: ["bun/creatinine", "bun/cr ratio", "blood urea nitrogen/creatinine"], unit: "", category: "Kidney", normalRange: "10-20", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Uric Acid", aliases: ["uric acid", "s.uric acid"], unit: "mg/dL", category: "Kidney", normalRange: "2.4-6.0 mg/dL", pattern: #"\d+\.?\d*"#),

        // Electrolytes
        LabTestMetadata(name: "Sodium", aliases: ["na", "sodium", "s.sodium"], unit: "mEq/L", category: "Electrolytes", normalRange: "135-145 mEq/L", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Potassium", aliases: ["k", "potassium", "s.potassium"], unit: "mEq/L", category: "Electrolytes", normalRange: "3.5-5.5 mEq/L", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Chloride", aliases: ["cl", "chloride", "s.chloride"], unit: "mmol/L", category: "Electrolytes", normalRange: "98-107 mmol/L", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Calcium", aliases: ["ca", "calcium", "s.calcium"], unit: "mg/dL", category: "Electrolytes", normalRange: "8.5-10.5 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Magnesium", aliases: ["mg", "magnesium", "s.magnesium"], unit: "mg/dL", category: "Electrolytes", normalRange: "1.6-2.3 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Phosphorus", aliases: ["phos", "phosphorus", "s.phosphorus"], unit: "mg/dL", category: "Electrolytes", normalRange: "2.5-4.5 mg/dL", pattern: #"\d+\.?\d*"#),
        
        // Iron Studies
        LabTestMetadata(name: "Serum Iron", aliases: ["iron", "s.iron", "serum iron"], unit: "µg/dL", category: "Iron", normalRange: "37-170 µg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Ferritin", aliases: ["ferritin", "s.ferritin"], unit: "ng/mL", category: "Iron", normalRange: "20-300 ng/mL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "TIBC", aliases: ["tibc", "total iron binding"], unit: "µg/dL", category: "Iron", normalRange: "265-497 µg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "UIBC", aliases: ["uibc", "unbound iron binding"], unit: "µg/dL", category: "Iron", normalRange: "110-370 µg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Transferrin Saturation", aliases: ["transferrin saturation", "transferrin sat"], unit: "%", category: "Iron", normalRange: "16-55 %", pattern: #"\d+\.?\d*"#),
        
        // Cardiac Risk
        LabTestMetadata(name: "HS-CRP", aliases: ["hs-crp", "high sensitivity crp", "cardiac crp"], unit: "mg/L", category: "Cardiac Risk", normalRange: "< 1.0 mg/L", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Apo B", aliases: ["apolipoprotein b", "apo b"], unit: "mg/dL", category: "Cardiac Risk", normalRange: "60-140 mg/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Lipoprotein (a)", aliases: ["lipoprotein (a)", "lp(a)"], unit: "mg/dL", category: "Cardiac Risk", normalRange: "< 30 mg/dL", pattern: #"\d+\.?\d*"#),

        // Thyroid
        LabTestMetadata(name: "TSH", aliases: ["tsh", "thyroid stimulating hormone", "s.tsh"], unit: "mIU/L", category: "Thyroid", normalRange: "0.4-4.0 mIU/L", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Free T4", aliases: ["ft4", "free t4", "t4f"], unit: "ng/dL", category: "Thyroid", normalRange: "0.8-1.8 ng/dL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Total T3", aliases: ["t3", "total t3", "triiodothyronine"], unit: "ng/dL", category: "Thyroid", normalRange: "80-200 ng/dL", pattern: #"\d+\.?\d*"#),
        
        // Vitamins
        LabTestMetadata(name: "Vitamin D", aliases: ["vit d", "vitamin d", "25-oh d", "d3", "vitamin d, total"], unit: "ng/mL", category: "Vitamins", normalRange: "30-100 ng/mL", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Vitamin B12", aliases: ["vit b12", "b12", "cobalamin"], unit: "pg/mL", category: "Vitamins", normalRange: "200-900 pg/mL", pattern: #"\d+\.?\d*"#),
        
        // Vitals
        LabTestMetadata(name: "Heart Rate", aliases: ["hr", "pulse", "heart rate", "pulse rate"], unit: "BPM", category: "Vitals", normalRange: "60-100 BPM", pattern: #"\d+"#),
        LabTestMetadata(name: "SpO2", aliases: ["spo2", "pulse ox", "oxygen sat", "o2 sat"], unit: "%", category: "Vitals", normalRange: "95-100%", pattern: #"\d+"#),
        LabTestMetadata(name: "Temperature", aliases: ["temp", "temperature", "body temp"], unit: "°F", category: "Vitals", normalRange: "97.0-99.0°F", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Weight", aliases: ["weight", "body weight"], unit: "kg", category: "Vitals", normalRange: "", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "BMI", aliases: ["bmi", "body mass index"], unit: "kg/m²", category: "Vitals", normalRange: "18.5-24.9", pattern: #"\d+\.?\d*"#),
        
        // CBC Differential
        LabTestMetadata(name: "Neutrophils", aliases: ["neutrophils", "neutrophil", "neuts", "poly"], unit: "%", category: "Differential", normalRange: "40-75%", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Lymphocytes", aliases: ["lymphocytes", "lymphocyte", "lymphs"], unit: "%", category: "Differential", normalRange: "20-45%", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Monocytes", aliases: ["monocytes", "monocyte", "monos"], unit: "%", category: "Differential", normalRange: "2-10%", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Eosinophils", aliases: ["eosinophils", "eosinophil", "eos"], unit: "%", category: "Differential", normalRange: "1-6%", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Basophils", aliases: ["basophils", "basophil", "basos"], unit: "%", category: "Differential", normalRange: "0-1%", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Absolute Neutrophil Count", aliases: ["absolute neutrophil count", "anc"], unit: "/mm³", category: "Differential", normalRange: "2000-7000 /mm³", pattern: #"\d+"#),
        LabTestMetadata(name: "Absolute Lymphocyte Count", aliases: ["absolute lymphocyte count", "alc"], unit: "/mm³", category: "Differential", normalRange: "1000-3000 /mm³", pattern: #"\d+"#),
        LabTestMetadata(name: "Absolute Monocyte Count", aliases: ["absolute monocyte count", "amc"], unit: "/mm³", category: "Differential", normalRange: "200-1000 /mm³", pattern: #"\d+"#),
        LabTestMetadata(name: "Absolute Eosinophil Count", aliases: ["absolute eosinophil count", "aec"], unit: "/mm³", category: "Differential", normalRange: "20-500 /mm³", pattern: #"\d+"#),
        LabTestMetadata(name: "Absolute Basophil Count", aliases: ["absolute basophil count", "abc"], unit: "/mm³", category: "Differential", normalRange: "0-100 /mm³", pattern: #"\d+"#),
        LabTestMetadata(name: "NLR", aliases: ["neutrophil lymphocyte ratio", "nlr"], unit: "", category: "Differential", normalRange: "1-3", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Platelet Hematocrit", aliases: ["platelet hematocrit", "pct"], unit: "%", category: "Blood Count", normalRange: "0.2-0.5", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Mean Platelet Volume", aliases: ["mean platelet volume", "mpv"], unit: "fL", category: "Blood Count", normalRange: "7-13 fL", pattern: #"\d+\.?\d*"#),

        // Urinalysis - Physical & Chemical
        LabTestMetadata(name: "Urine pH", aliases: ["ph", "urine ph"], unit: "", category: "Urinalysis", normalRange: "5-8", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Specific Gravity", aliases: ["sp. gr.", "specific gravity", "sg"], unit: "", category: "Urinalysis", normalRange: "1.001-1.035", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "Protein (Urine)", aliases: ["protein", "urine protein", "albumin (urine)"], unit: "", category: "Urinalysis", normalRange: "Nil", pattern: #"(?:negative|neg|positive|pos|nil|trace|present)"#),
        LabTestMetadata(name: "Glucose (Urine)", aliases: ["glucose", "urine glucose", "sugar (urine)"], unit: "", category: "Urinalysis", normalRange: "Nil", pattern: #"(?:negative|neg|positive|pos|nil|trace|present)"#),
        LabTestMetadata(name: "Bilirubin (Urine)", aliases: ["bilirubin", "urine bilirubin"], unit: "", category: "Urinalysis", normalRange: "Nil", pattern: #"(?:negative|neg|positive|pos|nil|trace|present)"#),
        LabTestMetadata(name: "Urobilinogen", aliases: ["urobilinogen", "urine urobilinogen"], unit: "", category: "Urinalysis", normalRange: "Normal", pattern: #"(?:normal|abnormal|\d+\.?\d*)"#),
        LabTestMetadata(name: "Blood (Urine)", aliases: ["blood", "urine blood"], unit: "", category: "Urinalysis", normalRange: "Negative", pattern: #"(?:negative|neg|positive|pos|nil|trace|present)"#),
        LabTestMetadata(name: "Leukocyte Esterase", aliases: ["leukocyte esterase"], unit: "", category: "Urinalysis", normalRange: "Negative", pattern: #"(?:negative|neg|positive|pos|nil|trace|present)"#),
        LabTestMetadata(name: "Nitrites", aliases: ["nitrites", "nitrite"], unit: "", category: "Urinalysis", normalRange: "Negative", pattern: #"(?:negative|neg|positive|pos|nil)"#),
        LabTestMetadata(name: "Ketones", aliases: ["ketones", "urine ketones"], unit: "", category: "Urinalysis", normalRange: "Negative", pattern: #"(?:negative|neg|positive|pos|nil|\+)"#),
        
        // Urinalysis - Microscopic
        LabTestMetadata(name: "Pus Cells", aliases: ["pus cells", "leukocytes", "wbc (urine)"], unit: "/hpf", category: "Urinalysis", normalRange: "0-5 /hpf", pattern: #"(?:nil|\d+(?:-\d+)?)"#),
        LabTestMetadata(name: "Epithelial Cells", aliases: ["epithelial cells", "epithelial"], unit: "/hpf", category: "Urinalysis", normalRange: "0-2 /hpf", pattern: #"(?:nil|\d+(?:-\d+)?)"#),
        LabTestMetadata(name: "RBC (Urine)", aliases: ["red blood cells (urine)", "rbc", "erythrocytes"], unit: "/hpf", category: "Urinalysis", normalRange: "Nil", pattern: #"(?:nil|\d+(?:-\d+)?)"#),
        LabTestMetadata(name: "Granular Casts", aliases: ["granular casts"], unit: "/hpf", category: "Urinalysis", normalRange: "Nil", pattern: #"(?:nil|absent|present|occasional)"#),
        LabTestMetadata(name: "Hyaline Casts", aliases: ["hyaline casts"], unit: "/hpf", category: "Urinalysis", normalRange: "Nil", pattern: #"(?:nil|absent|present|occasional)"#),
        LabTestMetadata(name: "Crystals", aliases: ["crystals", "uric acid crystals", "calcium oxalate", "phosphate crystals"], unit: "/hpf", category: "Urinalysis", normalRange: "Nil", pattern: #"(?:nil|absent|present|occasional)"#),
        LabTestMetadata(name: "Bacteria", aliases: ["bacteria"], unit: "", category: "Urinalysis", normalRange: "Nil", pattern: #"(?:nil|absent|present|occasional)"#),
        LabTestMetadata(name: "Yeast", aliases: ["yeast"], unit: "", category: "Urinalysis", normalRange: "Nil", pattern: #"(?:nil|absent|present|occasional)"#),
        LabTestMetadata(name: "Parasites", aliases: ["parasites"], unit: "", category: "Urinalysis", normalRange: "Nil", pattern: #"(?:nil|absent|present|occasional)"#),
        LabTestMetadata(name: "Mucus", aliases: ["mucus"], unit: "", category: "Urinalysis", normalRange: "Absent", pattern: #"(?:nil|absent|present|occasional)"#),

        // Coagulation
        LabTestMetadata(name: "PT", aliases: ["prothrombin time", "pt"], unit: "sec", category: "Coagulation", normalRange: "11-13.5 sec", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "INR", aliases: ["inr", "international normalized ratio"], unit: "", category: "Coagulation", normalRange: "0.8-1.1", pattern: #"\d+\.?\d*"#),
        
        // Inflammatory / Other
        LabTestMetadata(name: "CRP", aliases: ["c-reactive protein", "crp"], unit: "mg/L", category: "Inflammation", normalRange: "< 3.0 mg/L", pattern: #"\d+\.?\d*"#),
        LabTestMetadata(name: "ESR", aliases: ["erythrocyte sedimentation rate", "esr"], unit: "mm/hr", category: "Inflammation", normalRange: "0-20 mm/hr", pattern: #"\d+"#),
        LabTestMetadata(name: "PSA", aliases: ["psa", "prostate specific antigen"], unit: "ng/mL", category: "Prostate", normalRange: "< 4.0 ng/mL", pattern: #"\d+\.?\d*"#)
    ]
    
    // MARK: - Lab Results Parsing
    
    static func parseLabResults(from text: String) -> [LabResultModel] {
        var results: [LabResultModel] = []
        let lowercasedText = text.lowercased().replacingOccurrences(of: "_", with: " ") // Handle snake_case input
        
        print("🔬 [MedicalDataParser] ========== parseLabResults CALLED ==========")
        print("🔬 [MedicalDataParser] Input text length: \(text.count) characters")
        print("🔬 [MedicalDataParser] First 500 chars of text:")
        print(String(text.prefix(500)))
        print("🔬 [MedicalDataParser] Checking against \(labMetadata.count) known lab tests...")
        
        for metadata in labMetadata {
            // Build a flexible regex for each test
            // Matches: alias [optional colon/dash/space/dot] [optional result label/flag] value [optional unit]
            let aliasPattern = metadata.aliases.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
            // Updated to allow dots \. in the separator for "Hemoglobin ........ 13.5" style
            let regPattern = "(?:\(aliasPattern))[:\\s\\-\\.]*([<>\\s]*\(metadata.pattern))"
            
            if let regex = try? NSRegularExpression(pattern: regPattern, options: [.caseInsensitive, .anchorsMatchLines]) {
                let range = NSRange(lowercasedText.startIndex..., in: lowercasedText)
                let matches = regex.matches(in: lowercasedText, range: range)
                
                if let match = matches.last,
                   let valueRange = Range(match.range(at: 1), in: lowercasedText) {
                    
                    let rawValue = String(lowercasedText[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Enhanced value parsing
                    if let value = extractValue(from: rawValue) {
                        let status = determineStatus(value: value, metadata: metadata)
                        
                        let result = LabResultModel(
                            testName: metadata.name,
                            parameter: metadata.name,
                            value: value,
                            unit: metadata.unit,
                            normalRange: metadata.normalRange,
                            status: status,
                            testDate: Date(),
                            category: metadata.category
                        )
                        results.append(result)
                        print("🔬 [MedicalDataParser] MATCHED: \(metadata.name) = \(value) \(metadata.unit)")
                    }
                }
            }
        }
        
        // Post-processing: Handle Blood Pressure specifically due to slash
        if let bpMatch = extractBloodPressure(from: text) {
            results.append(bpMatch.systolic)
            results.append(bpMatch.diastolic)
            print("🔬 [MedicalDataParser] MATCHED: Blood Pressure (Systolic/Diastolic)")
        }
        
        // SPECIAL HANDLING: HbA1c in tabular formats (Orange Health, etc.)
        // Only add if not already found
        if !results.contains(where: { $0.testName.lowercased().contains("hba1c") }) {
            if let hba1c = extractHbA1cFromTabular(from: text) {
                results.append(hba1c)
                print("🔬 [MedicalDataParser] MATCHED HbA1c (tabular extraction): \(hba1c.value) %")
            }
        }
        
        // SPECIAL HANDLING: Fasting Glucose in tabular formats
        if !results.contains(where: { $0.testName.lowercased().contains("fasting glucose") || $0.testName.lowercased().contains("fbs") }) {
            if let fbs = extractFastingGlucoseFromTabular(from: text) {
                results.append(fbs)
                print("🔬 [MedicalDataParser] MATCHED Fasting Glucose (tabular extraction): \(fbs.value) mg/dL")
            }
        }
        
        // COMPREHENSIVE EXTRACTION: Use lineByLine parser to catch more results
        print("🔬 [MedicalDataParser] Running comprehensive lineByLine extraction...")
        let lineByLineResults = parseLineByLine(from: text, existingResults: results)
        if !lineByLineResults.isEmpty {
            results.append(contentsOf: lineByLineResults)
            print("🔬 [MedicalDataParser] LineByLine added \(lineByLineResults.count) additional results")
        }
        
        // Also try vitals extraction for heart rate, weight, blood pressure
        let vitals = extractVitals(from: text)
        for vital in vitals {
            if !results.contains(where: { $0.testName.lowercased() == vital.testName.lowercased() }) {
                results.append(vital)
            }
        }
        
        print("🔬 [MedicalDataParser] ========== parseLabResults COMPLETE: \(results.count) results found ==========")
        for (i, r) in results.enumerated() {
            print("   \(i+1). \(r.testName): \(r.value) \(r.unit) [\(r.category)]")
        }
        
        return results
    }
    
    // MARK: - Special HbA1c Extraction for Tabular Formats
    
    /// Extracts HbA1c from tabular lab reports where value might be separated
    /// Handles formats like: "Glycated Hemoglobin (HbA1c) ... 5.4 ... 4.0-5.6"
    private static func extractHbA1cFromTabular(from text: String) -> LabResultModel? {
        let lowercased = text.lowercased()
        
        // Check if HbA1c is mentioned anywhere in the text
        let hba1cKeywords = ["hba1c", "hbaic", "glycated hemoglobin", "glycated haemoglobin", "glycated hémoglobin", "hemoglobin a1c", "glycosylated"]
        
        var hasHbA1cMention = false
        for keyword in hba1cKeywords {
            if lowercased.contains(keyword) {
                hasHbA1cMention = true
                print("🔬 [HbA1c Extraction] Found keyword: \(keyword)")
                break
            }
        }
        
        if !hasHbA1cMention {
            return nil
        }
        
        // Look for HbA1c values in multiple patterns:
        // Pattern 1: "HbA1C ... 5.4 %" or "Glycated Hemoglobin ... 5.4%"
        let patterns = [
            #"(?:hba1c|hbaic|glycated\s*(?:h[ae]moglobin|hémoglobin))[^\d]*(\d+\.?\d*)\s*%"#,
            #"(?:hba1c|hbaic|glycated\s*(?:h[ae]moglobin|hémoglobin))[^\d]*(\d+\.?\d*)"#,
            #"(?:hba1c|hbaic)\s*[:\-\.]?\s*(\d+\.?\d*)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
               let valueRange = Range(match.range(at: 1), in: lowercased) {
                let valueStr = String(lowercased[valueRange])
                if let value = Double(valueStr), value >= 3.0, value <= 20.0 {
                    print("✅ [HbA1c Extraction] Found value: \(value) with pattern")
                    return LabResultModel(
                        testName: "HbA1c",
                        parameter: "HbA1c",
                        value: value,
                        unit: "%",
                        normalRange: "< 5.7%",
                        status: value < 5.7 ? "Normal" : (value < 6.5 ? "Borderline" : "High"),
                        testDate: Date(),
                        category: "Glucose"
                    )
                }
            }
        }
        
        // Pattern 2: Line-by-line search - find line with HbA1c and extract numbers
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let lineLower = line.lowercased()
            if hba1cKeywords.contains(where: { lineLower.contains($0) }) {
                // Extract all numbers from this line
                let numberPattern = #"(\d+\.?\d*)"#
                if let regex = try? NSRegularExpression(pattern: numberPattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let valueRange = Range(match.range(at: 1), in: line) {
                    let valueStr = String(line[valueRange])
                    if let value = Double(valueStr), value >= 3.0, value <= 20.0 {
                        print("✅ [HbA1c Extraction] Found value \(value) from line: \(line.prefix(60))...")
                        return LabResultModel(
                            testName: "HbA1c",
                            parameter: "HbA1c",
                            value: value,
                            unit: "%",
                            normalRange: "< 5.7%",
                            status: value < 5.7 ? "Normal" : (value < 6.5 ? "Borderline" : "High"),
                            testDate: Date(),
                            category: "Glucose"
                        )
                    }
                }
            }
        }
        
        print("⚠️ [HbA1c Extraction] Keyword found but no valid value extracted")
        return nil
    }
    
    /// Extracts Fasting Glucose from tabular lab reports
    private static func extractFastingGlucoseFromTabular(from text: String) -> LabResultModel? {
        let lowercased = text.lowercased()
        
        let fbsKeywords = ["fasting glucose", "fasting blood sugar", "fbs", "fbg", "f.b.s", "glucose fasting", "blood sugar fasting"]
        
        var hasFBSMention = false
        for keyword in fbsKeywords {
            if lowercased.contains(keyword) {
                hasFBSMention = true
                break
            }
        }
        
        if !hasFBSMention {
            return nil
        }
        
        // Look for FBS values
        let patterns = [
            #"(?:fasting\s*(?:glucose|blood\s*sugar)|fbs|fbg)[^\d]*(\d+\.?\d*)\s*(?:mg|mg/dl)?"#,
            #"(?:fbs|fbg)\s*[:\-\.]?\s*(\d+\.?\d*)"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
               let valueRange = Range(match.range(at: 1), in: lowercased) {
                let valueStr = String(lowercased[valueRange])
                if let value = Double(valueStr), value >= 40.0, value <= 600.0 {
                    return LabResultModel(
                        testName: "Fasting Glucose",
                        parameter: "Fasting Glucose",
                        value: value,
                        unit: "mg/dL",
                        normalRange: "70-100 mg/dL",
                        status: value < 100 ? "Normal" : (value < 126 ? "Borderline" : "High"),
                        testDate: Date(),
                        category: "Glucose"
                    )
                }
            }
        }
        
        return nil
    }
    
    private static func extractValue(from rawString: String) -> Double? {
        let cleaned = rawString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Handle Qualitative Terms
        if cleaned.contains("negative") || cleaned.contains("neg") || cleaned.contains("nil") || cleaned.contains("absent") { return 0.0 }
        if cleaned.contains("positive") || cleaned.contains("pos") || cleaned.contains("present") { return 1.0 }
        if cleaned.contains("trace") { return 0.5 }
        if cleaned.contains("normal") { return 0.0 } // As per Urobilinogen
        
        // 2. Handle Ranges (e.g., "2-3", "2 - 3")
        if cleaned.contains("-") {
            let parts = cleaned.components(separatedBy: "-")
            if parts.count == 2 {
                let p1 = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let p2 = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                // Recursively extract numeric from parts to handle "2 /hpf" etc
                if let v1 = extractNumeric(from: p1), let v2 = extractNumeric(from: p2) {
                    return (v1 + v2) / 2.0
                }
            }
        }
        
        // 3. Handle Inequalities (e.g., "< 0.5", "> 10")
        if cleaned.contains("<") {
             if let v = extractNumeric(from: cleaned) { return v } // Treat < 0.5 as 0.5 (conservative)
        }
        if cleaned.contains(">") {
             if let v = extractNumeric(from: cleaned) { return v + 0.1 } // Treat > 10 as 10.1 (indicative)
        }
        
        // 4. Standard Numeric Extraction
        return extractNumeric(from: cleaned)
    }
    
    // MARK: - Medical-Grade Validation
    
    /// Checks if a value is qualitative (Trace, Nil, Negative, etc.) and should NOT be converted to a number
    static func isQualitativeValue(_ text: String) -> Bool {
        let qualitativeTerms = [
            "trace", "nil", "negative", "positive", "absent", "present",
            "normal", "few", "many", "occasional", "rare", "moderate", "plenty",
            "1+", "2+", "3+", "4+", "++", "+++", "++++",
            "reactive", "non-reactive", "detected", "not detected"
        ]
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return qualitativeTerms.contains { lowercased.contains($0) }
    }
    
    /// Extract ONLY numeric values - returns nil for qualitative values
    /// This is a medical-grade strict extraction that NEVER fabricates numbers
    private static func extractValueStrict(from rawString: String) -> Double? {
        let cleaned = rawString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // RULE: Qualitative values MUST NOT be converted to numbers
        if isQualitativeValue(cleaned) {
            print("⚠️ [MedicalDataParser] REJECTED qualitative value: '\(rawString)' - not converting to number")
            return nil
        }
        
        // Handle ranges (e.g., "0-2") - take the upper bound for ranges like "0-2 /hpf"
        if cleaned.contains("-") && !cleaned.hasPrefix("-") {
            let parts = cleaned.components(separatedBy: "-")
            if parts.count == 2 {
                let p2 = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if let v2 = extractNumeric(from: p2) {
                    return v2 // Use upper bound of range
                }
            }
        }
        
        // Handle inequalities - these are valid numeric indicators
        if cleaned.contains("<") || cleaned.contains(">") {
            if let v = extractNumeric(from: cleaned) { return v }
        }
        
        // Standard numeric extraction
        return extractNumeric(from: cleaned)
    }
    
    private static func extractNumeric(from text: String) -> Double? {
        // Extract strictly the number part, handling decimals
        let validChars = Set("0123456789.")
        let numericString = text.filter { validChars.contains($0) }
        return Double(numericString)
    }
    
    // MARK: - Physiological Range Validation
    
    /// Validates that a value is within physiologically possible ranges
    /// Returns nil if value is biologically impossible (e.g., Potassium = 282885)
    static func validatePhysiologicalRange(testName: String, value: Double) -> Double? {
        // Define strict physiological limits for common tests
        let limits: [String: (min: Double, max: Double)] = [
            // Electrolytes
            "potassium": (2.0, 10.0),
            "sodium": (100.0, 180.0),
            "chloride": (80.0, 130.0),
            "calcium": (5.0, 15.0),
            "magnesium": (0.5, 5.0),
            "phosphorus": (1.0, 10.0),
            
            // Blood gases & pH
            "ph": (0.0, 14.0),
            "urine ph": (4.0, 9.0),
            
            // Liver enzymes
            "ast": (1.0, 2000.0),
            "alt": (1.0, 2000.0),
            "alp": (10.0, 1500.0),
            "ggt": (1.0, 1000.0),
            "alkaline phosphatase": (10.0, 1500.0),
            
            // Proteins
            "total protein": (3.0, 12.0),
            "albumin": (1.0, 7.0),
            "globulin": (1.0, 6.0),
            
            // Bilirubin
            "total bilirubin": (0.0, 30.0),
            "direct bilirubin": (0.0, 15.0),
            "indirect bilirubin": (0.0, 20.0),
            
            // Kidney function
            "creatinine": (0.1, 20.0),
            "urea": (5.0, 300.0),
            "bun": (2.0, 150.0),
            "egfr": (1.0, 200.0),
            "uric acid": (1.0, 20.0),
            
            // Lipids
            "total cholesterol": (50.0, 500.0),
            "hdl": (10.0, 150.0),
            "ldl": (20.0, 400.0),
            "triglycerides": (20.0, 2000.0),
            "vldl": (2.0, 200.0),
            "lipoprotein (a)": (0.0, 300.0),
            "apo b": (20.0, 300.0),
            
            // CBC
            "hemoglobin": (3.0, 25.0),
            "hematocrit": (10.0, 70.0),
            "rbc": (1.0, 10.0),
            "wbc": (500.0, 50000.0),
            "platelets": (10.0, 1500.0),
            "mcv": (50.0, 150.0),
            "mch": (15.0, 50.0),
            "mchc": (25.0, 45.0),
            
            // Differential counts (percentages)
            "neutrophils": (0.0, 100.0),
            "lymphocytes": (0.0, 100.0),
            "monocytes": (0.0, 100.0),
            "eosinophils": (0.0, 100.0),
            "basophils": (0.0, 100.0),
            
            // Absolute counts
            "anc": (0.0, 30000.0),
            "alc": (0.0, 15000.0),
            "amc": (0.0, 5000.0),
            "aec": (0.0, 5000.0),
            "abc": (0.0, 1000.0),
            
            // Thyroid
            "tsh": (0.01, 100.0),
            "t3": (0.1, 10.0),
            "t4": (1.0, 25.0),
            
            // Glucose
            "fasting glucose": (20.0, 600.0),
            "hba1c": (3.0, 20.0),
            
            // Inflammation
            "crp": (0.0, 500.0),
            "hs-crp": (0.0, 100.0),
            "esr": (0.0, 150.0),
            
            // Iron studies
            "serum iron": (10.0, 500.0),
            "tibc": (100.0, 700.0),
            "ferritin": (1.0, 5000.0),
            "transferrin saturation": (1.0, 100.0),
            
            // Vitamins
            "vitamin b12": (50.0, 2000.0),
            "vitamin d": (1.0, 200.0),
            
            // Pancreatic enzymes
            "amylase": (10.0, 2000.0),
            "lipase": (10.0, 2000.0),
            "fasting insulin": (0.5, 500.0),
            
            // Urinalysis
            "specific gravity": (1.000, 1.050),
        ]
        
        let testLower = testName.lowercased()
        
        // Check if this test has defined limits
        for (testKey, range) in limits {
            if testLower.contains(testKey) {
                if value < range.min || value > range.max {
                    print("🚫 [MedicalDataParser] REJECTED physiologically impossible value: \(testName) = \(value) (valid range: \(range.min)-\(range.max))")
                    return nil
                }
            }
        }
        
        // Additional general sanity check - no lab value should exceed 1 million
        if value > 1_000_000 {
            print("🚫 [MedicalDataParser] REJECTED absurdly high value: \(testName) = \(value)")
            return nil
        }
        
        return value
    }
    
    // MARK: - Vitals Extraction
    
    public static func extractVitals(from text: String) -> [LabResultModel] {
        var results: [LabResultModel] = []
        let lowercased = text.lowercased()
        
        // 1. Heart Rate (Pulse)
        if let hr = extractNumericVital(from: lowercased, keys: ["heart rate", "pulse", "pulse rate"], unit: "bpm") {
             results.append(LabResultModel(
                testName: "Heart Rate",
                value: hr,
                unit: "bpm",
                normalRange: "60-100 bpm",
                status: "Normal",
                category: "Vitals"
             ))
             print("❤️ [MedicalDataParser] EXTRACTED VITAL: Heart Rate = \(hr)")
        }
        
        // 2. Weight
        if let weight = extractNumericVital(from: lowercased, keys: ["weight", "body weight"], unit: "kg") {
             results.append(LabResultModel(
                testName: "Weight",
                value: weight,
                unit: "kg",
                normalRange: "",
                status: "Normal",
                category: "Vitals"
             ))
             print("⚖️ [MedicalDataParser] EXTRACTED VITAL: Weight = \(weight)")
        }
        
        // 3. Blood Group
        if let bg = extractBloodGroup(from: lowercased) {
             results.append(LabResultModel(
                testName: "Blood Group",
                value: 0.0,
                stringValue: bg,
                unit: "",
                normalRange: "",
                status: "Normal",
                category: "Vitals"
             ))
             print("🩸 [MedicalDataParser] EXTRACTED VITAL: Blood Group = \(bg)")
        }

        // 4. Blood Pressure (Composite)
        let bpPattern = #"(?:bp|blood pressure)[:\s-]*(\d{2,3}\s*[\/\\|]\s*\d{2,3})"#
        if let regex = try? NSRegularExpression(pattern: bpPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
           let range = Range(match.range(at: 1), in: lowercased) {
            let bpString = String(lowercased[range]).replacingOccurrences(of: " ", with: "")
            results.append(LabResultModel(
                testName: "Blood Pressure",
                value: 0.0,
                stringValue: bpString,
                unit: "mmHg",
                normalRange: "120/80",
                status: "Normal",
                category: "Vitals"
            ))
            print("🩺 [MedicalDataParser] EXTRACTED VITAL: Blood Pressure = \(bpString)")
        }
        
        return results
    }
    
    private static func extractNumericVital(from text: String, keys: [String], unit: String) -> Double? {
        // Pattern: Key ... Value ... Unit (optional)
        // e.g. "Weight: 80 kg" or "Heart Rate 96 /min"
        
        for key in keys {
            let escapedKey = NSRegularExpression.escapedPattern(for: key)
            let pattern = "\(escapedKey)[:\\s-]*(\\d{2,3})(?:\\s*\(unit))?"
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text),
               let val = Double(text[range]) {
                return val
            }
        }
        return nil
    }
    
    private static func extractBloodGroup(from text: String) -> String? {
        // Pattern: "Blood Group" ... [A/B/AB/O][+/-]
        let pattern = #"(?:blood group|abo group)[:\s-]*([ABO]{1,2}\s*[+-])"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            let bg = String(text[range]).uppercased().replacingOccurrences(of: " ", with: "")
            return bg
        }
        return nil
    }

    private static func extractBloodPressure(from text: String) -> (systolic: LabResultModel, diastolic: LabResultModel)? {
        let pattern = #"(?:bp|blood pressure)[:\s]*(\d{2,3})\s*[\/\\|]\s*(\d{2,3})"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let sRange = Range(match.range(at: 1), in: text),
           let dRange = Range(match.range(at: 2), in: text),
           let sVal = Double(text[sRange]),
           let dVal = Double(text[dRange]) {
            
            let sys = LabResultModel(
                testName: "Systolic BP",
                value: sVal,
                unit: "mmHg",
                normalRange: "90-120 mmHg",
                status: sVal > 120 ? "High" : sVal < 90 ? "Low" : "Normal",
                category: "Vitals"
            )
            
            let dia = LabResultModel(
                testName: "Diastolic BP",
                value: dVal,
                unit: "mmHg",
                normalRange: "60-80 mmHg",
                status: dVal > 80 ? "High" : dVal < 60 ? "Low" : "Normal",
                category: "Vitals"
            )
            
            return (sys, dia)
        }
        return nil
    }
    
    // MARK: - Universal Extraction (Fallback)
    
    /// Scans for any line containing valid units and extracts generic parameters
    public static func parseUniversalLabResults(from text: String, existingResults: [LabResultModel]) -> [LabResultModel] {
        var newResults: [LabResultModel] = []
        let lowercased = text.lowercased()
        let existingNames = Set(existingResults.map { $0.testName.lowercased() })
        
        // Units to look for (common lab units)
        let commonUnits = [
            "mg/dl", "g/dl", "mmol/l", "meq/l", "u/l", "iu/l", "ng/ml", "pg/ml", "ug/dl", "mck/ul", "mm/hr", "fl", "10^3/ul", "/hpf"
        ]
        
        // Regex to capture: (Label) (Value) (Unit)
        // Looks for text followed by a number followed by a known unit
        // Limit label length to avoid capturing full paragraphs
        let unitPattern = commonUnits.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        let pattern = #"(?m)^(.{2,30}?)\s+[:\-]?\s*(\d+(?:\.\d+)?)\s*("# + unitPattern + #")"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
             let range = NSRange(lowercased.startIndex..., in: lowercased)
             let matches = regex.matches(in: lowercased, range: range)
             
             for match in matches {
                 if let labelRange = Range(match.range(at: 1), in: lowercased),
                    let valueRange = Range(match.range(at: 2), in: lowercased),
                    let unitRange = Range(match.range(at: 3), in: lowercased) {
                     
                     let label = String(lowercased[labelRange]).trimmingCharacters(in: .whitespacesAndNewlines).capitalized
                     
                     // Skip if we already found this specific parameter
                     if !existingNames.contains(label.lowercased()) && !isLabelBlacklisted(label) {
                         let valueStr = String(lowercased[valueRange])
                         let unit = String(lowercased[unitRange])
                         
                         if let value = Double(valueStr) {
                             let genericResult = LabResultModel(
                                 testName: label,
                                 parameter: label,
                                 value: value,
                                 unit: unit,
                                 normalRange: "Unknown", // We don't know the range for generic
                                 status: "Normal", // Default to normal if we don't know standard
                                 testDate: Date(),
                                 category: "General"
                             )
                             newResults.append(genericResult)
                         }
                     }
                 }
             }
        }
        
        return newResults
    }
    
    // MARK: - Line-by-Line Parser (Most Comprehensive)
    
    /// Parses OCR text line by line, looking for any line containing a test name + numeric value
    /// This handles tabular formats like Orange Health Labs where columns become space-separated
    public static func parseLineByLine(from text: String, existingResults: [LabResultModel]) -> [LabResultModel] {
        var newResults: [LabResultModel] = []
        var existingNames = Set(existingResults.map { $0.testName.lowercased() })
        
        print("🔬 [MedicalDataParser] ========== parseLineByLine CALLED ==========")
        print("🔬 [MedicalDataParser] Scanning \(text.count) characters line by line...")
        
        // Known lab test names to look for (comprehensive list based on Orange Health Labs)
        let knownTests: [(name: String, aliases: [String], unit: String, category: String, organ: String)] = [
            // LIVER
            ("Total Bilirubin", ["bilirubin, total", "total bilirubin", "bilirubin total"], "mg/dL", "Liver", "Liver"),
            ("Direct Bilirubin", ["bilirubin, direct", "direct bilirubin", "bilirubin direct"], "mg/dL", "Liver", "Liver"),
            ("Indirect Bilirubin", ["bilirubin, indirect", "indirect bilirubin"], "mg/dL", "Liver", "Liver"),
            ("AST", ["aspartate aminotransferase", "sgot", "ast"], "U/L", "Liver", "Liver"),
            ("ALT", ["alanine transaminase", "sgpt", "alt"], "U/L", "Liver", "Liver"),
            ("Alkaline Phosphatase", ["alkaline phosphatase", "alp"], "U/L", "Liver", "Liver"),
            ("GGT", ["gamma-glutamyl", "ggt", "ggtp"], "U/L", "Liver", "Liver"),
            ("Total Protein", ["protein", "total protein"], "g/dL", "Liver", "Liver"),
            ("Albumin", ["albumin"], "g/dL", "Liver", "Liver"),
            ("Globulin", ["globulin"], "g/dL", "Liver", "Liver"),
            ("A/G Ratio", ["a/g ratio", "albumin/globulin"], "", "Liver", "Liver"),
            ("AST/ALT Ratio", ["ast/alt", "ast alt ratio", "aspartate aminotransferase/alanine"], "", "Liver", "Liver"),
            
            // PANCREAS
            ("Amylase", ["amylase"], "U/L", "Pancreas", "Pancreas"),
            ("Lipase", ["lipase"], "U/L", "Pancreas", "Pancreas"),
            ("Fasting Insulin", ["fasting insulin", "insulin fasting", "insulin"], "µU/mL", "Pancreas", "Pancreas"),
            
            // KIDNEYS
            ("Urea", ["urea", "blood urea"], "mg/dL", "Kidney", "Kidneys"),
            ("Creatinine", ["creatinine"], "mg/dL", "Kidney", "Kidneys"),
            ("BUN", ["bun", "blood urea nitrogen"], "mg/dL", "Kidney", "Kidneys"),
            ("BUN/Creatinine Ratio", ["bun/creatinine"], "", "Kidney", "Kidneys"),
            ("eGFR", ["egfr", "estimated glomerular"], "mL/min", "Kidney", "Kidneys"),
            ("Uric Acid", ["uric acid"], "mg/dL", "Kidney", "Kidneys"),
            
            // ELECTROLYTES
            ("Sodium", ["sodium"], "mmol/L", "Electrolytes", "Kidneys"),
            ("Potassium", ["potassium"], "mmol/L", "Electrolytes", "Kidneys"),
            ("Chloride", ["chloride"], "mmol/L", "Electrolytes", "Kidneys"),
            ("Calcium", ["calcium"], "mg/dL", "Electrolytes", "Kidneys"),
            ("Phosphorus", ["phosphorus"], "mg/dL", "Electrolytes", "Kidneys"),
            ("Magnesium", ["magnesium"], "mg/dL", "Electrolytes", "Kidneys"),
            
            // LIPIDS (HEART)
            ("Total Cholesterol", ["cholesterol, total", "total cholesterol", "cholesterol"], "mg/dL", "Lipid", "Heart"),
            ("Triglycerides", ["triglycerides"], "mg/dL", "Lipid", "Heart"),
            ("HDL", ["hdl", "hdl cholesterol", "high-density"], "mg/dL", "Lipid", "Heart"),
            ("LDL", ["ldl", "ldl cholesterol", "low-density lipoprotein"], "mg/dL", "Lipid", "Heart"),
            ("Non-HDL", ["non-hdl", "non-high density"], "mg/dL", "Lipid", "Heart"),
            ("VLDL", ["vldl", "very low-density"], "mg/dL", "Lipid", "Heart"),
            ("Chol/HDL Ratio", ["cholesterol/hdl", "chol/hdl"], "", "Lipid", "Heart"),
            ("LDL/HDL Ratio", ["ldl/hdl"], "", "Lipid", "Heart"),
            ("Apo B", ["apolipoprotein b", "apo b"], "mg/dL", "Lipid", "Heart"),
            ("Lipoprotein (a)", ["lipoprotein (a)", "lp(a)", "lipoprotein a"], "mg/dL", "Lipid", "Heart"),
            
            // INFLAMMATION
            ("CRP", ["c-reactive protein", "crp"], "mg/L", "Inflammation", "Heart"),
            ("hs-CRP", ["high sensitivity c-reactive", "hscrp", "hs-crp"], "mg/L", "Inflammation", "Heart"),
            ("ESR", ["erythrocyte sedimentation", "esr"], "mm/hr", "Inflammation", "Blood"),
            
            // BLOOD (CBC)
            ("Hemoglobin", ["hemoglobin", "haemoglobin", "hb"], "g/dL", "Blood Count", "Blood"),
            ("RBC", ["rbc count", "red blood cell", "erythrocyte"], "mill/mm³", "Blood Count", "Blood"),
            ("WBC", ["wbc count", "white blood cell", "leukocyte"], "cells/mm³", "Blood Count", "Blood"),
            ("Platelets", ["platelet count", "platelets", "thrombocyte"], "×10³/µL", "Blood Count", "Blood"),
            ("Hematocrit", ["hematocrit", "hct", "pcv"], "%", "Blood Count", "Blood"),
            ("MCV", ["mcv", "mean corpuscular volume"], "fL", "Blood Count", "Blood"),
            ("MCH", ["mch", "mean corpuscular hgb"], "pg", "Blood Count", "Blood"),
            ("MCHC", ["mchc"], "g/dL", "Blood Count", "Blood"),
            ("RDW", ["rdw", "red cell distribution"], "%", "Blood Count", "Blood"),
            ("ANC", ["anc", "absolute neutrophil"], "/mm³", "Differential", "Blood"),
            ("ALC", ["alc", "absolute lymphocyte"], "/mm³", "Differential", "Blood"),
            ("NLR", ["nlr", "neutrophil/lymphocyte"], "", "Differential", "Blood"),
            
            // GLUCOSE/DIABETES - EXPANDED FOR OCR VARIATIONS
            ("Fasting Glucose", ["fasting glucose", "glucose fasting", "blood glucose", "fbs", "f.b.s", "fbg", "fasting blood sugar", "fasting blood glucose"], "mg/dL", "Glucose", "Pancreas"),
            ("HbA1c", ["hba1c", "hbaic", "glycated hemoglobin", "glycated haemoglobin", "glycosylated", "glycated hémoglobin", "hemoglobin a1c", "haemoglobin a1c", "a1c", "hb a1c"], "%", "Glucose", "Pancreas"),
            ("PP Glucose", ["ppbs", "ppbg", "post prandial glucose", "pp glucose", "post prandial blood sugar", "2hr glucose"], "mg/dL", "Glucose", "Pancreas"),
            ("Mean Blood Glucose", ["mean blood glucose", "average glucose"], "mg/dL", "Glucose", "Pancreas"),
            
            // THYROID
            ("TSH", ["tsh", "thyroid stimulating"], "µIU/mL", "Thyroid", "Thyroid"),
            ("T3", ["t3", "triiodothyronine"], "ng/mL", "Thyroid", "Thyroid"),
            ("T4", ["t4", "thyroxine"], "µg/dL", "Thyroid", "Thyroid"),
            ("Free T3", ["free t3", "ft3"], "pg/mL", "Thyroid", "Thyroid"),
            ("Free T4", ["free t4", "ft4"], "ng/dL", "Thyroid", "Thyroid"),
            
            // IRON
            ("Serum Iron", ["iron", "serum iron"], "µg/dL", "Iron", "Blood"),
            ("TIBC", ["tibc", "total iron binding"], "µg/dL", "Iron", "Blood"),
            ("UIBC", ["uibc", "unbound iron"], "µg/dL", "Iron", "Blood"),
            ("Transferrin Saturation", ["transferrin saturation", "tsat"], "%", "Iron", "Blood"),
            ("Ferritin", ["ferritin"], "ng/mL", "Iron", "Blood"),
            
            // VITAMINS
            ("Vitamin B12", ["vitamin b12", "b12", "cyanocobalamin"], "pg/mL", "Vitamins", "Vitamins"),
            ("Vitamin D", ["vitamin d", "25-hydroxy", "cholecalciferol"], "ng/mL", "Vitamins", "Vitamins"),
            ("Folate", ["folate", "folic acid"], "ng/mL", "Vitamins", "Vitamins"),
            
            // DIFFERENTIAL COUNTS (Percentages)
            ("Neutrophils", ["neutrophils", "neutrophil"], "%", "Differential", "Blood"),
            ("Lymphocytes", ["lymphocytes", "lymphocyte"], "%", "Differential", "Blood"),
            ("Monocytes", ["monocytes", "monocyte"], "%", "Differential", "Blood"),
            ("Eosinophils", ["eosinophils", "eosinophil"], "%", "Differential", "Blood"),
            ("Basophils", ["basophils", "basophil"], "%", "Differential", "Blood"),
            
            // ABSOLUTE COUNTS
            ("AMC", ["amc", "absolute monocyte"], "/mm³", "Differential", "Blood"),
            ("AEC", ["aec", "absolute eosinophil"], "/mm³", "Differential", "Blood"),
            ("ABC", ["abc", "absolute basophil"], "/mm³", "Differential", "Blood"),
            
            // PLATELET INDICES
            ("MPV", ["mpv", "mean platelet volume"], "fL", "Blood Count", "Blood"),
            ("Platelet Hematocrit", ["platelet hematocrit", "pct"], "%", "Blood Count", "Blood"),
            ("PDW", ["pdw", "platelet distribution"], "%", "Blood Count", "Blood"),
            
            // PROSTATE
            ("PSA", ["psa", "prostate specific"], "ng/mL", "Prostate", "Prostate"),
            
            // URINALYSIS
            ("Urine pH", ["ph", "urine ph"], "", "Urinalysis", "Urinary"),
            ("Specific Gravity", ["specific gravity"], "", "Urinalysis", "Urinary"),
            ("Urine Volume", ["volume", "urine volume"], "mL", "Urinalysis", "Urinary"),
            ("Pus Cells", ["pus cells", "pus cell"], "/hpf", "Urinalysis", "Urinary"),
            ("Epithelial Cells", ["epithelial cells", "epithelial"], "/hpf", "Urinalysis", "Urinary"),
            ("RBC Urine", ["rbc", "red blood cells"], "/hpf", "Urinalysis", "Urinary"),
            ("Urine Protein", ["protein", "urine protein"], "", "Urinalysis", "Urinary"),
            ("Urine Glucose", ["glucose", "urine glucose"], "", "Urinalysis", "Urinary"),
            ("Urine Ketones", ["ketones", "ketone"], "", "Urinalysis", "Urinary"),
            ("Urine Bilirubin", ["bilirubin", "urine bilirubin"], "", "Urinalysis", "Urinary"),
            ("Urobilinogen", ["urobilinogen"], "", "Urinalysis", "Urinary"),
            ("Urine Blood", ["blood", "urine blood"], "", "Urinalysis", "Urinary"),
            ("Leucocyte Esterase", ["leucocyte esterase", "leukocyte esterase"], "", "Urinalysis", "Urinary"),
            ("Nitrites", ["nitrites", "nitrite"], "", "Urinalysis", "Urinary"),
            
            // CALCULATED INDICES
            ("Mentzer Index", ["mentzer index"], "", "Blood Count", "Blood"),
            ("Sehgal Index", ["sehgal index"], "", "Blood Count", "Blood"),
        ]
        
        // Split text into lines
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let lowercasedLine = line.lowercased().trimmingCharacters(in: .whitespaces)
            
            // Skip very short lines or header lines
            if lowercasedLine.count < 5 { continue }
            if lowercasedLine.contains("test") && lowercasedLine.contains("result") { continue }
            if lowercasedLine.contains("biological reference") { continue }
            
            // Check if this line contains any known test
            for test in knownTests {
                var matched = false
                
                // Check main name
                if lowercasedLine.contains(test.name.lowercased()) {
                    matched = true
                }
                
                // Check aliases
                if !matched {
                    for alias in test.aliases {
                        if lowercasedLine.contains(alias.lowercased()) {
                            matched = true
                            break
                        }
                    }
                }
                
                if matched && !existingNames.contains(test.name.lowercased()) {
                    // RULE: Skip qualitative values - they should NOT be converted to numbers
                    if isQualitativeValue(lowercasedLine) {
                        print("⚠️ [LineByLine] SKIPPED qualitative line for \(test.name): '\(line.prefix(50))...'")
                        continue
                    }
                    
                    var extractedValue: Double? = nil
                    
                    // Extract numeric value from this line
                    // Pattern 1: find a number followed by unit (most reliable)
                    let valuePattern = #"(?<!\d)(\d+\.?\d*)\s*(?:mg|g|u/l|iu|ng|pg|µg|mmol|meq|%|ml|cells|mill|×|\^|/)"#
                    
                    if let regex = try? NSRegularExpression(pattern: valuePattern, options: .caseInsensitive) {
                        let range = NSRange(lowercasedLine.startIndex..., in: lowercasedLine)
                        if let match = regex.firstMatch(in: lowercasedLine, range: range),
                           let valueRange = Range(match.range(at: 1), in: lowercasedLine) {
                            let valueStr = String(lowercasedLine[valueRange])
                            extractedValue = Double(valueStr)
                        }
                    }
                    
                    // Pattern 2: If no unit match, try standalone decimal numbers (for tabular formats)
                    if extractedValue == nil {
                        let standalonePattern = #"(?<![0-9\-])(\d+\.\d+)(?![0-9\-])"# // Matches decimals like 5.4, 145.2
                        if let regex = try? NSRegularExpression(pattern: standalonePattern) {
                            let range = NSRange(lowercasedLine.startIndex..., in: lowercasedLine)
                            if let match = regex.firstMatch(in: lowercasedLine, range: range),
                               let valueRange = Range(match.range(at: 1), in: lowercasedLine) {
                                let valueStr = String(lowercasedLine[valueRange])
                                extractedValue = Double(valueStr)
                            }
                        }
                    }
                    
                    // Validate and add result
                    if let rawValue = extractedValue {
                        // MEDICAL-GRADE VALIDATION: Check physiological plausibility
                        if let validatedValue = validatePhysiologicalRange(testName: test.name, value: rawValue) {
                            let result = LabResultModel(
                                testName: test.name,
                                parameter: test.name,
                                value: validatedValue,
                                unit: test.unit,
                                normalRange: "See Report",
                                status: "Normal",
                                testDate: Date(),
                                category: test.category
                            )
                            newResults.append(result)
                            existingNames.insert(test.name.lowercased())
                            print("✅ [LineByLine] VALID: \(test.name) = \(validatedValue) \(test.unit)")
                        }
                    }
                }
            }
        }
        
        print("🔬 [MedicalDataParser] ========== parseLineByLine COMPLETE: \(newResults.count) additional results ==========")
        return newResults
    }
    
    private static func isLabelBlacklisted(_ label: String) -> Bool {
        let blacklist = ["result", "range", "units", "flag", "reference", "test", "name", "value", "report", "date", "patient", "dr", "doctor", "biological", "clinical", "significance"]
        return blacklist.contains(label.lowercased())
    }
    
    // MARK: - Medication Parsing
    
    static func parseMedications(from text: String) -> [MedicationModel] {
        var medications: [MedicationModel] = []
        let lowercased = text.lowercased()
        
        // Enhanced medication regex: Name + Dosage + optional frequency
        // Example: "Lipitor 20mg daily" or "Aspirin 81 mg once a day"
        let medPattern = #"([a-z]{3,})\s+(\d+\s*(?:mg|mcg|ml|g|gm|iu))\s*((?:once|twice|thrice|daily|od|bd|tid|qid|q\d+h|hs|every\s\d+\shours)[^.\n,]*|)"#
        
        if let regex = try? NSRegularExpression(pattern: medPattern, options: .caseInsensitive) {
            let range = NSRange(lowercased.startIndex..., in: lowercased)
            let matches = regex.matches(in: lowercased, range: range)
            
            for match in matches {
                if let nameRange = Range(match.range(at: 1), in: lowercased),
                   let dosageRange = Range(match.range(at: 2), in: lowercased) {
                    
                    let name = String(lowercased[nameRange]).capitalized
                    let dosage = String(lowercased[dosageRange])
                    var frequency = "As prescribed"
                    
                    if match.numberOfRanges > 3, let freqRange = Range(match.range(at: 3), in: lowercased) {
                        let extractedFreq = String(lowercased[freqRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !extractedFreq.isEmpty {
                            frequency = extractedFreq.capitalized
                        }
                    }
                    
                    // Basic blacklist for common non-medication words picked up by scanner
                    let blacklist = ["Report", "Patient", "Doctor", "Medical", "Hospital", "Results", "Ref Range", "Result"]
                    if !blacklist.contains(name) {
                        let medication = MedicationModel(
                            name: name,
                            dosage: dosage,
                            frequency: frequency,
                            startDate: Date(),
                            isActive: true
                        )
                        medications.append(medication)
                    }
                }
            }
        }
        
        return medications
    }
    
    // MARK: - Report Type & Organ
    
    static func detectReportType(from text: String) -> String {
        let lowercased = text.lowercased()
        
        // Priority based on keywords
        if lowercased.contains("prescription") || lowercased.contains("rx:") { return "Prescription" }
        if lowercased.contains("lipid") || lowercased.contains("cholesterol") { return "Lipid Panel" }
        if lowercased.contains("cbc") || lowercased.contains("hemoglobin") { return "Blood Test" }
        if lowercased.contains("liver") || lowercased.contains("lft") || lowercased.contains("hepatic") { return "Liver Function Test" }
        if lowercased.contains("kidney") || lowercased.contains("renal") || lowercased.contains("creatinine") { return "Kidney Function Test" }
        if lowercased.contains("discharge") || lowercased.contains("clinical summary") { return "Clinical Summary" }
        if lowercased.contains("imaging") || lowercased.contains("radiology") { return "Imaging Report" }
        
        return "Medical Report"
    }
    
    // MARK: - Status Logic
    
    private static func determineStatus(value: Double, metadata: LabTestMetadata) -> String {
        // Advanced status logic using metadata ranges
        let range = metadata.normalRange.lowercased()
        
        if range.contains("<") {
            let limitPart = range.components(separatedBy: CharacterSet.decimalDigits.inverted).joined(separator: "")
            if let limit = Double(limitPart), value > limit { return "High" }
            return "Normal"
        }
        
        if range.contains(">") {
            let limitPart = range.components(separatedBy: CharacterSet.decimalDigits.inverted).joined(separator: "")
            if let limit = Double(limitPart), value < limit { return "Low" }
            return "Normal"
        }
        
        if range.contains("-") {
            let parts = range.components(separatedBy: "-")
            if parts.count == 2 {
                let lowPart = parts[0].components(separatedBy: CharacterSet.decimalDigits.inverted.subtracting(CharacterSet(charactersIn: "."))).joined()
                let highPart = parts[1].components(separatedBy: CharacterSet.decimalDigits.inverted.subtracting(CharacterSet(charactersIn: "."))).joined()
                
                if let low = Double(lowPart), let high = Double(highPart) {
                    if value < low { return "Low" }
                    if value > high { return "High" }
                }
            }
        }
        
        return "Normal"
    }
}

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
