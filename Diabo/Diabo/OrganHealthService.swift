
import Foundation
import SwiftData

/// Service to calculate accurate, medically defensible organ health scores.
/// Logic:
/// 1. Normalize each parameter into a deviation score.
/// 2. Apply clinical weights to parameters.
/// 3. Aggregate into an Organ Status Band (not a % score).
final class OrganHealthService {
    static let shared = OrganHealthService()
    
    // Status Bands for Organ Health
    enum OrganStatus: String {
        case normal = "Normal Function"
        case mild = "Mild Deviation"
        case moderate = "Moderate Deviation"
        case significant = "Significant Deviation"
        case unknown = "Insufficient Data"
        
        var color: String {
            switch self {
            case .normal: return "Green"
            case .mild: return "Yellow"
            case .moderate: return "Orange"
            case .significant: return "Red"
            case .unknown: return "Gray"
            }
        }
    }
    
    struct OrganEvaluation {
        let status: OrganStatus
        let normalizedScore: Double // 0.0 (Normal) to 1.0+ (Abnormal)
        let contributingFactors: [String] // Parameters that drove this score
        let date: Date
    }
    
    // Clinical Weights (Configurable)
    private let liverWeights: [String: Double] = [
        "alt": 0.25, "ast": 0.25, "bilirubin": 0.20, "albumin": 0.15, "alp": 0.15
    ]
    
    private let kidneyWeights: [String: Double] = [
        "creatinine": 0.40, "egfr": 0.30, "bun": 0.20, "sodium": 0.05, "potassium": 0.05
    ]
    
    private let heartWeights: [String: Double] = [
        "troponin": 0.40, "bnp": 0.30, "ck-mb": 0.20, "myoglobin": 0.10
    ]
    
    // MARK: - Evaluation Logic
    
    func evaluateOrganHealth(organ: String, dataPoints: [LabGraphDataModel], standardProvider: MedicalStandardProvider) -> [OrganEvaluation] {
        // 1. Group data by date (Daily buckets)
        let groupedData = Dictionary(grouping: dataPoints) { point -> Date in
            Calendar.current.startOfDay(for: point.date)
        }
        
        var evaluations: [OrganEvaluation] = []
        
        for (_, points) in groupedData {
            let eval = calculateDailyScore(organ: organ, points: points, provider: standardProvider)
            evaluations.append(eval)
        }
        
        return evaluations.sorted { $0.date < $1.date }
    }
    
    private func calculateDailyScore(organ: String, points: [LabGraphDataModel], provider: MedicalStandardProvider) -> OrganEvaluation {
        let weights = getWeights(for: organ)
        var totalWeightedDeviation: Double = 0.0
        var totalWeightUsed: Double = 0.0
        var abnormalities: [String] = []
        
        for point in points {
            let paramName = point.parameter.lowercased()
            // Find weight (partial match search)
            let weightPair = weights.first { paramName.contains($0.key) }
            let weight = weightPair?.value ?? 0.1 // Default low weight if unknown param
            
            // Get Standard Range
            guard let range = provider.getStandard(for: point.parameter) else { continue }
            
            // Calculate Normalized Deviation
            // 0.0 = perfect middle of range
            // 1.0 = exactly at the limit of normal
            // >1.0 = abnormal
            let midpoint = (range.min + range.max) / 2.0
            let rangeWidth = range.max - range.min
            let deviationRaw = abs(point.value - midpoint)
            // We scale so that (rangeWidth/2) maps to 1.0 normalized deviation
            let normalizedParamScore = deviationRaw / (rangeWidth / 2.0)
            
            // Interaction: If abnormal, add to list
            if normalizedParamScore > 1.0 {
                abnormalities.append(point.parameter)
            }
            
            totalWeightedDeviation += normalizedParamScore * weight
            totalWeightUsed += weight
        }
        
        guard totalWeightUsed > 0 else {
            return OrganEvaluation(status: .unknown, normalizedScore: 0, contributingFactors: [], date: points.first?.date ?? Date())
        }
        
        // Final Score: 0.0 - 1.0 is Normal. >1.0 is Abnormal.
        let finalScore = totalWeightedDeviation / totalWeightUsed
        
        // Map to Bands
        let status: OrganStatus
        if finalScore <= 1.0 {
            status = .normal
        } else if finalScore <= 1.5 {
            status = .mild
        } else if finalScore <= 2.5 {
            status = .moderate
        } else {
            status = .significant
        }
        
        return OrganEvaluation(
            status: status,
            normalizedScore: finalScore,
            contributingFactors: Array(Set(abnormalities)), // Unique
            date: points.first?.date ?? Date()
        )
    }
    
    private func getWeights(for organ: String) -> [String: Double] {
        switch organ.lowercased() {
        case "liver": return liverWeights
        case "kidney", "renal": return kidneyWeights
        case "heart", "cardiac": return heartWeights
        default: return [:]
        }
    }
}
