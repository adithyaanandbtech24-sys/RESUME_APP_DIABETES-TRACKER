import SwiftUI
import SwiftData

// MARK: - Organ System Lab View
// Groups lab results by organ system for clinical interpretation.

struct OrganSystemLabView: View {
    @Query(sort: \LabResultModel.testDate, order: .reverse) private var labResults: [LabResultModel]
    @Query private var userProfiles: [UserProfileModel]
    
    private var profile: UserProfileModel? { userProfiles.first }
    
    // MARK: - Organ Systems
    private let organSystems: [(name: String, icon: String, color: Color, keywords: [String])] = [
        ("Metabolism", "flame.fill", .orange, ["glucose", "hba1c", "hemoglobin", "fasting", "sugar", "insulin"]),
        ("Heart", "heart.fill", .red, ["cholesterol", "ldl", "hdl", "triglyceride", "lipid", "cardiac", "troponin", "bnp"]),
        ("Kidneys", "kidney.fill", .purple, ["creatinine", "urea", "bun", "egfr", "gfr", "uric", "microalbumin", "albumin"]),
        ("Liver", "liver.fill", .brown, ["alt", "ast", "sgpt", "sgot", "bilirubin", "albumin", "alkaline", "ggt"]),
        ("Blood", "drop.fill", .red, ["rbc", "wbc", "platelet", "hemoglobin", "hematocrit", "mcv", "mch"]),
        ("Thyroid", "sparkles.rectangle.stack", .teal, ["tsh", "t3", "t4", "thyroid"])
    ]
    
    // MARK: - Grouped Labs
    private var groupedLabs: [(system: String, icon: String, color: Color, labs: [LabResultModel])] {
        organSystems.compactMap { system in
            let matching = labResults.filter { lab in
                // Priority: Check category first, then keywords
                if lab.category.localizedCaseInsensitiveContains(system.name) {
                    return true
                }
                // Fallback to keyword matching
                return system.keywords.contains { keyword in
                    lab.testName.localizedCaseInsensitiveContains(keyword) ||
                    lab.parameter.localizedCaseInsensitiveContains(keyword)
                }
            }
            if matching.isEmpty { return nil }
            return (system.name, system.icon, system.color, matching)
        }
    }
    
    // MARK: - Theme
    private let deepPurple = Color(red: 0.25, green: 0.15, blue: 0.45)
    private let vibrantPurple = Color(red: 0.65, green: 0.55, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile-Based Risk Summary
                    if let profile = profile {
                        RiskSummaryBanner(profile: profile)
                    }
                    
                    // Organ System Cards
                    if groupedLabs.isEmpty {
                        EmptyLabsView()
                    } else {
                        ForEach(groupedLabs, id: \.system) { group in
                            LabOrganCard(
                                systemName: group.system,
                                icon: group.icon,
                                color: group.color,
                                labs: group.labs,
                                profile: profile
                            )
                        }
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Lab Results")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// ... RiskSummaryBanner (unchanged) ...
// ... RiskIndicator (unchanged) ...
// ... LabOrganCard (unchanged except it uses new LabResultRow) ...

// MARK: - Lab Result Row

struct LabResultRow: View {
    let lab: LabResultModel
    let accentColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Parameter Info
            VStack(alignment: .leading, spacing: 4) {
                Text(lab.testName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(UIColor.label))
                    .fixedSize(horizontal: false, vertical: true) // Allow multiline
                
                if !lab.normalRange.isEmpty {
                    Text("Ref: \(lab.normalRange)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Value & Status
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    if let strVal = lab.stringValue, !strVal.isEmpty {
                        Text(strVal)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(UIColor.label))
                    } else {
                        Text(String(format: "%.1f", lab.value))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(UIColor.label))
                    }
                    
                    Text(lab.unit)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                // Status Badge
                if !isNormal {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        
                        Text(lab.status.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
    
    private var isNormal: Bool {
        lab.status.lowercased() == "normal"
    }
    
    private var statusColor: Color {
        let s = lab.status.lowercased()
        if s.contains("high") || s.contains("elevated") { return .red }
        if s.contains("low") { return .blue }
        if s.contains("borderline") { return .orange }
        if s.contains("critical") { return .purple }
        return .green
    }
}

// MARK: - Risk Summary Banner

struct RiskSummaryBanner: View {
    let profile: UserProfileModel
    private let engine = DiabetesTargetEngine.shared
    
    private var risk: DiabetesRiskAssessment {
        engine.assessRisk(for: profile)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.title2)
                    .foregroundColor(riskColor(risk.overallRisk))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Complication Risk Assessment")
                        .font(.headline)
                        .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.45))
                    
                    Text("\(profile.diabetesType) • \(profile.treatmentType)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(risk.overallRisk.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(riskColor(risk.overallRisk))
                    .cornerRadius(8)
            }
            
            // Risk Breakdown
            HStack(spacing: 16) {
                RiskIndicator(label: "CV", risk: risk.cardiovascularRisk)
                RiskIndicator(label: "Kidney", risk: risk.nephropathyRisk)
                RiskIndicator(label: "Nerves", risk: risk.neuropathyRisk)
                RiskIndicator(label: "Eyes", risk: risk.retinopathyRisk)
                RiskIndicator(label: "Hypo", risk: risk.hypoglycemiaRisk)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private func riskColor(_ risk: DiabetesRiskAssessment.RiskCategory) -> Color {
        switch risk {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .veryHigh: return .red
        }
    }
}

struct RiskIndicator: View {
    let label: String
    let risk: DiabetesRiskAssessment.RiskCategory
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(riskColor)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
    }
    
    private var riskColor: Color {
        switch risk {
        case .low: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .veryHigh: return .red
        }
    }
}

// MARK: - Lab Organ Card

struct LabOrganCard: View {
    let systemName: String
    let icon: String
    let color: Color
    let labs: [LabResultModel]
    let profile: UserProfileModel?
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    // Icon
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                        .frame(width: 40, height: 40)
                        .background(color.opacity(0.15))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(systemName)
                            .font(.headline)
                            .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.45))
                        
                        Text("\(labs.count) result\(labs.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Status Summary
                    statusSummary
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded Content
            if isExpanded {
                Divider()
                    .padding(.horizontal)
                
                VStack(spacing: 0) {
                    ForEach(labs.prefix(5)) { lab in
                        LabResultRow(lab: lab, accentColor: color)
                        
                        if lab.id != labs.prefix(5).last?.id {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                    
                    if labs.count > 5 {
                        HStack {
                            Spacer()
                            Text("+ \(labs.count - 5) more")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
    
    private var statusSummary: some View {
        let abnormalCount = labs.filter { 
            $0.status.lowercased().contains("high") || $0.status.lowercased().contains("low")
        }.count
        
        return Group {
            if abnormalCount > 0 {
                Text("\(abnormalCount) abnormal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            } else {
                Text("All normal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }
}

// MARK: - Lab Result Row


// MARK: - Empty Labs View

struct EmptyLabsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.4))
            
            Text("No Lab Results Yet")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Upload a medical report to see your lab results organized by organ system.")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(40)
        .background(Color.white)
        .cornerRadius(20)
    }
}

#Preview {
    OrganSystemLabView()
}
