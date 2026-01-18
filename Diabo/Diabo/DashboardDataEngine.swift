// DashboardDataEngine.swift
import Foundation
import SwiftData

// MARK: - Dashboard Models

struct LabTrendSummary {
    let parameter: String
    let currentValue: Double
    let unit: String
    let trend: TrendDirection
    let changePercent: Double
    let isOutOfRange: Bool
    let normalRange: String
    let history: [LabDataPoint]
}

struct LabDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let status: String // "Normal", "High", "Low"
}



struct MedicationAdherenceSummary {
    let totalMedications: Int
    let activeMedications: Int
    let adherenceScore: Double // 0-100
    let missedDoses: Int
    let upcomingDoses: [UpcomingDose]
}

struct UpcomingDose {
    let medicationName: String
    let time: Date
    let dosage: String
}

struct DiagnosisSummary {
    let recentDiagnoses: [String]
    let organSystems: [String]
    let severity: String
}

struct TimelineSummary {
    let totalEvents: Int
    let recentEvents: [TimelineEvent]
    let majorEvents: [TimelineEvent]
}

struct TimelineEvent {
    let date: Date
    let type: String
    let title: String
    let severity: EventSeverity
}



struct AlertSummary {
    let criticalAlerts: [HealthAlert]
    let warnings: [HealthAlert]
    let totalAlerts: Int
}

struct HealthAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let message: String
    let severity: EventSeverity
    let date: Date
}

enum AlertType: String {
    case labOutOfRange = "Lab Out of Range"
    case rapidChange = "Rapid Change"
    case missedMedication = "Missed Medication"
    case abnormalTrend = "Abnormal Trend"
}

// MARK: - Dashboard Data Engine

@MainActor
final class DashboardDataEngine {
    static let shared = DashboardDataEngine()
    
    private init() {}
    
    // MARK: - Lab Trend Analysis
    
    /// Analyze lab results and generate trend summaries
    func analyzeLabTrends(labResults: [LabResultModel]) -> [LabTrendSummary] {
        // Group by parameter
        let groupedLabs = Dictionary(grouping: labResults) { $0.parameter }
        
        var trends: [LabTrendSummary] = []
        
        for (parameter, results) in groupedLabs {
            guard !results.isEmpty else { continue }
            
            // Sort by date
            let sortedResults = results.sorted { $0.testDate < $1.testDate }
            
            guard let latest = sortedResults.last else { continue }
            
            // Calculate trend
            let trend = calculateTrend(results: sortedResults)
            
            // Calculate change
            let changePercent = calculateChangePercent(results: sortedResults)
            
            // Check if out of range
            let isOutOfRange = latest.status != "Normal"
            
            // Create history data points
            let history = sortedResults.map { result in
                LabDataPoint(
                    date: result.testDate,
                    value: result.value,
                    status: result.status
                )
            }
            
            let summary = LabTrendSummary(
                parameter: parameter,
                currentValue: latest.value,
                unit: latest.unit,
                trend: trend,
                changePercent: changePercent,
                isOutOfRange: isOutOfRange,
                normalRange: latest.normalRange,
                history: history
            )
            
            trends.append(summary)
        }
        
        return trends
    }
    
    /// Calculate trend direction
    private func calculateTrend(results: [LabResultModel]) -> TrendDirection {
        guard results.count >= 2 else { return .unknown }
        
        let sortedResults = results.sorted { $0.testDate < $1.testDate }
        let recentResults = Array(sortedResults.suffix(3))
        
        guard recentResults.count >= 2 else { return .unknown }
        
        let values = recentResults.map { $0.value }
        
        // Simple linear trend
        let isImproving = values.last! < values.first! && recentResults.last!.status == "Normal"
        let isDeclining = values.last! > values.first! && recentResults.last!.status != "Normal"
        
        if isImproving {
            return .improving
        } else if isDeclining {
            return .declining
        } else {
            return .stable
        }
    }
    
    /// Calculate percentage change
    private func calculateChangePercent(results: [LabResultModel]) -> Double {
        guard results.count >= 2 else { return 0.0 }
        
        let sortedResults = results.sorted { $0.testDate < $1.testDate }
        
        guard let first = sortedResults.first,
              let last = sortedResults.last else { return 0.0 }
        
        let change = ((last.value - first.value) / first.value) * 100
        return change
    }
    
    // MARK: - Outlier Detection
    
    /// Detect outliers in lab results
    func detectOutliers(labResults: [LabResultModel]) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        
        for result in labResults {
            if result.status == "High" || result.status == "Low" {
                let alert = HealthAlert(
                    type: .labOutOfRange,
                    message: "\(result.parameter) is \(result.status): \(result.value) \(result.unit) (Normal: \(result.normalRange))",
                    severity: result.status == "High" ? .high : .medium,
                    date: result.testDate
                )
                alerts.append(alert)
            }
        }
        
        return alerts
    }
    
    /// Detect rapid changes between reports
    func detectRapidChanges(labResults: [LabResultModel]) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        
        let groupedLabs = Dictionary(grouping: labResults) { $0.parameter }
        
        for (parameter, results) in groupedLabs {
            let sortedResults = results.sorted { $0.testDate < $1.testDate }
            
            for i in 1..<sortedResults.count {
                let previous = sortedResults[i-1]
                let current = sortedResults[i]
                
                let change = abs((current.value - previous.value) / previous.value) * 100
                
                // Alert if change > 30%
                if change > 30 {
                    let alert = HealthAlert(
                        type: .rapidChange,
                        message: "\(parameter) changed by \(Int(change))% from \(previous.value) to \(current.value) \(current.unit)",
                        severity: .high,
                        date: current.testDate
                    )
                    alerts.append(alert)
                }
            }
        }
        
        return alerts
    }
    
    // MARK: - Dashboard Summary
    
    /// Generate complete dashboard summary
    func generateDashboardSummary(
        reports: [MedicalReportModel],
        medications: [MedicationModel],
        labResults: [LabResultModel],
        timelineEntries: [TimelineEntryModel],
        healthMetrics: [HealthMetricEntry] = []
    ) -> (
        labTrends: [LabTrendSummary],
        medicationSummary: MedicationAdherenceSummary,
        diagnosisSummary: DiagnosisSummary,
        timelineSummary: TimelineSummary,
        alertSummary: AlertSummary
    ) {
        // Lab trends
        var labTrends = analyzeLabTrends(labResults: labResults)
        
        // Add HealthKit trends
        let healthTrends = analyzeHealthMetrics(healthMetrics)
        labTrends.append(contentsOf: healthTrends)
        
        // Medication summary
        let activeMeds = medications.filter { $0.isActive }
        
        // Calculate real adherence score
        let adherenceScore = MedicationAdherenceEngine.shared.calculateAdherenceScore(medications: medications).overall
        
        let medicationSummary = MedicationAdherenceSummary(
            totalMedications: medications.count,
            activeMedications: activeMeds.count,
            adherenceScore: adherenceScore,
            missedDoses: 0, // No dose log yet
            upcomingDoses: []
        )
        
        // Diagnosis summary
        let recentReports = reports.sorted { $0.uploadDate > $1.uploadDate }.prefix(5)
        let organs = Set(recentReports.map { $0.organ })
        
        // Determine severity based on report content keywords
        let severity = determineOverallSeverity(reports: Array(recentReports))
        
        let diagnosisSummary = DiagnosisSummary(
            recentDiagnoses: Array(recentReports.map { $0.title }),
            organSystems: Array(organs),
            severity: severity
        )
        
        // Timeline summary
        let recentEntries = timelineEntries.sorted { $0.date > $1.date }.prefix(10)
        let timelineSummary = TimelineSummary(
            totalEvents: timelineEntries.count,
            recentEvents: recentEntries.map { entry in
                TimelineEvent(
                    date: entry.date,
                    type: entry.type,
                    title: entry.title,
                    severity: .medium // Default, could be enhanced
                )
            },
            majorEvents: []
        )
        
        // Alerts
        let outlierAlerts = detectOutliers(labResults: labResults)
        let changeAlerts = detectRapidChanges(labResults: labResults)
        let healthAlerts = detectHealthMetricAlerts(healthMetrics)
        let allAlerts = outlierAlerts + changeAlerts + healthAlerts
        
        let criticalAlerts = allAlerts.filter { $0.severity == .critical || $0.severity == .high }
        let warnings = allAlerts.filter { $0.severity == .medium || $0.severity == .low }
        
        let alertSummary = AlertSummary(
            criticalAlerts: criticalAlerts,
            warnings: warnings,
            totalAlerts: allAlerts.count
        )
        
        return (labTrends, medicationSummary, diagnosisSummary, timelineSummary, alertSummary)
    }
    
    private func determineOverallSeverity(reports: [MedicalReportModel]) -> String {
        let criticalKeywords = ["malignant", "critical", "severe", "emergency", "acute"]
        let highKeywords = ["abnormal", "high", "elevated", "chronic"]
        
        var hasCritical = false
        var hasHigh = false
        
        for report in reports {
            let content = (report.title + " " + report.aiInsights).lowercased()
            if criticalKeywords.contains(where: { content.contains($0) }) {
                hasCritical = true
            }
            if highKeywords.contains(where: { content.contains($0) }) {
                hasHigh = true
            }
        }
        
        if hasCritical { return "Critical" }
        if hasHigh { return "High" }
        return "Stable"
    }
    
    // MARK: - Health Metrics Analysis
    
    private func analyzeHealthMetrics(_ metrics: [HealthMetricEntry]) -> [LabTrendSummary] {
        let grouped = Dictionary(grouping: metrics) { $0.type }
        var trends: [LabTrendSummary] = []
        
        for (type, typeMetrics) in grouped {
            let sorted = typeMetrics.sorted { $0.date < $1.date }
            guard let latest = sorted.last else { continue }
            
            // Determine status for each point
            let history = sorted.suffix(20).map { metric -> LabDataPoint in
                let status = determineMetricStatus(type: metric.type, value: metric.value)
                return LabDataPoint(date: metric.date, value: metric.value, status: status)
            }
            
            let trend: TrendDirection
            if sorted.count >= 2 {
                let first = sorted.first!.value
                let last = sorted.last!.value
                trend = last < first ? .declining : (last > first ? .improving : .stable)
            } else {
                trend = .stable
            }
            
            let latestStatus = determineMetricStatus(type: type, value: latest.value)
            let isOutOfRange = latestStatus != "Normal"
            
            trends.append(LabTrendSummary(
                parameter: type,
                currentValue: latest.value,
                unit: latest.unit,
                trend: trend,
                changePercent: 0,
                isOutOfRange: isOutOfRange,
                normalRange: getNormalRange(for: type),
                history: history
            ))
        }
        
        return trends
    }
    
    private func determineMetricStatus(type: String, value: Double) -> String {
        switch type {
        case "Heart Rate":
            if value > 100 { return "High" }
            if value < 60 { return "Low" }
            return "Normal"
        case "Oxygen Saturation":
            if value < 95 { return "Low" }
            return "Normal"
        case "Respiratory Rate":
            if value > 20 { return "High" }
            if value < 12 { return "Low" }
            return "Normal"
        case "Body Temperature":
            if value > 37.5 { return "High" }
            if value < 36.0 { return "Low" }
            return "Normal"
        case "Systolic Blood Pressure":
            if value > 140 { return "High" }
            if value < 90 { return "Low" }
            return "Normal"
        case "Diastolic Blood Pressure":
            if value > 90 { return "High" }
            if value < 60 { return "Low" }
            return "Normal"
        default:
            return "Normal" // Default if unknown
        }
    }
    
    private func getNormalRange(for type: String) -> String {
        switch type {
        case "Heart Rate": return "60-100 bpm"
        case "Oxygen Saturation": return "> 95%"
        case "Respiratory Rate": return "12-20 /min"
        case "Body Temperature": return "36.0-37.5 °C"
        case "Systolic Blood Pressure": return "90-140 mmHg"
        case "Diastolic Blood Pressure": return "60-90 mmHg"
        default: return "N/A"
        }
    }
    
    private func detectHealthMetricAlerts(_ metrics: [HealthMetricEntry]) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        
        for metric in metrics {
            if metric.type == "Heart Rate" && metric.value > 120 {
                alerts.append(HealthAlert(
                    type: .labOutOfRange,
                    message: "High Heart Rate: \(Int(metric.value)) bpm",
                    severity: .high,
                    date: metric.date
                ))
            }
            if metric.type == "Oxygen Saturation" && metric.value < 95 {
                alerts.append(HealthAlert(
                    type: .labOutOfRange,
                    message: "Low Oxygen: \(Int(metric.value))%",
                    severity: .high,
                    date: metric.date
                ))
            }
        }
        
        return alerts
    }
}
