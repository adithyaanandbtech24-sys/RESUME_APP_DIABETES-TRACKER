import SwiftUI
import SwiftData
import Combine

/// ViewModel for managing health data locally (Refactored for local-first)
@MainActor
class HealthDataViewModel: ObservableObject {
    private let modelContext: ModelContext
    
    @Published var reports: [MedicalReportModel] = []
    @Published var labResults: [LabResultModel] = []
    @Published var medications: [MedicationModel] = []
    @Published var timelineEntries: [TimelineEntryModel] = []
    @Published var graphData: [LabGraphDataModel] = []
    
    private let auth = FirebaseAuthService.shared
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refreshData()
    }
    
    // MARK: - Data Management
    
    func refreshData() {
        fetchReports()
        fetchLabs()
        fetchMedications()
        fetchTimeline()
        fetchGraphData()
    }
    
    private func fetchReports() {
        let descriptor = FetchDescriptor<MedicalReportModel>(sortBy: [SortDescriptor(\.uploadDate, order: .reverse)])
        reports = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func fetchLabs() {
        let descriptor = FetchDescriptor<LabResultModel>(sortBy: [SortDescriptor(\.testDate, order: .reverse)])
        labResults = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func fetchMedications() {
        let descriptor = FetchDescriptor<MedicationModel>(
            predicate: #Predicate<MedicationModel> { $0.isActive },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        medications = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func fetchTimeline() {
        let descriptor = FetchDescriptor<TimelineEntryModel>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        timelineEntries = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func fetchGraphData() {
        let descriptor = FetchDescriptor<LabGraphDataModel>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        graphData = (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Computed Properties
    
    /// Get latest lab result for a specific test
    func latestLabResult(for testName: String) -> LabResultModel? {
        labResults.first { $0.testName == testName }
    }
    
    /// Get lab results by category
    func labResults(for category: String) -> [LabResultModel] {
        labResults.filter { $0.category == category }
    }
    
    /// Get health summary statistics
    var healthSummary: HealthSummary {
        HealthSummary(
            totalReports: reports.count,
            totalLabTests: labResults.count,
            activeMedications: medications.count,
            abnormalResults: labResults.filter { $0.status != "Normal" && $0.status != "Optimal" }.count
        )
    }
    
    /// Get recent activity (last 7 days)
    var recentActivity: [TimelineEntryModel] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return timelineEntries.filter { $0.date >= sevenDaysAgo }
    }
}

// MARK: - Supporting Types

struct HealthSummary {
    let totalReports: Int
    let totalLabTests: Int
    let activeMedications: Int
    let abnormalResults: Int
}

