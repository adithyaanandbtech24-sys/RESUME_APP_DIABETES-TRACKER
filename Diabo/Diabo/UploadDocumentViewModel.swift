// UploadDocumentViewModel.swift
import SwiftUI
import SwiftData
import PhotosUI
import Combine
import UIKit

@MainActor
class UploadDocumentViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var documentTitle: String = ""
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var userRole: UserRole = .patient
    @Published var canUpload: Bool = true
    
    // Multi-image tracking
    @Published var currentImageIndex: Int = 0
    @Published var totalImages: Int = 0
    
    private let reportService = ReportService.shared
    private let roleService = UserRoleService.shared
    private let authService = FirebaseAuthService.shared
    
    // MARK: - Initialization
    
    func checkUploadPermissions(patientUid: String? = nil) async {
        // Bypass permission checks for Demo Mode (Fake Auth)
        if AppManager.shared.isDemoMode {
            canUpload = true
            return
        }
        
        do {
            let targetUid = patientUid ?? authService.getCurrentUserID() ?? ""
            userRole = try await roleService.getCurrentUserRole()
            canUpload = try await roleService.canWritePatientData(patientUid: targetUid)
            
            if !canUpload {
                errorMessage = "You don't have permission to upload documents for this patient."
            }
        } catch {
            errorMessage = "Failed to check permissions: \(error.localizedDescription)"
            canUpload = false
        }
    }
    
    // MARK: - Image Selection
    
    func selectImage(_ image: UIImage) {
        selectedImage = image
        errorMessage = nil
        successMessage = nil
    }
    
    // MARK: - Multi-Image Upload
    
    func uploadMultipleImages(_ images: [UIImage], context: ModelContext) async {
        // Guest Limit Check
        do {
            try AppManager.shared.checkGuestLimit()
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        
        guard canUpload else {
            errorMessage = "You don't have permission to upload documents."
            return
        }
        
        guard !images.isEmpty else {
            errorMessage = "Please select at least one image"
            return
        }
        
        guard !documentTitle.isEmpty else {
            errorMessage = "Please enter a document title"
            return
        }
        
        isUploading = true
        errorMessage = nil
        successMessage = nil
        uploadProgress = 0.0
        totalImages = images.count
        currentImageIndex = 0
        
        var successCount = 0
        var failCount = 0
        
        for (index, image) in images.enumerated() {
            currentImageIndex = index
            uploadProgress = Double(index) / Double(images.count)
            
            do {
                // Generate unique title for each image
                let imageTitle = images.count > 1 
                    ? "\(documentTitle) (\(index + 1))" 
                    : documentTitle
                
                _ = try await reportService.processImageReport(
                    image: image,
                    title: imageTitle,
                    context: context
                )
                
                successCount += 1
                
            } catch {
                failCount += 1
                print("Failed to upload image \(index + 1): \(error.localizedDescription)")
            }
        }
        
        // Increment Guest Count (count all successful uploads)
        for _ in 0..<successCount {
            AppManager.shared.incrementGuestUploadCount()
        }
        
        uploadProgress = 1.0
        
        if failCount == 0 {
            successMessage = "\(successCount) report(s) uploaded successfully!"
            HapticFeedback.success.trigger() // Success haptic
        } else if successCount > 0 {
            successMessage = "\(successCount) uploaded, \(failCount) failed."
            errorMessage = nil
            HapticFeedback.warning.trigger() // Partial success haptic
        } else {
            errorMessage = "All uploads failed. Please try again."
            HapticFeedback.error.trigger() // Error haptic
        }
        
        // Clear form on success
        if successCount > 0 {
            selectedImage = nil
            documentTitle = ""
        }
        
        isUploading = false
    }
    
    // MARK: - Single Image Upload (Legacy)
    
    func uploadDocument(context: ModelContext) async {
        guard let image = selectedImage else {
            errorMessage = "Please select an image first"
            return
        }
        
        await uploadMultipleImages([image], context: context)
    }
    
    // MARK: - PDF Upload
    
    func uploadPDF(url: URL, context: ModelContext) async {
        // Guest Limit Check
        do {
            try AppManager.shared.checkGuestLimit()
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        
        guard canUpload else {
            errorMessage = "You don't have permission to upload documents."
            return
        }
        
        guard !documentTitle.isEmpty else {
            errorMessage = "Please enter a document title"
            return
        }
        
        isUploading = true
        errorMessage = nil
        successMessage = nil
        uploadProgress = 0.0
        totalImages = 1
        currentImageIndex = 0
        
        do {
            // Process and upload PDF
            _ = try await reportService.processPDFReport(
                fileURL: url,
                title: documentTitle,
                context: context
            )
            
            // Increment Guest Count
            AppManager.shared.incrementGuestUploadCount()
            
            uploadProgress = 1.0
            successMessage = "PDF uploaded successfully!"
            
            // Clear form
            documentTitle = ""
            
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
        
        isUploading = false
    }
    
    // MARK: - Role-Based Checks
    
    func canUploadForPatient() -> Bool {
        return userRole == .patient || (userRole == .provider && canUpload)
    }
}
