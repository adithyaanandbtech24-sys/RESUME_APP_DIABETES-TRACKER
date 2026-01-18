import Foundation
import SwiftData

// MARK: - Diabetes Target Engine
// A clinical-grade service providing personalized targets based on user profile.
// All thresholds are based on ADA (American Diabetes Association) guidelines.

/// Personalized glucose targets
struct GlucoseTargets {
    let fastingMin: Double
    let fastingMax: Double
    let postPrandialMax: Double  // 2-hour post-meal
    let randomMax: Double
    let hba1cGoal: Double?
    let timeInRangeGoal: Double  // Percentage (e.g., 70.0 for 70%)
    
    var fastingRange: String {
        "\(Int(fastingMin))-\(Int(fastingMax)) mg/dL"
    }
    
    var postPrandialRange: String {
        "<\(Int(postPrandialMax)) mg/dL"
    }
    
    var hba1cDisplay: String {
        guard let goal = hba1cGoal else { return "N/A" }
        return String(format: "<%.1f%%", goal)
    }
}

/// Blood pressure targets
struct BPTargets {
    let systolicMax: Int
    let diastolicMax: Int
    
    var display: String {
        "<\(systolicMax)/\(diastolicMax) mmHg"
    }
}

/// Vital interpretation result
struct VitalInterpretation {
    let status: VitalStatus
    let message: String
    let trend: TrendDirection
    let riskLevel: RiskLevel
    let targetRange: String
    
    enum VitalStatus: String {
        case optimal = "Optimal"
        case normal = "Normal"
        case elevated = "Elevated"
        case high = "High"
        case critical = "Critical"
        case low = "Low"
        case veryLow = "Very Low"
        
        var color: String {
            switch self {
            case .optimal: return "green"
            case .normal: return "green"
            case .elevated: return "orange"
            case .high: return "red"
            case .critical: return "red"
            case .low: return "orange"
            case .veryLow: return "red"
            }
        }
    }
    
    enum RiskLevel: String {
        case none = "No immediate concern"
        case low = "Monitor regularly"
        case moderate = "Discuss with doctor"
        case high = "Seek medical attention"
        case critical = "Urgent medical attention required"
    }
}

/// Diabetes risk assessment
struct DiabetesRiskAssessment {
    let overallRisk: RiskCategory
    let cardiovascularRisk: RiskCategory
    let nephropathyRisk: RiskCategory
    let neuropathyRisk: RiskCategory
    let retinopathyRisk: RiskCategory
    let hypoglycemiaRisk: RiskCategory
    
    enum RiskCategory: String, CaseIterable {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case veryHigh = "Very High"
        
        var color: String {
            switch self {
            case .low: return "green"
            case .moderate: return "yellow"
            case .high: return "orange"
            case .veryHigh: return "red"
            }
        }
    }
}

// MARK: - Main Engine

final class DiabetesTargetEngine {
    
    static let shared = DiabetesTargetEngine()
    private init() {}
    
    // MARK: - Glucose Targets
    
    /// Returns personalized glucose targets based on diabetes type, age, and risk factors
    func glucoseTargets(for profile: UserProfileModel) -> GlucoseTargets {
        let diabetesType = profile.diabetesType.lowercased()
        let age = profile.age
        let hasHypoRisk = profile.comorbidities.contains { $0.lowercased().contains("hypoglycemia") }
        
        switch diabetesType {
        case "type 1":
            return type1Targets(age: age, hypoRisk: hasHypoRisk)
        case "type 2":
            return type2Targets(age: age, hypoRisk: hasHypoRisk)
        case "prediabetes":
            return prediabetesTargets()
        case "gestational":
            return gestationalTargets()
        default:
            return type2Targets(age: age, hypoRisk: hasHypoRisk) // Default to T2
        }
    }
    
    private func type1Targets(age: Int, hypoRisk: Bool) -> GlucoseTargets {
        // ADA Guidelines for T1D
        var fastingMin = 80.0
        var fastingMax = 130.0
        var ppMax = 180.0
        var hba1c = 7.0
        
        // Elderly adjustment (>65 years)
        if age > 65 {
            fastingMin = 90.0
            fastingMax = 150.0
            ppMax = 200.0
            hba1c = 7.5
        }
        
        // Hypoglycemia risk adjustment
        if hypoRisk {
            fastingMin = 100.0
            hba1c = min(hba1c + 0.5, 8.0)
        }
        
        return GlucoseTargets(
            fastingMin: fastingMin,
            fastingMax: fastingMax,
            postPrandialMax: ppMax,
            randomMax: 180.0,
            hba1cGoal: hba1c,
            timeInRangeGoal: 70.0
        )
    }
    
    private func type2Targets(age: Int, hypoRisk: Bool) -> GlucoseTargets {
        // ADA Guidelines for T2D
        var fastingMin = 80.0
        var fastingMax = 130.0
        let ppMax = 180.0 // Targeted glucose goal
        var hba1c = 7.0
        
        // Elderly with comorbidities
        if age > 65 {
            hba1c = 7.5
            if age > 75 {
                hba1c = 8.0
                fastingMax = 150.0
            }
        }
        
        if hypoRisk {
            fastingMin = 100.0
            hba1c = min(hba1c + 0.5, 8.5)
        }
        
        return GlucoseTargets(
            fastingMin: fastingMin,
            fastingMax: fastingMax,
            postPrandialMax: ppMax,
            randomMax: 180.0,
            hba1cGoal: hba1c,
            timeInRangeGoal: 70.0
        )
    }
    
    private func prediabetesTargets() -> GlucoseTargets {
        // Stricter targets to prevent progression
        return GlucoseTargets(
            fastingMin: 70.0,
            fastingMax: 99.0,  // Below diabetic threshold
            postPrandialMax: 140.0,
            randomMax: 140.0,
            hba1cGoal: 5.7,  // Stay below prediabetes threshold
            timeInRangeGoal: 90.0
        )
    }
    
    private func gestationalTargets() -> GlucoseTargets {
        // Very strict targets for pregnancy
        return GlucoseTargets(
            fastingMin: 70.0,
            fastingMax: 95.0,
            postPrandialMax: 140.0,  // 1-hour post meal: <140, 2-hour: <120
            randomMax: 120.0,
            hba1cGoal: nil,  // HbA1c not primary marker in GDM
            timeInRangeGoal: 85.0
        )
    }
    
    // MARK: - Blood Pressure Targets
    
    func bpTargets(for profile: UserProfileModel) -> BPTargets {
        let hasHypertension = profile.comorbidities.contains { $0.lowercased().contains("hypertension") }
        let hasKidneyDisease = profile.comorbidities.contains { $0.lowercased().contains("kidney") }
        
        // ADA recommends <130/80 for most diabetics
        // More aggressive for those with kidney disease
        if hasKidneyDisease {
            return BPTargets(systolicMax: 120, diastolicMax: 75)
        } else if hasHypertension {
            return BPTargets(systolicMax: 130, diastolicMax: 80)
        } else {
            return BPTargets(systolicMax: 140, diastolicMax: 90)
        }
    }
    
    // MARK: - Vital Interpretation
    
    /// Interprets a glucose value with clinical context
    func interpretFastingGlucose(_ value: Double, profile: UserProfileModel) -> VitalInterpretation {
        let targets = glucoseTargets(for: profile)
        
        if value < 54 {
            return VitalInterpretation(
                status: .critical,
                message: "Severe hypoglycemia - seek immediate help",
                trend: .unknown,
                riskLevel: .critical,
                targetRange: targets.fastingRange
            )
        } else if value < 70 {
            return VitalInterpretation(
                status: .low,
                message: "Low blood sugar - consider fast-acting carbs",
                trend: .unknown,
                riskLevel: .high,
                targetRange: targets.fastingRange
            )
        } else if value >= targets.fastingMin && value <= targets.fastingMax {
            return VitalInterpretation(
                status: .normal,
                message: "Within your target range",
                trend: .stable,
                riskLevel: .none,
                targetRange: targets.fastingRange
            )
        } else if value <= 180 {
            return VitalInterpretation(
                status: .elevated,
                message: "Above target - monitor and adjust",
                trend: .unknown,
                riskLevel: .low,
                targetRange: targets.fastingRange
            )
        } else if value <= 250 {
            return VitalInterpretation(
                status: .high,
                message: "High glucose - check for ketones if Type 1",
                trend: .unknown,
                riskLevel: .moderate,
                targetRange: targets.fastingRange
            )
        } else {
            return VitalInterpretation(
                status: .critical,
                message: "Very high glucose - contact your healthcare provider",
                trend: .unknown,
                riskLevel: .high,
                targetRange: targets.fastingRange
            )
        }
    }
    
    /// Interprets post-prandial glucose
    func interpretPostPrandial(_ value: Double, profile: UserProfileModel) -> VitalInterpretation {
        let targets = glucoseTargets(for: profile)
        let max = targets.postPrandialMax
        
        if value < 70 {
            return VitalInterpretation(
                status: .low,
                message: "Low glucose - monitor closely",
                trend: .unknown,
                riskLevel: .moderate,
                targetRange: "< \(Int(max))"
            )
        } else if value <= max {
            return VitalInterpretation(
                status: .normal,
                message: "Within post-meal target",
                trend: .stable,
                riskLevel: .none,
                targetRange: "< \(Int(max))"
            )
        } else if value <= max + 40 {
             return VitalInterpretation(
                status: .elevated,
                message: "Above target",
                trend: .unknown,
                riskLevel: .low,
                targetRange: "< \(Int(max))"
            )
        } else {
             return VitalInterpretation(
                status: .high,
                message: "High post-meal glucose",
                trend: .unknown,
                riskLevel: .high,
                targetRange: "< \(Int(max))"
            )
        }
    }
    
    /// Interprets HbA1c value
    func interpretHbA1c(_ value: Double, profile: UserProfileModel) -> VitalInterpretation {
        let targets = glucoseTargets(for: profile)
        guard let goal = targets.hba1cGoal else {
            return VitalInterpretation(
                status: .normal,
                message: "HbA1c tracking not primary for gestational diabetes",
                trend: .unknown,
                riskLevel: .none,
                targetRange: "N/A"
            )
        }
        
        if value < goal {
            return VitalInterpretation(
                status: .optimal,
                message: "Excellent glucose control",
                trend: .improving,
                riskLevel: .none,
                targetRange: targets.hba1cDisplay
            )
        } else if value < goal + 0.5 {
            return VitalInterpretation(
                status: .normal,
                message: "Near target - maintain current management",
                trend: .stable,
                riskLevel: .low,
                targetRange: targets.hba1cDisplay
            )
        } else if value < goal + 1.5 {
            return VitalInterpretation(
                status: .elevated,
                message: "Above target - review treatment plan",
                trend: .declining,
                riskLevel: .moderate,
                targetRange: targets.hba1cDisplay
            )
        } else {
            return VitalInterpretation(
                status: .high,
                message: "Significantly elevated - intensify management",
                trend: .declining,
                riskLevel: .high,
                targetRange: targets.hba1cDisplay
            )
        }
    }
    
    // MARK: - Risk Assessment
    
    func assessRisk(for profile: UserProfileModel) -> DiabetesRiskAssessment {
        let comorbidities = Set(profile.comorbidities.map { $0.lowercased() })
        let yearsWithDiabetes = calculateYearsWithDiabetes(profile)
        
        // Cardiovascular Risk
        var cvRisk: DiabetesRiskAssessment.RiskCategory = .low
        if comorbidities.contains("hypertension") { cvRisk = .moderate }
        if comorbidities.contains("dyslipidemia") { cvRisk = max(cvRisk, .moderate) }
        if yearsWithDiabetes > 10 { cvRisk = max(cvRisk, .high) }
        
        // Nephropathy Risk
        var kidneyRisk: DiabetesRiskAssessment.RiskCategory = .low
        if comorbidities.contains(where: { $0.contains("kidney") }) { kidneyRisk = .high }
        if comorbidities.contains("hypertension") { kidneyRisk = max(kidneyRisk, .moderate) }
        
        // Neuropathy Risk
        var neuroRisk: DiabetesRiskAssessment.RiskCategory = .low
        if comorbidities.contains(where: { $0.contains("neuropathy") }) { neuroRisk = .high }
        if yearsWithDiabetes > 5 { neuroRisk = max(neuroRisk, .moderate) }
        
        // Retinopathy Risk
        var eyeRisk: DiabetesRiskAssessment.RiskCategory = .low
        if comorbidities.contains(where: { $0.contains("retinopathy") }) { eyeRisk = .high }
        if yearsWithDiabetes > 5 { eyeRisk = max(eyeRisk, .moderate) }
        
        // Hypoglycemia Risk
        var hypoRisk: DiabetesRiskAssessment.RiskCategory = .low
        if profile.treatmentType.lowercased().contains("insulin") { hypoRisk = .moderate }
        if comorbidities.contains(where: { $0.contains("hypoglycemia") }) { hypoRisk = .high }
        
        // Overall Risk (worst of all)
        let allRisks = [cvRisk, kidneyRisk, neuroRisk, eyeRisk, hypoRisk]
        let overallRisk = allRisks.max() ?? .low
        
        return DiabetesRiskAssessment(
            overallRisk: overallRisk,
            cardiovascularRisk: cvRisk,
            nephropathyRisk: kidneyRisk,
            neuropathyRisk: neuroRisk,
            retinopathyRisk: eyeRisk,
            hypoglycemiaRisk: hypoRisk
        )
    }
    
    // MARK: - Helpers
    
    private func calculateYearsWithDiabetes(_ profile: UserProfileModel) -> Int {
        guard let diagnosisYear = profile.diagnosisYear else { return 0 }
        let currentYear = Calendar.current.component(.year, from: Date())
        return max(0, currentYear - diagnosisYear)
    }
    
    /// Calculate BMI from height (cm) and weight (kg)
    func calculateBMI(heightCm: Double?, weightKg: Double?) -> Double? {
        guard let h = heightCm, let w = weightKg, h > 0 else { return nil }
        let heightM = h / 100.0
        return w / (heightM * heightM)
    }
    
    /// Interpret BMI for diabetic patients
    func interpretBMI(_ bmi: Double?) -> String {
        guard let bmi = bmi else { return "Not available" }
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        case 30..<35: return "Obese Class I"
        case 35..<40: return "Obese Class II"
        default: return "Obese Class III"
        }
    }

    
    // MARK: - Population Context (Indian Context)
    
    struct HbA1cPopulationStats {
        let normalAverage: Double
        let diabeticAverage: Double
        let ageGroup: String
    }
    
    func getIndianPopulationStats(for age: Int) -> HbA1cPopulationStats {
        // Based on Indian epidemiological data trends
        if age < 30 {
            return HbA1cPopulationStats(normalAverage: 5.4, diabeticAverage: 8.2, ageGroup: "< 30")
        } else if age < 50 {
            return HbA1cPopulationStats(normalAverage: 5.6, diabeticAverage: 8.5, ageGroup: "30-50")
        } else {
            return HbA1cPopulationStats(normalAverage: 5.8, diabeticAverage: 8.8, ageGroup: "50+")
        }
    }
}

// MARK: - Trend Direction Extension
extension TrendDirection {
    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable: return "arrow.right" 
        case .unknown: return "minus"
        }
    }
}

// MARK: - Comparable Extension for RiskCategory
extension DiabetesRiskAssessment.RiskCategory: Comparable {
    static func < (lhs: DiabetesRiskAssessment.RiskCategory, rhs: DiabetesRiskAssessment.RiskCategory) -> Bool {
        let order: [DiabetesRiskAssessment.RiskCategory] = [.low, .moderate, .high, .veryHigh]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else { return false }
        return lhsIndex < rhsIndex
    }
}
