// DemoDataManager.swift
import Foundation
import SwiftData
import SwiftUI
import Combine

/// Manages demo data for testing and demonstrations
@MainActor
class DemoDataManager: ObservableObject {
    static let shared = DemoDataManager()
    
    @Published var isDemoMode: Bool = UserDefaults.standard.bool(forKey: "isDemoMode") {
        didSet {
            UserDefaults.standard.set(isDemoMode, forKey: "isDemoMode")
        }
    }
    
    private init() {}
    
    // MARK: - Main Functions
    
    /// Load all demo data into SwiftData (currently only clears data, keeping demo mode active but without populating demo entries)
    func loadAllDemoData(context: ModelContext) {
        print("🎭 [DemoDataManager] Clearing demo data (demo mode active, no data loaded)...")
        
        // Remove any existing demo data; do not generate new demo entries
        clearAllDemoData(context: context)
        
        // Demo data generation is disabled for production-ready state
        // generateDemoReports(context: context)
        // generateDemoMedications(context: context)
        // generateDemoLabResults(context: context)
        // generateDemoOrganTrends(context: context)
        // generateDemoChatMessages(context: context)
        // generateDemoTimelineEntries(context: context)
        
        // Save the cleared state
        try? context.save()
        
        print("✅ [DemoDataManager] Demo data cleared; demo mode remains enabled without data.")
    }
    
    /// Clear all demo data from SwiftData
    func clearAllDemoData(context: ModelContext) {
        print("🗑️ [DemoDataManager] Clearing all demo data...")
        
        try? context.delete(model: MedicalReportModel.self)
        try? context.delete(model: MedicationModel.self)
        try? context.delete(model: LabResultModel.self)
        try? context.delete(model: ParameterTrendModel.self)
        try? context.delete(model: AIChatMessage.self)
        try? context.delete(model: TimelineEntryModel.self)
        try? context.delete(model: HealthMetricModel.self)
        
        try? context.save()
        
        print("✅ [DemoDataManager] All data cleared")
    }
    
    // MARK: - Demo Data Generators
    
    private func generateDemoReports(context: ModelContext) {
        let reports = [
            MedicalReportModel(
                title: "Complete Blood Count (CBC)",
                uploadDate: Date().addingTimeInterval(-7 * 24 * 60 * 60),
                reportType: "Lab Report",
                organ: "Blood",
                extractedText: "CBC results show normal values across all parameters.",
                aiInsights: "Blood count within normal range. No anemia detected."
            ),
            MedicalReportModel(
                title: "Lipid Profile",
                uploadDate: Date().addingTimeInterval(-14 * 24 * 60 * 60),
                reportType: "Lab Report",
                organ: "Heart",
                extractedText: "Cholesterol levels slightly elevated.",
                aiInsights: "Total cholesterol: 210 mg/dL. Recommend dietary changes."
            ),
            MedicalReportModel(
                title: "ECG Report",
                uploadDate: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                reportType: "Diagnostic Test",
                organ: "Heart",
                extractedText: "Normal sinus rhythm.",
                aiInsights: "Heart rhythm normal."
            )
        ]
        
        reports.forEach { context.insert($0) }
    }
    
    private func generateDemoMedications(context: ModelContext) {
        let medications = [
            MedicationModel(
                name: "Metformin",
                dosage: "500mg",
                frequency: "Twice daily",
                instructions: "Take with meals",
                startDate: Date().addingTimeInterval(-60 * 24 * 60 * 60),
                prescribedBy: "Dr. Sarah Johnson",
                isActive: true
            ),
            MedicationModel(
                name: "Lisinopril",
                dosage: "10mg",
                frequency: "Once daily",
                instructions: "Take in the morning",
                startDate: Date().addingTimeInterval(-90 * 24 * 60 * 60),
                prescribedBy: "Dr. Michael Chen",
                isActive: true
            ),
            MedicationModel(
                name: "Atorvastatin",
                dosage: "20mg",
                frequency: "Once daily",
                instructions: "Take at bedtime",
                startDate: Date().addingTimeInterval(-120 * 24 * 60 * 60),
                prescribedBy: "Dr. Sarah Johnson",
                isActive: true
            )
        ]
        
        medications.forEach { context.insert($0) }
    }
    
    private func generateDemoLabResults(context: ModelContext) {
        let labResults = [
            LabResultModel(
                testName: "HbA1c",
                value: 5.8,
                unit: "%",
                normalRange: "< 5.7",
                status: "Borderline High",
                testDate: Date().addingTimeInterval(-7 * 24 * 60 * 60),
                category: "Blood Sugar"
            ),
            LabResultModel(
                testName: "Total Cholesterol",
                value: 210,
                unit: "mg/dL",
                normalRange: "< 200",
                status: "Slightly High",
                testDate: Date().addingTimeInterval(-14 * 24 * 60 * 60),
                category: "Lipid Panel"
            ),
            LabResultModel(
                testName: "LDL Cholesterol",
                value: 135,
                unit: "mg/dL",
                normalRange: "< 100",
                status: "High",
                testDate: Date().addingTimeInterval(-14 * 24 * 60 * 60),
                category: "Lipid Panel"
            ),
            LabResultModel(
                testName: "HDL Cholesterol",
                value: 52,
                unit: "mg/dL",
                normalRange: "> 40",
                status: "Normal",
                testDate: Date().addingTimeInterval(-14 * 24 * 60 * 60),
                category: "Lipid Panel"
            ),
            LabResultModel(
                testName: "Creatinine",
                value: 1.1,
                unit: "mg/dL",
                normalRange: "0.7-1.3",
                status: "Normal",
                testDate: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                category: "Kidney Function"
            ),
            LabResultModel(
                testName: "Hemoglobin",
                value: 14.2,
                unit: "g/dL",
                normalRange: "13.5-17.5",
                status: "Normal",
                testDate: Date().addingTimeInterval(-7 * 24 * 60 * 60),
                category: "Blood Count"
            )
        ]
        
        labResults.forEach { context.insert($0) }
    }
    
    private func generateDemoOrganTrends(context: ModelContext) {
        let baseDate = Date().addingTimeInterval(-90 * 24 * 60 * 60)
        
        // Heart trends
        for i in 0..<20 {
            let trend = ParameterTrendModel(
                organ: "Heart",
                parameter: "Heart Rate",
                value: Double.random(in: 65...85),
                unit: "bpm",
                date: baseDate.addingTimeInterval(Double(i * 4) * 24 * 60 * 60),
                trend: "stable",
                comparisonValue: 72
            )
            context.insert(trend)
        }
        
        // Kidney trends
        for i in 0..<15 {
            let trend = ParameterTrendModel(
                organ: "Kidney",
                parameter: "eGFR",
                value: Double.random(in: 85...105),
                unit: "mL/min",
                date: baseDate.addingTimeInterval(Double(i * 6) * 24 * 60 * 60),
                trend: "stable",
                comparisonValue: 95
            )
            context.insert(trend)
        }
        
        // Liver trends
        for i in 0..<15 {
            let trend = ParameterTrendModel(
                organ: "Liver",
                parameter: "ALT",
                value: Double.random(in: 20...40),
                unit: "U/L",
                date: baseDate.addingTimeInterval(Double(i * 6) * 24 * 60 * 60),
                trend: "stable",
                comparisonValue: 30
            )
            context.insert(trend)
        }
        
        // Lungs trends
        for i in 0..<20 {
            let trend = ParameterTrendModel(
                organ: "Lungs",
                parameter: "SpO2",
                value: Double.random(in: 95...99),
                unit: "%",
                date: baseDate.addingTimeInterval(Double(i * 4) * 24 * 60 * 60),
                trend: "stable",
                comparisonValue: 97
            )
            context.insert(trend)
        }
    }
    
    private func generateDemoChatMessages(context: ModelContext) {
        let messages = [
            AIChatMessage(
                text: "Hello! How can I help you with your health information today?",
                isUser: false,
                timestamp: Date().addingTimeInterval(-2 * 60 * 60)
            ),
            AIChatMessage(
                text: "What does my HbA1c level of 5.8% mean?",
                isUser: true,
                timestamp: Date().addingTimeInterval(-2 * 60 * 60 + 30)
            ),
            AIChatMessage(
                text: "An HbA1c of 5.8% indicates you're in the pre-diabetic range (5.7-6.4%). It's important to consult with your doctor about lifestyle changes.",
                isUser: false,
                timestamp: Date().addingTimeInterval(-2 * 60 * 60 + 45)
            )
        ]
        
        messages.forEach { context.insert($0) }
    }
    
    private func generateDemoTimelineEntries(context: ModelContext) {
        let entries = [
            TimelineEntryModel(
                date: Date().addingTimeInterval(-7 * 24 * 60 * 60),
                type: "Lab Result",
                title: "Blood Test Results",
                summary: "Complete Blood Count - All values normal",
                iconName: "drop.fill",
                color: "#FF6B6B"
            ),
            TimelineEntryModel(
                date: Date().addingTimeInterval(-14 * 24 * 60 * 60),
                type: "Medication",
                title: "Started Atorvastatin",
                summary: "Prescribed 20mg daily",
                iconName: "pills.fill",
                color: "#95E1D3"
            ),
            TimelineEntryModel(
                date: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                type: "Appointment",
                title: "Cardiology Checkup",
                summary: "Annualscreening - ECG normal",
                iconName: "heart.fill",
                color: "#FFD93D"
            )
        ]
        
        entries.forEach { context.insert($0) }
    }
}
