import SwiftUI
import SwiftData
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Premium Onboarding View
// A clinical-grade, 5-step onboarding experience for the MediSync diabetes platform.

struct PostLoginSetupView: View {
    
    // MARK: - Navigation State
    enum SetupPhase {
        case onboarding
        case welcome
    }
    
    @State private var currentPhase: SetupPhase = .onboarding
    @State private var currentStep = 0  // 0-indexed: 0,1,2,3,4
    @ObservedObject private var appManager = AppManager.shared
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Step Titles
    private let stepTitles = [
        "Diabetes Type",
        "Treatment Plan", 
        "Risk Factors",
        "Personal Info",
        "Privacy & Terms"
    ]
    
    // MARK: - Diabetes Data (Step 0 & 1)
    @State private var diabetesType: String = ""
    @State private var diagnosisYear: String = ""
    @State private var treatmentType: String = ""
    
    // MARK: - Risk Factors (Step 2)
    @State private var selectedComorbidities: Set<String> = []
    @State private var familyHistory: Bool = false
    @State private var hasHypoglycemiaHistory: Bool = false
    
    // MARK: - Personal Info (Step 3)
    @State private var userName: String = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var gender: String = "Male"
    @State private var height: String = ""
    @State private var weight: String = ""
    @State private var waistCircumference: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var profilePhotoData: Data? = nil
    
    // MARK: - Initial Vitals (Step 3)
    @State private var fastingGlucose: String = ""
    @State private var postMealGlucose: String = ""
    @State private var systolicBP: String = ""
    @State private var diastolicBP: String = ""
    
    // MARK: - Privacy (Step 4)
    @State private var enableAI = true
    @State private var hasAgreed = false
    @State private var showPrivacy = false
    @State private var showTerms = false
    
    // MARK: - Constants
    private let diabetesTypes = [
        ("Type 1", "syringe.fill", "Insulin-dependent, autoimmune"),
        ("Type 2", "pills.fill", "Insulin resistance, lifestyle-linked"),
        ("Prediabetes", "exclamationmark.triangle.fill", "Elevated glucose, preventable"),
        ("Gestational", "figure.and.child.holdinghands", "Pregnancy-related")
    ]
    
    private let treatmentOptions = [
        ("Insulin Therapy", "syringe.fill", "Basal, bolus, or pump"),
        ("Oral Medications", "pills.fill", "Metformin, sulfonylureas, etc."),
        ("Injectable (GLP-1)", "cross.vial.fill", "Ozempic, Trulicity, etc."),
        ("Lifestyle Only", "leaf.fill", "Diet and exercise")
    ]
    
    private let comorbidityOptions = [
        ("Hypertension", "heart.fill"),
        ("Dyslipidemia", "drop.triangle.fill"),
        ("Neuropathy", "hand.raised.fingers.spread.fill"),
        ("Retinopathy", "eye.fill"),
        ("Kidney Disease", "kidney.fill"),
        ("Obesity", "figure.arms.open")
    ]
    
    private let genderOptions = ["Male", "Female", "Other"]
    
    // MARK: - Theme Colors
    private let primaryGradient = LinearGradient(
        colors: [Color(red: 0.4, green: 0.3, blue: 0.8), Color(red: 0.65, green: 0.55, blue: 0.95)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let vibrantPurple = Color(red: 0.65, green: 0.55, blue: 0.95)
    private let deepPurple = Color(red: 0.25, green: 0.15, blue: 0.45)
    
    // MARK: - Computed Properties
    
    private var calculatedAge: Int {
        let components = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date())
        return components.year ?? 30
    }
    
    private var calculatedBMI: Double? {
        guard let h = Double(height), let w = Double(weight), h > 0 else { return nil }
        let heightM = h / 100.0
        return w / (heightM * heightM)
    }
    
    private var bmiStatus: String {
        guard let bmi = calculatedBMI else { return "" }
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        case 30..<35: return "Obese I"
        default: return "Obese II+"
    }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return !diabetesType.isEmpty
        case 1: return !treatmentType.isEmpty
        case 2: return true // Risk factors optional
        case 3: return !userName.isEmpty && !height.isEmpty && !weight.isEmpty
        case 4: return hasAgreed
        default: return false
        }
    }
    
    private var progressPercentage: Double {
        Double(currentStep + 1) / Double(stepTitles.count)
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Premium Gradient Background
            primaryGradient
                .ignoresSafeArea()
            
            switch currentPhase {
            case .onboarding:
                onboardingContent
                    .transition(.opacity)
            case .welcome:
                Color.clear
                    .onAppear {
                        appManager.completeQuestionnaire()
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentPhase)
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
    
    // MARK: - Onboarding Content
    
    private var onboardingContent: some View {
        VStack(spacing: 0) {
            // Header with Progress
            headerSection
            
            // Main Card
            mainCard
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Back Button + Title
            HStack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text(stepTitles[currentStep])
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Placeholder for symmetry
                Circle()
                    .fill(Color.clear)
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            
            // Progress Ring
            progressRing
                .padding(.top, 10)
        }
    }
    
    private var progressRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 6)
                .frame(width: 70, height: 70)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progressPercentage)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5), value: progressPercentage)
            
            // Step number
            VStack(spacing: 0) {
                Text("\(currentStep + 1)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("of \(stepTitles.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    // MARK: - Main Card
    
    private var mainCard: some View {
        VStack(spacing: 0) {
            // Step Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) { // Increased spacing
                    stepContent
                        .padding(.horizontal, 24)
                        .padding(.top, 40) // Increased top padding
                        .padding(.bottom, 40) // Increased bottom padding
                }
            }
            
            // Navigation Footer
            navigationFooter
        }
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 30, x: 0, y: -5)
        )
        .padding(.top, 24)
        .ignoresSafeArea(.container, edges: .bottom)
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0: diabetesTypeStep
        case 1: treatmentStep
        case 2: riskFactorsStep
        case 3: personalInfoStep
        case 4: privacyStep
        default: EmptyView()
        }
    }
    
    // MARK: - Step 0: Diabetes Type
    
    private var diabetesTypeStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                title: "What type of diabetes do you have?",
                subtitle: "This helps us personalize your glucose targets and alerts."
            )
            
            VStack(spacing: 12) {
                ForEach(diabetesTypes, id: \.0) { type, icon, description in
                    PremiumSelectionCard(
                        title: type,
                        subtitle: description,
                        icon: icon,
                        isSelected: diabetesType == type,
                        action: { withAnimation(.spring(response: 0.3)) { diabetesType = type } }
                    )
                }
            }
            
            // Diagnosis Year
            VStack(alignment: .leading, spacing: 10) {
                Text("Year of Diagnosis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(deepPurple)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(vibrantPurple)
                    TextField("e.g. 2020", text: $diagnosisYear)
                        .keyboardType(.numberPad)
                }
                .padding()
                .background(Color.gray.opacity(0.06))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Step 1: Treatment
    
    private var treatmentStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                title: "How are you managing your diabetes?",
                subtitle: "Your treatment type affects our safety alerts and medication tracking."
            )
            
            VStack(spacing: 12) {
                ForEach(treatmentOptions, id: \.0) { option, icon, description in
                    PremiumSelectionCard(
                        title: option,
                        subtitle: description,
                        icon: icon,
                        isSelected: treatmentType == option,
                        action: { withAnimation(.spring(response: 0.3)) { treatmentType = option } }
                    )
                }
            }
        }
    }
    
    // MARK: - Step 2: Risk Factors
    
    private var riskFactorsStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                title: "Any related health conditions?",
                subtitle: "This helps us assess complication risks and customize monitoring."
            )
            
            // Comorbidities Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(comorbidityOptions, id: \.0) { condition, icon in
                    ComorbidityChip(
                        title: condition,
                        icon: icon,
                        isSelected: selectedComorbidities.contains(condition),
                        action: {
                            withAnimation(.spring(response: 0.3)) {
                                if selectedComorbidities.contains(condition) {
                                    selectedComorbidities.remove(condition)
                                } else {
                                    selectedComorbidities.insert(condition)
                                }
                            }
                        }
                    )
                }
            }
            
            // Additional Risk Toggles
            VStack(spacing: 12) {
                RiskToggleRow(
                    title: "Family history of diabetes",
                    subtitle: "Parent or sibling with diabetes",
                    isOn: $familyHistory
                )
                
                RiskToggleRow(
                    title: "History of severe hypoglycemia",
                    subtitle: "Required assistance in past",
                    isOn: $hasHypoglycemiaHistory
                )
            }
            .padding(.top, 10)
        }
    }

    // MARK: - Step 3: Personal Info (Refactored)
    
    private var personalInfoStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            stepHeader(
                title: "Tell us about yourself",
                subtitle: "Used for personalized targets and BMI calculation."
            )
            
            // Photo + Name
            HStack(spacing: 24) {
                // Photo
                VStack {
                    if let data = profilePhotoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(vibrantPurple, lineWidth: 3))
                            .shadow(radius: 5)
                    } else {
                        Circle()
                        .fill(vibrantPurple.opacity(0.1))
                            .frame(width: 90, height: 90)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(vibrantPurple.opacity(0.5))
                            )
                    }
                    
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text("Add Photo")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(vibrantPurple)
                            .padding(.top, 4)
                    }
                    .onChange(of: selectedPhotoItem) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                profilePhotoData = data
                            }
                        }
                    }
                }
                
                // Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("FULL NAME")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray.opacity(0.8))
                        .tracking(1.0)
                    
                    TextField("Your Name", text: $userName)
                        .font(.system(size: 20, weight: .medium))
                        .padding(.vertical, 12)
                        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.3)), alignment: .bottom)
                }
            }
            
            // Date of Birth (Professional Row)
            VStack(alignment: .leading, spacing: 10) {
                Text("DATE OF BIRTH")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray.opacity(0.8))
                    .tracking(1.0)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(vibrantPurple)
                        .font(.system(size: 20))
                    
                    DatePicker("", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .accentColor(vibrantPurple)
                        
                    Spacer()
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.02), radius: 5, x: 0, y: 2)
            }
            
            // Gender (Professional Row)
            VStack(alignment: .leading, spacing: 10) {
                Text("GENDER")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray.opacity(0.8))
                    .tracking(1.0)
                    
                Picker("", selection: $gender) {
                    ForEach(genderOptions, id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
            }
            
            // Height + Weight + BMI
            HStack(spacing: 16) {
                MetricField(label: "HEIGHT", placeholder: "cm", text: $height)
                MetricField(label: "WEIGHT", placeholder: "kg", text: $weight)
            }
            
            // BMI Display Card
            if let bmi = calculatedBMI {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BMI SCORE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray.opacity(0.8))
                        
                        Text(String(format: "%.1f", bmi))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(deepPurple)
                    }
                    
                    Spacer()
                    
                    Text(bmiStatus)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(bmiStatusColor)
                        .clipShape(Capsule())
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(16)
            }
            
            // Initial Vitals Section
            VStack(alignment: .leading, spacing: 16) {
                Text("OPTIONAL: INITIAL VITALS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray.opacity(0.8))
                    .tracking(1.0)
                
                Text("Add your latest readings for personalized targets")
                    .font(.footnote)
                    .foregroundColor(.gray)
                
                HStack(spacing: 16) {
                    MetricField(label: "FASTING GLUCOSE", placeholder: "mg/dL", text: $fastingGlucose)
                    MetricField(label: "POST-MEAL GLUCOSE", placeholder: "mg/dL", text: $postMealGlucose)
                }
                
                HStack(spacing: 16) {
                    MetricField(label: "SYSTOLIC BP", placeholder: "mmHg", text: $systolicBP)
                    MetricField(label: "DIASTOLIC BP", placeholder: "mmHg", text: $diastolicBP)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.03))
            .cornerRadius(16)
        }
    }
    
    private var bmiStatusColor: Color {
        guard let bmi = calculatedBMI else { return .gray }
        switch bmi {
        case ..<18.5: return .orange
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }
    
    // MARK: - Step 4: Privacy
    
    private var privacyStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(
                title: "Privacy & Legal",
                subtitle: "Please review and accept the following before continuing."
            )
            
            // MEDICAL DISCLAIMER - CRITICAL FOR APP STORE
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Medical Disclaimer")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(deepPurple)
                }
                
                Text("Diabo is designed for informational purposes only. It does NOT provide medical advice, diagnosis, or treatment. Always consult a qualified healthcare professional for medical decisions. Never disregard professional medical advice or delay seeking it because of information provided by this app.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.orange.opacity(0.08))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
            
            // Info boxes
            VStack(spacing: 10) {
                InfoBox(
                    icon: "lock.fill",
                    color: .green,
                    text: "Your data is encrypted and stored locally on your device."
                )
                
                InfoBox(
                    icon: "hand.raised.fill",
                    color: .blue,
                    text: "We never sell or share your personal health information."
                )
            }
            
            // Legal Links
            HStack(spacing: 24) {
                Button(action: { showPrivacy = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.caption)
                        Text("Privacy Policy")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(vibrantPurple)
                }
                
                Button(action: { showTerms = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.caption)
                        Text("Terms of Service")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(vibrantPurple)
                }
            }
            .padding(.top, 4)
            
            Divider().padding(.vertical, 8)
            
            // Consent Toggles
            VStack(spacing: 14) {
                Toggle(isOn: $enableAI) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundColor(vibrantPurple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable AI Insights")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(deepPurple)
                            Text("Personalized trend analysis and alerts")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: vibrantPurple))
                .padding(14)
                .background(Color.gray.opacity(0.04))
                .cornerRadius(14)
                
                Toggle(isOn: $hasAgreed) {
                    HStack(spacing: 12) {
                        Image(systemName: hasAgreed ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(hasAgreed ? .green : .gray)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("I Agree")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(deepPurple)
                            Text("I have read and accept the Medical Disclaimer, Privacy Policy, and Terms of Service.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: vibrantPurple))
                .padding(14)
                .background(hasAgreed ? vibrantPurple.opacity(0.08) : Color.gray.opacity(0.04))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(hasAgreed ? vibrantPurple.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
            }
        }
    }
    
    // MARK: - Navigation Footer
    
    private var navigationFooter: some View {
        HStack {
            // Step indicator
            Text("Step \(currentStep + 1) of \(stepTitles.count)")
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            // Next Button
            Button(action: nextStep) {
                HStack(spacing: 8) {
                    Text(currentStep == 4 ? "Get Started" : "Continue")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    
                    if currentStep < 4 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(canProceed ? vibrantPurple : Color.gray.opacity(0.3))
                .cornerRadius(16)
                .shadow(color: canProceed ? vibrantPurple.opacity(0.4) : .clear, radius: 10, x: 0, y: 5)
            }
            .disabled(!canProceed)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Color.white)
    }
    
    // MARK: - Helper Views
    
    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(deepPurple)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Actions
    
    private func goBack() {
        if currentStep > 0 {
            withAnimation { currentStep -= 1 }
        } else {
            appManager.backToAuth()
        }
    }
    
    private func nextStep() {
        if currentStep < 4 {
            withAnimation { currentStep += 1 }
        } else {
            // Save data before transition to welcome loop
            saveProfileData()
            withAnimation { currentPhase = .welcome }
        }
    }
    
    private func saveProfileData() {
        // Build comorbidities list
        var allComorbidities = Array(selectedComorbidities)
        if hasHypoglycemiaHistory {
            allComorbidities.append("Hypoglycemia History")
        }
        
        // Delete existing profile if exists
        // Check if this is a new identity (wiping old data if so)
        let descriptor = FetchDescriptor<UserProfileModel>()
        var shouldWipeData = false
        
        if let existingProfiles = try? modelContext.fetch(descriptor), let existingProfile = existingProfiles.first {
            // If the name is different, assume it's a new user and wipe previous data
            // (Case-insensitive comparison for better UX)
            if existingProfile.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != userName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                shouldWipeData = true
            }
            
            // We always replace the profile object with the fresh one
            for p in existingProfiles { modelContext.delete(p) }
        } else {
            // No saved profile? Wipe to ensure a clean slate for the first user
            shouldWipeData = true
        }
        
        if shouldWipeData {
            print("⚠️ [PostLoginSetup] Detected new user identity. Wiping all previous medical data.")
            modelContext.clearAllData()
        } else {
            print("✅ [PostLoginSetup] Recognizing returning user. Preserving medical data.")
        }
        
        // Create new profile
        let profile = UserProfileModel(
            name: userName,
            age: calculatedAge,
            gender: gender.lowercased(),
            height: Double(height),
            weight: Double(weight),
            profilePhotoData: profilePhotoData,
            enableAI: enableAI,
            diabetesType: diabetesType,
            diagnosisYear: Int(diagnosisYear),
            treatmentType: treatmentType,
            comorbidities: allComorbidities,
            familyHistory: familyHistory ? "Yes" : "None"
        )
        
        modelContext.insert(profile)
        
        // Save initial vitals as LabResultModel entries
        if let fgValue = Double(fastingGlucose), fgValue > 0 {
            let fastingResult = LabResultModel(
                testName: "Fasting Glucose",
                value: fgValue,
                unit: "mg/dL",
                normalRange: "70-99",
                status: fgValue < 100 ? "Normal" : (fgValue < 126 ? "Borderline" : "High"),
                category: "Diabetes"
            )
            modelContext.insert(fastingResult)
            print("✅ [PostLoginSetup] Saved Fasting Glucose: \(fgValue) mg/dL")
        }
        
        if let pmValue = Double(postMealGlucose), pmValue > 0 {
            let postMealResult = LabResultModel(
                testName: "Post-Meal Glucose",
                value: pmValue,
                unit: "mg/dL",
                normalRange: "< 140",
                status: pmValue < 140 ? "Normal" : (pmValue < 180 ? "Borderline" : "High"),
                category: "Diabetes"
            )
            modelContext.insert(postMealResult)
            print("✅ [PostLoginSetup] Saved Post-Meal Glucose: \(pmValue) mg/dL")
        }
        
        if let sysValue = Double(systolicBP), sysValue > 0 {
            let diaValue = Double(diastolicBP) ?? 0
            let bpStatus: String
            if sysValue < 120 && diaValue < 80 {
                bpStatus = "Normal"
            } else if sysValue < 130 && diaValue < 85 {
                bpStatus = "Elevated"
            } else {
                bpStatus = "High"
            }
            
            let bpResult = LabResultModel(
                testName: "Blood Pressure (Systolic)",
                value: sysValue,
                unit: "mmHg",
                normalRange: "< 120",
                status: bpStatus,
                category: "Cardiovascular"
            )
            modelContext.insert(bpResult)
            
            if diaValue > 0 {
                let diaResult = LabResultModel(
                    testName: "Blood Pressure (Diastolic)",
                    value: diaValue,
                    unit: "mmHg",
                    normalRange: "< 80",
                    status: bpStatus,
                    category: "Cardiovascular"
                )
                modelContext.insert(diaResult)
            }
            print("✅ [PostLoginSetup] Saved Blood Pressure: \(sysValue)/\(diaValue) mmHg")
        }
        
        do {
            try modelContext.save()
            print("✅ [PostLoginSetup] Profile saved: \(userName), Type: \(diabetesType)")
        } catch {
            print("❌ [PostLoginSetup] Failed to save profile: \(error)")
        }
    }
}

// MARK: - Supporting Components

struct PremiumSelectionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    private let vibrantPurple = Color(red: 0.65, green: 0.55, blue: 0.95)
    private let deepPurple = Color(red: 0.25, green: 0.15, blue: 0.45)
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : vibrantPurple)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? vibrantPurple : vibrantPurple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(deepPurple)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(vibrantPurple)
                }
            }
            .padding(16)
            .background(isSelected ? vibrantPurple.opacity(0.08) : Color.gray.opacity(0.04))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? vibrantPurple.opacity(0.4) : Color.gray.opacity(0.1), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ComorbidityChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    private let vibrantPurple = Color(red: 0.65, green: 0.55, blue: 0.95)
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(isSelected ? vibrantPurple : Color.gray.opacity(0.08))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RiskToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    private let vibrantPurple = Color(red: 0.65, green: 0.55, blue: 0.95)
    private let deepPurple = Color(red: 0.25, green: 0.15, blue: 0.45)
    
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(deepPurple)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: vibrantPurple))
        .padding(16)
        .background(Color.gray.opacity(0.04))
        .cornerRadius(14)
    }
}

struct MetricField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.gray)
            
            HStack {
                TextField("", text: $text)
                    .keyboardType(.numberPad)
                    .font(.system(size: 16, weight: .medium))
                Text(placeholder)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.06))
            .cornerRadius(12)
        }
    }
}

struct InfoBox: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.75))
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06))
        .cornerRadius(14)
    }
}


// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
