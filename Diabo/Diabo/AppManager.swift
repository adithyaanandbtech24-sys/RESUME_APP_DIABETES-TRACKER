import SwiftUI
import Combine
import FirebaseAuth
import WebKit
import SwiftData
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum AppFlowState {
    case allInOneDashboard  // New: Animated feature showcase
    case auth
    case setup
    case welcomeAnimation
    case main
}

@MainActor
final class AppManager: ObservableObject {
    static let shared = AppManager()
    
    // Published State
    @Published var appState: AppFlowState = .allInOneDashboard
    @Published var isGuestMode: Bool = false
    
    // Guest Limits
    @AppStorage("guestUploadCount") var guestUploadCount: Int = 0
    let guestUploadLimit = 2
    
    // Demo Mode (For "Any Email" login with unlimited uploads)
    @Published var isDemoMode: Bool = false
    
    @AppStorage("hasSeenPrologue") private var hasSeenPrologue: Bool = false
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        determineInitialState()
        
        // Listen for auth changes to handle transitions
        FirebaseAuthService.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                self?.handleAuthChange(isAuthenticated: isAuthenticated)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - State Logic
    
    func determineInitialState() {
        // Check if user has completed onboarding before
        if hasSeenPrologue && hasCompletedSetup {
            // User has completed full onboarding - go to main
            if FirebaseAuthService.shared.isAuthenticated {
                appState = .main
            } else {
                // They completed before but logged out - go to auth
                appState = .auth
            }
        } else if hasSeenPrologue {
            // Seen prologue but not completed setup
            if FirebaseAuthService.shared.isAuthenticated {
                appState = .setup
            } else {
                appState = .auth
            }
        } else {
            // First time user - show onboarding
            appState = .allInOneDashboard
        }
    }
    
    private func handleAuthChange(isAuthenticated: Bool) {
        // DON'T override All-in-One Dashboard state
        // Only handle auth changes AFTER user has seen the onboarding
        if appState == .allInOneDashboard {
            return // Don't change state - let user see All-in-One Dashboard first
        }
        
        if isAuthenticated {
            let user = FirebaseAuthService.shared.currentUser
            if let user = user, !user.isAnonymous {
                isGuestMode = false
            } else if let user = user, user.isAnonymous == true {
                isGuestMode = true
            }
            
            if hasCompletedSetup {
                appState = .main
            } else {
                appState = .setup
            }
        } else if !isGuestMode {
            hasSeenPrologue = false
            appState = .allInOneDashboard
        }
    }
    
    // MARK: - Actions
    
    func completeAllInOneDashboard() {
        hasSeenPrologue = true
        appState = .auth
    }
    
    func enterGuestMode() {
        isGuestMode = true
        isDemoMode = false
        // Guests must also go through setup now
        appState = .setup
    }
    
    func enterDemoMode() {
        // "Fake" Authenticated User
        isGuestMode = false // Unlimited uploads
        isDemoMode = true
        appState = .setup
    }
    
    func completeSetup() {
        hasCompletedSetup = true
        appState = .main
    }
    
    func completeQuestionnaire() {
        appState = .welcomeAnimation
    }
    
    func signOut() {
        try? FirebaseAuthService.shared.signOut()
        isGuestMode = false
        appState = .auth
        // Note: We don't reset 'hasSeenPrologue'
    }
    
    func backToAllInOneDashboard() {
        hasSeenPrologue = false
        appState = .allInOneDashboard
    }
    
    func backToAuth() {
        isGuestMode = false
        appState = .auth
    }
    
    func logout() {
        // Clear guest uploads for privacy
        guestUploadCount = 0 
        appState = .auth
    }
    
    func resetApp() {
        guestUploadCount = 0
        appState = .auth
        // In a real app, you'd also wipe UserDefaults and local files here
    }
    
    /// Navigate to auth screen for sign up (from guest limit modal)
    func showAuthForSignUp() {
        isGuestMode = false
        appState = .auth
    }
    
    /// Navigate to auth screen for sign in (from guest limit modal)
    func showAuthForSignIn() {
        isGuestMode = false
        appState = .auth
    }
    
    // MARK: - Guest Logic
    
    func canUploadInGuestMode() -> Bool {
        if !isGuestMode { return true }
        return guestUploadCount < guestUploadLimit
    }
    
    func incrementGuestUploadCount() {
        if isGuestMode {
            guestUploadCount += 1
        }
    }
    
    func checkGuestLimit() throws {
        if isGuestMode && guestUploadCount >= guestUploadLimit {
            throw AppError.guestLimitReached
        }
    }
}


enum AppError: LocalizedError {
    case guestLimitReached
    
    var errorDescription: String? {
        switch self {
        case .guestLimitReached:
            return "Guest upload limit reached."
        }
    }
}

// MARK: - WebPortalPreviewView and SharedAccessService (Combined for accessibility)

struct WebPortalPreviewView: UIViewRepresentable {
    let url: URL?
    let htmlContent: String?
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let html = htmlContent {
            uiView.loadHTMLString(html, baseURL: nil)
        } else if let url = url {
            uiView.load(URLRequest(url: url))
        }
    }
}

struct PreviewSheet: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            WebPortalPreviewView(url: nil, htmlContent: SharedAccessService.doctorPortalHTML)
                .navigationTitle("Doctor's View")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Shared Access Service
@MainActor
final class SharedAccessService: ObservableObject {
    static let shared = SharedAccessService()
    
    private let webViewerBaseURL = "https://medisync-diabo.web.app/share"
    
    private init() {}
    
    func generateLink(for audience: ShareAudience, expiryHours: Int) async throws -> (url: String, expiry: Date) {
        let userId = FirebaseAuthService.shared.currentUser?.uid ?? "local-user-\(UUID().uuidString)"
        let token = UUID().uuidString
        let expiryDate = Date().addingTimeInterval(TimeInterval(expiryHours * 3600))
        
        // 3. Create Link Record
        let linkData: [String: Any] = [
            "id": token,
            "userId": userId,
            "audience": audience.rawValue, // "doctor" or "family"
            "createdAt": Date(),
            "expiresAt": expiryDate,
            "isActive": true,
            "accessLevel": "read-only"
        ]
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        var finalData = linkData
        finalData["createdAt"] = Timestamp(date: Date())
        finalData["expiresAt"] = Timestamp(date: expiryDate)
        
        try await db.collection("shared_links").document(token).setData(finalData)
        #else
        print("📝 [SharedAccess] Simulating Firestore Write: \(linkData)")
        try? await Task.sleep(nanoseconds: 500_000_000)
        #endif
        
        let url = "\(webViewerBaseURL)?token=\(token)"
        return (url, expiryDate)
    }
    
    func revokeLink(token: String) async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try? await db.collection("shared_links").document(token).updateData(["isActive": false])
        #else
        print("🚫 [SharedAccess] Simulating Revoke: \(token)")
        #endif
    }
}

enum ShareAudience: String {
    case doctor = "doctor"
    case family = "family"
}

extension SharedAccessService {
    static let doctorPortalHTML = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MediSync Health Viewer</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/moment.js/2.29.4/moment.min.js"></script>
    <style>.gradient-text { background: linear-gradient(135deg, #6366f1 0%, #a855f7 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }</style>
</head>
<body class="bg-slate-50 min-h-screen text-slate-800 font-sans">
    <div id="dashboard" class="max-w-6xl mx-auto px-4 py-8">
        <header class="flex justify-between items-center mb-10 pb-6 border-b border-slate-200">
            <div class="flex items-center gap-4">
                <div class="w-10 h-10 bg-indigo-600 rounded-xl flex items-center justify-center shadow-lg shadow-indigo-200">
                    <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"></path></svg>
                </div>
                <div>
                    <h1 class="text-2xl font-bold text-slate-900">MediSync <span class="text-indigo-600">Connect</span></h1>
                    <p class="text-sm text-slate-500">Secure Report Viewer (Preview Mode)</p>
                </div>
            </div>
            <div class="text-right"><div class="text-sm font-medium text-slate-900">Patient Data</div><div class="text-xs text-slate-500">Live Preview</div></div>
        </header>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-10">
            <div class="bg-white p-6 rounded-2xl shadow-sm border border-slate-100">
                <span class="text-sm font-medium text-slate-600 flex items-center gap-2">HbA1c</span>
                <div class="text-3xl font-bold text-slate-900 mb-1">6.2%</div>
                <div class="text-xs text-green-600 bg-green-50 inline-block px-2 py-1 rounded-md font-medium">Normal</div>
            </div>
            <div class="bg-white p-6 rounded-2xl shadow-sm border border-slate-100">
                <span class="text-sm font-medium text-slate-600 flex items-center gap-2">Avg Glucose</span>
                <div class="text-3xl font-bold text-slate-900 mb-1">115</div>
                <div class="text-xs text-slate-400">mg/dL</div>
            </div>
            <div class="bg-white p-6 rounded-2xl shadow-sm border border-slate-100">
                <span class="text-sm font-medium text-slate-600 flex items-center gap-2">Blood Pressure</span>
                <div class="text-3xl font-bold text-slate-900 mb-1">125/82</div>
                <div class="text-xs text-amber-600 bg-amber-50 inline-block px-2 py-1 rounded-md font-medium">Attention</div>
            </div>
            <div class="bg-white p-6 rounded-2xl shadow-sm border border-slate-100">
                <span class="text-sm font-medium text-slate-600 flex items-center gap-2">Reports</span>
                <div class="text-3xl font-bold text-slate-900 mb-1">12</div>
                <div class="text-xs text-slate-400">Uploaded</div>
            </div>
        </div>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-10">
            <div class="bg-white p-6 rounded-2xl shadow-sm border border-slate-100">
                <h3 class="text-lg font-bold text-slate-800 mb-6">Glucose Trends</h3>
                <canvas id="glucoseChart" height="250"></canvas>
            </div>
            <div class="bg-white p-6 rounded-2xl shadow-sm border border-slate-100">
                <h3 class="text-lg font-bold text-slate-800 mb-6">Recent Parameters</h3>
                <div class="space-y-4">
                    <div class="flex justify-between items-center p-3 bg-slate-50 rounded-lg"><span class="font-medium text-slate-700">Hemoglobin A1c</span><span class="font-bold text-slate-900">6.2%</span></div>
                    <div class="flex justify-between items-center p-3 bg-slate-50 rounded-lg"><span class="font-medium text-slate-700">Total Cholesterol</span><span class="font-bold text-slate-900">185 mg/dL</span></div>
                    <div class="flex justify-between items-center p-3 bg-slate-50 rounded-lg"><span class="font-medium text-slate-700">Vitamin D</span><span class="font-bold text-slate-900">32 ng/mL</span></div>
                </div>
            </div>
        </div>
    </div>
    <script>
        document.addEventListener('DOMContentLoaded', () => {
            const ctx = document.getElementById('glucoseChart').getContext('2d');
            new Chart(ctx, {
                type: 'line',
                data: {
                    labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
                    datasets: [{
                        label: 'Fasting Glucose (mg/dL)',
                        data: [108, 112, 115, 110, 118, 115],
                        borderColor: '#6366f1',
                        tension: 0.4,
                        fill: true,
                        backgroundColor: 'rgba(99, 102, 241, 0.1)'
                    }]
                },
                options: { responsive: true, plugins: { legend: { display: false } }, scales: { y: { beginAtZero: false } } }
            });
        });
    </script>
</body>
</html>
"""
}
