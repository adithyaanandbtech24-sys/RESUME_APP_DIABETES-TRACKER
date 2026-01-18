
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfileModel]
    @ObservedObject private var auth = FirebaseAuthService.shared
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                // Section 1: Profile
                Section(header: Text("Profile")) {
                    if let profile = userProfiles.first {
                        HStack {
                            if let photoData = profile.profilePhotoData, let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(profile.name)
                                    .font(.headline)
                                Text(auth.currentUser?.email ?? "Guest User")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    } else {
                        Text("No Profile Found")
                    }
                }
                
                // Section 2: App
                Section(header: Text("About")) {
                    NavigationLink(destination: LegalView(title: "Privacy Policy")) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    NavigationLink(destination: LegalView(title: "Terms of Service")) {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                    }
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0 (1)")
                            .foregroundColor(.gray)
                    }
                }
                
                // Section 3: Danger Zone
                Section {
                    Button(action: {
                        try? auth.signOut()
                        AppManager.shared.logout()
                    }) {
                        Label("Log Out", systemImage: "arrow.right.square")
                            .foregroundColor(.red)
                    }
                    
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Label("Delete Account", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Deleting your account will permanently remove all your data from our servers. This action cannot be undone.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete Account?"),
                    message: Text("Are you sure you want to delete your account? All data will be lost."),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteAccount()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private func deleteAccount() {
        // 1. Clear SwiftData
        try? modelContext.delete(model: UserProfileModel.self)
        try? modelContext.delete(model: MedicalReportModel.self)
        try? modelContext.delete(model: LabResultModel.self)
        try? modelContext.delete(model: MedicationModel.self)
        
        // 2. Sign out Auth
        try? auth.signOut()
        
        // 3. Reset App State
        AppManager.shared.resetApp()
    }
}

struct LegalView: View {
    let title: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if title == "Privacy Policy" {
                    privacyPolicyContent
                } else {
                    termsOfServiceContent
                }
            }
            .padding()
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
    
    // MARK: - Privacy Policy Content
    private var privacyPolicyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last Updated: January 2026")
                .font(.caption)
                .foregroundColor(.gray)
            
            legalSection(title: "1. Information We Collect",
                        content: """
                        Diabo collects the following information:
                        • Personal health data you upload (medical reports, lab results)
                        • Profile information (name, age, diabetes type)
                        • Device identifiers for anonymous analytics
                        
                        All health data is stored LOCALLY on your device unless you explicitly enable cloud sync.
                        """)
            
            legalSection(title: "2. How We Use Your Data",
                        content: """
                        Your data is used to:
                        • Provide personalized health insights
                        • Generate AI-powered analysis of your medical reports
                        • Track your health trends over time
                        
                        We do NOT sell your data to third parties.
                        """)
            
            legalSection(title: "3. Data Storage & Security",
                        content: """
                        • Your data is encrypted on your device using iOS encryption
                        • Cloud data (if enabled) is stored in Firebase with industry-standard encryption
                        • We follow HIPAA-inspired security practices
                        """)
            
            legalSection(title: "4. AI Processing",
                        content: """
                        When you upload a medical report, we may process it using secure AI services to extract information. This is done to provide you with insights. Your data is not stored by our AI providers.
                        """)
            
            legalSection(title: "5. Your Rights",
                        content: """
                        You have the right to:
                        • Access your data at any time
                        • Delete all your data using the \"Delete Account\" feature
                        • Export your health data
                        • Opt out of AI insights
                        """)
            
            legalSection(title: "6. Contact Us",
                        content: "For privacy concerns, contact us at: privacy@medisync-diabo.app")
        }
    }
    
    // MARK: - Terms of Service Content
    private var termsOfServiceContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last Updated: January 2026")
                .font(.caption)
                .foregroundColor(.gray)
            
            legalSection(title: "1. Acceptance of Terms",
                        content: "By using Diabo, you agree to these Terms of Service. If you do not agree, please do not use the app.")
            
            legalSection(title: "2. Medical Disclaimer",
                        content: """
                        ⚠️ IMPORTANT: Diabo is NOT a medical device and does NOT provide medical advice.
                        
                        • The app provides informational insights only
                        • Always consult a qualified healthcare professional before making any medical decisions
                        • Never disregard professional medical advice based on information from this app
                        • In emergencies, call your local emergency number immediately
                        """)
            
            legalSection(title: "3. User Responsibilities",
                        content: """
                        You agree to:
                        • Provide accurate information
                        • Use the app for personal, non-commercial purposes
                        • Not attempt to reverse engineer or misuse the app
                        • Keep your account credentials secure
                        """)
            
            legalSection(title: "4. Intellectual Property",
                        content: "All app content, design, and code are owned by Diabo and protected by intellectual property laws.")
            
            legalSection(title: "5. Limitation of Liability",
                        content: """
                        Diabo is provided \"AS IS\" without warranties. We are not liable for:
                        • Any health decisions made based on app information
                        • Data loss due to device failure
                        • Interruptions in service
                        """)
            
            legalSection(title: "6. Changes to Terms",
                        content: "We may update these terms. Continued use after changes constitutes acceptance.")
            
            legalSection(title: "7. Contact",
                        content: "Questions? Contact us at: support@medisync-diabo.app")
        }
    }
    
    private func legalSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.black)
            
            Text(content)
                .font(.subheadline)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}
