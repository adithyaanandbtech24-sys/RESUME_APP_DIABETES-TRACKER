import Foundation
import Combine
import SwiftData
typealias ChatMessageModel = AIChatMessage
/// Central app state manager using ObservableObject for SwiftUI integration
@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    
    /// Currently authenticated user
    @Published var currentUser: User?
    
    /// All uploaded medical reports
    @Published var reports: [MedicalReport] = []
    
    /// Health metrics extracted from reports
    @Published var healthMetrics: [HealthMetric] = []
    
    /// Active chat messages
    @Published var chatMessages: [ChatMessageModel] = []
    
    /// App loading state
    @Published var isLoading: Bool = false
    
    /// Error message for UI display
    @Published var errorMessage: String?
    
    /// Active connections (doctors/family)
    @Published var activeConnections: [Connection] = []
    
    // MARK: - Singleton
    static let shared = AppState()
    
    private init() {
        loadInitialData()
    }
    
    // MARK: - Methods
    
    /// Load initial app data
    func loadInitialData() {
        // Load cached user data
        currentUser = User(
            id: UUID().uuidString,
            name: "Anand",
            email: "anand@medisync.com",
            dateOfBirth: Date()
        )
        
        // Load sample data for development
        loadSampleData()
    }
    
    /// Add a new medical report
    func addReport(_ report: MedicalReport) {
        reports.append(report)
        extractMetricsFromReport(report)
    }
    
    /// Update health metrics from report
    private func extractMetricsFromReport(_ report: MedicalReport) {
        // Extract metrics and update healthMetrics array
        // This will be populated by OCRService and MLService
    }
    
    /// Add chat message
    func addChatMessage(_ message: ChatMessageModel) {
        chatMessages.append(message)
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Set loading state
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    /// Load sample data for development
    private func loadSampleData() {
        // Sample health metrics
        healthMetrics = [
            HealthMetric(
                id: UUID().uuidString,
                type: .heartRate,
                value: 72,
                unit: "bpm",
                date: Date(),
                source: "Blood Test"
            ),
            HealthMetric(
                id: UUID().uuidString,
                type: .bloodPressure,
                value: 120,
                unit: "mmHg",
                date: Date(),
                source: "Health Checkup"
            )
        ]
    }
}

// MARK: - Supporting Models

struct User: Identifiable, Codable {
    let id: String
    var name: String
    var email: String
    var dateOfBirth: Date
    var profileImageURL: String?
}

struct MedicalReport: Identifiable, Codable {
    let id: String
    var title: String
    var date: Date
    var type: ReportType
    var imageURL: String?
    var extractedText: String?
    var metrics: [String: Any]?
    var aiInsights: String?
    
    enum ReportType: String, Codable {
        case bloodTest = "Blood Test"
        case xray = "X-Ray"
        case mri = "MRI"
        case prescription = "Prescription"
        case labReport = "Lab Report"
        case other = "Other"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, date, type, imageURL, extractedText, aiInsights
    }
}

struct HealthMetric: Identifiable, Codable {
    let id: String
    var type: MetricType
    var value: Double
    var unit: String
    var date: Date
    var source: String
    
    enum MetricType: String, Codable {
        case heartRate = "Heart Rate"
        case bloodPressure = "Blood Pressure"
        case cholesterol = "Cholesterol"
        case glucose = "Glucose"
        case hemoglobin = "Hemoglobin"
        case vitaminD = "Vitamin D"
        case eGFR = "eGFR"
        case alt = "ALT"
        case ast = "AST"
        case spo2 = "SpO2"
    }
}



struct Connection: Identifiable, Codable {
    let id: String
    var name: String
    var type: ConnectionType
    var connectedDate: Date
    var shareLink: String?
    var linkExpiry: Date?
    
    enum ConnectionType: String, Codable {
        case doctor = "Doctor"
        case family = "Family"
    }
}
