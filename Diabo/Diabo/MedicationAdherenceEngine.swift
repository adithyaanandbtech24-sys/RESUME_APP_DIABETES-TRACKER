// MedicationAdherenceEngine.swift
import Foundation
import SwiftData

// MARK: - Adherence Models

struct AdherenceScore {
    let overall: Double // 0-100
    let byMedication: [String: Double]
    let trend: TrendDirection
    let riskLevel: RiskLevel
}

enum RiskLevel: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

struct MissedDose {
    let medicationName: String
    let scheduledTime: Date
    let dosage: String
    let daysMissed: Int
}

struct AdherenceChartData: Identifiable {
    let id = UUID()
    let date: Date
    let adherenceRate: Double
    let medicationName: String
}

struct MedicationReminder {
    let medicationName: String
    let dosage: String
    let time: Date
    let frequency: String
    let isOverdue: Bool
}

// MARK: - Medication Adherence Engine

@MainActor
final class MedicationAdherenceEngine {
    static let shared = MedicationAdherenceEngine()
    
    private init() {}
    
    // MARK: - Adherence Calculation
    
    /// Calculate overall adherence score
    func calculateAdherenceScore(medications: [MedicationModel]) -> AdherenceScore {
        let activeMeds = medications.filter { $0.isActive }
        
        guard !activeMeds.isEmpty else {
            return AdherenceScore(
                overall: 100.0,
                byMedication: [:],
                trend: .stable,
                riskLevel: .low
            )
        }
        
        // Calculate adherence for each medication
        var byMedication: [String: Double] = [:]
        var totalScore: Double = 0.0
        
        for med in activeMeds {
            let score = calculateMedicationAdherence(medication: med)
            byMedication[med.name] = score
            totalScore += score
        }
        
        let overall = totalScore / Double(activeMeds.count)
        
        // Determine risk level
        let riskLevel = determineRiskLevel(score: overall)
        
        // Determine trend (placeholder - would need historical data)
        let trend: TrendDirection = overall >= 80 ? .stable : .declining
        
        return AdherenceScore(
            overall: overall,
            byMedication: byMedication,
            trend: trend,
            riskLevel: riskLevel
        )
    }
    
    /// Calculate adherence for a single medication
    private func calculateMedicationAdherence(medication: MedicationModel) -> Double {
        // Calculate based on start date and current date
        let daysSinceStart = Calendar.current.dateComponents([.day], from: medication.startDate, to: Date()).day ?? 0
        
        guard daysSinceStart > 0 else { return 100.0 }
        
        // Since we don't have a dose log yet, we cannot calculate real adherence.
        // Returning 0.0 to indicate "No Data" or "Unknown".
        // In a future version with dose tracking, this would calculate (taken / expected) * 100
        return 0.0
    }
    
    /// Parse frequency string to get doses per day
    private func parseFrequency(_ frequency: String) -> Double {
        let lowercased = frequency.lowercased()
        
        if lowercased.contains("once") || lowercased.contains("1") {
            return 1.0
        } else if lowercased.contains("twice") || lowercased.contains("2") {
            return 2.0
        } else if lowercased.contains("three") || lowercased.contains("3") {
            return 3.0
        } else if lowercased.contains("four") || lowercased.contains("4") {
            return 4.0
        }
        
        return 1.0 // Default
    }
    
    // MARK: - Missed Dose Detection
    
    /// Detect missed doses
    func detectMissedDoses(medications: [MedicationModel]) -> [MissedDose] {
        // Currently we do not have a dose log, so we cannot detect missed doses accurately.
        // Returning empty array to avoid showing fake missed doses.
        return []
    }
    
    // MARK: - Risk Prediction
    
    /// Predict adherence risk
    func predictAdherenceRisk(
        medications: [MedicationModel],
        adherenceScore: AdherenceScore
    ) -> (riskLevel: RiskLevel, factors: [String]) {
        var riskFactors: [String] = []
        
        // Check number of medications
        let activeMeds = medications.filter { $0.isActive }
        if activeMeds.count > 5 {
            riskFactors.append("High medication count (\(activeMeds.count) active medications)")
        }
        
        // Check adherence score
        // Only flag if we actually have data (score > 0 but < 80)
        if adherenceScore.overall > 0 && adherenceScore.overall < 80 {
            riskFactors.append("Low adherence score (\(Int(adherenceScore.overall))%)")
        }
        
        // Check for complex regimens
        let complexMeds = activeMeds.filter { med in
            let freq = parseFrequency(med.frequency)
            return freq > 2
        }
        if complexMeds.count > 2 {
            riskFactors.append("Complex medication schedule")
        }
        
        // Determine overall risk
        let riskLevel = determineRiskLevel(score: adherenceScore.overall)
        
        return (riskLevel, riskFactors)
    }
    
    private func determineRiskLevel(score: Double) -> RiskLevel {
        // If score is 0 (no data), assume Low risk until proven otherwise, or handle as "Unknown"
        if score == 0 { return .low }
        
        switch score {
        case 90...100:
            return .low
        case 75..<90:
            return .medium
        case 50..<75:
            return .high
        default:
            return .critical
        }
    }
    
    // MARK: - Chart Data Generation
    
    /// Generate adherence chart data
    func generateAdherenceChartData(
        medications: [MedicationModel],
        days: Int = 30
    ) -> [AdherenceChartData] {
        // No real data to plot yet.
        return []
    }
    
    /// Generate per-medication chart data
    func generatePerMedicationChartData(
        medication: MedicationModel,
        days: Int = 30
    ) -> [AdherenceChartData] {
        // No real data to plot yet.
        return []
    }
    
    // MARK: - Reminders
    
    /// Generate upcoming medication reminders
    func generateReminders(medications: [MedicationModel]) -> [MedicationReminder] {
        var reminders: [MedicationReminder] = []
        
        let activeMeds = medications.filter { $0.isActive }
        let calendar = Calendar.current
        let now = Date()
        
        for med in activeMeds {
            let dosesPerDay = Int(parseFrequency(med.frequency))
            
            // Generate reminders for today
            for doseIndex in 0..<dosesPerDay {
                let hour = 8 + (doseIndex * (12 / max(1, dosesPerDay)))
                
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = hour
                components.minute = 0
                
                if let reminderTime = calendar.date(from: components) {
                    let isOverdue = reminderTime < now
                    
                    let reminder = MedicationReminder(
                        medicationName: med.name,
                        dosage: med.dosage,
                        time: reminderTime,
                        frequency: med.frequency,
                        isOverdue: isOverdue
                    )
                    
                    reminders.append(reminder)
                }
            }
        }
        
        return reminders.sorted { $0.time < $1.time }
    }
}
