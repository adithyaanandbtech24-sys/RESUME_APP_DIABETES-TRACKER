import SwiftUI
import PDFKit
import SwiftData

// MARK: - Health Report PDF Generator
// Generates doctor-friendly PDF reports from patient data.

struct HealthReportGenerator {
    
    static func generatePDF(
        profile: UserProfileModel,
        labResults: [LabResultModel],
        medications: [MedicationModel],
        dateRange: ClosedRange<Date>? = nil
    ) -> Data? {
        let pageWidth: CGFloat = 612.0  // US Letter
        let pageHeight: CGFloat = 792.0
        let margin: CGFloat = 50.0
        
        let pdfMetaData = [
            kCGPDFContextCreator: "MediSync Diabo",
            kCGPDFContextAuthor: profile.name,
            kCGPDFContextTitle: "Diabetes Health Report"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let engine = DiabetesTargetEngine.shared
        let targets = engine.glucoseTargets(for: profile)
        let risk = engine.assessRisk(for: profile)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            var yOffset: CGFloat = margin
            
            // MARK: - Header
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor(red: 0.25, green: 0.15, blue: 0.45, alpha: 1.0)
            ]
            let headerText = "Diabetes Health Report"
            headerText.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: headerAttrs)
            yOffset += 40
            
            // Date
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            let dateText = "Generated: \(Date().formatted(date: .long, time: .shortened))"
            dateText.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: dateAttrs)
            yOffset += 30
            
            // Divider
            context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            context.cgContext.setLineWidth(1)
            context.cgContext.move(to: CGPoint(x: margin, y: yOffset))
            context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: yOffset))
            context.cgContext.strokePath()
            yOffset += 20
            
            // MARK: - Patient Info
            let sectionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor(red: 0.25, green: 0.15, blue: 0.45, alpha: 1.0)
            ]
            "Patient Information".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: sectionAttrs)
            yOffset += 25
            
            let infoAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            
            let patientInfo = """
            Name: \(profile.name)
            Age: \(profile.age) years | Gender: \(profile.gender.capitalized)
            Diabetes Type: \(profile.diabetesType)
            Treatment: \(profile.treatmentType)
            Diagnosis Year: \(profile.diagnosisYear.map { String($0) } ?? "N/A")
            """
            patientInfo.draw(in: CGRect(x: margin, y: yOffset, width: pageWidth - 2*margin, height: 100), withAttributes: infoAttrs)
            yOffset += 90
            
            // MARK: - Personalized Targets
            "Your Personalized Targets".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: sectionAttrs)
            yOffset += 25
            
            let targetsInfo = """
            Fasting Glucose: \(targets.fastingRange)
            Post-Meal Glucose: \(targets.postPrandialRange)
            HbA1c Goal: \(targets.hba1cDisplay)
            Time in Range Goal: \(Int(targets.timeInRangeGoal))%
            """
            targetsInfo.draw(in: CGRect(x: margin, y: yOffset, width: pageWidth - 2*margin, height: 80), withAttributes: infoAttrs)
            yOffset += 80
            
            // MARK: - Risk Assessment
            "Complication Risk Assessment".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: sectionAttrs)
            yOffset += 25
            
            let riskInfo = """
            Overall Risk: \(risk.overallRisk.rawValue)
            Cardiovascular: \(risk.cardiovascularRisk.rawValue)
            Kidney (Nephropathy): \(risk.nephropathyRisk.rawValue)
            Nerve (Neuropathy): \(risk.neuropathyRisk.rawValue)
            Eye (Retinopathy): \(risk.retinopathyRisk.rawValue)
            Hypoglycemia Risk: \(risk.hypoglycemiaRisk.rawValue)
            """
            riskInfo.draw(in: CGRect(x: margin, y: yOffset, width: pageWidth - 2*margin, height: 100), withAttributes: infoAttrs)
            yOffset += 110
            
            // MARK: - Recent Lab Results
            "Recent Lab Results".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: sectionAttrs)
            yOffset += 25
            
            let recentLabs = labResults.prefix(10)
            for lab in recentLabs {
                if yOffset > pageHeight - 100 {
                    context.beginPage()
                    yOffset = margin
                }
                
                let labLine = "\(lab.testName): \(String(format: "%.1f", lab.value)) \(lab.unit) (\(lab.status))"
                labLine.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: infoAttrs)
                yOffset += 18
            }
            
            if recentLabs.isEmpty {
                "No lab results available.".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: infoAttrs)
                yOffset += 20
            }
            
            yOffset += 20
            
            // MARK: - Active Medications
            if yOffset > pageHeight - 150 {
                context.beginPage()
                yOffset = margin
            }
            
            "Active Medications".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: sectionAttrs)
            yOffset += 25
            
            let activeMeds = medications.filter { $0.isActive }
            for med in activeMeds.prefix(10) {
                let medLine = "• \(med.name) - \(med.dosage), \(med.frequency)"
                medLine.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: infoAttrs)
                yOffset += 18
            }
            
            if activeMeds.isEmpty {
                "No active medications recorded.".draw(at: CGPoint(x: margin, y: yOffset), withAttributes: infoAttrs)
            }
            
            // MARK: - Disclaimer Footer
            let disclaimerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            let disclaimer = "This report is for informational purposes only. Please consult your healthcare provider for medical advice."
            disclaimer.draw(at: CGPoint(x: margin, y: pageHeight - 40), withAttributes: disclaimerAttrs)
        }
        
        return data
    }
}

// MARK: - Health Report View

struct HealthReportView: View {
    @Query(sort: \LabResultModel.testDate, order: .reverse) private var labResults: [LabResultModel]
    @Query(sort: \MedicationModel.startDate, order: .reverse) private var medications: [MedicationModel]
    @Query private var userProfiles: [UserProfileModel]
    
    @State private var pdfData: Data?
    @State private var showShareSheet = false
    @State private var isGenerating = false
    
    private var profile: UserProfileModel? { userProfiles.first }
    
    private let deepPurple = Color(red: 0.25, green: 0.15, blue: 0.45)
    private let vibrantPurple = Color(red: 0.65, green: 0.55, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview Card
                    ReportPreviewCard(profile: profile, labCount: labResults.count, medCount: medications.filter { $0.isActive }.count)
                    
                    // Generate Button
                    Button(action: generateReport) {
                        HStack(spacing: 10) {
                            if isGenerating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "doc.richtext.fill")
                            }
                            Text(isGenerating ? "Generating..." : "Generate PDF Report")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(vibrantPurple)
                        .cornerRadius(16)
                    }
                    .disabled(profile == nil || isGenerating)
                    
                    // Share Button
                    if pdfData != nil {
                        Button(action: { showShareSheet = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Report")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(deepPurple)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(vibrantPurple.opacity(0.15))
                            .cornerRadius(16)
                        }
                    }
                    
                    // Info Section
                    ReportInfoCard()
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Health Report")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showShareSheet) {
                if let data = pdfData {
                    ShareSheet(items: [data])
                }
            }
        }
    }
    
    private func generateReport() {
        guard let profile = profile else { return }
        isGenerating = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let data = HealthReportGenerator.generatePDF(
                profile: profile,
                labResults: labResults,
                medications: medications
            )
            
            DispatchQueue.main.async {
                self.pdfData = data
                self.isGenerating = false
                if data != nil {
                    self.showShareSheet = true
                }
            }
        }
    }
}

// MARK: - Report Preview Card

struct ReportPreviewCard: View {
    let profile: UserProfileModel?
    let labCount: Int
    let medCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title)
                    .foregroundColor(Color(red: 0.65, green: 0.55, blue: 0.95))
                
                VStack(alignment: .leading) {
                    Text("Diabetes Health Report")
                        .font(.headline)
                    Text("Doctor-ready PDF export")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Divider()
            
            // Contents Preview
            VStack(alignment: .leading, spacing: 10) {
                ContentRow(icon: "person.fill", text: "Patient Profile: \(profile?.name ?? "Not set")")
                ContentRow(icon: "target", text: "Personalized Glucose Targets")
                ContentRow(icon: "shield.checkered", text: "Complication Risk Assessment")
                ContentRow(icon: "flask.fill", text: "\(labCount) Lab Result\(labCount == 1 ? "" : "s")")
                ContentRow(icon: "pills.fill", text: "\(medCount) Active Medication\(medCount == 1 ? "" : "s")")
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct ContentRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.8))
        }
    }
}

// MARK: - Report Info Card

struct ReportInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("About Health Reports")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Text("Generated reports include your personalized targets, risk assessment, recent lab results, and active medications. Share with your healthcare provider for better care coordination.")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(14)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    HealthReportView()
}
