import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore
import Combine

// MARK: - Real Firebase Authentication Service
// Replaces the previous mock implementation with actual Firebase Auth

final class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: FirebaseAuth.User?
    
    private let db = Firestore.firestore()
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    
    private init() {
        // Listen to Auth state changes
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = (user != nil)
                print("🔐 [FirebaseAuth] State changed. User: \(user?.uid ?? "nil")")
            }
        }
    }
    
    deinit {
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Authentication Methods
    
    /// Signs in with Email and Password
    func signIn(email: String, password: String) async throws -> String {
         let result = try await Auth.auth().signIn(withEmail: email, password: password)
         print("✅ [FirebaseAuth] Signed in: \(result.user.uid)")
         return result.user.uid
    }
    
    /// Signs up a new user with Email and Password
    func signUp(email: String, password: String) async throws -> String {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let uid = result.user.uid
        print("✅ [FirebaseAuth] Account created: \(uid)")
        
        // Create initial user document in Firestore
        try await createInitialUserRecord(uid: uid, email: email)
        
        return uid
    }
    
    /// Ensures an anonymous user exists (Guest Mode)
    func ensureAnonymousUser() async throws -> String {
        if let user = Auth.auth().currentUser {
            return user.uid
        }
        
        // Attempt anonymous sign-in, but fallback to local UUID if it fails
        do {
            let result = try await Auth.auth().signInAnonymously()
            print("👤 [FirebaseAuth] Signed in anonymously: \(result.user.uid)")
            return result.user.uid
        } catch {
            // Fallback for offline or misconfigured Firebase
            let localId = "local_\(UUID().uuidString)"
            print("⚠️ [FirebaseAuth] Anonymous sign-in failed, using local ID: \(localId)")
            return localId
        }
    }
    
    /// Signs out the current user
    func signOut() throws {
        try Auth.auth().signOut()
        print("👋 [FirebaseAuth] Signed out")
    }
    
    /// Get current User ID
    func getCurrentUserID() -> String? {
        return Auth.auth().currentUser?.uid
    }
    
    // MARK: - Firestore User Management
    
    /// Creates a basic user record in Firestore after sign up
    private func createInitialUserRecord(uid: String, email: String) async throws {
        let userData: [String: Any] = [
            "uid": uid,
            "email": email,
            "createdAt": FieldValue.serverTimestamp(),
            "isAnonymous": false,
            "accountType": "standard"
        ]
        
        try await db.collection("users").document(uid).setData(userData)
        print("📂 [Firestore] User record created for \(uid)")
    }
}


// MARK: - Mock Sync Service (Retained for Compatibility)
// If you implement real sync later, replace this too.

final class FirebaseSyncService {
    static let shared = FirebaseSyncService()
    private init() {}
    
    func sync() async {
        // Real sync logic would go here
    }
    
    func startAutoSync() {
        // Real sync listeners would start here
    }
    
    func syncMedication(_ medication: Any) async throws {
        // Placeholder
    }
}
