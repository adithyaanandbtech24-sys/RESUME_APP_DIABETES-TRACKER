import SwiftUI
import SwiftData
import Charts

// MARK: - Comprehensive Organ Health Detail View
/// Displays ALL lab results organized by organ system with proper tables,
/// status indicators, and summary sections - matching clinical lab report format

struct OrganHealthDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LabResultModel.testDate, order: .reverse) private var labResults: [LabResultModel]
    @Query(sort: \MedicalReportModel.uploadDate, order: .reverse) private var reports: [MedicalReportModel]
    
    @State private var expandedOrgans: Set<String> = []
    @State private var showUploadSheet = false
    
    // MARK: - Organ System Definitions
    private let organSystems: [(name: String, icon: String, color: Color, keywords: [String])] = [
        ("LIVER", "cross.case.fill", Color(red: 1.0, green: 0.6, blue: 0.3), 
         ["bilirubin", "ast", "alt", "sgpt", "sgot", "alkaline phosphatase", "alp", "ggt", "gamma", 
          "albumin", "globulin", "a/g ratio", "protein", "liver"]),
        
        ("PANCREAS", "staroflife.fill", Color(red: 0.4, green: 0.7, blue: 0.5),
         ["amylase", "lipase", "insulin", "pancreas", "pancreatic"]),
        
        ("KIDNEYS", "drop.fill", Color(red: 0.5, green: 0.4, blue: 0.9),
         ["urea", "creatinine", "bun", "egfr", "gfr", "uric acid", "sodium", "potassium", 
          "chloride", "calcium", "phosphorus", "magnesium", "electrolyte", "renal", "kidney"]),
        
        ("HEART", "heart.fill", Color(red: 1.0, green: 0.4, blue: 0.5),
         ["cholesterol", "triglyceride", "hdl", "ldl", "vldl", "lipoprotein", "apo", "crp", 
          "hs-crp", "c-reactive", "lipid", "cardiovascular", "cardiac", "heart"]),
        
        ("BLOOD", "drop.triangle.fill", Color(red: 0.9, green: 0.3, blue: 0.3),
         ["hemoglobin", "rbc", "wbc", "platelet", "hematocrit", "mcv", "mch", "mchc", "rdw", 
          "neutrophil", "lymphocyte", "monocyte", "eosinophil", "basophil", "anc", "alc", "nlr",
          "mentzer", "sehgal", "hematology", "cbc", "blood", "esr", "mpv", "pdw"]),
        
        ("THYROID", "waveform.path.ecg", Color(red: 0.6, green: 0.4, blue: 0.8),
         ["tsh", "t3", "t4", "thyroxine", "thyroid", "ft3", "ft4"]),
        
        ("METABOLIC", "flame.fill", Color(red: 1.0, green: 0.5, blue: 0.2),
         ["glucose", "hba1c", "a1c", "glycated", "fasting sugar", "blood sugar", "diabetes", "metabolic"]),
        
        ("IRON STORES", "bolt.fill", Color(red: 0.7, green: 0.5, blue: 0.3),
         ["iron", "ferritin", "tibc", "transferrin", "iron binding"]),
        
        ("VITAMINS", "pills.fill", Color(red: 0.3, green: 0.7, blue: 0.9),
         ["vitamin", "b12", "d3", "folate", "folic"]),
        
        ("URINALYSIS", "testtube.2", Color(red: 0.9, green: 0.7, blue: 0.2),
         ["urine", "pus cell", "epithelial", "specific gravity", "ph", "ketone", "urobilinogen",
          "nitrite", "leucocyte", "cast", "crystal", "bacteria", "yeast", "mucus"])
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection
                
                if reports.isEmpty {
                    emptyStateView
                } else {
                    // Organ Cards
                    ForEach(organSystems, id: \.name) { organ in
                        let organLabs = getLabsForOrgan(organ.keywords)
                        if !organLabs.isEmpty {
                            OrganHealthCard(
                                organName: organ.name,
                                icon: organ.icon,
                                iconColor: organ.color,
                                labResults: organLabs,
                                isExpanded: expandedOrgans.contains(organ.name),
                                onToggle: {
                                    withAnimation(.spring(response: 0.3)) {
                                        if expandedOrgans.contains(organ.name) {
                                            expandedOrgans.remove(organ.name)
                                        } else {
                                            expandedOrgans.insert(organ.name)
                                        }
                                    }
                                }
                            )
                        }
                    }
                    
                    // Final Summary Section
                    finalSummarySection
                }
            }
            .padding(.bottom, 100)
        }
        .background(Color(red: 0.98, green: 0.98, blue: 0.99))
        .sheet(isPresented: $showUploadSheet) {
            UploadDocumentView(onUploadSuccess: {})
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Health Timeline")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Multi-Organ System Analysis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Latest Report Badge
                if let latestReport = reports.first {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 12))
                        let dateFormatter = DateFormatter()
                        let _ = dateFormatter.dateFormat = "d MMM yyyy"
                        Text(dateFormatter.string(from: latestReport.uploadDate))
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.medicalPurpleLight.opacity(0.1))
                    .foregroundColor(Color.vibrantPurple)
                    .clipShape(Capsule())
                }
            }
            
            Text("A comprehensive assessment of your physiological clinical parameters, auto-triaged by organ system for medical clarity.")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.8))
                .lineSpacing(4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "chart.xyaxis.line",
            title: "No Health Trends Yet",
            message: "Upload medical reports to see your comprehensive health analysis organized by organ system",
            buttonTitle: "Upload First Report",
            action: { showUploadSheet = true }
        )
        .padding(.top, 40)
        .padding(.horizontal)
    }
    
    // MARK: - Final Summary Section
    private var finalSummarySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.vibrantPurple.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.vibrantPurple)
                }
                
                Text("ORGAN FUNCTION SUMMARY")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color.vibrantPurple)
                    .tracking(1)
            }
            .padding(.horizontal, 8)
            
            VStack(spacing: 0) {
                ForEach(organSystems.indices, id: \.self) { index in
                    let organ = organSystems[index]
                    let organLabs = getLabsForOrgan(organ.keywords)
                    if !organLabs.isEmpty {
                        let status = calculateOrganStatus(organLabs)
                        
                        HStack {
                            HStack(spacing: 12) {
                                Image(systemName: organ.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(organ.color)
                                    .frame(width: 20)
                                
                                Text(organ.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            StatusBadge(text: status.text, level: status.level)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        
                        if index < organSystems.count - 1 {
                            Divider()
                                .background(Color.gray.opacity(0.1))
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.03), radius: 15, x: 0, y: 5)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }
    
    // MARK: - Helper Functions
    private func getLabsForOrgan(_ keywords: [String]) -> [LabResultModel] {
        let matchingLabs = labResults.filter { result in
            let testNameLower = result.testName.lowercased()
            let categoryLower = result.category.lowercased()
            return keywords.contains { keyword in
                testNameLower.contains(keyword) || categoryLower.contains(keyword)
            }
        }
        
        // Deduplicate: Keep only unique combinations of testName + value + testDate
        var seen = Set<String>()
        return matchingLabs.filter { result in
            let calendar = Calendar.current
            let dateKey = calendar.startOfDay(for: result.testDate)
            let key = "\(result.testName.lowercased())-\(result.value)-\(dateKey.timeIntervalSince1970)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }
    
    private func calculateOrganStatus(_ labs: [LabResultModel]) -> (text: String, color: Color, level: StatusLevel) {
        var hasAbnormal = false
        var hasBorderline = false
        
        for lab in labs {
            let status = lab.status.lowercased()
            if status.contains("high") || status.contains("low") || status.contains("abnormal") || status.contains("critical") {
                hasAbnormal = true
            } else if status.contains("borderline") || status.contains("slightly") {
                hasBorderline = true
            }
        }
        
        if hasAbnormal {
            return ("Abnormal", Color(red: 0.9, green: 0.3, blue: 0.3), .abnormal)
        } else if hasBorderline {
            return ("Borderline", Color.orange, .borderline)
        } else {
            return ("Normal", Color(red: 0.3, green: 0.7, blue: 0.4), .normal)
        }
    }
}

enum StatusLevel {
    case normal
    case borderline
    case abnormal
}

// MARK: - Professional Status Badge
struct StatusBadge: View {
    let text: String
    let level: StatusLevel
    
    private var colors: (bg: Color, text: Color) {
        switch level {
        case .normal:
            return (Color(red: 0.3, green: 0.7, blue: 0.4).opacity(0.12), Color(red: 0.2, green: 0.6, blue: 0.3))
        case .borderline:
            return (Color.orange.opacity(0.12), Color.orange)
        case .abnormal:
            return (Color(red: 0.9, green: 0.3, blue: 0.3).opacity(0.12), Color(red: 0.8, green: 0.2, blue: 0.2))
        }
    }
    
    private var dotColor: Color {
        switch level {
        case .normal: return Color(red: 0.3, green: 0.7, blue: 0.4)
        case .borderline: return Color.orange
        case .abnormal: return Color(red: 0.9, green: 0.3, blue: 0.3)
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            
            Text(text.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(colors.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(colors.bg)
        .clipShape(Capsule())
    }
}

// MARK: - Premium Icon Box
struct IconBox: View {
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.1))
                .frame(width: 44, height: 44)
            
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
        }
    }
}

// MARK: - Organ Health Card Component
struct OrganHealthCard: View {
    let organName: String
    let icon: String
    let iconColor: Color
    let labResults: [LabResultModel]
    let isExpanded: Bool
    let onToggle: () -> Void
    
    // State for per-parameter graph popup
    @State private var selectedParameter: String? = nil
    @State private var showParameterGraph: Bool = false
    
    // Group results by test date with deduplication
    private var groupedByDate: [(date: Date, results: [LabResultModel])] {
        let sorted = labResults.sorted { $0.testDate > $1.testDate }
        var groups: [Date: [LabResultModel]] = [:]
        
        let calendar = Calendar.current
        for result in sorted {
            let dayStart = calendar.startOfDay(for: result.testDate)
            groups[dayStart, default: []].append(result)
        }
        
        // Deduplicate within each date group
        var deduplicatedGroups: [(date: Date, results: [LabResultModel])] = []
        for (date, results) in groups {
            var seen = Set<String>()
            let uniqueResults = results.filter { result in
                let key = "\(result.testName.lowercased())-\(result.value)"
                if seen.contains(key) {
                    return false
                }
                seen.insert(key)
                return true
            }
            deduplicatedGroups.append((date: date, results: uniqueResults))
        }
        
        return deduplicatedGroups.sorted { $0.date > $1.date }
    }
    
    private var organStatus: (text: String, color: Color, level: StatusLevel) {
        var hasAbnormal = false
        var hasBorderline = false
        
        for lab in labResults {
            let status = lab.status.lowercased()
            if status.contains("high") || status.contains("low") || status.contains("abnormal") || status.contains("critical") {
                hasAbnormal = true
            } else if status.contains("borderline") || status.contains("slightly") {
                hasBorderline = true
            }
        }
        
        if hasAbnormal {
            return ("Abnormal", Color(red: 0.9, green: 0.3, blue: 0.3), .abnormal)
        } else if hasBorderline {
            return ("Borderline", Color.orange, .borderline)
        } else {
            return ("Normal", Color(red: 0.3, green: 0.7, blue: 0.4), .normal)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (Always Visible)
            Button(action: onToggle) {
                HStack(spacing: 16) {
                    IconBox(icon: icon, color: iconColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(organName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Text("\(labResults.count)")
                                .fontWeight(.bold)
                            Text("parameters analyzed")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        StatusBadge(text: organStatus.text, level: organStatus.level)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray.opacity(0.5))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .padding(20)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded Content
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 16) {
                    // Table Header
                    HStack {
                        Text("Test")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Result")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(width: 70, alignment: .trailing)
                        Text("Range")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(width: 70, alignment: .trailing)
                        Text("Status")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Results grouped by date
                    ForEach(groupedByDate, id: \.date) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            // Date Header
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11))
                                    .foregroundColor(iconColor)
                                Text(formatDate(group.date))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(iconColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            
                            // Lab Results Table - Clickable for graph
                            ForEach(group.results, id: \.id) { result in
                                Button(action: {
                                    selectedParameter = result.testName
                                    showParameterGraph = true
                                }) {
                                    DetailLabResultRow(result: result, accentColor: iconColor)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Organ Status Summary
                    organSummaryView
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
        .sheet(isPresented: $showParameterGraph) {
            if let paramName = selectedParameter {
                ParameterGraphSheet(
                    parameterName: paramName,
                    labResults: labResults.filter { $0.testName == paramName },
                    accentColor: iconColor
                )
            }
        }
    }
    
    // MARK: - Organ Summary
    private var organSummaryView: some View {
        let abnormalCount = labResults.filter { 
            let s = $0.status.lowercased()
            return s.contains("high") || s.contains("low") || s.contains("abnormal")
        }.count
        
        
        
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(organStatus.color.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(organStatus.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(organName) CLINICAL STATUS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(0.5)
                
                HStack(spacing: 6) {
                    if abnormalCount > 0 {
                        Text("\(abnormalCount) parameters outside reference range")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(organStatus.color)
                    } else {
                        Text("All physiological parameters within normal limits")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.3, green: 0.7, blue: 0.4))
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Color.gray.opacity(0.03))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(organStatus.color.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Lab Result Row Component
struct DetailLabResultRow: View {
    let result: LabResultModel
    let accentColor: Color
    
    private var statusInfo: (text: String, color: Color) {
        let status = result.status.lowercased()
        if status.contains("high") || status.contains("critical") {
            return ("High", Color(red: 0.8, green: 0.2, blue: 0.2))
        } else if status.contains("low") {
            return ("Low", Color(red: 0.9, green: 0.5, blue: 0.2))
        } else if status.contains("borderline") || status.contains("slightly") {
            return ("Borderline", Color.orange)
        } else if status.contains("trace") || status.contains("present") {
            return ("Warning", Color.orange)
        } else {
            return ("Normal", Color(red: 0.3, green: 0.7, blue: 0.4))
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Test Name
            VStack(alignment: .leading, spacing: 2) {
                Text(result.testName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if !result.category.isEmpty {
                    Text(result.category.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray.opacity(0.6))
                        .tracking(0.5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Result Value
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatValue(result.value, unit: result.unit))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(statusInfo.color)
                
                Text(result.unit)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .frame(width: 80, alignment: .trailing)
            
            // Reference Range
            Text(result.normalRange)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray.opacity(0.8))
                .lineLimit(1)
                .frame(width: 90, alignment: .trailing)
            
            // Status Dot
            ZStack {
                Circle()
                    .fill(statusInfo.color.opacity(0.15))
                    .frame(width: 24, height: 24)
                
                Circle()
                    .fill(statusInfo.color)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusInfo.color.opacity(0.3), radius: 2)
            }
            .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(statusInfo.color == Color(red: 0.3, green: 0.7, blue: 0.4) ? Color.clear : statusInfo.color.opacity(0.03))
    }
    
    private func formatValue(_ value: Double, unit: String) -> String {
        // Format based on value magnitude
        if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Organ Timeline Graph Component
struct OrganTimelineGraph: View {
    let labResults: [LabResultModel]
    let accentColor: Color
    
    // Group results by Unit first, then by Test Name
    // This ensures we never plot mg/dL and U/L on the same axis
    private var groupedByUnit: [(unit: String, parameters: [(name: String, color: Color, results: [LabResultModel])])] {
        let textUnits = Set(labResults.map { $0.unit })
        // Sort units to keep "mg/dL" or common ones first if needed, else alphabetical
        let sortedUnits = textUnits.sorted()
        
        var unitGroups: [(unit: String, parameters: [(name: String, color: Color, results: [LabResultModel])])] = []
        
        for unit in sortedUnits {
            // Get all results for this unit
            let unitResults = labResults.filter { $0.unit == unit }
            
            // Now group these by test name
            let uniqueNames = Array(Set(unitResults.map { $0.testName })).sorted()
            
            var parameters: [(name: String, color: Color, results: [LabResultModel])] = []
            
            for (index, name) in uniqueNames.enumerated() {
                // Generate a consistent color based on the hash of the name to keep it stable across views
                let color = generateColor(for: name, index: index)
                let paramResults = unitResults.filter { $0.testName == name }.sorted { $0.testDate < $1.testDate }
                parameters.append((name: name, color: color, results: paramResults))
            }
            
            unitGroups.append((unit: unit, parameters: parameters))
        }
        
        return unitGroups
    }
    
    private func generateColor(for string: String, index: Int) -> Color {
        // Simple distinct palette
        let palette: [Color] = [
            Color(red: 0.5, green: 0.4, blue: 0.9), // Purple
            Color(red: 0.2, green: 0.7, blue: 0.5), // Green
            Color(red: 0.9, green: 0.5, blue: 0.3), // Orange
            Color(red: 0.3, green: 0.6, blue: 0.9), // Blue
            Color(red: 0.9, green: 0.3, blue: 0.5), // Pink
            Color(red: 0.4, green: 0.8, blue: 0.8), // Teal
            Color(red: 0.8, green: 0.8, blue: 0.2), // Yellow-Lime
            Color(red: 0.6, green: 0.4, blue: 0.2)  // Brown
        ]
        return palette[index % palette.count]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !labResults.isEmpty {
                // Create a separate chart for each Unit group
                ForEach(groupedByUnit, id: \.unit) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        // Title for this unit section
                        HStack {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 12))
                                .foregroundColor(accentColor)
                            Text("Trends (\(group.unit))")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(accentColor)
                            Spacer()
                        }
                        
                        Chart {
                            ForEach(group.parameters, id: \.name) { param in
                                ForEach(param.results, id: \.id) { result in
                                    LineMark(
                                        x: .value("Date", result.testDate),
                                        y: .value("Value", result.value)
                                    )
                                    .foregroundStyle(by: .value("Parameter", param.name))
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                    
                                    PointMark(
                                        x: .value("Date", result.testDate),
                                        y: .value("Value", result.value)
                                    )
                                    .foregroundStyle(by: .value("Parameter", param.name))
                                    .symbolSize(30)
                                }
                            }
                        }
                        .chartForegroundStyleScale(
                            domain: group.parameters.map { $0.name },
                            range: group.parameters.map { $0.color }
                        )
                        .chartXAxis {
                            AxisMarks(values: .automatic) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartLegend(position: .bottom, spacing: 10)
                        .frame(height: 180)
                        .padding(.vertical, 8)
                    }
                }
            } else {
                Text("Not enough data points to display graph")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(height: 100)
            }
        }
        .padding(16)
        .background(Color(red: 0.98, green: 0.98, blue: 0.99))
        .cornerRadius(12)
    }
}

// MARK: - Parameter Graph Sheet (Single Parameter Trend)
struct ParameterGraphSheet: View {
    let parameterName: String
    let labResults: [LabResultModel]
    let accentColor: Color
    @Environment(\.dismiss) private var dismiss
    
    private var sortedResults: [LabResultModel] {
        labResults.sorted { $0.testDate < $1.testDate }
    }
    
    // Parse normal range from the latest result for reference
    private var referenceRange: RangeParser.RangeBounds {
        // Prefer the most recent range if available, as lab standards can change
        // or the user might have different tests over time.
        if let latest = sortedResults.last, !latest.normalRange.isEmpty {
            return RangeParser.parse(latest.normalRange)
        }
        return RangeParser.RangeBounds(min: nil, max: nil)
    }
    
    private var yAxisDomain: ClosedRange<Double>? {
        guard !sortedResults.isEmpty else { return nil }
        
        let values = sortedResults.map { $0.value }
        var minVal = values.min() ?? 0
        var maxVal = values.max() ?? 100
        
        // Include reference range in domain
        if let refMin = referenceRange.min {
            minVal = min(minVal, refMin)
        }
        if let refMax = referenceRange.max {
            maxVal = max(maxVal, refMax)
        }
        
        // Add minimal padding (10%)
        let range = maxVal - minVal
        let padding = range * 0.1
        
        // Ensure no division by zero or negative domains if only one point
        if range == 0 {
             return (minVal * 0.9)...(maxVal * 1.1)
        }
        
        return (max(0, minVal - padding))...(maxVal + padding)
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with latest value big display
                VStack(alignment: .leading, spacing: 8) {
                    Text(parameterName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let latest = sortedResults.last {
                        HStack(alignment: .firstTextBaseline) {
                            Text(String(format: latest.value >= 10 ? "%.0f" : "%.2f", latest.value))
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(accentColor)
                            Text(latest.unit)
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        
                        // Reference range indicator
                        if let min = referenceRange.min, let max = referenceRange.max {
                            HStack {
                                Image(systemName: "checkmark.shield")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("Normal: \(String(format: "%.1f", min)) - \(String(format: "%.1f", max))")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        } else if let max = referenceRange.max {
                             HStack {
                                Image(systemName: "checkmark.shield")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("Normal: < \(String(format: "%.1f", max))")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Detailed Chart
                if labResults.count >= 1 {
                    Chart {
                        // 1. Draw Normal Range Band (Background)
                        if let min = referenceRange.min, let max = referenceRange.max {
                            RectangleMark(
                                xStart: .value("Start", sortedResults.first?.testDate ?? Date()),
                                xEnd: .value("End", sortedResults.last?.testDate ?? Date()),
                                yStart: .value("Min Normal", min),
                                yEnd: .value("Max Normal", max)
                            )
                            .foregroundStyle(Color.green.opacity(0.1))
                            .annotation(position: .trailing, alignment: .center) {
                                Text("Normal")
                                    .font(.caption2)
                                    .foregroundColor(.green.opacity(0.8))
                            }
                        } else if let max = referenceRange.max {
                            // Upper limit only
                            RectangleMark(
                                xStart: .value("Start", sortedResults.first?.testDate ?? Date()),
                                xEnd: .value("End", sortedResults.last?.testDate ?? Date()),
                                yStart: .value("Zero", 0),
                                yEnd: .value("Max Normal", max)
                            )
                            .foregroundStyle(Color.green.opacity(0.1))
                        }
                        
                        // 2. Plot Data Points
                        ForEach(sortedResults, id: \.id) { result in
                            // Line connecting points
                            LineMark(
                                x: .value("Date", result.testDate),
                                y: .value("Value", result.value)
                            )
                            .foregroundStyle(accentColor)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            .interpolationMethod(.catmullRom) // Smooth curves
                            
                            // Actual Points
                            PointMark(
                                x: .value("Date", result.testDate),
                                y: .value("Value", result.value)
                            )
                            .foregroundStyle(.white)
                            .symbolSize(80) // White background for ring effect
                            
                            PointMark(
                                x: .value("Date", result.testDate),
                                y: .value("Value", result.value)
                            )
                            .foregroundStyle(accentColor)
                            .symbolSize(40) // Inner dot
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartYScale(domain: yAxisDomain ?? 0...100)
                    .frame(height: 250)
                    .padding()
                } else {
                    Text("Not enough data for detailed graph")
                        .padding()
                }
                
                // History List
                List {
                    Section(header: Text("History")) {
                        ForEach(sortedResults.reversed(), id: \.id) { result in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(result.testDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 16, weight: .medium))
                                    Text(result.normalRange.isEmpty ? "Range: N/A" : "Ref: \(result.normalRange)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("\(String(format: "%.2f", result.value))")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(accentColor)
                                    Text(result.unit)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                
            }
            .background(Color(red: 0.98, green: 0.98, blue: 0.99))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    OrganHealthDetailView()
}

/// Helper structure to handle parsing of medical reference ranges
struct RangeParser {
    
    /// Result of a range parsing operation
    struct RangeBounds {
        let min: Double?
        let max: Double?
        
        var isValid: Bool {
            return min != nil || max != nil
        }
    }
    
    /// Parse a reference range string into numeric bounds
    static func parse(_ rangeString: String) -> RangeBounds {
        let cleanString = rangeString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "–", with: "-") // Replace en-dash with hyphen
        
        if cleanString.isEmpty {
            return RangeBounds(min: nil, max: nil)
        }
        
        // Format: "< 5.7" or "upto 5.7" (Upper bound only)
        if cleanString.hasPrefix("<") || cleanString.contains("upto") || cleanString.contains("up to") {
            let numberString = cleanString
                .replacingOccurrences(of: "<", with: "")
                .replacingOccurrences(of: "upto", with: "")
                .replacingOccurrences(of: "up to", with: "")
                .replacingOccurrences(of: "=", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            if let max = Double(numberString) {
                return RangeBounds(min: 0.0, max: max)
            }
        }
        
        // Format: "> 60" (Lower bound only)
        if cleanString.hasPrefix(">") {
            let numberString = cleanString
                .replacingOccurrences(of: ">", with: "")
                .replacingOccurrences(of: "=", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            if let min = Double(numberString) {
                return RangeBounds(min: min, max: nil)
            }
        }
        
        // Format: "13.5 - 17.5" (Standard Range)
        if cleanString.contains("-") {
            let components = cleanString.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            if components.count == 2, 
               let min = Double(components[0]), 
               let max = Double(components[1]) {
                return RangeBounds(min: min, max: max)
            }
        }
        
        // Fallback: Try regex
        do {
            let pattern = "([0-9.]+).*?([0-9.]+)"
            let regex = try NSRegularExpression(pattern: pattern)
            let nsString = cleanString as NSString
            if let match = regex.firstMatch(in: cleanString, range: NSRange(location: 0, length: nsString.length)) {
                if match.numberOfRanges >= 3,
                   let min = Double(nsString.substring(with: match.range(at: 1))),
                   let max = Double(nsString.substring(with: match.range(at: 2))) {
                    return RangeBounds(min: min, max: max)
                }
            }
        } catch {
            print("Regex error in RangeParser: \(error)")
        }
        
        return RangeBounds(min: nil, max: nil)
    }
}
