import Foundation
import SwiftData
import SwiftUI

/// Service for generating intelligent summaries and clinical analysis from lab results
public class ReportAnalyzerService {
    
    // MARK: - Analysis Result
    struct AnalysisResult {
        let reportType: String
        let summary: String
        let highlights: [Highlight]
        let parameterCount: Int
        let testDate: Date
        let labResults: [LabResultModel]
        var trendInsights: [String] = [] // New: Trends compared to history
        
        struct Highlight {
            let parameter: String
            let value: Double
            let unit: String
            let status: String
            let severity: MedicalStandardProvider.StandardRange.Severity
            let message: String
        }
        
        /// Generate a rich natural language report summary for the AI-lite experience
        func generateChatbotMessage() -> String {
            var message = "📊 **Medical Insights Dashboard**\n\n"
            message += "**Report Type:** \(reportType)\n"
            message += "**Date:** \(testDate.formatted(date: .abbreviated, time: .omitted))\n"
            message += "**Extracted Results:** \(parameterCount) tests analyzed\n\n"
            
            if !trendInsights.isEmpty {
                message += "📈 **Trends & Progress:**\n"
                for trend in trendInsights {
                    message += "• \(trend)\n"
                }
                message += "\n"
            }
            
            if !highlights.isEmpty {
                message += "🔍 **Key Clinical Findings:**\n"
                
                // Categorize by severity
                let critical = highlights.filter { $0.severity == .critical }
                let abnormal = highlights.filter { $0.severity == .abnormal }
                let borderline = highlights.filter { $0.severity == .borderline }
                
                if !critical.isEmpty {
                    message += "\n🔴 **CRITICAL (Action Recommended):**\n"
                    for item in critical {
                        message += "• **\(item.parameter)**: \(String(format: "%.1f", item.value))\(item.unit) (\(item.status))\n  _\(item.message)_\n"
                    }
                }
                
                if !abnormal.isEmpty {
                    message += "\n⚠️ **ABNORMAL:**\n"
                    for item in abnormal {
                        message += "• **\(item.parameter)**: \(String(format: "%.1f", item.value))\(item.unit) (\(item.status))\n  _\(item.message)_\n"
                    }
                }
                
                if !borderline.isEmpty {
                    message += "\n⚡ **BORDERLINE:**\n"
                    for item in borderline {
                        message += "• \(item.parameter): \(String(format: "%.1f", item.value))\(item.unit) - \(item.message)\n"
                    }
                }
                
                let normalCount = parameterCount - (critical.count + abnormal.count + borderline.count)
                if normalCount > 0 {
                    message += "\n✅ **\(normalCount) Parameters are within normal ranges.**\n"
                }
            } else if parameterCount > 0 {
                message += "✅ **Excellent News:** All extracted results are within the normal reference ranges for your profile.\n"
            } else {
                message += "⚠️ **No quantifiable data found.** The scanner didn't pick up specific lab values from this document format.\n"
            }
            
            message += "\n--- \n*Disclaimer: This is an automated offline analysis. Always consult your healthcare provider for medical decisions.*"
            
            return message
        }
    }
    
    private let standardProvider: MedicalStandardProvider
    
    init(userProfile: UserProfileModel) {
        self.standardProvider = MedicalStandardProvider(userProfile: userProfile)
    }
    
    // MARK: - Analysis Methods
    
    /// Analyze a medical report from OCR text with optional historical context
    func analyzeReport(ocrText: String, testDate: Date = Date(), history: [LabResultModel] = []) -> AnalysisResult {
        // Step 1: Parse lab results using the upgraded parser
        var labResults = MedicalDataParser.parseLabResults(from: ocrText)
        
        // Step 1.5: Universal Fallback Extraction (Catch-all for unknown parameters)
        let universalResults = MedicalDataParser.parseUniversalLabResults(from: ocrText, existingResults: labResults)
        labResults.append(contentsOf: universalResults)
        
        // Step 2: Detect report type
        let reportType = MedicalDataParser.detectReportType(from: ocrText)
        
        // Step 3: Analyze each result against standards
        var highlights: [AnalysisResult.Highlight] = []
        
        for result in labResults {
            if let standard = standardProvider.getStandard(for: result.testName) {
                let assessment = standard.assess(value: result.value)
                
                let message = generateMessage(
                    parameter: result.testName,
                    value: result.value,
                    unit: result.unit,
                    status: assessment.status,
                    standard: standard
                )
                
                let highlight = AnalysisResult.Highlight(
                    parameter: result.testName,
                    value: result.value,
                    unit: result.unit,
                    status: assessment.status,
                    severity: assessment.severity,
                    message: message
                )
                
                if assessment.severity != .normal {
                    highlights.append(highlight)
                }
            }
        }
        
        // Step 4: Compare with history (Trends)
        let trendInsights = compareWithHistory(currentResults: labResults, history: history)
        
        // Step 5: Perform Correlative Analysis (New)
        let clinicalInsights = performCorrelativeAnalysis(results: labResults)
        
        // Step 6: Generate quick summary
        let summary = generateSummary(
            reportType: reportType,
            labResults: labResults,
            highlights: highlights,
            trends: trendInsights
        )
        
        var result = AnalysisResult(
            reportType: reportType,
            summary: summary,
            highlights: highlights,
            parameterCount: labResults.count,
            testDate: testDate,
            labResults: labResults
        )
        result.trendInsights = trendInsights + clinicalInsights
        
        return result
    }
    
    /// Detect patterns involving multiple markers
    private func performCorrelativeAnalysis(results: [LabResultModel]) -> [String] {
        var insights: [String] = []
        let patterns = standardProvider.clinicalPatterns
        
        for pattern in patterns {
            // Check if all markers for this pattern were found and are abnormal
            var markersFoundAndAbnormal = 0
            
            for markerName in pattern.markers {
                let match = results.first { $0.testName.lowercased().contains(markerName.lowercased()) }
                if let m = match {
                    // Check if it's outside normal range
                    if m.status.lowercased() != "normal" {
                        markersFoundAndAbnormal += 1
                    }
                }
            }
            
            // If all required markers for a pattern are abnormal, trigger the insight
            if markersFoundAndAbnormal == pattern.markers.count && markersFoundAndAbnormal > 0 {
                let emoji = pattern.alertLevel == .critical ? "🚨" : "🔍"
                insights.append("\(emoji) **\(pattern.name) Detected**: \(pattern.condition)")
            }
        }
        
        return insights
    }
    
    /// Compare current results with historical data directly
    private func compareWithHistory(currentResults: [LabResultModel], history: [LabResultModel]) -> [String] {
        var insights: [String] = []
        
        for current in currentResults {
            // Find the most recent previous result for this parameter
            let previous = history
                .filter { $0.testName.lowercased() == current.testName.lowercased() && $0.testDate < current.testDate }
                .sorted(by: { $0.testDate > $1.testDate })
                .first
            
            if let last = previous {
                let change = current.value - last.value
                let percentChange = (change / last.value) * 100
                
                if abs(percentChange) >= 5 { // Report changes of 5% or more
                    let direction = change > 0 ? "increased" : "decreased"
                    let statusEmoji = (change > 0 && current.status == "High") || (change < 0 && current.status == "Low") ? "⚠️" : "📉"
                    
                    let insight = "\(statusEmoji) Your **\(current.testName)** has \(direction) by \(String(format: "%.1f", abs(percentChange)))% since your last test."
                    insights.append(insight)
                }
            }
        }
        
        return insights
    }
    
    // MARK: - Helper Methods
    
    private func generateMessage(
        parameter: String,
        value: Double,
        unit: String,
        status: String,
        standard: MedicalStandardProvider.StandardRange
    ) -> String {
        let normalRange = "\(String(format: "%.1f", standard.min))-\(String(format: "%.1f", standard.max)) \(standard.unit)"
        
        switch status {
        case "Critically Low":
            return "Extreme low detected. Range: \(normalRange). Consult emergency care if symptomatic."
        case "Critically High":
            return "Extreme high detected. Range: \(normalRange). Consult emergency care if symptomatic."
        case "Low":
            return "Below normal range (\(normalRange))."
        case "High":
            return "Above normal range (\(normalRange))."
        default:
            return "Within normal range (\(normalRange))."
        }
    }
    
    private func generateSummary(
        reportType: String,
        labResults: [LabResultModel],
        highlights: [AnalysisResult.Highlight],
        trends: [String]
    ) -> String {
        var summary = "Scan found \(labResults.count) parameters in this \(reportType). "
        if !highlights.isEmpty {
            summary += "\(highlights.filter({$0.severity != .normal}).count) results outside normal range. "
        }
        if !trends.isEmpty {
            summary += "Significant changes detected since last report."
        }
        return summary
    }
}

