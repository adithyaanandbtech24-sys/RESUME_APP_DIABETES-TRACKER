// TimelineViewModel.swift
import Foundation
import SwiftData
import Combine

@MainActor
class TimelineViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var timelineEntries: [TimelineEntryModel] = []
    @Published var processedEntries: [ProcessedTimelineEntry] = []
    @Published var groupedEntries: [String: [ProcessedTimelineEntry]] = [:]
    @Published var majorEvents: [ProcessedTimelineEntry] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedFilter: String = "All" // "All", "Reports", "Labs", "Medications"
    @Published var userRole: UserRole = .patient
    @Published var canEdit: Bool = true
    
    // MARK: - Dependencies
    private let syncService = FirebaseSyncService.shared
    private let roleService = UserRoleService.shared
    private let authService = FirebaseAuthService.shared
    private let analysisEngine = TimelineAnalysisEngine.shared
    
    // MARK: - Data Loading
    
    func loadTimelineEntries(context: ModelContext, patientUid: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        // Determine which patient's data to load
        let targetUid = patientUid ?? authService.getCurrentUserID() ?? ""
        
        do {
            // Check permissions
            userRole = try await roleService.getCurrentUserRole()
            canEdit = try await roleService.canWritePatientData(patientUid: targetUid)
            
            // Sync timeline entries from Firestore (Placeholder for future implementation)
            // await syncService.syncTimelineEntries(context: context)
            
            // Load from local SwiftData and process
            await refreshLocalData(context: context)
            
        } catch {
            errorMessage = "Failed to load timeline: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func refreshLocalData(context: ModelContext) async {
        // Fetch raw entries
        let descriptor = FetchDescriptor<TimelineEntryModel>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        timelineEntries = (try? context.fetch(descriptor)) ?? []
        
        // Fetch related data for analysis
        let reports = (try? context.fetch(FetchDescriptor<MedicalReportModel>())) ?? []
        let labResults = (try? context.fetch(FetchDescriptor<LabResultModel>())) ?? []
        
        // Fetch HealthKit data
        let healthMetrics = await HealthKitManager.shared.fetchHealthData(days: 30)
        
        // Process entries
        processedEntries = analysisEngine.processTimelineEntries(
            timelineEntries,
            reports: reports,
            labResults: labResults,
            healthMetrics: healthMetrics
        )
        
        // Apply filter
        applyFilter()
        
        // Analyze for major events
        majorEvents = analysisEngine.detectMajorEvents(processedEntries)
    }
    
    func applyFilter() {
        var filtered = processedEntries
        
        if selectedFilter != "All" {
            filtered = filtered.filter { entry in
                switch selectedFilter {
                case "Reports": return entry.type == .report
                case "Labs": return entry.type == .lab
                case "Medications": return entry.type == .medication
                default: return true
                }
            }
        }
        
        // Update grouped entries based on filtered data
        // Default grouping by Month for the UI
        groupedEntries = analysisEngine.groupByMonth(filtered)
    }
    
    // MARK: - Role-Based Actions
    
    func canAddEntry() -> Bool {
        return canEdit
    }
    
    func canDeleteEntry() -> Bool {
        return userRole == .patient
    }
    
    func canEditEntry() -> Bool {
        return canEdit
    }
}
