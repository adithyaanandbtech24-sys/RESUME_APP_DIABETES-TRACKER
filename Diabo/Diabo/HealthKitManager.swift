// HealthKitManager.swift
import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var errorMessage: String?
    
    private init() {}
    
    // MARK: - Permissions
    
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device."
            return
        }
        
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            errorMessage = "Failed to request HealthKit authorization: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Data Fetching
    
    func fetchHealthData(days: Int = 7) async -> [HealthMetricEntry] {
        guard isAuthorized else { return [] }
        
        var metrics: [HealthMetricEntry] = []
        
        // Fetch all metrics concurrently
        async let heartRates = fetchHeartRate(days: days)
        async let steps = fetchSteps(days: days)
        async let oxygen = fetchOxygenSaturation(days: days)
        async let sleep = fetchSleepAnalysis(days: days)
        
        let (hrData, stepData, oxygenData, sleepData) = await (heartRates, steps, oxygen, sleep)
        
        metrics.append(contentsOf: hrData)
        metrics.append(contentsOf: stepData)
        metrics.append(contentsOf: oxygenData)
        metrics.append(contentsOf: sleepData)
        
        return metrics.sorted { $0.date > $1.date }
    }
    
    // MARK: - Individual Fetch Methods
    
    private func fetchHeartRate(days: Int) async -> [HealthMetricEntry] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return [] }
        return await fetchQuantitySamples(type: type, days: days, unit: HKUnit.count().unitDivided(by: .minute()), typeName: "Heart Rate")
    }
    
    private func fetchSteps(days: Int) async -> [HealthMetricEntry] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        // Steps are cumulative, so we might want statistics, but for timeline, samples are okay or daily totals
        // Let's get daily totals for steps
        return await fetchDailyStatistics(type: type, days: days, unit: .count(), typeName: "Steps")
    }
    
    private func fetchOxygenSaturation(days: Int) async -> [HealthMetricEntry] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else { return [] }
        return await fetchQuantitySamples(type: type, days: days, unit: .percent(), typeName: "Oxygen Saturation", multiplier: 100)
    }
    
    private func fetchSleepAnalysis(days: Int) async -> [HealthMetricEntry] {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        
        let predicate = createPredicate(days: days)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                guard let samples = samples as? [HKCategorySample], error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                
                let entries = samples.compactMap { sample -> HealthMetricEntry? in
                    // Filter for asleep samples
                    // Note: 'asleep' was deprecated in iOS 16.0, replaced by 'asleepUnspecified'
                    // We check for all sleep states to be safe
                    guard sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                          sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                          sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                          sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue else {
                        return nil
                    }
                    
                    let durationHours = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
                    
                    return HealthMetricEntry(
                        date: sample.startDate,
                        type: "Sleep",
                        value: durationHours,
                        unit: "hours",
                        source: "HealthKit"
                    )
                }
                
                continuation.resume(returning: entries)
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchQuantitySamples(type: HKQuantityType, days: Int, unit: HKUnit, typeName: String, multiplier: Double = 1.0) async -> [HealthMetricEntry] {
        let predicate = createPredicate(days: days)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                
                let entries = samples.map { sample in
                    HealthMetricEntry(
                        date: sample.startDate,
                        type: typeName,
                        value: sample.quantity.doubleValue(for: unit) * multiplier,
                        unit: unit.unitString,
                        source: "HealthKit"
                    )
                }
                
                continuation.resume(returning: entries)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchDailyStatistics(type: HKQuantityType, days: Int, unit: HKUnit, typeName: String) async -> [HealthMetricEntry] {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else { return [] }
        
        var interval = DateComponents()
        interval.day = 1
        
        let anchorDate = calendar.startOfDay(for: endDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: anchorDate,
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, results, error in
                guard let results = results, error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                
                var entries: [HealthMetricEntry] = []
                
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    if let quantity = statistics.sumQuantity() {
                        let value = quantity.doubleValue(for: unit)
                        let entry = HealthMetricEntry(
                            date: statistics.startDate,
                            type: typeName,
                            value: value,
                            unit: unit.unitString,
                            source: "HealthKit"
                        )
                        entries.append(entry)
                    }
                }
                
                continuation.resume(returning: entries)
            }
            
            healthStore.execute(query)
        }
    }
    
    private func createPredicate(days: Int) -> NSPredicate {
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: now)
        return HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
    }
}

// MARK: - Health Metric Entry Model (Non-persisted for now, or mapped to SwiftData)
struct HealthMetricEntry: Identifiable {
    let id = UUID()
    let date: Date
    let type: String
    let value: Double
    let unit: String
    let source: String
}
