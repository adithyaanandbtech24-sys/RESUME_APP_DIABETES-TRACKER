import Foundation

/// Service for managing account relationships and access (MOCKED for local-first)
@MainActor
final class AccountManagementService {
    static let shared = AccountManagementService()
    
    private let auth = FirebaseAuthService.shared
    private let roleService = UserRoleService.shared
    
    private init() {}
    
    // MARK: - Family Member Management
    
    /// Add family member by email
    func addFamilyMemberByEmail(
        email: String,
        name: String,
        relationship: String
    ) async throws -> String {
        return "mock-family-uid"
    }
    
    /// Remove family member access
    func removeFamilyMember(familyUid: String) async throws {
        // No-op in local-first
    }
    
    /// Get list of family members
    func getFamilyMembers() async throws -> [FamilyMember] {
        return []
    }
    
    // MARK: - Provider Management
    
    /// Assign provider to current patient
    func assignProvider(providerEmail: String) async throws -> String {
        return "mock-provider-uid"
    }
    
    /// Remove provider access
    func removeProvider(providerUid: String) async throws {
        // No-op in local-first
    }
    
    // MARK: - Provider Patient Management
    
    /// Get list of patients (for providers)
    func getProviderPatients() async throws -> [PatientInfo] {
        return []
    }
    
    /// Switch active patient (for providers)
    func switchActivePatient(patientUid: String) async throws {
        roleService.activePatientId = patientUid
    }
}

// MARK: - Supporting Models

struct FamilyMember {
    let userId: String
    let name: String
    let relationship: String
    let grantedAt: Date
}

struct PatientInfo {
    let userId: String
    let displayName: String
    let email: String
    let assignedAt: Date
}
