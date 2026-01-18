import SwiftUI
import SwiftData

/// Provides dynamic medical standards and relationship logic for intelligent health analysis
class MedicalStandardProvider {
    
    // MARK: - Standard Range
    struct StandardRange {
        let min: Double
        let max: Double
        let unit: String
        let description: String
        let severity: Severity
        
        enum Severity {
            case normal
            case borderline
            case abnormal
            case critical
        }
        
        func assess(value: Double) -> (status: String, severity: Severity) {
            if value < min {
                let percentBelow = ((min - value) / min) * 100
                if percentBelow > 30 {
                    return ("Critically Low", .critical)
                } else if percentBelow > 15 {
                    return ("Low", .abnormal)
                } else {
                    return ("Low", .borderline)
                }
            } else if value > max {
                let percentAbove = ((value - max) / max) * 100
                if percentAbove > 40 {
                    return ("Critically High", .critical)
                } else if percentAbove > 15 {
                    return ("High", .abnormal)
                } else {
                    return ("Borderline High", .borderline)
                }
            } else {
                return ("Normal", .normal)
            }
        }
    }
    
    // MARK: - Correlative Pattern
    struct CorrelativePattern {
        let name: String
        let markers: [String] // Parameter names that must be abnormal
        let condition: String // Description of what this pattern implies
        let alertLevel: StandardRange.Severity
    }
    
    private let userProfile: UserProfileModel
    
    init(userProfile: UserProfileModel) {
        self.userProfile = userProfile
    }
    
    // MARK: - Get Standards
    
    func getStandard(for parameter: String) -> StandardRange? {
        let normalizedParam = parameter.lowercased().trimmingCharacters(in: .whitespaces)
        
        // BMI
        if normalizedParam == "bmi" || normalizedParam == "body mass index" {
             return bmiRange
        }
        
        // Weight (Derived from Height & BMI)
        else if normalizedParam == "weight" || normalizedParam == "body weight" {
            return weightRange
        }
        
        // Blood Count
        else if normalizedParam.contains("hemoglobin") || normalizedParam.contains("hb") {
            return hemoglobinRange
        } else if normalizedParam.contains("wbc") || normalizedParam.contains("white blood") {
            return wbcRange
        } else if normalizedParam.contains("rbc") || normalizedParam.contains("red blood") {
            return rbcRange
        } else if normalizedParam.contains("platelet") {
            return plateletRange
        }
        
        // Lipid Panel (Indian specific: strict due to high cardiovascular risk)
        else if normalizedParam.contains("cholesterol") && !normalizedParam.contains("ldl") && !normalizedParam.contains("hdl") {
            return totalCholesterolRange
        } else if normalizedParam.contains("ldl") {
            return ldlRange
        } else if normalizedParam.contains("hdl") {
            return hdlRange
        } else if normalizedParam.contains("triglyceride") {
            return triglycerideRange
        }
        
        // Glucose & Diabetes (ICMR Guidelines)
        else if normalizedParam.contains("glucose") && normalizedParam.contains("fasting") {
            return fastingGlucoseRange
        } else if normalizedParam.contains("ppbs") || (normalizedParam.contains("glucose") && normalizedParam.contains("post")) {
            return postPrandialGlucoseRange
        } else if normalizedParam.contains("hba1c") || normalizedParam.contains("a1c") {
            return hba1cRange
        }
        
        // Liver Function
        else if normalizedParam.contains("alt") || normalizedParam.contains("sgpt") {
            return altRange
        } else if normalizedParam.contains("ast") || normalizedParam.contains("sgot") {
            return astRange
        } else if normalizedParam.contains("bilirubin") && normalizedParam.contains("total") {
            return bilirubinRange
        }
        
        // Kidney Function
        else if normalizedParam.contains("creatinine") {
            return creatinineRange
        } else if normalizedParam.contains("egfr") {
            return egfrRange
        } else if normalizedParam.contains("bun") || normalizedParam.contains("urea") {
            return bunRange
        }
        
        // Electrolytes & Minerals
        else if normalizedParam.contains("sodium") {
            return sodiumRange
        } else if normalizedParam.contains("potassium") {
            return potassiumRange
        } else if normalizedParam.contains("calcium") {
            return calciumRange
        } else if normalizedParam.contains("magnesium") {
            return magnesiumRange
        }
        
        // Iron Studies
        else if normalizedParam.contains("iron") && !normalizedParam.contains("ferritin") {
            return serumIronRange
        } else if normalizedParam.contains("ferritin") {
            return ferritinRange
        }
        
        // Vitals
        else if normalizedParam.contains("heart rate") || normalizedParam.contains("pulse") {
            return heartRateRange
        } else if normalizedParam.contains("blood pressure") && normalizedParam.contains("systolic") {
            return systolicBPRange
        } else if normalizedParam.contains("blood pressure") && normalizedParam.contains("diastolic") {
            return diastolicBPRange
        } else if normalizedParam.contains("spo2") || normalizedParam.contains("oxygen") {
            return spo2Range
        }
        
        // Thyroid
        else if normalizedParam.contains("tsh") {
            return tshRange
        } else if normalizedParam.contains("t3") {
            return t3Range
        } else if normalizedParam.contains("t4") {
            return t4Range
        }
        
        // Vitamins
        else if normalizedParam.contains("vitamin d") || normalizedParam.contains("vit d") {
            return vitaminDRange
        } else if normalizedParam.contains("vitamin b12") || normalizedParam.contains("b12") {
            return vitaminB12Range
        }
        
        return nil
    }
    
    /// Get correlations patterns to check for
    var clinicalPatterns: [CorrelativePattern] {
        [
            CorrelativePattern(name: "Microcytic Anemia Risk", markers: ["Hemoglobin", "Ferritin"], condition: "Low hemoglobin combined with low ferritin strongly suggests iron-deficiency anemia, common in India.", alertLevel: .abnormal),
            CorrelativePattern(name: "Metabolic Syndrome Profile", markers: ["Glucose", "Triglycerides", "HDL Cholesterol"], condition: "Elevated sugar and lipids alongside low healthy cholesterol indicates high metabolic risk.", alertLevel: .abnormal),
            CorrelativePattern(name: "Dehydration Indicator", markers: ["Sodium", "BUN"], condition: "Elevated levels of sodium and BUN often point to acute dehydration.", alertLevel: .borderline),
            CorrelativePattern(name: "Renal Contrast Risk", markers: ["Creatinine", "eGFR"], condition: "The relationship between rising creatinine and falling eGFR indicates worsening kidney clearance.", alertLevel: .critical)
        ]
    }
    
    // MARK: - Range Definitions (Indian Standards)
    
    private var bmiRange: StandardRange {
        // Asian/Indian BMI Standards (WHO Expert Consultation)
        // Normal: 18.5 - 22.9
        // Overweight: 23 - 24.9
        // Obese: >= 25
        StandardRange(min: 18.5, max: 22.9, unit: "kg/m²", description: "Normal BMI (Asian Standard)", severity: .normal)
    }
    
    private var weightRange: StandardRange {
        guard let heightCM = userProfile.height, heightCM > 0 else {
            // Fallback if height is missing (Standard 70kg male reference)
            return StandardRange(min: 50, max: 80, unit: "kg", description: "Normal Weight (Estimate)", severity: .normal)
        }
        
        let heightM: Double = heightCM / 100.0
        // Target BMI 18.5 - 22.9 for Indians
        let minBMI: Double = 18.5
        let maxBMI: Double = 22.9
        
        let minWeight: Double = minBMI * (heightM * heightM)
        let maxWeight: Double = maxBMI * (heightM * heightM)
        
        return StandardRange(
            min: minWeight,
            max: maxWeight,
            unit: "kg",
            description: "Ideal Weight for Height \(Int(heightCM))cm",
            severity: .normal
        )
    }
    
    private var hemoglobinRange: StandardRange {
        switch userProfile.gender.lowercased() {
        case "male":
            return StandardRange(min: 13.0, max: 17.0, unit: "g/dL", description: "Normal Hemoglobin (Male)", severity: .normal)
        case "female":
            // Slightly lower lower-bound tolerance due to high prevalence of mild anemia in India
            return StandardRange(min: 11.5, max: 15.0, unit: "g/dL", description: "Normal Hemoglobin (Female)", severity: .normal)
        default:
            return StandardRange(min: 12.0, max: 16.0, unit: "g/dL", description: "Normal Hemoglobin", severity: .normal)
        }
    }
    
    private var wbcRange: StandardRange {
        StandardRange(min: 4.0, max: 11.0, unit: "×10³/µL", description: "Normal White Blood Cell Count", severity: .normal)
    }
    
    private var rbcRange: StandardRange {
        switch userProfile.gender.lowercased() {
        case "male":
            return StandardRange(min: 4.5, max: 6.5, unit: "million/µL", description: "Normal RBC (Male)", severity: .normal)
        case "female":
            return StandardRange(min: 3.8, max: 5.8, unit: "million/µL", description: "Normal RBC (Female)", severity: .normal)
        default:
            return StandardRange(min: 4.0, max: 6.0, unit: "million/µL", description: "Normal RBC", severity: .normal)
        }
    }
    
    private var plateletRange: StandardRange {
        StandardRange(min: 150, max: 450, unit: "×10³/µL", description: "Normal Platelet Count", severity: .normal)
    }
    
    private var totalCholesterolRange: StandardRange {
        StandardRange(min: 125, max: 200, unit: "mg/dL", description: "Desirable Total Cholesterol", severity: .normal)
    }
    
    private var ldlRange: StandardRange {
        // Indian Heart Association recommends < 100 mg/dL strictly
        StandardRange(min: 0, max: 100, unit: "mg/dL", description: "Optimal LDL", severity: .normal)
    }
    
    private var hdlRange: StandardRange {
        StandardRange(min: 40, max: 100, unit: "mg/dL", description: "Healthy HDL", severity: .normal)
    }
    
    private var triglycerideRange: StandardRange {
        // Indian diet is high in carbs, often leading to higher triglycerides.
        // Standard is < 150 mg/dL.
        StandardRange(min: 0, max: 150, unit: "mg/dL", description: "Normal Triglycerides", severity: .normal)
    }
    
    private var fastingGlucoseRange: StandardRange {
        // ADA & ICMR Guidelines
        // 70-100 Normal
        // 100-125 Prediabetes
        // 126+ Diabetes
        StandardRange(min: 70, max: 100, unit: "mg/dL", description: "Normal Fasting Glucose", severity: .normal)
    }
    
    private var postPrandialGlucoseRange: StandardRange {
        // < 140 Normal
        // 140-199 Prediabetes (Impaired Glucose Tolerance)
        // 200+ Diabetes
         StandardRange(min: 70, max: 140, unit: "mg/dL", description: "Normal PPBS", severity: .normal)
    }
    
    private var hba1cRange: StandardRange {
        // < 5.7% Normal
        // 5.7% - 6.4% Prediabetes
        // >= 6.5% Diabetes
        StandardRange(min: 4.0, max: 5.7, unit: "%", description: "Normal HbA1c", severity: .normal)
    }
    
    private var altRange: StandardRange {
        StandardRange(min: 7, max: 56, unit: "U/L", description: "Normal ALT", severity: .normal)
    }
    
    private var astRange: StandardRange {
        StandardRange(min: 10, max: 40, unit: "U/L", description: "Normal AST", severity: .normal)
    }
    
    private var bilirubinRange: StandardRange {
        StandardRange(min: 0.1, max: 1.2, unit: "mg/dL", description: "Normal Total Bilirubin", severity: .normal)
    }
    
    private var creatinineRange: StandardRange {
        switch userProfile.gender.lowercased() {
        case "male":
            return StandardRange(min: 0.7, max: 1.3, unit: "mg/dL", description: "Normal Creatinine (Male)", severity: .normal)
        case "female":
            return StandardRange(min: 0.6, max: 1.1, unit: "mg/dL", description: "Normal Creatinine (Female)", severity: .normal)
        default:
            return StandardRange(min: 0.6, max: 1.2, unit: "mg/dL", description: "Normal Creatinine", severity: .normal)
        }
    }
    
    private var egfrRange: StandardRange {
        if userProfile.age >= 60 {
            return StandardRange(min: 60, max: 90, unit: "mL/min/1.73m²", description: "Normal eGFR (60+)", severity: .normal)
        } else {
            return StandardRange(min: 90, max: 120, unit: "mL/min/1.73m²", description: "Normal eGFR", severity: .normal)
        }
    }
    
    private var bunRange: StandardRange {
        StandardRange(min: 7, max: 20, unit: "mg/dL", description: "Normal BUN", severity: .normal)
    }
    
    private var sodiumRange: StandardRange {
        StandardRange(min: 135, max: 145, unit: "mEq/L", description: "Normal Sodium", severity: .normal)
    }
    
    private var potassiumRange: StandardRange {
        StandardRange(min: 3.5, max: 5.1, unit: "mEq/L", description: "Normal Potassium", severity: .normal)
    }
    
    private var calciumRange: StandardRange {
        StandardRange(min: 8.5, max: 10.5, unit: "mg/dL", description: "Normal Calcium", severity: .normal)
    }
    
    private var magnesiumRange: StandardRange {
        StandardRange(min: 1.7, max: 2.2, unit: "mg/dL", description: "Normal Magnesium", severity: .normal)
    }
    
    private var serumIronRange: StandardRange {
        StandardRange(min: 60, max: 170, unit: "µg/dL", description: "Normal Serum Iron", severity: .normal)
    }
    
    private var ferritinRange: StandardRange {
        switch userProfile.gender.lowercased() {
        case "male":
            return StandardRange(min: 24, max: 336, unit: "ng/mL", description: "Normal Ferritin (Male)", severity: .normal)
        case "female":
            return StandardRange(min: 11, max: 307, unit: "ng/mL", description: "Normal Ferritin (Female)", severity: .normal)
        default:
            return StandardRange(min: 20, max: 300, unit: "ng/mL", description: "Normal Ferritin", severity: .normal)
        }
    }
    
    private var heartRateRange: StandardRange {
        if userProfile.age < 18 {
            return StandardRange(min: 70, max: 100, unit: "BPM", description: "Normal Heart Rate (Youth)", severity: .normal)
        } else if userProfile.age >= 60 {
            return StandardRange(min: 60, max: 90, unit: "BPM", description: "Normal Heart Rate (Senior)", severity: .normal)
        } else {
            return StandardRange(min: 60, max: 100, unit: "BPM", description: "Normal Resting Heart Rate", severity: .normal)
        }
    }
    
    private var systolicBPRange: StandardRange {
        // ACC/AHA & Indian Hypertension Guidelines (Normal < 120/80)
        // Elevated: 120-129 / <80
        // Stage 1: 130-139 / 80-89
        // Stage 2: >= 140 / >= 90
        // We set range for 'Normal' here
        StandardRange(min: 90, max: 120, unit: "mmHg", description: "Normal Systolic Blood Pressure", severity: .normal)
    }
    
    private var diastolicBPRange: StandardRange {
        StandardRange(min: 60, max: 80, unit: "mmHg", description: "Normal Diastolic Blood Pressure", severity: .normal)
    }
    
    private var spo2Range: StandardRange {
        StandardRange(min: 95, max: 100, unit: "%", description: "Normal Oxygen Saturation", severity: .normal)
    }
    
    private var tshRange: StandardRange {
        StandardRange(min: 0.4, max: 4.0, unit: "mIU/L", description: "Normal TSH", severity: .normal)
    }
    
    private var t3Range: StandardRange {
        StandardRange(min: 80, max: 200, unit: "ng/dL", description: "Normal T3", severity: .normal)
    }
    
    private var t4Range: StandardRange {
        StandardRange(min: 5.0, max: 12.0, unit: "µg/dL", description: "Normal T4", severity: .normal)
    }
    
    private var vitaminDRange: StandardRange {
        // 30-100 is sufficient. <20 deficiency, 20-29 insufficiency.
        StandardRange(min: 30, max: 100, unit: "ng/mL", description: "Sufficient Vitamin D", severity: .normal)
    }
    
    private var vitaminB12Range: StandardRange {
        StandardRange(min: 200, max: 900, unit: "pg/mL", description: "Normal Vitamin B12", severity: .normal)
    }
}
