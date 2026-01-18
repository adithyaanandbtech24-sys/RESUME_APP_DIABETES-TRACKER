import Foundation
import SwiftData
import Combine

/// A "Lite" Graph RAG engine that treats SwiftData models as nodes and their relationships as edges.
/// It performs keyword-based retrieval and traverses relationships to build a rich context for the AI.
@MainActor
final class GraphRAGEngine {
    static let shared = GraphRAGEngine()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Retrieves relevant medical context based on the user's query.
    /// - Parameters:
    ///   - query: The user's chat message.
    ///   - context: The SwiftData ModelContext to search within.
    /// - Returns: A formatted string containing relevant medical facts.
    func retrieveContext(for query: String, context: ModelContext) -> String {
        let keywords = extractKeywords(from: query)
        
        var contextParts: [String] = []
        
        // ALWAYS include user profile first
        if let profile = try? context.fetch(FetchDescriptor<UserProfileModel>()).first {
            contextParts.append("--- USER PROFILE ---")
            contextParts.append("Name: \(profile.name), Age: \(profile.age), Gender: \(profile.gender)")
            if let height = profile.height { contextParts.append("Height: \(height) cm") }
            if let weight = profile.weight { contextParts.append("Weight: \(weight) kg") }
        }
        
        // ALWAYS include all report summaries with dates
        if let allReports = try? context.fetch(FetchDescriptor<MedicalReportModel>(sortBy: [SortDescriptor(\.uploadDate, order: .reverse)])) {
            if !allReports.isEmpty {
                contextParts.append("\n--- ALL UPLOAD HISTORY (\(allReports.count) reports) ---")
                for report in allReports {
                    contextParts.append("• \(formatDate(report.uploadDate)): \(report.title) (\(report.reportType))")
                }
            }
        }
        
        // Keyword-based search for relevant data
        if !keywords.isEmpty {
            // 1. Search Nodes (Keyword Match)
            let relevantLabs = findRelevantLabs(keywords: keywords, context: context)
            let relevantMeds = findRelevantMeds(keywords: keywords, context: context)
            let relevantReports = findRelevantReports(keywords: keywords, context: context)
            
            // 2. Labs Context
            if !relevantLabs.isEmpty {
                contextParts.append("\n--- RELEVANT LAB RESULTS ---")
                for lab in relevantLabs {
                    var entry = "- \(lab.testName): \(lab.value) \(lab.unit) (\(lab.status)) on \(formatDate(lab.testDate))"
                    entry += ". Normal Range: \(lab.normalRange)."
                    contextParts.append(entry)
                }
            }
            
            // 3. Medications Context
            if !relevantMeds.isEmpty {
                contextParts.append("\n--- RELEVANT MEDICATIONS ---")
                for med in relevantMeds {
                    var entry = "- \(med.name): \(med.dosage), \(med.frequency)."
                    if let instructions = med.instructions {
                        entry += " Instructions: \(instructions)."
                    }
                    if med.isActive {
                        entry += " (Active)"
                    } else {
                        entry += " (Past medication, ended \(formatDate(med.endDate ?? Date())))"
                    }
                    contextParts.append(entry)
                }
            }
            
            // 4. Reports Context with detailed insights
            if !relevantReports.isEmpty {
                contextParts.append("\n--- RELEVANT REPORTS ---")
                for report in relevantReports {
                    var entry = "- Report: \(report.title) (uploaded \(formatDate(report.uploadDate)))"
                    if !report.aiInsights.isEmpty {
                        entry += "\n  Summary: \(report.aiInsights)"
                    }
                    if let labs = report.labResults, !labs.isEmpty {
                        let labNames = labs.map { $0.testName }.joined(separator: ", ")
                        entry += "\n  Contains labs: \(labNames)"
                    }
                    contextParts.append(entry)
                }
            }
        }
        
        if contextParts.isEmpty {
            return ""
        }
        
        return """
        CONTEXT FROM MEDICAL RECORDS:
        \(contextParts.joined(separator: "\n"))
        
        INSTRUCTIONS: Use the above context to answer the user's question accurately. Cite specific dates and values where possible. You have access to ALL their upload history.
        """
    }
    
    // MARK: - Helper Methods
    
    private func extractKeywords(from query: String) -> [String] {
        // Simple stop-word removal and tokenization
        let stopWords: Set<String> = ["the", "is", "at", "which", "on", "a", "an", "and", "or", "but", "in", "with", "to", "of", "my", "me", "i", "what", "how", "when", "where", "does", "do", "did", "can", "could", "should", "would"]
        
        let words = query.lowercased().components(separatedBy: .punctuationCharacters).joined().components(separatedBy: .whitespaces)
        return words.filter { !stopWords.contains($0) && $0.count > 2 }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // MARK: - Search Methods
    
    private func findRelevantLabs(keywords: [String], context: ModelContext) -> [LabResultModel] {
        // Fetch all labs (inefficient for huge datasets, but fine for local device)
        // SwiftData predicates with dynamic arrays are tricky, so we filter in memory for this "Lite" version.
        guard let allLabs = try? context.fetch(FetchDescriptor<LabResultModel>()) else { return [] }
        
        return allLabs.filter { lab in
            let content = "\(lab.testName) \(lab.parameter) \(lab.category)".lowercased()
            return keywords.contains { content.contains($0) }
        }
    }
    
    private func findRelevantMeds(keywords: [String], context: ModelContext) -> [MedicationModel] {
        guard let allMeds = try? context.fetch(FetchDescriptor<MedicationModel>()) else { return [] }
        
        return allMeds.filter { med in
            let content = "\(med.name) \(med.notes ?? "") \(med.prescribedBy ?? "")".lowercased()
            return keywords.contains { content.contains($0) }
        }
    }
    
    private func findRelevantReports(keywords: [String], context: ModelContext) -> [MedicalReportModel] {
        guard let allReports = try? context.fetch(FetchDescriptor<MedicalReportModel>()) else { return [] }
        
        return allReports.filter { report in
            let content = "\(report.title) \(report.organ) \(report.reportType) \(report.aiInsights)".lowercased()
            return keywords.contains { content.contains($0) }
        }
    }
}
