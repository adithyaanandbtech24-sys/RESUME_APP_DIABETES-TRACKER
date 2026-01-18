// TimelineAnalysisEngine.swift
import Foundation
import SwiftData

// MARK: - Timeline Models

struct ProcessedTimelineEntry: Identifiable {
    let id: String
    let date: Date
    let type: TimelineEntryType
    let title: String
    let summary: String
    let category: String
    let organ: String?
    let severity: EventSeverity
    let metadata: TimelineMetadata
}

enum TimelineEntryType: String {
    case report = "Report"
    case lab = "Lab"
    case medication = "Medication"
    case appointment = "Appointment"
    case hospitalization = "Hospitalization"
    case surgery = "Surgery"
}

struct TimelineMetadata {
    let hasAbnormalValues: Bool
    let changeFromPrevious: String?
    let relatedEntries: [String]
    let tags: [String]
}

// EventSeverity moved to SwiftDataModels.swift

struct GroupedTimelineEntries {
    let byOrgan: [String: [ProcessedTimelineEntry]]
    let byCategory: [String: [ProcessedTimelineEntry]]
    let byMonth: [String: [ProcessedTimelineEntry]]
    let majorEvents: [ProcessedTimelineEntry]
}

// MARK: - Timeline Analysis Engine

@MainActor
final class TimelineAnalysisEngine {
    static let shared = TimelineAnalysisEngine()
    
    private init() {}
    
    // MARK: - Entry Processing
    
    /// Convert raw timeline entries to processed entries
    func processTimelineEntries(
        _ entries: [TimelineEntryModel],
        reports: [MedicalReportModel],
        labResults: [LabResultModel],
        healthMetrics: [HealthMetricEntry] = []
    ) -> [ProcessedTimelineEntry] {
        var processed: [ProcessedTimelineEntry] = []
        
        // Process standard entries
        for entry in entries {
            // Find related report
            let relatedReport = reports.first { $0.id == entry.relatedReportId }
            
            // Determine severity
            let severity = determineSeverity(entry: entry, report: relatedReport, labResults: labResults)
            
            // Create metadata
            let metadata = createMetadata(entry: entry, report: relatedReport, labResults: labResults)
            
            let processedEntry = ProcessedTimelineEntry(
                id: entry.id,
                date: entry.date,
                type: TimelineEntryType(rawValue: entry.type) ?? .report,
                title: entry.title,
                summary: entry.summary,
                category: categorizeEntry(entry),
                organ: relatedReport?.organ,
                severity: severity,
                metadata: metadata
            )
            
            processed.append(processedEntry)
        }
        
        // Process health metrics
        for metric in healthMetrics {
            // Only include significant metrics or daily summaries to avoid clutter
            // For now, we'll include all for demonstration, but in production we'd filter/aggregate
            
            // Determine severity for metrics
            let severity = determineMetricSeverity(metric)
            
            let processedEntry = ProcessedTimelineEntry(
                id: metric.id.uuidString,
                date: metric.date,
                type: .lab, // Treat as lab/vitals
                title: metric.type,
                summary: String(format: "%.1f %@", metric.value, metric.unit),
                category: "Health Metrics",
                organ: determineOrganForMetric(metric.type),
                severity: severity,
                metadata: TimelineMetadata(
                    hasAbnormalValues: severity == .high || severity == .critical,
                    changeFromPrevious: nil,
                    relatedEntries: [],
                    tags: ["HealthKit", metric.type]
                )
            )
            
            processed.append(processedEntry)
        }
        
        return processed.sorted { $0.date > $1.date }
    }
    
    private func determineMetricSeverity(_ metric: HealthMetricEntry) -> EventSeverity {
        switch metric.type {
        case "Heart Rate":
            if metric.value > 100 || metric.value < 50 { return .high }
        case "Oxygen Saturation":
            if metric.value < 95 { return .high }
        default:
            break
        }
        return .low
    }
    
    private func determineOrganForMetric(_ type: String) -> String? {
        switch type {
        case "Heart Rate", "Blood Pressure": return "Heart"
        case "Oxygen Saturation", "Respiratory Rate": return "Lungs"
        default: return nil
        }
    }
    
    // MARK: - Grouping
    
    /// Group timeline entries by organ
    func groupByOrgan(_ entries: [ProcessedTimelineEntry]) -> [String: [ProcessedTimelineEntry]] {
        var grouped: [String: [ProcessedTimelineEntry]] = [:]
        
        for entry in entries {
            let organ = entry.organ ?? "General"
            if grouped[organ] == nil {
                grouped[organ] = []
            }
            grouped[organ]?.append(entry)
        }
        
        return grouped
    }
    
    /// Group timeline entries by category
    func groupByCategory(_ entries: [ProcessedTimelineEntry]) -> [String: [ProcessedTimelineEntry]] {
        return Dictionary(grouping: entries) { $0.category }
    }
    
    /// Group timeline entries by month
    func groupByMonth(_ entries: [ProcessedTimelineEntry]) -> [String: [ProcessedTimelineEntry]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        return Dictionary(grouping: entries) { entry in
            formatter.string(from: entry.date)
        }
    }
    
    /// Create comprehensive grouped structure
    func createGroupedStructure(_ entries: [ProcessedTimelineEntry]) -> GroupedTimelineEntries {
        return GroupedTimelineEntries(
            byOrgan: groupByOrgan(entries),
            byCategory: groupByCategory(entries),
            byMonth: groupByMonth(entries),
            majorEvents: detectMajorEvents(entries)
        )
    }
    
    // MARK: - Event Detection
    
    /// Detect major medical events
    func detectMajorEvents(_ entries: [ProcessedTimelineEntry]) -> [ProcessedTimelineEntry] {
        return entries.filter { entry in
            entry.severity == .critical || entry.severity == .high ||
            entry.type == .hospitalization || entry.type == .surgery ||
            entry.metadata.hasAbnormalValues
        }
    }
    
    /// Detect hospitalizations
    func detectHospitalizations(_ entries: [ProcessedTimelineEntry]) -> [ProcessedTimelineEntry] {
        return entries.filter { entry in
            entry.title.lowercased().contains("hospital") ||
            entry.title.lowercased().contains("admission") ||
            entry.title.lowercased().contains("emergency")
        }
    }
    
    /// Detect surgeries
    func detectSurgeries(_ entries: [ProcessedTimelineEntry]) -> [ProcessedTimelineEntry] {
        return entries.filter { entry in
            entry.title.lowercased().contains("surgery") ||
            entry.title.lowercased().contains("operation") ||
            entry.title.lowercased().contains("procedure")
        }
    }
    
    // MARK: - Helper Methods
    
    private func determineSeverity(
        entry: TimelineEntryModel,
        report: MedicalReportModel?,
        labResults: [LabResultModel]
    ) -> EventSeverity {
        // Check for critical keywords
        let criticalKeywords = ["emergency", "critical", "severe", "urgent", "ketoacidosis", "hypoglycemia", "coma"]
        let highKeywords = ["abnormal", "elevated", "high", "low", "hyperglycemia", "diabetes", "insulin"]
        
        let text = (entry.title + " " + entry.summary).lowercased()
        
        if criticalKeywords.contains(where: { text.contains($0) }) {
            return .critical
        }
        
        if highKeywords.contains(where: { text.contains($0) }) {
            return .high
        }
        
        // Check related lab results
        if entry.relatedReportId != nil {
            let relatedLabs = labResults.filter { lab in
                // Assuming labs are linked to reports somehow
                return lab.testDate.timeIntervalSince(entry.date) < 86400 // Within 24 hours
            }
            
            // Critical Glucose Checks
            for lab in relatedLabs {
                if lab.testName.lowercased().contains("glucose") {
                   if lab.value < 70 { return .critical } // Hypo
                   if lab.value > 250 { return .high } // Hyper
                }
            }
            
            let hasAbnormal = relatedLabs.contains { $0.status != "Normal" }
            if hasAbnormal {
                return .high
            }
        }
        
        return .medium
    }
    
    private func createMetadata(
        entry: TimelineEntryModel,
        report: MedicalReportModel?,
        labResults: [LabResultModel]
    ) -> TimelineMetadata {
        // Check for abnormal values
        let relatedLabs = labResults.filter { lab in
            lab.testDate.timeIntervalSince(entry.date) < 86400
        }
        let hasAbnormal = relatedLabs.contains { $0.status != "Normal" }
        
        // Generate tags
        var tags: [String] = []
        if let organ = report?.organ {
            tags.append(organ)
        }
        tags.append(entry.type)
        
        return TimelineMetadata(
            hasAbnormalValues: hasAbnormal,
            changeFromPrevious: nil,
            relatedEntries: [],
            tags: tags
        )
    }
    
    private func categorizeEntry(_ entry: TimelineEntryModel) -> String {
        switch entry.type {
        case "Report":
            return "Medical Report"
        case "Lab":
            return "Laboratory Test"
        case "Medication":
            return "Medication"
        case "Appointment":
            return "Appointment"
        default:
            return "Other"
        }
    }
    
    // MARK: - Chronological Sorting
    
    /// Sort entries chronologically
    func sortChronologically(_ entries: [ProcessedTimelineEntry], ascending: Bool = false) -> [ProcessedTimelineEntry] {
        return entries.sorted { ascending ? $0.date < $1.date : $0.date > $1.date }
    }
    
    /// Get entries within date range
    func filterByDateRange(
        _ entries: [ProcessedTimelineEntry],
        from startDate: Date,
        to endDate: Date
    ) -> [ProcessedTimelineEntry] {
        return entries.filter { entry in
            entry.date >= startDate && entry.date <= endDate
        }
    }
    
    /// Get recent entries (last N days)
    func getRecentEntries(_ entries: [ProcessedTimelineEntry], days: Int = 30) -> [ProcessedTimelineEntry] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return entries.filter { $0.date >= cutoffDate }
    }
}
