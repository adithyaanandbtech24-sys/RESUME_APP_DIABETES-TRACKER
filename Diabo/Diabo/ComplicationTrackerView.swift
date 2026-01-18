import SwiftUI
import SwiftData

// MARK: - Complication Tracker View
// Tracks diabetic complications: Neuropathy, Retinopathy, Nephropathy, Cardiovascular.

struct ComplicationTrackerView: View {
    @Query private var userProfiles: [UserProfileModel]
    @Environment(\.modelContext) private var modelContext
    
    private var profile: UserProfileModel? { userProfiles.first }
    private let engine = DiabetesTargetEngine.shared
    
    // MARK: - Self-Assessment States
    @State private var footSensationScore: Int = 0  // 0-10
    @State private var visionScore: Int = 0  // 0-10
    @State private var fatigueScore: Int = 0  // 0-10
    @State private var chestPainFrequency: Int = 0  // 0 = never, 1 = rarely, 2 = sometimes, 3 = often
    
    @State private var showNeuropathyAssessment = false
    @State private var showRetinopathyInfo = false
    
    // MARK: - Theme
    private let deepPurple = Color(red: 0.25, green: 0.15, blue: 0.45)
    private let vibrantPurple = Color(red: 0.65, green: 0.55, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Risk Overview
                    if let profile = profile {
                        ComplicationRiskCard(profile: profile, engine: engine)
                    }
                    
                    // Complication Modules
                    ForEach(complications, id: \.name) { complication in
                        ComplicationModuleCard(
                            complication: complication,
                            onTap: { handleComplicationTap(complication) }
                        )
                    }
                    
                    // Disclaimer
                    DisclaimerCard()
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Complications")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showNeuropathyAssessment) {
                NeuropathySelfAssessment(score: $footSensationScore)
            }
        }
    }
    
    // MARK: - Complication Data
    
    private var complications: [ComplicationModule] {
        [
            ComplicationModule(
                name: "Neuropathy",
                icon: "hand.raised.fingers.spread.fill",
                color: .orange,
                description: "Nerve damage affecting feet and hands",
                symptoms: ["Tingling or numbness", "Burning sensation", "Loss of sensation", "Pain in extremities"],
                selfAssessmentAvailable: true
            ),
            ComplicationModule(
                name: "Retinopathy",
                icon: "eye.fill",
                color: .blue,
                description: "Eye damage affecting vision",
                symptoms: ["Blurry vision", "Dark spots", "Difficulty seeing at night", "Color changes"],
                selfAssessmentAvailable: false
            ),
            ComplicationModule(
                name: "Nephropathy",
                icon: "kidney.fill",
                color: .purple,
                description: "Kidney damage affecting filtration",
                symptoms: ["Swelling in legs", "Fatigue", "Frequent urination", "Foamy urine"],
                selfAssessmentAvailable: false
            ),
            ComplicationModule(
                name: "Cardiovascular",
                icon: "heart.fill",
                color: .red,
                description: "Heart and blood vessel damage",
                symptoms: ["Chest pain", "Shortness of breath", "Fatigue", "Irregular heartbeat"],
                selfAssessmentAvailable: false
            ),
            ComplicationModule(
                name: "Foot Health",
                icon: "shoeprints.fill",
                color: .brown,
                description: "Foot complications from neuropathy",
                symptoms: ["Slow healing wounds", "Calluses", "Infections", "Ulcers"],
                selfAssessmentAvailable: true
            )
        ]
    }
    
    private func handleComplicationTap(_ complication: ComplicationModule) {
        if complication.name == "Neuropathy" || complication.name == "Foot Health" {
            showNeuropathyAssessment = true
        }
    }
}

// MARK: - Complication Module Model

struct ComplicationModule {
    let name: String
    let icon: String
    let color: Color
    let description: String
    let symptoms: [String]
    let selfAssessmentAvailable: Bool
}

// MARK: - Complication Risk Card

struct ComplicationRiskCard: View {
    let profile: UserProfileModel
    let engine: DiabetesTargetEngine
    
    private var risk: DiabetesRiskAssessment {
        engine.assessRisk(for: profile)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Complication Risk")
                        .font(.headline)
                        .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.45))
                    
                    Text("Based on your profile and comorbidities")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(risk.overallRisk.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(riskColor(risk.overallRisk))
                    .cornerRadius(10)
            }
            
            // Risk Breakdown Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RiskItem(title: "Heart Disease", risk: risk.cardiovascularRisk, icon: "heart.fill")
                RiskItem(title: "Kidney Damage", risk: risk.nephropathyRisk, icon: "kidney.fill")
                RiskItem(title: "Nerve Damage", risk: risk.neuropathyRisk, icon: "hand.raised.fill")
                RiskItem(title: "Eye Damage", risk: risk.retinopathyRisk, icon: "eye.fill")
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(18)
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

struct RiskItem: View {
    let title: String
    let risk: DiabetesRiskAssessment.RiskCategory
    let icon: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(riskColor)
                .frame(width: 32, height: 32)
                .background(riskColor.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(risk.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(riskColor)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
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

// MARK: - Complication Module Card

struct ComplicationModuleCard: View {
    let complication: ComplicationModule
    let onTap: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: { 
                if complication.selfAssessmentAvailable {
                    onTap()
                } else {
                    withAnimation { isExpanded.toggle() }
                }
            }) {
                HStack {
                    Image(systemName: complication.icon)
                        .font(.title3)
                        .foregroundColor(complication.color)
                        .frame(width: 44, height: 44)
                        .background(complication.color.opacity(0.12))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(complication.name)
                            .font(.headline)
                            .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.45))
                        
                        Text(complication.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if complication.selfAssessmentAvailable {
                        Text("Self-Check")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(complication.color)
                            .cornerRadius(8)
                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded Symptoms
            if isExpanded {
                Divider()
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Common Symptoms")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    
                    ForEach(complication.symptoms, id: \.self) { symptom in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(complication.color)
                                .frame(width: 6, height: 6)
                            Text(symptom)
                                .font(.subheadline)
                                .foregroundColor(.black.opacity(0.8))
                        }
                    }
                    
                    Text("If experiencing symptoms, consult your healthcare provider.")
                        .font(.caption2)
                        .italic()
                        .foregroundColor(.gray)
                        .padding(.top, 6)
                }
                .padding()
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Neuropathy Self Assessment

struct NeuropathySelfAssessment: View {
    @Binding var score: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var q1: Int = 0  // Numbness
    @State private var q2: Int = 0  // Tingling
    @State private var q3: Int = 0  // Burning
    @State private var q4: Int = 0  // Pain
    @State private var q5: Int = 0  // Sensitivity to touch
    
    private var totalScore: Int { q1 + q2 + q3 + q4 + q5 }
    
    private var riskLevel: String {
        switch totalScore {
        case 0...4: return "Low"
        case 5...9: return "Moderate"
        case 10...14: return "Elevated"
        default: return "High"
        }
    }
    
    private var riskColor: Color {
        switch totalScore {
        case 0...4: return .green
        case 5...9: return .yellow
        case 10...14: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Intro
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Neuropathy Self-Check")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Rate each symptom from 0 (never) to 4 (always) over the past week.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    // Questions
                    SymptomSlider(label: "Numbness in feet or hands", value: $q1)
                    SymptomSlider(label: "Tingling sensation", value: $q2)
                    SymptomSlider(label: "Burning feeling", value: $q3)
                    SymptomSlider(label: "Sharp or stabbing pain", value: $q4)
                    SymptomSlider(label: "Sensitivity to light touch", value: $q5)
                    
                    // Result
                    VStack(spacing: 12) {
                        Text("Your Neuropathy Risk")
                            .font(.headline)
                        
                        Text("\(totalScore)/20")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(riskColor)
                        
                        Text(riskLevel)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(riskColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(riskColor.opacity(0.1))
                    .cornerRadius(16)
                    
                    // Disclaimer
                    Text("This is a screening tool only. It does not diagnose neuropathy. Please discuss results with your healthcare provider.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
            }
            .navigationTitle("Self-Assessment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        score = totalScore
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SymptomSlider: View {
    let label: String
    @Binding var value: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(value)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.65, green: 0.55, blue: 0.95))
            }
            
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Int($0) }
            ), in: 0...4, step: 1)
            .accentColor(Color(red: 0.65, green: 0.55, blue: 0.95))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

// MARK: - Disclaimer Card

struct DisclaimerCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Medical Disclaimer")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Text("This complication tracker provides general information and self-assessment tools. It is not a substitute for professional medical evaluation. Regular check-ups with your endocrinologist are essential.")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    ComplicationTrackerView()
}
