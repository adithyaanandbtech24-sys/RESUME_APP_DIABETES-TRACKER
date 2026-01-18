import Foundation
import SwiftData
#if canImport(FirebaseFirestore)
import FirebaseFirestore // For Timestamp
#endif
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Medical Report Model
@Model
public final class MedicalReportModel {
    @Attribute(.unique) public var id: String
    public var title: String
    public var uploadDate: Date
    public var clinicalDate: Date  // Date from the report itself (extracted from OCR)
    public var reportType: String
    public var organ: String // e.g., "Heart", "Kidney", "Liver"
    public var imageURL: String?
    public var pdfURL: String?
    public var extractedText: String
    public var aiInsights: String
    public var syncState: String = "pending" // "pending", "synced", "failed"
    
    // Relationships
    @Relationship(deleteRule: .cascade) public var labResults: [LabResultModel]?
    @Relationship(deleteRule: .cascade) public var medications: [MedicationModel]?
    
    /// The display date: prefers clinicalDate if it's different from uploadDate, otherwise shows uploadDate
    public var displayDate: Date {
        // If clinicalDate is within 1 minute of uploadDate, it wasn't extracted - use uploadDate
        if abs(clinicalDate.timeIntervalSince(uploadDate)) < 60 {
            return uploadDate
        }
        return clinicalDate
    }
    
    public init(id: String = UUID().uuidString,
         title: String,
         uploadDate: Date = Date(),
         clinicalDate: Date? = nil,
         reportType: String,
         organ: String = "General",
         imageURL: String? = nil,
         pdfURL: String? = nil,
         extractedText: String = "",
         aiInsights: String = "") {
        self.id = id
        self.title = title
        self.uploadDate = uploadDate
        self.clinicalDate = clinicalDate ?? uploadDate  // Default to upload date if not extracted
        self.reportType = reportType
        self.organ = organ
        self.imageURL = imageURL
        self.pdfURL = pdfURL
        self.extractedText = extractedText
        self.aiInsights = aiInsights
        self.syncState = "pending"
    }
}

// MARK: - User Profile Model
@Model
public final class UserProfileModel {
    public var name: String
    public var age: Int
    public var gender: String // "male", "female", "other"
    public var height: Double? // cm
    public var weight: Double? // kg
    public var profilePhotoData: Data? // JPEG or PNG data
    public var enableAI: Bool // User preference for AI-powered features
    
    // Diabetes Specific Fields
    public var diabetesType: String // "Type 1", "Type 2", "Gestational", "Prediabetes"
    public var diagnosisYear: Int?
    public var treatmentType: String // "Insulin", "Oral", "Lifestyle"
    public var comorbidities: [String] // e.g. ["Hypertension", "Neuropathy"]
    public var familyHistory: String // e.g. "Father", "None"
    
    public init(name: String = "User",
         age: Int = 30,
         gender: String = "male",
         height: Double? = nil,
         weight: Double? = nil,
         profilePhotoData: Data? = nil,
         enableAI: Bool = true,
         diabetesType: String = "Type 2",
         diagnosisYear: Int? = nil,
         treatmentType: String = "Oral",
         comorbidities: [String] = [],
         familyHistory: String = "None") {
        self.name = name
        self.age = age
        self.gender = gender
        self.height = height
        self.weight = weight
        self.profilePhotoData = profilePhotoData
        self.enableAI = enableAI
        self.diabetesType = diabetesType
        self.diagnosisYear = diagnosisYear
        self.treatmentType = treatmentType
        self.comorbidities = comorbidities
        self.familyHistory = familyHistory
    }
}

// MARK: - Lab Result Model
@Model
public final class LabResultModel {
    @Attribute(.unique) public var id: String
    public var testName: String
    public var parameter: String // e.g., "Hemoglobin", "Cholesterol"
    public var value: Double
    public var stringValue: String? // Support for text-based results (e.g. "A+", "Positive")
    public var unit: String
    public var normalRange: String
    public var status: String // "Normal", "High", "Low"
    public var testDate: Date
    public var category: String // "Blood", "Urine", "Liver", etc.
    public var syncState: String = "pending"
    
    public init(id: String = UUID().uuidString,
         testName: String,
         parameter: String? = nil,
         value: Double,
         stringValue: String? = nil,
         unit: String,
         normalRange: String,
         status: String,
         testDate: Date = Date(),
         category: String) {
        self.id = id
        self.testName = testName
        self.parameter = parameter ?? testName
        self.value = value
        self.stringValue = stringValue
        self.unit = unit
        self.normalRange = normalRange
        self.status = status
        self.testDate = testDate
        self.category = category
        self.syncState = "pending"
    }
}

// MARK: - Medication Model
@Model
public final class MedicationModel {
    @Attribute(.unique) public var id: String
    public var name: String
    public var dosage: String
    public var frequency: String
    public var instructions: String?
    public var startDate: Date
    public var endDate: Date?
    public var prescribedBy: String?
    public var notes: String?
    public var sideEffects: String?
    public var alternatives: String?
    public var isActive: Bool
    public var source: String // "Prescribed", "Detected from document", "Self-reported", "Unknown"
    public var syncState: String = "pending"
    
    public init(id: String = UUID().uuidString,
         name: String,
         dosage: String,
         frequency: String,
         instructions: String? = nil,
         startDate: Date = Date(),
         endDate: Date? = nil,
         prescribedBy: String? = nil,
         notes: String? = nil,
         sideEffects: String? = nil,
         alternatives: String? = nil,
         isActive: Bool = true,
         source: String = "Unknown") {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.instructions = instructions
        self.startDate = startDate
        self.endDate = endDate
        self.prescribedBy = prescribedBy
        self.notes = notes
        self.sideEffects = sideEffects
        self.alternatives = alternatives
        self.isActive = isActive
        self.source = source
        self.syncState = "pending"
    }
}

// MARK: - Lab Graph Data Model
@Model
public final class LabGraphDataModel {
    @Attribute(.unique) public var id: String
    public var organ: String
    public var parameter: String
    public var value: Double
    public var unit: String
    public var date: Date
    public var reportId: String?
    public var refMin: Double? // Store specific reference range min
    public var refMax: Double? // Store specific reference range max
    public var syncState: String = "pending"
    
    public init(id: String = UUID().uuidString,
         organ: String,
         parameter: String,
         value: Double,
         unit: String,
         date: Date = Date(),
         refMin: Double? = nil,
         refMax: Double? = nil,
         reportId: String? = nil) {
        self.id = id
        self.organ = organ
        self.parameter = parameter
        self.value = value
        self.unit = unit
        self.date = date
        self.refMin = refMin
        self.refMax = refMax
        self.reportId = reportId
        self.syncState = "pending"
    }
    
    // MARK: - Firestore Sync Support
    #if canImport(FirebaseFirestore)
    static func fromFirestore(_ data: [String: Any]) -> LabGraphDataModel? {
        guard let id = data["id"] as? String,
              let organ = data["organ"] as? String,
              let parameter = data["parameter"] as? String,
              let value = data["value"] as? Double,
              let unit = data["unit"] as? String else {
            return nil
        }
        
        let date: Date
        if let timestamp = data["date"] as? Timestamp {
            date = timestamp.dateValue()
        } else if let timeInterval = data["date"] as? TimeInterval {
            date = Date(timeIntervalSince1970: timeInterval)
        } else {
            date = Date()
        }
              
        return LabGraphDataModel(
            id: id,
            organ: organ,
            parameter: parameter,
            value: value,
            unit: unit,
            date: date,
            reportId: data["reportId"] as? String
        )
    }
    
    func toFirestore() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "organ": organ,
            "parameter": parameter,
            "value": value,
            "unit": unit,
            "date": Timestamp(date: date)
        ]
        
        if let reportId = reportId {
            dict["reportId"] = reportId
        }
        
        return dict
    }
    #endif
}

// MARK: - Helper Types

public struct GraphPoint: Identifiable {
    public let id: String
    public let date: Date
    public let value: Double
    
    public init(id: String = UUID().uuidString, date: Date, value: Double) {
        self.id = id
        self.date = date
        self.value = value
    }
    
    public init(from model: LabGraphDataModel) {
        self.id = model.id
        self.date = model.date
        self.value = model.value
    }
}

// MARK: - Parameter Trend Model (for Timeline)
@Model
public final class ParameterTrendModel {
    @Attribute(.unique) public var id: String
    public var organ: String // "Heart", "Kidney", "Lungs", etc.
    public var parameter: String // "Heart Rate", "eGFR", "SpO2"
    public var value: Double
    public var unit: String
    public var date: Date
    public var trend: String // "improving", "stable", "declining"
    public var comparisonValue: Double? // Previous value for comparison
    
    public init(id: String = UUID().uuidString,
         organ: String,
         parameter: String,
         value: Double,
         unit: String,
         date: Date = Date(),
         trend: String = "stable",
         comparisonValue: Double? = nil) {
        self.id = id
        self.organ = organ
        self.parameter = parameter
        self.value = value
        self.unit = unit
        self.date = date
        self.trend = trend
        self.comparisonValue = comparisonValue
    }
}

// MARK: - Timeline Entry Model
@Model
public final class TimelineEntryModel {
    @Attribute(.unique) public var id: String
    public var date: Date
    public var type: String // "Report", "Lab", "Medication", "Appointment"
    public var title: String
    public var summary: String // Renamed from 'description' to avoid SwiftData conflict
    public var relatedReportId: String?
    public var iconName: String
    public var color: String // Hex color string
    public var syncState: String = "pending"
    
    public init(id: String = UUID().uuidString,
         date: Date = Date(),
         type: String,
         title: String,
         summary: String,
         relatedReportId: String? = nil,
         iconName: String,
         color: String) {
        self.id = id
        self.date = date
        self.type = type
        self.title = title
        self.summary = summary
        self.relatedReportId = relatedReportId
        self.iconName = iconName
        self.color = color
        self.syncState = "pending"
    }
}

// MARK: - Chat Message Model
// MARK: - Chat Message Model
@Model
public final class AIChatMessage {
    @Attribute(.unique) public var id: String
    public var text: String
    public var isUser: Bool
    public var timestamp: Date
    
    public init(id: String = UUID().uuidString, text: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
}


extension ModelContext {
    /// Clear all data including medical records, chat history, and metrics.
    /// Does NOT delete UserProfileModel unless explicitly handled by caller (but usually caller does).
    /// Actually, let's include all data EXCEPT profile if we want to be selective, 
    /// but the method name implies "All Data". 
    /// Let's delete EVERYTHING including Profile for a "factory reset" feel, 
    /// or let the caller decide. 
    /// Given the use case, I'll delete EVERYTHING.
    func clearAllData() {
        // Medical Data
        try? delete(model: MedicalReportModel.self)
        try? delete(model: LabResultModel.self)
        try? delete(model: MedicationModel.self)
        try? delete(model: LabGraphDataModel.self)
        try? delete(model: ParameterTrendModel.self)
        try? delete(model: TimelineEntryModel.self)
        try? delete(model: HealthMetricModel.self)
        
        // Chat History
        try? delete(model: AIChatMessage.self)
        
        // User Profile (Often handled separately, but clean to wipe)
        try? delete(model: UserProfileModel.self)
        
        try? save()
    }
}
// MARK: - Health Metric Model (Persisted)
@Model
public final class HealthMetricModel {
    @Attribute(.unique) public var id: String
    public var date: Date
    public var type: String // "Heart Rate", "Steps", "Sleep", "Oxygen Saturation"
    public var value: Double
    public var unit: String
    public var source: String // "HealthKit", "Manual"
    
    public init(id: String = UUID().uuidString,
         date: Date,
         type: String,
         value: Double,
         unit: String,
         source: String = "HealthKit") {
        self.id = id
        self.date = date
        self.type = type
        self.value = value
        self.unit = unit
        self.source = source
    }
}

// MARK: - Shared Enums

public enum TrendDirection: String, Codable {
    case improving = "improving"
    case stable = "stable"
    case declining = "declining"
    case unknown = "unknown"
}

public enum EventSeverity: String, Codable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"
    case normal = "normal"
}
