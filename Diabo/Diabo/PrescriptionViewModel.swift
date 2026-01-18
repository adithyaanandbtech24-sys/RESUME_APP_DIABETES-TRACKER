
import Foundation
import SwiftData
import Combine

@MainActor
class PrescriptionViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var medications: [MedicationModel] = []
    @Published var adherenceScore: AdherenceScore?
    @Published var adherenceChartData: [AdherenceChartData] = []
    @Published var upcomingReminders: [MedicationReminder] = []
    @Published var missedDoses: [MissedDose] = []
    @Published var riskLevel: RiskLevel = .low
    @Published var riskFactors: [String] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userRole: UserRole = .patient
    @Published var canEdit: Bool = true
    
    // MARK: - Dependencies
    private let syncService = FirebaseSyncService.shared
    private let authService = FirebaseAuthService.shared
    private let roleService = UserRoleService.shared
    private let adherenceEngine = MedicationAdherenceEngine.shared
    
    // MARK: - Initialization
    init() {
        // Initial load handled by view
    }
    
    // MARK: - Data Loading
    
    func loadMedications(context: ModelContext, patientUid: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        // Determine which patient's data to load
        let targetUid = patientUid ?? authService.getCurrentUserID() ?? ""
        
        do {
            // Check permissions
            userRole = try await roleService.getCurrentUserRole()
            canEdit = try await roleService.canWritePatientData(patientUid: targetUid)
            
            // Sync medications from Firestore
            // Note: syncAll handles medications, but we can add specific sync if needed
            // For now, we rely on the main sync or specific medication syncs
            
            // Load from local SwiftData
            await refreshLocalData(context: context)
            
        } catch {
            errorMessage = "Failed to load medications: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func refreshLocalData(context: ModelContext) async {
        let descriptor = FetchDescriptor<MedicationModel>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        
        medications = (try? context.fetch(descriptor)) ?? []
        
        // Analyze adherence
        analyzeAdherence()
    }
    
    // MARK: - Analysis
    
    private func analyzeAdherence() {
        // Calculate scores
        let score = adherenceEngine.calculateAdherenceScore(medications: medications)
        self.adherenceScore = score
        
        // Generate chart data
        self.adherenceChartData = adherenceEngine.generateAdherenceChartData(medications: medications)
        
        // Generate reminders
        self.upcomingReminders = adherenceEngine.generateReminders(medications: medications)
        
        // Detect missed doses
        self.missedDoses = adherenceEngine.detectMissedDoses(medications: medications)
        
        // Predict risk
        let prediction = adherenceEngine.predictAdherenceRisk(medications: medications, adherenceScore: score)
        self.riskLevel = prediction.riskLevel
        self.riskFactors = prediction.factors
    }
    
    // MARK: - Actions
    
    func addMedication(
        name: String,
        dosage: String,
        frequency: String,
        instructions: String?,
        context: ModelContext
    ) async {
        guard canEdit else {
            errorMessage = "You do not have permission to add medications."
            return
        }
        
        let medication = MedicationModel(
            id: UUID().uuidString,
            name: name,
            dosage: dosage,
            frequency: frequency,
            instructions: instructions,
            startDate: Date(),
            isActive: true
        )
        
        context.insert(medication)
        try? context.save()
        
        do {
            try await syncService.syncMedication(medication)
            await refreshLocalData(context: context)
        } catch {
            errorMessage = "Failed to sync medication: \(error.localizedDescription)"
        }
    }
    
    func updateMedicationStatus(medication: MedicationModel, isActive: Bool, context: ModelContext) async {
        guard canEdit else {
            errorMessage = "You do not have permission to update medications."
            return
        }
        
        medication.isActive = isActive
        if !isActive {
            medication.endDate = Date()
        }
        try? context.save()
        
        do {
            try await syncService.syncMedication(medication)
            await refreshLocalData(context: context)
        } catch {
            errorMessage = "Failed to update status: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Role-Based Actions
    
    func canAddMedication() -> Bool {
        return canEdit
    }
    
    func canEditMedication() -> Bool {
        return canEdit
    }
}

