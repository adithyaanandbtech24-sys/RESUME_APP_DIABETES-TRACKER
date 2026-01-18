import SwiftUI
import SwiftData
import Charts

// MARK: - Diabetes Vitals View
// A clinical-grade vitals dashboard that adapts to the user's diabetes profile.

struct DiabetesVitalsView: View {
    @Query private var userProfiles: [UserProfileModel]
    @Query(sort: \LabResultModel.testDate, order: .reverse) private var labResults: [LabResultModel]
    
    private var profile: UserProfileModel? { userProfiles.first }
    private let engine = DiabetesTargetEngine.shared
    
    // MARK: - Computed Vital Values
    
    private var latestHbA1c: LabResultModel? {
        let match = labResults.first { result in
            let name = result.testName.lowercased()
            // Comprehensive HbA1c matching - handles OCR variations
            return name.contains("hba1c") || 
                   name.contains("hb a1c") ||
                   name.contains("a1c") ||
                   name.contains("glycated") ||
                   name.contains("glycosylated") ||
                   name.contains("hemoglobin a1c") ||
                   name.contains("haemoglobin a1c") ||
                   name.contains("glyco") ||
                   name.contains("average blood glucose") || // Sometimes eAG is confused
                   (name.contains("hb") && name.contains("1c"))
        }
        if match == nil && !labResults.isEmpty {
            print("⚠️ [DiabetesVitals] No HbA1c found. Available tests: \(labResults.prefix(10).map { $0.testName })")
        }
        return match
    }
    
    private var latestFastingGlucose: LabResultModel? {
        let match = labResults.first { result in
            let name = result.testName.lowercased()
            // Fasting glucose/sugar variations
            let isFasting = name.contains("fasting") || 
                            name.contains("fbs") || 
                            name.contains("fbg") ||
                            name.contains("f.b.s") ||
                            name.contains("f b s") ||
                            name.contains("fast glucose") ||
                            name.contains("fst glucose")
            let isGlucose = name.contains("glucose") || 
                            name.contains("sugar") || 
                            name.contains("blood sugar") ||
                            name.contains("gluco")
            return isFasting || (isGlucose && name.contains("fast"))
        }
        return match
    }
    
    private var latestPostPrandial: LabResultModel? {
        labResults.first { result in
            let name = result.testName.lowercased()
            // Post-prandial glucose variations
            return name.contains("ppbs") ||
                   name.contains("pp glucose") ||
                   name.contains("post prandial") ||
                   name.contains("postprandial") ||
                   name.contains("post meal") ||
                   name.contains("ppbg") ||
                   name.contains("2hr") ||
                   name.contains("2 hr") ||
                   name.contains("2 hour") ||
                   name.contains("after meal") ||
                   (name.contains("glucose") && (name.contains("pp") || name.contains("post")))
        }
    }
    
    private var fastingGlucoseHistory: [LabResultModel] {
        labResults.filter { result in
            let name = result.testName.lowercased()
            let isFasting = name.contains("fasting") || name.contains("fbs") || name.contains("fbg") || name.contains("f.b.s") || name.contains("f b s") || name.contains("fast glucose") || name.contains("fst glucose")
            let isGlucose = name.contains("glucose") || name.contains("sugar") || name.contains("blood sugar") || name.contains("gluco")
            return isFasting || (isGlucose && name.contains("fast"))
        }.sorted { $0.testDate < $1.testDate }
    }
    
    private var postMealGlucoseHistory: [LabResultModel] {
        labResults.filter { result in
            let name = result.testName.lowercased()
            return name.contains("ppbs") || name.contains("pp glucose") || name.contains("post prandial") || name.contains("postprandial") || name.contains("post meal") || name.contains("ppbg") || name.contains("2hr") || name.contains("2 hr") || name.contains("2 hour") || name.contains("after meal") || (name.contains("glucose") && (name.contains("pp") || name.contains("post")))
        }.sorted { $0.testDate < $1.testDate }
    }
    
    private var targets: GlucoseTargets {
        engine.glucoseTargets(for: profile ?? UserProfileModel(name: "Guest", age: 45, gender: "Male", diabetesType: "Type 2"))
    }
    
    private var latestBP: LabResultModel? {
        labResults.first { result in
            let name = result.testName.lowercased()
            return name.contains("blood pressure") || 
                   name.contains("bp") ||
                   name.contains("systolic") ||
                   name.contains("diastolic") ||
                   name.contains("b.p") ||
                   name.contains("hypertension")
        }
    }
    
    private var latestWeight: LabResultModel? {
        // 1. Try to find in lab results
        if let labWeight = labResults.first(where: { $0.testName.localizedCaseInsensitiveContains("weight") }) {
            return labWeight
        }
        
        // 2. Fallback to profile weight
        if let profile = profile, let weightVal = profile.weight {
            return LabResultModel(
                testName: "Weight",
                value: weightVal,
                unit: "kg",
                normalRange: "18.5-24.9",
                status: "Normal", // Calculated elsewhere via BMI
                category: "Vitals"
            )
        }
        
        return nil
    }
    
    // Additional Diabetes-Relevant Vitals
    
    private var latestFastingInsulin: LabResultModel? {
        labResults.first { result in
            let name = result.testName.lowercased()
            return name.contains("fasting insulin") || 
                   name.contains("insulin fasting") ||
                   (name.contains("insulin") && name.contains("fast"))
        }
    }
    
    private var latestEGFR: LabResultModel? {
        labResults.first { result in
            let name = result.testName.lowercased()
            return name.contains("egfr") || 
                   name.contains("gfr") ||
                   name.contains("glomerular filtration")
        }
    }
    
    private var latestCreatinine: LabResultModel? {
        labResults.first { result in
            let name = result.testName.lowercased()
            return name.contains("creatinine") && !name.contains("clearance")
        }
    }
    
    private var latestCholesterol: LabResultModel? {
        labResults.first { result in
            let name = result.testName.lowercased()
            return (name.contains("cholesterol") && name.contains("total")) ||
                   name == "cholesterol" ||
                   name.contains("total cholesterol")
        }
    }
    
    private var latestTriglycerides: LabResultModel? {
        labResults.first { result in
            let name = result.testName.lowercased()
            return name.contains("triglyceride")
        }
    }
    
    private var latestLDL: LabResultModel? {
        labResults.first { result in
            let name = result.testName.lowercased()
            return name.contains("ldl") || name.contains("low density")
        }
    }
    
    private var latestHDL: LabResultModel? {
        labResults.first { result in
            let name = result.testName.lowercased()
            return name.contains("hdl") || name.contains("high density")
        }
    }
    
    private var latestMeanBloodGlucose: LabResultModel? {
        labResults.first { result in
            let name = result.testName.lowercased()
            return name.contains("mean blood glucose") || 
                   name.contains("average glucose") ||
                   name.contains("mbg") ||
                   name.contains("estimated average glucose") ||
                   name.contains("eag")
        }
    }
    
    private var latestUrineAlbumin: LabResultModel? {
        labResults.first { result in
            let name = result.testName.lowercased()
            return name.contains("microalbumin") || 
                   name.contains("urine albumin") ||
                   name.contains("albumin creatinine ratio") ||
                   name.contains("acr") ||
                   name.contains("uacr")
        }
    }
    
    // MARK: - Theme Colors
    private let deepPurple = Color(red: 0.25, green: 0.15, blue: 0.45)
    private let vibrantPurple = Color(red: 0.65, green: 0.55, blue: 0.95)
    private let lightPurple = Color(red: 0.94, green: 0.92, blue: 0.98)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section Header with Personalization Badge
            headerSection
            
            // Note: Goals removed here - already shown in dashboard header
            
            // 1. Glycemic Control Section
            glycemicSection

            
            // 2. Cardiovascular & Body Section
            cardiovascularSection
            
            // 3. Lipid Panel Section (critical for diabetics)
            lipidPanelSection
            
            // 4. Kidney Health Section (diabetes affects kidneys)
            kidneyHealthSection
        }
        .padding(.vertical)
        .background(lightPurple.opacity(0.3))
        .onAppear {
            // DEBUG: Log all lab results from query
            print("🔬 [DiabetesVitals] ========== QUERY RESULTS ==========")
            print("🔬 [DiabetesVitals] Total lab results in @Query: \(labResults.count)")
            print("🔬 [DiabetesVitals] Profile available: \(profile != nil)")
            if let p = profile {
                print("🔬 [DiabetesVitals] Profile: \(p.name), Type: \(p.diabetesType)")
            } else {
                print("⚠️ [DiabetesVitals] NO PROFILE - Goals will not show!")
            }
            
            for (idx, result) in labResults.prefix(20).enumerated() {
                let name = result.testName.lowercased()
                let isHbA1c = name.contains("hba1c") || name.contains("glycated") || name.contains("a1c")
                print("  \(idx+1). '\(result.testName)' = \(result.value) \(result.unit) [cat: \(result.category)] \(isHbA1c ? "✅ HbA1c MATCH" : "")")
            }
            if let hba1c = latestHbA1c {
                print("✅ [DiabetesVitals] HbA1c FOUND: \(hba1c.value) \(hba1c.unit)")
            } else {
                print("⚠️ [DiabetesVitals] HbA1c NOT FOUND in \(labResults.count) results")
            }
            print("🔬 [DiabetesVitals] =====================================")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Diabetes Vitals")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(deepPurple)
                
                if let profile = profile {
                    Text("\(profile.diabetesType) • Personalized")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            NavigationLink(destination: TimelineAnalysisView()) {
                HStack(spacing: 4) {
                    Text("See Logs")
                        .font(.footnote)
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(vibrantPurple)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Targets Banner
    
    private func targetsBanner(for profile: UserProfileModel) -> some View {
        let targets = engine.glucoseTargets(for: profile)
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                TargetChip(
                    label: "Fasting Goal",
                    value: targets.fastingRange,
                    icon: "sunrise.fill",
                    color: .blue
                )
                
                TargetChip(
                    label: "Post-Meal Goal",
                    value: targets.postPrandialRange,
                    icon: "fork.knife",
                    color: .orange
                )
                
                TargetChip(
                    label: "HbA1c Goal",
                    value: targets.hba1cDisplay,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                )
                
                TargetChip(
                    label: "TIR Goal",
                    value: "\(Int(targets.timeInRangeGoal))%",
                    icon: "clock.fill",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Glycemic Section
    
    private var glycemicSection: some View {
        VStack(spacing: 12) {
            // HbA1c Interactive Analysis Graph
            if let hba1c = latestHbA1c {
                HbA1cAnalysisView(result: hba1c, profile: profile, engine: engine)
            } else {
                EmptyMetricCard(title: "HbA1c", icon: "drop.circle.fill", message: "No data yet")
                    .padding(.horizontal)
            }
            
            // Fasting + Post-Meal Cards
            HStack(spacing: 12) {
                GlucoseCard(
                    title: "Fasting Glucose",
                    result: latestFastingGlucose,
                    history: fastingGlucoseHistory,
                    targetRange: (min: targets.fastingMin, max: targets.fastingMax),
                    profile: profile,
                    engine: engine,
                    icon: "sunrise.fill",
                    color: .blue
                )
                
                GlucoseCard(
                    title: "Post-Meal Glucose",
                    result: latestPostPrandial,
                    history: postMealGlucoseHistory,
                    targetRange: (min: 70, max: targets.postPrandialMax),
                    profile: profile,
                    engine: engine,
                    icon: "fork.knife",
                    color: .orange
                )
            }
            .padding(.horizontal)
            
            // Secondary Glycemic Metrics (Mean Glucose, Insulin)
            if latestMeanBloodGlucose != nil || latestFastingInsulin != nil {
                HStack(spacing: 12) {
                    if let result = latestMeanBloodGlucose {
                        VitalCard(title: "Mean Glucose", result: result, icon: "chart.xyaxis.line", color: .purple)
                    }
                    if let result = latestFastingInsulin {
                        VitalCard(title: "Fasting Insulin", result: result, icon: "drop.triangle", color: .indigo)
                    }
                    if latestMeanBloodGlucose == nil || latestFastingInsulin == nil {
                        Spacer()
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Cardiovascular Section
    
    private var cardiovascularSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cardiovascular & Body")
                .font(.headline)
                .foregroundColor(deepPurple.opacity(0.8))
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                VitalStatusCard(
                    title: "Blood Pressure",
                    result: latestBP,
                    profile: profile,
                    icon: "heart.fill",
                    color: .red
                )
                
                VitalStatusCard(
                    title: "Weight",
                    result: latestWeight,
                    profile: profile,
                    icon: "figure.stand",
                    color: .green
                )
            }
            .padding(.horizontal)
            
            // BMI Card if we have weight and height
            if let profile = profile, let weight = profile.weight, let height = profile.height {
                BMICard(weight: weight, height: height, engine: engine)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Sub-Components

struct TargetChip: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

struct HbA1cHeroCard: View {
    let result: LabResultModel
    let profile: UserProfileModel?
    let engine: DiabetesTargetEngine
    
    private var safeProfile: UserProfileModel {
        profile ?? UserProfileModel(name: "Guest", age: 45, gender: "Male", diabetesType: "Type 2")
    }
    
    private var interpretation: VitalInterpretation {
        engine.interpretHbA1c(result.value, profile: safeProfile)
    }
    
    private var targets: GlucoseTargets {
        engine.glucoseTargets(for: safeProfile)
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Circular Progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.1), lineWidth: 8)
                    .frame(width: 85, height: 85)
                
                Circle()
                    .trim(from: 0, to: min(CGFloat(result.value) / 14.0, 1.0))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.green, .yellow, .orange, .red]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 85, height: 85)
                
                VStack(spacing: 0) {
                    Text(String(format: "%.1f", result.value))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.45))
                    Text("%")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("HbA1c (3-Month Average)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                
                HStack(spacing: 8) {
                    Text(interpretation.status.rawValue)
                        .font(.headline)
                        .foregroundColor(statusColor(interpretation.status))
                    
                    // Risk badge
                    Text(interpretation.riskLevel.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor(interpretation.status).opacity(0.15))
                        .foregroundColor(statusColor(interpretation.status))
                        .cornerRadius(6)
                }
                
                Text("Target: \(targets.hba1cDisplay)")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.8))
                
                Text(result.testDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.3))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private func statusColor(_ status: VitalInterpretation.VitalStatus) -> Color {
        switch status {
        case .optimal, .normal: return .green
        case .elevated: return .orange
        case .high, .critical: return .red
        case .low, .veryLow: return .blue
        }
    }
}

struct GlucoseCard: View {
    let title: String
    let result: LabResultModel?
    let history: [LabResultModel]
    let targetRange: (min: Double, max: Double)?
    let profile: UserProfileModel?
    let engine: DiabetesTargetEngine
    let icon: String
    let color: Color
    
    private var interpretation: VitalInterpretation? {
        guard let result = result, let profile = profile else { return nil }
        // Use generic interpretation or specific based on title?
        // Reuse engine logic
        if title.contains("Fasting") {
            return engine.interpretFastingGlucose(result.value, profile: profile)
        } else {
             return engine.interpretPostPrandial(result.value, profile: profile) 
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Spacer()
                
                if let interp = interpretation {
                    StatusDot(status: interp.status)
                }
            }
            
            // Value Display
            if let res = result {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(String(format: "%.0f", res.value))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.45))
                    Text(res.unit)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                if let interp = interpretation {
                    Text(interp.status.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(statusColor(interp.status))
                }
            } else {
                Text("--")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.gray.opacity(0.5))
            }
            
            // Trend Graph
            if history.count >= 2 {
                if #available(iOS 16.0, *) {
                    Chart {
                        // Target Band
                        if let range = targetRange {
                            RectangleMark(
                                yStart: .value("Min", range.min),
                                yEnd: .value("Max", range.max)
                            )
                            .foregroundStyle(Color.green.opacity(0.1))
                        }
                        
                        // History Line
                        ForEach(history) { item in
                            LineMark(
                                x: .value("Date", item.testDate),
                                y: .value("Value", item.value)
                            )
                            .foregroundStyle(color)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            
                            PointMark(
                                x: .value("Date", item.testDate),
                                y: .value("Value", item.value)
                            )
                            .foregroundStyle(color)
                            .symbolSize(20)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 50) // Sparkline style
                }
            } else if let res = result, let date = res.testDate as Date? {
                // Single point info
                Text("Last: \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
    
    private func statusColor(_ status: VitalInterpretation.VitalStatus) -> Color {
        switch status {
        case .optimal, .normal: return .green
        case .elevated: return .orange
        case .high, .critical: return .red
        case .low, .veryLow: return .blue
        }
    }
}

struct VitalStatusCard: View {
    let title: String
    let result: LabResultModel?
    let profile: UserProfileModel?
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            if let res = result {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    if let strVal = res.stringValue, !strVal.isEmpty {
                        Text(strVal)
                            .font(.headline)
                            .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.45))
                    } else {
                        Text(String(format: "%.0f", res.value))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.45))
                    }
                    Text(res.unit)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Text(res.status)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(statusColor(for: res.status))
            } else {
                Text("--")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
    
    func statusColor(for status: String) -> Color {
        let s = status.lowercased()
        if s.contains("normal") || s.contains("optimal") { return .green }
        if s.contains("high") || s.contains("low") { return .red }
        return .orange
    }
}

struct BMICard: View {
    let weight: Double
    let height: Double
    let engine: DiabetesTargetEngine
    
    private var bmi: Double? {
        engine.calculateBMI(heightCm: height, weightKg: weight)
    }
    
    private var bmiStatus: String {
        engine.interpretBMI(bmi)
    }
    
    private var bmiColor: Color {
        guard let bmi = bmi else { return .gray }
        switch bmi {
        case ..<18.5: return .orange
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "figure.arms.open")
                .font(.title2)
                .foregroundColor(bmiColor)
                .padding(12)
                .background(bmiColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Body Mass Index")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    if let bmi = bmi {
                        Text(String(format: "%.1f", bmi))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.45))
                    } else {
                        Text("--")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    Text("kg/m²")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Text(bmiStatus)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(bmiColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(bmiColor.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

struct StatusDot: View {
    let status: VitalInterpretation.VitalStatus
    
    var color: Color {
        switch status {
        case .optimal, .normal: return .green
        case .elevated: return .orange
        case .high, .critical: return .red
        case .low, .veryLow: return .blue
        }
    }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .shadow(color: color.opacity(0.4), radius: 2, x: 0, y: 1)
    }
}

struct EmptyMetricCard: View {
    let title: String
    let icon: String
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.gray)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.6))
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.7))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundColor(.gray.opacity(0.3))
        )
    }
}

struct VitalCard: View {
    let title: String
    let result: LabResultModel?
    let icon: String // SF Symbol name
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(1)
            
            if let res = result {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", res.value))
                        .font(.headline)
                        .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.45))
                    
                    Text(res.unit)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            } else {
                Text("--")
                    .font(.headline)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

extension DiabetesVitalsView {
    // MARK: - Lipid Panel Section
    
    private var lipidPanelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lipid Monitoring")
                .font(.headline)
                .foregroundColor(deepPurple)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                // Total Cholesterol
                VitalCard(
                    title: "Cholesterol",
                    result: latestCholesterol,
                    icon: "drop.fill",
                    color: .orange
                )
                
                // LDL (Bad Cholesterol)
                VitalCard(
                    title: "LDL",
                    result: latestLDL,
                    icon: "arrow.down.circle.fill", // Should keep low
                    color: .red
                )
            }
            .padding(.horizontal)
            
            HStack(spacing: 12) {
                // HDL (Good Cholesterol)
                VitalCard(
                    title: "HDL",
                    result: latestHDL,
                    icon: "arrow.up.circle.fill", // Should keep high
                    color: .green
                )
                
                // Triglycerides
                VitalCard(
                    title: "Triglycerides",
                    result: latestTriglycerides,
                    icon: "chart.bar.fill",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Kidney Health Section
    
    private var kidneyHealthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kidney Health")
                .font(.headline)
                .foregroundColor(deepPurple)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                // eGFR (Kidney Function)
                VitalCard(
                    title: "eGFR",
                    result: latestEGFR,
                    icon: "function",
                    color: .blue
                )
                
                // Creatinine
                VitalCard(
                    title: "Creatinine",
                    result: latestCreatinine,
                    icon: "flask.fill",
                    color: .cyan
                )
            }
            .padding(.horizontal)
            
            if let urine = latestUrineAlbumin {
                HStack(spacing: 12) {
                    VitalCard(
                        title: "Urine Albumin",
                        result: urine,
                        icon: "drop.triangle.fill",
                        color: .yellow
                    )
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - HbA1c Graph View

struct HbA1cAnalysisView: View {
    let result: LabResultModel
    let profile: UserProfileModel?
    let engine: DiabetesTargetEngine
    
    // Default profile for calculation if missing
    private var safeProfile: UserProfileModel {
        profile ?? UserProfileModel(name: "Guest", age: 45, gender: "Male", diabetesType: "Type 2")
    }
    
    private var comparisonStats: DiabetesTargetEngine.HbA1cPopulationStats {
        engine.getIndianPopulationStats(for: safeProfile.age)
    }
    
    private var userGoal: Double {
        engine.glucoseTargets(for: safeProfile).hba1cGoal ?? 7.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HbA1c Analysis")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", result.value))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(statusColor)
                        
                        Text("%")
                            .font(.body)
                            .foregroundColor(.gray)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                // Context Chip
                Text(comparisonText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Chart
            if #available(iOS 16.0, *) {
                Chart {
                    // 1. User Value
                    BarMark(
                        x: .value("Category", "You"),
                        y: .value("HbA1c", result.value)
                    )
                    .foregroundStyle(statusColor.gradient)
                    .annotation(position: .top) {
                        Text("\(String(format: "%.1f", result.value))%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(statusColor)
                    }
                    
                    // 2. Goal
                    RuleMark(
                        y: .value("Goal", userGoal)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundStyle(.green)
                    .annotation(position: .leading, alignment: .bottom) {
                        Text("Goal < \(String(format: "%.1f", userGoal))")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    // 3. Indian Avg (Diabetic)
                    BarMark(
                        x: .value("Category", "Avg (India)"),
                        y: .value("HbA1c", comparisonStats.diabeticAverage)
                    )
                    .foregroundStyle(Color.gray.opacity(0.3).gradient)
                    .annotation(position: .top) {
                        Text("\(String(format: "%.1f", comparisonStats.diabeticAverage))%")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    // 4. Normal Baseline
                    RuleMark(
                        y: .value("Normal", comparisonStats.normalAverage)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .foregroundStyle(.blue.opacity(0.5))
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            } else {
                // Fallback for older iOS (using ProgressView logic if needed, but sticking to simple text here)
                Text("Update iOS to see interactive charts")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Insight Text
            Text(insightMessage)
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Helpers
    
    private var statusColor: Color {
        if result.value <= 5.7 { return .green }
        if result.value <= 6.4 { return .orange }
        if result.value <= userGoal { return .teal } // Good control for diabetic
        return .red
    }
    
    private var comparisonText: String {
        let diff = result.value - comparisonStats.diabeticAverage
        if diff < -0.5 {
            return "Better than Avg"
        } else if diff > 0.5 {
            return "Above Avg"
        } else {
            return "Average"
        }
    }
    
    private var insightMessage: String {
        let diff = comparisonStats.diabeticAverage - result.value
        if diff > 0 {
            return "Great job! Your HbA1c is lower than the average diabetic in India (age \(comparisonStats.ageGroup))."
        } else {
            return "Your levels are higher than the average. Consider adjustments to reach your goal of \(String(format: "%.1f", userGoal))%."
        }
    }
}
