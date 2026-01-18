// MedicationManager.swift
import SwiftUI
import SwiftData
import Foundation
import UserNotifications
import Combine

/// Manages medication data to ensure only uploaded medications are shown
@MainActor
public class MedicationManager {
    static let shared = MedicationManager()
    
    private init() {}
    
    /// Clear all existing medications (removes demo data)
    func clearAllMedications(context: ModelContext) {
        context.clearAllMedications()
        print("✅ [MedicationManager] All medications cleared. Only medications from uploaded documents will be shown.")
    }
    
    /// Check if medications exist and clear demo data if needed
    func initializeMedications(context: ModelContext) {
        let existingMedications = context.fetchAllMedications()
        
        if !existingMedications.isEmpty {
            print("ℹ️ [MedicationManager] Found \(existingMedications.count) existing medications")
            
            // Check if any medications appear to be demo data (generic names without specific sources)
            let demoMedicationNames = ["Aspirin", "Metformin", "Lisinopril", "Atorvastatin"]
            let hasDemoData = existingMedications.contains { med in
                demoMedicationNames.contains(med.name) && 
                (med.prescribedBy == nil || med.prescribedBy == "Dr. Unknown" || med.prescribedBy == "Dr. Sarah Johnson")
            }
            
            if hasDemoData {
                print("🗑️ [MedicationManager] Clearing demo medications found")
                clearAllMedications(context: context)
            } else {
                print("✅ [MedicationManager] No demo data found. Keeping existing medications.")
            }
        } else {
            print("ℹ️ [MedicationManager] No existing medications found.")
        }
    }
    
    /// Get medications that were explicitly extracted from uploaded documents
    /// STRICT: Only returns medications that have clear document analysis markers
    func getUploadedMedications(context: ModelContext) -> [MedicationModel] {
        let allMedications = context.fetchAllMedications()
        
        // STRICT FILTER: Only return medications that were explicitly extracted from reports
        // No fallbacks to date-based filtering - only show what was actually mentioned in documents
        let uploadedMedications = allMedications.filter { medication in
            // Only keep medications that have explicit document analysis markers:
            // 1. prescribedBy = "From Document Analysis" (set by ReportService)
            // 2. prescribedBy = "From PDF Analysis" (set by ReportService for PDFs)
            // 3. instructions containing document extraction marker
            // 4. User manually added (prescribedBy = "User Added")
            
            let isFromDocumentAnalysis = medication.prescribedBy == "From Document Analysis"
            let isFromPDFAnalysis = medication.prescribedBy == "From PDF Analysis"
            let isUserAdded = medication.prescribedBy == "User Added"
            let hasDocumentInstructions = medication.instructions?.contains("Extracted from uploaded document") == true
            
            // STRICT: Only return if one of these explicit markers is present
            let hasMarker = isFromDocumentAnalysis || isFromPDFAnalysis || isUserAdded || hasDocumentInstructions
            
            // FINAL SAFETY CHECK: Filter out garbage names that might have slipped through
            guard hasMarker else { return false }
            
            return self.isValidMedicationName(medication.name)
        }
        
        return uploadedMedications.sorted { $0.startDate > $1.startDate }
    }
    
    /// Strict validation to filter out non-medication terms like "Calculated", "Urease", etc.
    func isValidMedicationName(_ name: String) -> Bool {
        let lowerName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Length check
        if lowerName.count < 3 { return false }
        
        // 2. Letter check (must have at least 3 letters)
        let letters = lowerName.filter { $0.isLetter }
        if letters.count < 3 { return false }
        
        // 3. Blacklist check (names containing these words are fake)
        // Includes common lab terms often hallucinated as meds
        let blacklist = [
            "calculated", "urease", "method", "range", "interval", "reference", 
            "result", "sample", "specimen", "report", "test", "parameter", "value",
            "level", "reading", "index", "ratio", "count", "volume", "mean",
            "normal", "high", "low", "critical", "abnormal", "flag",
            "date", "time", "patient", "gender", "age", "dob",
            "urine", "serum", "blood", "plasma",
            "unit", "units", "mg/dl", "g/dl", "mmol/l"
        ]
        
        // 4. Check if the name contains ANY blacklisted term
        if blacklist.contains(where: { lowerName.contains($0) }) {
            // Exceptions: Some meds might contain these substrings (e.g. "Insulin" contains "in", but not blacklist words)
            // But "Calculated" is definitely bad.
            return false
        }
        
        return true
    }
    
    /// Get Past medications ensuring no overlap with Active ones
    func getUniquePastMedications(context: ModelContext) -> [MedicationModel] {
        let allMeds = getUploadedMedications(context: context)
        let activeMeds = allMeds.filter { $0.isActive }
        let pastMeds = allMeds.filter { !$0.isActive }
        
        let activeNames = Set(activeMeds.map { $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
        
        return pastMeds.filter { pastMed in
            let pastName = pastMed.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return !activeNames.contains(pastName)
        }
    }
    
    /// Process new medications from a prescription upload
    /// Implements Active/Passive logic:
    /// - If a medication exists in the NEW list, it remains/becomes ACTIVE.
    /// - If a medication was previously ACTIVE but is NOT in the new list, it becomes PASSIVE (Past).
    /// - If a medication is NEW, it is added as ACTIVE.
    func processMedicationUpdate(newMedications: [MedicationModel], context: ModelContext) {
        print("💊 [MedicationManager] Processing medication update with \(newMedications.count) new items")
        
        // 1. Fetch all currently ACTIVE medications
        let allMedications = context.fetchAllMedications()
        let activeMedications = allMedications.filter { $0.isActive }
        
        print("   - Found \(activeMedications.count) currently active medications")
        
        // 2. Iterate through currently active medications
        for activeMed in activeMedications {
            let matchesNew = newMedications.contains { newMed in
                // Match by name (case insensitive)
                return newMed.name.lowercased() == activeMed.name.lowercased()
            }
            
            if !matchesNew {
                // Medication is NOT in the new list -> Move to Past
                print("   - Moving to past: \(activeMed.name)")
                activeMed.isActive = false
                activeMed.endDate = Date() // Ended now
            } else {
                // Medication IS in the new list -> Keep Active
                print("   - Keeping active: \(activeMed.name)")
            }
        }
        
        // 3. Add NEW medications (that don't exist yet)
        for newMed in newMedications {
            let exists = activeMedications.contains { $0.name.lowercased() == newMed.name.lowercased() }
            
            if !exists {
                print("   - Adding new active medication: \(newMed.name)")
                newMed.isActive = true
                newMed.startDate = Date()
                context.insert(newMed)
            }
        }
        
        // 4. Save changes
        try? context.save()
    }
    
    /// Permanently delete invalid medications from the database to clean up persistence
    func cleanUpInvalidMedications(context: ModelContext) {
        let allMeds = context.fetchAllMedications()
        var deletedCount = 0
        
        for med in allMeds {
            if !isValidMedicationName(med.name) {
                print("🗑️ [MedicationManager] Deleting invalid medication during cleanup: \(med.name)")
                context.delete(med)
                deletedCount += 1
            }
        }
        
        if deletedCount > 0 {
            try? context.save()
            print("✅ [MedicationManager] Cleanup complete. Deleted \(deletedCount) invalid medications.")
        }
    }
    
    /// Alternative: Get all medications but mark demo ones
    func getMedicationsWithDemo标记(context: ModelContext) -> (medications: [MedicationModel], hasDemoData: Bool) {
        let allMedications = context.fetchAllMedications()
        
        let demoMedicationNames = ["Aspirin", "Metformin", "Lisinopril", "Atorvastatin"]
        var hasDemoData = false
        
        let markedMedications = allMedications.map { medication in
            let isDemo = demoMedicationNames.contains(medication.name) && 
                        (medication.prescribedBy == nil || 
                         medication.prescribedBy == "Dr. Unknown" || 
                         medication.prescribedBy == "Dr. Sarah Johnson")
            
            if isDemo {
                hasDemoData = true
            }
            
            return medication
        }
        
        return (medications: markedMedications, hasDemoData: hasDemoData)
    }
}

// MARK: - Medication Reminder Manager
class MedicationReminderManager: ObservableObject {
    static let shared = MedicationReminderManager()
    
    @Published var permissionGranted = false
    
    init() {
        requestPermission()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.permissionGranted = granted
                if let error = error {
                    print("Notification permission error: \(error)")
                }
            }
        }
    }
    
    func scheduleReminder(title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}