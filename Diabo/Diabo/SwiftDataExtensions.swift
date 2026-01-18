import Foundation
import SwiftData

// MARK: - ModelContext CRUD Extensions

extension ModelContext {
    
    // MARK: - Medical Reports CRUD
    
    /// Create a new medical report
    func createReport(
        title: String,
        reportType: String,
        organ: String = "General",
        imageURL: String? = nil,
        pdfURL: String? = nil,
        extractedText: String? = nil,
        aiInsights: String? = nil
    ) -> MedicalReportModel {
        let report = MedicalReportModel(
            title: title,
            reportType: reportType,
            organ: organ,
            imageURL: imageURL,
            pdfURL: pdfURL,
            extractedText: extractedText ?? "",
            aiInsights: aiInsights ?? ""
        )
        insert(report)
        try? save()
        return report
    }
    
    /// Read all reports
    func fetchAllReports() -> [MedicalReportModel] {
        let descriptor = FetchDescriptor<MedicalReportModel>(
            sortBy: [SortDescriptor(\.uploadDate, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Read report by ID
    func fetchReport(id: String) -> MedicalReportModel? {
        let descriptor = FetchDescriptor<MedicalReportModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try? fetch(descriptor).first
    }
    
    /// Update report
    func updateReport(
        _ report: MedicalReportModel,
        title: String? = nil,
        aiInsights: String? = nil,
        extractedText: String? = nil
    ) {
        if let title = title {
            report.title = title
        }
        if let aiInsights = aiInsights {
            report.aiInsights = aiInsights
        }
        if let extractedText = extractedText {
            report.extractedText = extractedText
        }
        try? save()
    }
    
    /// Delete report
    func deleteReport(_ report: MedicalReportModel) {
        delete(report)
        try? save()
    }
    
    /// Delete report by ID
    func deleteReport(id: String) {
        if let report = fetchReport(id: id) {
            delete(report)
            try? save()
        }
    }
    
    // MARK: - Medications CRUD
    
    /// Create a new medication
    func createMedication(
        name: String,
        dosage: String,
        frequency: String,
        instructions: String? = nil,
        prescribedBy: String? = nil,
        notes: String? = nil
    ) -> MedicationModel {
        let medication = MedicationModel(
            name: name,
            dosage: dosage,
            frequency: frequency,
            instructions: instructions,
            prescribedBy: prescribedBy,
            notes: notes
        )
        insert(medication)
        try? save()
        return medication
    }
    
    /// Read all medications
    func fetchAllMedications() -> [MedicationModel] {
        let descriptor = FetchDescriptor<MedicationModel>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Read active medications only
    func fetchActiveMedications() -> [MedicationModel] {
        let descriptor = FetchDescriptor<MedicationModel>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Read medication by ID
    func fetchMedication(id: String) -> MedicationModel? {
        let descriptor = FetchDescriptor<MedicationModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try? fetch(descriptor).first
    }
    
    /// Update medication
    func updateMedication(
        _ medication: MedicationModel,
        dosage: String? = nil,
        frequency: String? = nil,
        instructions: String? = nil,
        isActive: Bool? = nil
    ) {
        if let dosage = dosage {
            medication.dosage = dosage
        }
        if let frequency = frequency {
            medication.frequency = frequency
        }
        if let instructions = instructions {
            medication.instructions = instructions
        }
        if let isActive = isActive {
            medication.isActive = isActive
        }
        try? save()
    }
    
    /// Delete medication
    func deleteMedication(_ medication: MedicationModel) {
        delete(medication)
        try? save()
    }
    
    /// Mark medication as inactive (soft delete)
    func deactivateMedication(_ medication: MedicationModel) {
        medication.isActive = false
        medication.endDate = Date()
        try? save()
    }
    
    // MARK: - Parameter Trends CRUD
    
    /// Create a new parameter trend entry
    func createParameterTrend(
        organ: String,
        parameter: String,
        value: Double,
        unit: String,
        trend: String = "stable",
        comparisonValue: Double? = nil
    ) -> ParameterTrendModel {
        let parameterTrend = ParameterTrendModel(
            organ: organ,
            parameter: parameter,
            value: value,
            unit: unit,
            trend: trend,
            comparisonValue: comparisonValue
        )
        insert(parameterTrend)
        try? save()
        return parameterTrend
    }
    
    /// Read all parameter trends
    func fetchAllParameterTrends() -> [ParameterTrendModel] {
        let descriptor = FetchDescriptor<ParameterTrendModel>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Read trends for specific parameter
    func fetchParameterTrends(for parameter: String) -> [ParameterTrendModel] {
        let descriptor = FetchDescriptor<ParameterTrendModel>(
            predicate: #Predicate { $0.parameter == parameter },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Read trend by ID
    func fetchParameterTrend(id: String) -> ParameterTrendModel? {
        let descriptor = FetchDescriptor<ParameterTrendModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try? fetch(descriptor).first
    }
    
    /// Update parameter trend
    func updateParameterTrend(
        _ trend: ParameterTrendModel,
        value: Double? = nil,
        trendStatus: String? = nil
    ) {
        if let value = value {
            trend.value = value
        }
        if let trendStatus = trendStatus {
            trend.trend = trendStatus
        }
        try? save()
    }
    
    /// Delete parameter trend
    func deleteParameterTrend(_ trend: ParameterTrendModel) {
        delete(trend)
        try? save()
    }
    
    // MARK: - Lab Results CRUD
    
    /// Create a new lab result
    func createLabResult(
        testName: String,
        parameter: String,
        value: Double,
        unit: String,
        normalRange: String,
        status: String,
        category: String
    ) -> LabResultModel {
        let labResult = LabResultModel(
            testName: testName,
            parameter: parameter,
            value: value,
            unit: unit,
            normalRange: normalRange,
            status: status,
            category: category
        )
        insert(labResult)
        try? save()
        return labResult
    }
    
    /// Read all lab results
    func fetchAllLabResults() -> [LabResultModel] {
        let descriptor = FetchDescriptor<LabResultModel>(
            sortBy: [SortDescriptor(\.testDate, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Delete lab result
    func deleteLabResult(_ labResult: LabResultModel) {
        delete(labResult)
        try? save()
    }
}

// MARK: - Medical Reports Extensions

extension ModelContext {
    
    /// Fetch recent reports (last 30 days)
    func fetchRecentReports(days: Int = 30) -> [MedicalReportModel] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<MedicalReportModel>(
            predicate: #Predicate { $0.uploadDate >= cutoffDate },
            sortBy: [SortDescriptor(\.uploadDate, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Filter reports by organ
    func fetchReports(forOrgan organ: String) -> [MedicalReportModel] {
        let descriptor = FetchDescriptor<MedicalReportModel>(
            predicate: #Predicate { $0.organ == organ },
            sortBy: [SortDescriptor(\.uploadDate, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Filter reports by type
    func fetchReports(ofType reportType: String) -> [MedicalReportModel] {
        let descriptor = FetchDescriptor<MedicalReportModel>(
            predicate: #Predicate { $0.reportType == reportType },
            sortBy: [SortDescriptor(\.uploadDate, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Fetch reports sorted by date (ascending or descending)
    func fetchReportsSortedByDate(ascending: Bool = false) -> [MedicalReportModel] {
        let descriptor = FetchDescriptor<MedicalReportModel>(
            sortBy: [SortDescriptor(\.uploadDate, order: ascending ? .forward : .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Fetch reports within date range
    func fetchReports(from startDate: Date, to endDate: Date) -> [MedicalReportModel] {
        let descriptor = FetchDescriptor<MedicalReportModel>(
            predicate: #Predicate { $0.uploadDate >= startDate && $0.uploadDate <= endDate },
            sortBy: [SortDescriptor(\.uploadDate, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Get unique organs from all reports
    func fetchUniqueOrgans() -> [String] {
        let reports = fetchAllReports()
        return Array(Set(reports.map { $0.organ })).sorted()
    }
    
    /// Get unique report types
    func fetchUniqueReportTypes() -> [String] {
        let reports = fetchAllReports()
        return Array(Set(reports.map { $0.reportType })).sorted()
    }
}

// MARK: - Medications Extensions

extension ModelContext {
    
    /// Fetch medications expiring soon (within next 7 days)
    func fetchExpiringSoonMedications(days: Int = 7) -> [MedicationModel] {
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<MedicationModel>(
            predicate: #Predicate { 
                $0.isActive == true && 
                $0.endDate != nil && 
                $0.endDate! <= futureDate 
            },
            sortBy: [SortDescriptor(\.endDate, order: .forward)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Fetch medications by prescriber
    func fetchMedications(prescribedBy doctor: String) -> [MedicationModel] {
        let descriptor = FetchDescriptor<MedicationModel>(
            predicate: #Predicate { $0.prescribedBy == doctor },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Search medications by name
    func searchMedications(name: String) -> [MedicationModel] {
        let descriptor = FetchDescriptor<MedicationModel>(
            predicate: #Predicate { $0.name.localizedStandardContains(name) },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return (try? fetch(descriptor)) ?? []
    }
}

// MARK: - Parameter Trends Extensions

extension ModelContext {
    
    /// Fetch recent trends (last 30 days)
    func fetchRecentParameterTrends(days: Int = 30) -> [ParameterTrendModel] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<ParameterTrendModel>(
            predicate: #Predicate { $0.date >= cutoffDate },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Fetch trends by parameter
    func fetchParameterTrends(parameter: String) -> [ParameterTrendModel] {
        let descriptor = FetchDescriptor<ParameterTrendModel>(
            predicate: #Predicate { $0.parameter == parameter },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Fetch improving trends
    func fetchImprovingTrends() -> [ParameterTrendModel] {
        let descriptor = FetchDescriptor<ParameterTrendModel>(
            predicate: #Predicate { $0.trend == "improving" },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Fetch declining trends
    func fetchDecliningTrends() -> [ParameterTrendModel] {
        let descriptor = FetchDescriptor<ParameterTrendModel>(
            predicate: #Predicate { $0.trend == "declining" },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Get latest trend for specific parameter
    func fetchLatestTrend(for parameter: String) -> ParameterTrendModel? {
        let descriptor = FetchDescriptor<ParameterTrendModel>(
            predicate: #Predicate { $0.parameter == parameter },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try? fetch(descriptor).first
    }
    
    /// Get unique parameters from trends
    func fetchUniqueParametersFromTrends() -> [String] {
        let trends = fetchAllParameterTrends()
        return Array(Set(trends.map { $0.parameter })).sorted()
    }
}

// MARK: - Lab Results Extensions

extension ModelContext {
    
    /// Fetch recent lab results (last 30 days)
    func fetchRecentLabResults(days: Int = 30) -> [LabResultModel] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<LabResultModel>(
            predicate: #Predicate { $0.testDate >= cutoffDate },
            sortBy: [SortDescriptor(\.testDate, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Filter lab results by category
    func fetchLabResults(forCategory category: String) -> [LabResultModel] {
        let descriptor = FetchDescriptor<LabResultModel>(
            predicate: #Predicate { $0.category == category },
            sortBy: [SortDescriptor(\.testDate, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Fetch abnormal lab results
    func fetchAbnormalLabResults() -> [LabResultModel] {
        let descriptor = FetchDescriptor<LabResultModel>(
            predicate: #Predicate { $0.status != "Normal" && $0.status != "Optimal" },
            sortBy: [SortDescriptor(\.testDate, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
    
    /// Search lab results by test name
    func searchLabResults(testName: String) -> [LabResultModel] {
        let descriptor = FetchDescriptor<LabResultModel>(
            predicate: #Predicate { $0.testName.localizedStandardContains(testName) },
            sortBy: [SortDescriptor(\.testDate, order: .reverse)]
        )
        return (try? fetch(descriptor)) ?? []
    }
}

// MARK: - Batch Operations

extension ModelContext {
    
    /// Delete all reports older than specified days
    func deleteOldReports(olderThan days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<MedicalReportModel>(
            predicate: #Predicate { $0.uploadDate < cutoffDate }
        )
        
        if let oldReports = try? fetch(descriptor) {
            for report in oldReports {
                delete(report)
            }
            try? save()
        }
    }
    
    /// Delete all inactive medications
    func deleteInactiveMedications() {
        let descriptor = FetchDescriptor<MedicationModel>(
            predicate: #Predicate { $0.isActive == false }
        )
        
        if let inactiveMeds = try? fetch(descriptor) {
            for med in inactiveMeds {
                delete(med)
            }
            try? save()
        }
    }
    
    /// Clear all medications from the database
    func clearAllMedications() {
        let descriptor = FetchDescriptor<MedicationModel>()
        let allMedications = try? fetch(descriptor)
        allMedications?.forEach { delete($0) }
        try? save()
        print("🗑️ [SwiftDataExtensions] All medications cleared")
    }
    
    /// Get statistics
    func getHealthStatistics() -> HealthStatistics {
        let totalReports = fetchAllReports().count
        let totalLabResults = fetchAllLabResults().count
        let activeMedications = fetchActiveMedications().count
        let abnormalResults = fetchAbnormalLabResults().count
        let recentReports = fetchRecentReports(days: 30).count
        
        return HealthStatistics(
            totalReports: totalReports,
            totalLabResults: totalLabResults,
            activeMedications: activeMedications,
            abnormalResults: abnormalResults,
            recentReports: recentReports
        )
    }
}

// MARK: - Supporting Types

struct HealthStatistics {
    let totalReports: Int
    let totalLabResults: Int
    let activeMedications: Int
    let abnormalResults: Int
    let recentReports: Int
}
