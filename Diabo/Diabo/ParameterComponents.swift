import SwiftUI
import SwiftData

/// A card displaying a specific medical parameter (e.g., Blood Pressure, ECG)
struct ParameterCard: View {
    let testName: String
    let value: Double
    let unit: String
    let status: String
    let normalRange: String
    let color: Color
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: getIcon(for: testName))
                            .font(.system(size: 16))
                            .foregroundColor(color)
                    }
                    
                    Spacer()
                    
                    StatusTag(status: status)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(testName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", value))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text(unit)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                if !normalRange.isEmpty {
                    Text("Range: \(normalRange)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.8))
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func getIcon(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("glucose") || n.contains("hba1c") { return "drop.fill" }
        if n.contains("pressure") || n.contains("bp") { return "heart.fill" }
        if n.contains("heart") || n.contains("bpm") { return "waveform.path.ecg" }
        if n.contains("cholesterol") || n.contains("ldl") || n.contains("hdl") { return "gauge.medium" }
        if n.contains("weight") || n.contains("bmi") { return "figure.stand" }
        if n.contains("temp") { return "thermometer.medium" }
        if n.contains("oxygen") || n.contains("spo2") { return "lungs.fill" }
        return "chart.bar.fill"
    }
}

// MARK: - Parameter Graph View
/// Shows historical trend for a specific parameter
struct ParameterGraphView: View {
    let parameterName: String
    let color: Color
    
    @Query private var allGraphData: [LabGraphDataModel]
    
    private var history: [LabGraphDataModel] {
        allGraphData.filter { $0.parameter.lowercased() == parameterName.lowercased() }
            .sorted { $0.date < $1.date }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No historical data yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Upload more reports to see trends")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            } else {
                // Simple line graph
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height - 40
                    
                    let values = history.map { $0.value }
                    let minValue = (values.min() ?? 0) * 0.9
                    let maxValue = (values.max() ?? 100) * 1.1
                    let range = maxValue - minValue
                    
                    ZStack(alignment: .leading) {
                        // Background lines
                        VStack {
                            ForEach(0..<4) { i in
                                Divider()
                                    .background(Color.gray.opacity(0.2))
                                if i < 3 { Spacer() }
                            }
                        }
                        .frame(height: height)
                        
                        // Data points and line
                        Path { path in
                            for (index, entry) in history.enumerated() {
                                let x = width * CGFloat(index) / CGFloat(max(history.count - 1, 1))
                                let y = height - (height * CGFloat((entry.value - minValue) / range))
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(color, lineWidth: 2)
                        
                        // Data points
                        ForEach(Array(history.enumerated()), id: \.element.id) { index, entry in
                            let x = width * CGFloat(index) / CGFloat(max(history.count - 1, 1))
                            let y = height - (height * CGFloat((entry.value - minValue) / range))
                            
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                                .position(x: x, y: y)
                        }
                    }
                    
                    // Date labels at bottom
                    HStack {
                        if let first = history.first {
                            Text(dateFormatter.string(from: first.date))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        if let last = history.last, history.count > 1 {
                            Text(dateFormatter.string(from: last.date))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .offset(y: height + 10)
                }
                .padding()
                .background(Color.white)
            }
        }
    }
}

// MARK: - Medical Status Calculation (ACCURATE)

/// Calculate medically accurate status from value and reference range
/// NEVER returns "Normal" without a valid range
func calculateParameterStatus(value: Double, normalRange: String, refMin: Double? = nil, refMax: Double? = nil) -> String {
    // Priority 1: Use explicit numeric ranges from data
    if let min = refMin, let max = refMax {
        return assessValue(value, min: min, max: max, source: "Lab")
    }
    
    // Priority 2: Parse normalRange string if numeric
    if !normalRange.isEmpty, let parsedRange = parseNormalRange(normalRange) {
        return assessValue(value, min: parsedRange.min, max: parsedRange.max, source: "Parsed")
    }
    
    // Priority 3: No valid range available
    return "Unknown"
}

private func assessValue(_ value: Double, min: Double, max: Double, source: String) -> String {
    if value < min {
        let percentBelow = ((min - value) / min) * 100
        if percentBelow > 15 {
            return "Low"
        } else {
            return "Borderline Low"
        }
    } else if value > max {
        let percentAbove = ((value - max) / max) * 100
        if percentAbove > 15 {
            return "High"
        } else {
            return "Borderline High"
        }
    } else {
        return "Normal"
    }
}

private func parseNormalRange(_ range: String) -> (min: Double, max: Double)? {
    // Try to parse patterns like "70-100", "70 - 100", "70 to 100"
    let cleaned = range.replacingOccurrences(of: " ", with: "")
    let patterns = ["-", "to", "–", "—"]
    
    for pattern in patterns {
        let components = cleaned.components(separatedBy: pattern)
        if components.count == 2,
           let min = Double(components[0].filter { $0.isNumber || $0 == "." }),
           let max = Double(components[1].filter { $0.isNumber || $0 == "." }) {
            return (min, max)
        }
    }
    
    return nil
}

struct StatusTag: View {
    let status: String
    
    var color: Color {
        let s = status.lowercased()
        if s.contains("normal") || s.contains("optimal") { return .green }
        if s.contains("high") && s.contains("borderline") { return .orange }
        if s.contains("low") && s.contains("borderline") { return .orange }
        if s.contains("high") || s.contains("abnormal") { return .red }
        if s.contains("low") { return .red }
        if s.contains("unknown") { return .gray }
        return .gray
    }
    
    var body: some View {
        Text(status.uppercased())
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .cornerRadius(8)
    }
}

struct ParameterDetailView: View {
    let testName: String
    let latestValue: Double
    let unit: String
    let status: String
    let normalRange: String
    let color: Color
    
    @Environment(\.presentationMode) var presentationMode
    @Query private var allGraphData: [LabGraphDataModel]
    
    private var history: [LabGraphDataModel] {
        allGraphData.filter { $0.parameter.lowercased() == testName.lowercased() }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        ZStack {
            Color.medicalPurpleLight.opacity(0.3).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color.medicalPurpleDeep)
                    }
                    
                    Spacer()
                    
                    Text("Parameter Details")
                        .font(.headline)
                        .foregroundColor(Color.medicalPurpleDeep)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.left").foregroundColor(.clear)
                }
                .padding()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Value Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(testName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.medicalPurpleDeep)
                                
                                Spacer()
                                
                                StatusTag(status: status)
                            }
                            
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text(String(format: "%.1f", latestValue))
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(Color.medicalPurpleDeep)
                                
                                Text(unit)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color.medicalPurpleDeep.opacity(0.6))
                            }
                            
                            if !normalRange.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Normal Range")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(normalRange)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.black)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(24)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
                        .padding(.horizontal)
                        
                        // Graph placeholder
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Historical Trend")
                                .font(.headline)
                                .foregroundColor(Color.medicalPurpleDeep)
                            
                            ParameterGraphView(parameterName: testName, color: color)
                                .frame(height: 300)
                                .cornerRadius(24)
                        }
                        .padding(.horizontal)
                        
                        // About Parameter Section
                        ParameterDescriptionView(testName: testName)
                        .padding(.horizontal)
                        
                        // History List
                        VStack(alignment: .leading, spacing: 16) {
                            Text("History")
                                .font(.headline)
                                .foregroundColor(Color.medicalPurpleDeep)
                            
                            ForEach(history) { entry in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(String(format: "%.1f", entry.value)) \(unit)")
                                        .font(.headline)
                                        .foregroundColor(Color.medicalPurpleDeep)
                                }
                                .padding()
                                .background(Color.medicalPurpleLight.opacity(0.5))
                                .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(.top, 10)
                }
            }
        }
    }
}

// Helper to get descriptions
func getParameterDescription(_ testName: String) -> String {
    let lowercasedName = testName.lowercased()
    let disclaimer = "\n\nThis information is educational only. Please consult your physician for medical advice specific to your situation."
    
    // Blood Count (CBC)
    if lowercasedName.contains("hemoglobin") {
        return "Hemoglobin is a protein in your red blood cells that carries oxygen to your body's organs and tissues and transports carbon dioxide from your organs and tissues back to your lungs." + disclaimer
    } else if lowercasedName.contains("wbc") || lowercasedName.contains("white blood cell") {
        return "White blood cells (leukocytes) are part of the body's immune system. They help the body fight infection and other diseases." + disclaimer
    } else if lowercasedName.contains("rbc") || lowercasedName.contains("red blood cell") {
        return "Red blood cells (erythrocytes) carry oxygen from your lungs to the rest of your body. They also carry carbon dioxide back to your lungs to be exhaled." + disclaimer
    } else if lowercasedName.contains("platelets") {
        return "Platelets (thrombocytes) are colorless blood cells that help blood clot. Platelets stop bleeding by clumping and forming plugs in blood vessel injuries." + disclaimer
    } else if lowercasedName.contains("hematocrit") {
        return "Hematocrit measures the proportion of red blood cells in your blood. It is used to check for conditions like anemia, dehydration, or polycythemia." + disclaimer
        
    // Lipid Panel
    } else if lowercasedName.contains("total cholesterol") {
        return "Total cholesterol is a measure of the total amount of cholesterol in your blood, including LDL (bad) and HDL (good) cholesterol." + disclaimer
    } else if lowercasedName.contains("ldl") {
        return "LDL (Low-Density Lipoprotein) is often called 'bad' cholesterol because high levels can lead to a buildup of cholesterol in your arteries." + disclaimer
    } else if lowercasedName.contains("hdl") {
        return "HDL (High-Density Lipoprotein) is often called 'good' cholesterol because it helps remove other forms of cholesterol from your bloodstream." + disclaimer
    } else if lowercasedName.contains("triglycerides") {
        return "Triglycerides are a type of fat (lipid) found in your blood. When you eat, your body converts any calories it doesn't need to use right away into triglycerides." + disclaimer
        
    // Glucose & Diabetes
    } else if lowercasedName.contains("hba1c") {
        return "HbA1c reflects your average blood sugar levels over the past 2–3 months, helping assess long-term glucose control and diabetes risk." + disclaimer
    } else if lowercasedName.contains("glucose") || lowercasedName.contains("sugar") {
        return "Blood glucose measures the amount of sugar in your blood. It's the main source of energy for your body's cells." + disclaimer
    } else if lowercasedName.contains("insulin") {
        return "Insulin is a hormone that helps your body use glucose for energy. Fasting insulin levels can help assess insulin resistance." + disclaimer
        
    // Liver Function
    } else if lowercasedName.contains("alt") || lowercasedName.contains("sgpt") {
        return "ALT (Alanine Transaminase) is an enzyme found mostly in the liver. High levels can indicate liver damage." + disclaimer
    } else if lowercasedName.contains("ast") || lowercasedName.contains("sgot") {
        return "AST (Aspartate Transaminase) is an enzyme found in the liver and other tissues. High levels can indicate liver damage or muscle injury." + disclaimer
    } else if lowercasedName.contains("bilirubin") {
        return "Bilirubin is a yellowish substance in your blood. It forms after red blood cells break down, and it travels through your liver, gallbladder, and digestive tract before being excreted." + disclaimer
    } else if lowercasedName.contains("albumin") {
        return "Albumin is a protein made by your liver. It helps keep fluid in your bloodstream so it doesn't leak into other tissues." + disclaimer
        
    // Kidney Function
    } else if lowercasedName.contains("creatinine") {
        return "Creatinine is a waste product that comes from the normal wear and tear on muscles of the body. It is filtered out by the kidneys, so its level in the blood is a good indicator of kidney function." + disclaimer
    } else if lowercasedName.contains("egfr") || lowercasedName.contains("gfr") {
        return "eGFR (Estimated Glomerular Filtration Rate) is a test used to check how well the kidneys are working. It estimates how much blood passes through the tiny filters in the kidneys, called glomeruli, each minute." + disclaimer
    } else if lowercasedName.contains("bun") || lowercasedName.contains("urea") {
        return "BUN (Blood Urea Nitrogen) measures the amount of nitrogen in your blood that comes from the waste product urea. It is used to evaluate kidney function." + disclaimer
    } else if lowercasedName.contains("uric acid") {
        return "Uric acid is a waste product found in blood. It's created when the body breaks down chemicals called purines." + disclaimer
        
    // Thyroid
    } else if lowercasedName.contains("tsh") {
        return "TSH (Thyroid Stimulating Hormone) is produced by the pituitary gland. It tells your thyroid gland how much thyroid hormone to make." + disclaimer
    } else if lowercasedName.contains("t4") {
        return "T4 (Thyroxine) is the main hormone secreted into the bloodstream by the thyroid gland. It plays a vital role in metabolism." + disclaimer
    } else if lowercasedName.contains("t3") {
        return "T3 (Triiodothyronine) is a thyroid hormone that plays vital roles in the body's metabolic rate, heart and digestive functions, muscle control, and brain development." + disclaimer
        
    // Vitals
    } else if lowercasedName.contains("heart rate") || lowercasedName.contains("pulse") || lowercasedName.contains("bpm") {
        return "Heart rate is the number of times your heart beats per minute. It is a key indicator of cardiovascular health and fitness." + disclaimer
    } else if lowercasedName.contains("blood pressure") || lowercasedName.contains("bp") {
        return "Blood pressure is the force of your blood pushing against the walls of your arteries. High blood pressure puts extra strain on your heart and blood vessels." + disclaimer
    } else if lowercasedName.contains("spo2") || lowercasedName.contains("oxygen") {
        return "SpO2 (Oxygen Saturation) measures the percentage of hemoglobin in your blood that is carrying oxygen." + disclaimer
    } else if lowercasedName.contains("bmi") {
        return "BMI (Body Mass Index) is a measure of body fat based on height and weight that applies to adult men and women." + disclaimer
        
    } else {
        return "This is a standard medical parameter detected in your report. Please consult your physician for a personalized interpretation of these results in the context of your overall health."
    }
}

// MARK: - API-Powered Parameter Description
struct ParameterDescriptionView: View {
    let testName: String
    @State private var description: String = "Loading insights..."
    @State private var isLoading = true
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About this parameter")
                .font(.headline)
                .foregroundColor(Color.medicalPurpleDeep)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Fetching AI insights...")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            } else {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Text("Disclaimer: This information is educational only. Please consult your physician for medical advice.")
                .font(.system(size: 10))
                .foregroundColor(.gray.opacity(0.6))
                .padding(.top, 4)
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
        .task {
            // Fetch profile for context
            let descriptor = FetchDescriptor<UserProfileModel>()
            let profile = (try? modelContext.fetch(descriptor))?.first
            
            let age = profile?.age ?? 30
            let gender = profile?.gender ?? "Unknown"
            
            let info = await ChatService.shared.getParameterInfo(
                parameterName: testName,
                age: age,
                gender: gender
            )
            
            await MainActor.run {
                description = info.description
                isLoading = false
            }
        }
    }
}
