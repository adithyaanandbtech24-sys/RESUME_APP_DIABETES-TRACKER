import Foundation
import Combine

/// User roles in the system
enum UserRole: String, Codable {
    case patient = "PATIENT"
    case family = "FAMILY"
    case provider = "PROVIDER"
}

/// Service for managing user roles and access permissions (MOCKED for local-first)
@MainActor
final class UserRoleService {
    static let shared = UserRoleService()
    
    private let auth = FirebaseAuthService.shared
    
    // Published properties for reactive UI
    @Published var currentUserRole: UserRole? = .patient
    @Published var activePatientId: String? // For providers switching between patients
    
    private init() {}
    
    // MARK: - Role Management
    
    /// Fetch user's role
    func fetchUserRole(uid: String) async throws -> UserRole {
        return .patient
    }
    
    /// Set user's role
    func setUserRole(uid: String, role: UserRole) async throws {
        if uid == auth.getCurrentUserID() {
            currentUserRole = role
        }
    }
    
    /// Get current user's role
    func getCurrentUserRole() async throws -> UserRole {
        return currentUserRole ?? .patient
    }
    
    // MARK: - Family Access Management
    
    func assignFamilyMember(
        patientUid: String,
        familyUid: String,
        familyName: String,
        relationship: String
    ) async throws {
        // No-op in local-first
    }
    
    func removeFamilyMember(patientUid: String, familyUid: String) async throws {
        // No-op in local-first
    }
    
    func checkIfFamilyHasAccess(patientUid: String, familyUid: String) async throws -> Bool {
        return true
    }
    
    func getFamilyMembers(patientUid: String) async throws -> [[String: Any]] {
        return []
    }
    
    // MARK: - Provider Access Management
    
    func assignProviderToPatient(
        providerUid: String,
        patientUid: String,
        permissions: [String] = ["read", "write"]
    ) async throws {
        // No-op in local-first
    }
    
    func removeProviderFromPatient(providerUid: String, patientUid: String) async throws {
        // No-op in local-first
    }
    
    func checkIfProviderHasAccess(providerUid: String, patientUid: String) async throws -> Bool {
        return true
    }
    
    func getProviderPatients(providerUid: String) async throws -> [[String: Any]] {
        return []
    }
    
    // MARK: - Access Control Helpers
    
    func canReadPatientData(patientUid: String) async throws -> Bool {
        return true
    }
    
    func canWritePatientData(patientUid: String) async throws -> Bool {
        return true
    }
    
    // MARK: - User Profile Management
    
    func updateUserProfile(
        uid: String,
        displayName: String,
        email: String,
        role: UserRole
    ) async throws {
        // No-op in local-first
    }
    
    func getUserProfile(uid: String) async throws -> [String: Any] {
        return [
            "displayName": "Demo User",
            "email": "demo@example.com",
            "role": "PATIENT"
        ]
    }
}
