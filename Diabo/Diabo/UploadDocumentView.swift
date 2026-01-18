// UploadDocumentView.swift
import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct UploadDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = UploadDocumentViewModel()
    
    // Multi-image selection
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showPDFPicker = false
    
    var onUploadSuccess: (() -> Void)?
    
    // Theme colors
    private let deepPurple = Color(red: 0.35, green: 0.20, blue: 0.75)
    private let vibrantPurple = Color(red: 0.55, green: 0.40, blue: 0.95)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Document Title")
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            TextField("e.g., Blood Test Nov 2024", text: $viewModel.documentTitle)
                                .textFieldStyle(.roundedBorder)
                                .padding()
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Upload Options
                        VStack(spacing: 16) {
                            Text("Select Upload Method")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            // Multi-Image Upload Button
                            PhotosPicker(
                                selection: $selectedItems,
                                maxSelectionCount: 10,
                                matching: .images
                            ) {
                                HStack {
                                    Image(systemName: "photo.stack.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Upload Images")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text(selectedImages.isEmpty ? "Select multiple images" : "\(selectedImages.count) image(s) selected")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.uploadBlue, Color.uploadBlue.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color.uploadBlue.opacity(0.3), radius: 8, y: 4)
                            }
                            .padding(.horizontal)
                            
                            // PDF Upload Button
                            Button {
                                showPDFPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Upload PDF")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text("Select PDF document")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.uploadPurple, Color.uploadPurple.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color.uploadPurple.opacity(0.3), radius: 8, y: 4)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Multi-Image Preview Grid
                        if !selectedImages.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Selected Images (\(selectedImages.count))")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    
                                    Button("Clear All") {
                                        selectedImages.removeAll()
                                        selectedItems.removeAll()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                                
                                // Grid of previews
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                    ForEach(selectedImages.indices, id: \.self) { index in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: selectedImages[index])
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipped()
                                                .cornerRadius(12)
                                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                            
                                            // Remove button
                                            Button {
                                                selectedImages.remove(at: index)
                                                if index < selectedItems.count {
                                                    selectedItems.remove(at: index)
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.red))
                                            }
                                            .offset(x: 6, y: -6)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Upload Progress - Enhanced AI Analysis Overlay
                        if viewModel.isUploading {
                            VStack(spacing: 20) {
                                // Pulsing Brain Icon
                                ZStack {
                                    Circle()
                                        .fill(vibrantPurple.opacity(0.1))
                                        .frame(width: 80, height: 80)
                                        .scaleEffect(viewModel.uploadProgress < 1.0 ? 1.2 : 1.0)
                                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.uploadProgress)
                                    
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 36))
                                        .foregroundColor(vibrantPurple)
                                        .scaleEffect(viewModel.uploadProgress < 1.0 ? 1.1 : 1.0)
                                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.uploadProgress)
                                }
                                
                                VStack(spacing: 8) {
                                    Text("Analyzing with AI...")
                                        .font(.headline)
                                        .foregroundColor(deepPurple)
                                    
                                    Text("Processing image \(viewModel.currentImageIndex + 1) of \(viewModel.totalImages)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                // Progress Bar
                                VStack(spacing: 6) {
                                    ProgressView(value: viewModel.uploadProgress)
                                        .progressViewStyle(.linear)
                                        .tint(vibrantPurple)
                                        .frame(height: 8)
                                        .background(Color.gray.opacity(0.2))
                                        .clipShape(Capsule())
                                    
                                    Text("\(Int(viewModel.uploadProgress * 100))% complete")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(24)
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: vibrantPurple.opacity(0.15), radius: 15, x: 0, y: 5)
                            .padding(.horizontal)
                        }
                        
                        // Status Messages
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.callout)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                        
                        if let success = viewModel.successMessage {
                            Text(success)
                                .font(.callout)
                                .foregroundColor(.green)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Upload Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Task {
                            await viewModel.uploadMultipleImages(selectedImages, context: modelContext)
                            if viewModel.successMessage != nil {
                                onUploadSuccess?()
                                dismiss()
                            }
                        }
                    }
                    .font(.headline)
                    .foregroundColor(vibrantPurple)
                    .disabled(selectedImages.isEmpty || viewModel.documentTitle.isEmpty || viewModel.isUploading)
                }
            }
            .sheet(isPresented: $showPDFPicker) {
                DocumentPicker { url in
                    viewModel.documentTitle = url.lastPathComponent.replacingOccurrences(of: ".pdf", with: "")
                    Task {
                        await viewModel.uploadPDF(url: url, context: modelContext)
                        if viewModel.successMessage != nil {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                dismiss()
                                onUploadSuccess?()
                            }
                        }
                    }
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                Task {
                    selectedImages.removeAll()
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImages.append(image)
                        }
                    }
                    // Set first image as preview for single-image compatibility
                    if let first = selectedImages.first {
                        viewModel.selectImage(first)
                    }
                }
            }
        }
    }
}

// MARK: - Document Picker for PDFs

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource
            let hasAccess = url.startAccessingSecurityScopedResource()
            
            // Copy to temp directory IMMEDIATELY while we have access
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempURL = tempDirectory.appendingPathComponent(url.lastPathComponent)
            
            do {
                // Remove existing file if any
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                // Copy file while we have access
                try FileManager.default.copyItem(at: url, to: tempURL)
                
                // Release security-scoped access NOW (we have our copy)
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
                
                // Pass the temp URL which we have full access to
                onPick(tempURL)
            } catch {
                print("❌ [DocumentPicker] Failed to copy PDF: \(error)")
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
    }
}
