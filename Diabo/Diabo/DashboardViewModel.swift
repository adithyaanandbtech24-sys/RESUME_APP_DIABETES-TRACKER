// DashboardViewModel.swift
import Foundation
import SwiftData
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var recentReports: [MedicalReportModel] = []
    @Published var activeMedications: [MedicationModel] = []
    @Published var labResults: [LabResultModel] = []
    @Published var labTrends: [LabTrendSummary] = []
    @Published var healthAlerts: [HealthAlert] = []
    @Published var medicationSummary: MedicationAdherenceSummary?
    @Published var diagnosisSummary: DiagnosisSummary?
    @Published var timelineSummary: TimelineSummary?
    @Published var healthScore: Int = 0 // Default to 0 (No Data)
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userRole: UserRole = .patient
    @Published var canEdit: Bool = true
    
    // MARK: - Dependencies
    private let authService = FirebaseAuthService.shared
    private let roleService = UserRoleService.shared
    private let dataEngine = DashboardDataEngine.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
    }
    
    // MARK: - Data Loading
    
    func loadDashboardData(context: ModelContext, patientUid: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            userRole = try await roleService.getCurrentUserRole()
            canEdit = true // Default to can edit in local-first
            
            // Load data from SwiftData
            await analyzeMedicalData(context: context)
            
        } catch {
            errorMessage = "Failed to load dashboard: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Medical Data Analysis
    
    private func analyzeMedicalData(context: ModelContext) async {
        // Fetch all data for analysis from SwiftData
        let reports = (try? context.fetch(FetchDescriptor<MedicalReportModel>(sortBy: [SortDescriptor(\.uploadDate, order: .reverse)]))) ?? []
        let medications = (try? context.fetch(FetchDescriptor<MedicationModel>(predicate: #Predicate<MedicationModel> { $0.isActive }))) ?? []
        let labResults = (try? context.fetch(FetchDescriptor<LabResultModel>(sortBy: [SortDescriptor(\.testDate, order: .reverse)]))) ?? []
        let timelineEntries = (try? context.fetch(FetchDescriptor<TimelineEntryModel>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        
        self.recentReports = Array(reports.prefix(10))
        self.activeMedications = medications
        self.labResults = labResults
        
        // Fetch HealthKit data
        let healthMetrics = await HealthKitManager.shared.fetchHealthData()
        
        // Generate comprehensive dashboard summary
        let summary = dataEngine.generateDashboardSummary(
            reports: reports,
            medications: medications,
            labResults: labResults,
            timelineEntries: timelineEntries,
            healthMetrics: healthMetrics
        )
        
        // Update published properties
        labTrends = summary.labTrends
        medicationSummary = summary.medicationSummary
        diagnosisSummary = summary.diagnosisSummary
        timelineSummary = summary.timelineSummary
        
        // Combine all alerts
        healthAlerts = summary.alertSummary.criticalAlerts + summary.alertSummary.warnings
        
        // Calculate health score based on data
        healthScore = calculateHealthScore(summary: summary, hasData: !reports.isEmpty || !labResults.isEmpty || !healthMetrics.isEmpty)
    }
    
    private func calculateHealthScore(summary: (
        labTrends: [LabTrendSummary],
        medicationSummary: MedicationAdherenceSummary,
        diagnosisSummary: DiagnosisSummary,
        timelineSummary: TimelineSummary,
        alertSummary: AlertSummary
    ), hasData: Bool) -> Int {
        // If no data at all, return 0
        guard hasData else { return 0 }
        
        var score = 100
        
        // Deduct for out-of-range labs
        let outOfRangeLabs = summary.labTrends.filter { $0.isOutOfRange }.count
        score -= outOfRangeLabs * 5
        
        // Deduct for critical alerts
        score -= summary.alertSummary.criticalAlerts.count * 10
        
        // Deduct for warnings
        score -= summary.alertSummary.warnings.count * 3
        
        // Bonus for good medication adherence
        if summary.medicationSummary.adherenceScore > 90 {
            score += 5
        }
        
        return max(0, min(100, score))
    }
    
    // MARK: - Public Methods
    
    func refresh(context: ModelContext) async {
        await analyzeMedicalData(context: context)
    }
    
    /// Get recent lab trends for a specific parameter
    func getLabTrend(for parameter: String) -> LabTrendSummary? {
        return labTrends.first { $0.parameter == parameter }
    }
    
    /// Get critical alerts only
    func getCriticalAlerts() -> [HealthAlert] {
        return healthAlerts.filter { $0.severity == .critical || $0.severity == .high }
    }
    
    // MARK: - Role-Based Actions
    
    func canUploadDocuments() -> Bool {
        return true
    }
    
    func canDeleteReports() -> Bool {
        return true
    }
    
    func canEditMedications() -> Bool {
        return true
    }
}
