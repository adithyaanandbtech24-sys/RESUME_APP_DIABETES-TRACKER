import SwiftUI
import SwiftData
import Combine

// MARK: - Diabetes Alert Engine
// Tiered alert system for diabetes safety monitoring.

final class DiabetesAlertEngine: ObservableObject {
    
    static let shared = DiabetesAlertEngine()
    private init() {}
    
    @Published var activeAlerts: [DiabetesAlert] = []
    
    // MARK: - Alert Generation
    
    func generateAlerts(
        labResults: [LabResultModel],
        medications: [MedicationModel],
        profile: UserProfileModel
    ) -> [DiabetesAlert] {
        var alerts: [DiabetesAlert] = []
        
        // 1. Glucose Alerts
        alerts.append(contentsOf: checkGlucoseAlerts(labResults: labResults, profile: profile))
        
        // 2. HbA1c Alerts
        alerts.append(contentsOf: checkHbA1cAlerts(labResults: labResults, profile: profile))
        
        // 3. Medication Alerts
        alerts.append(contentsOf: checkMedicationAlerts(medications: medications, profile: profile))
        
        // 4. Kidney Function Alerts
        alerts.append(contentsOf: checkKidneyAlerts(labResults: labResults))
        
        // 5. Blood Pressure Alerts
        alerts.append(contentsOf: checkBPAlerts(labResults: labResults, profile: profile))
        
        // Sort by severity
        activeAlerts = alerts.sorted { $0.severity.order < $1.severity.order }
        return activeAlerts
    }
    
    // MARK: - Glucose Checks
    
    private func checkGlucoseAlerts(labResults: [LabResultModel], profile: UserProfileModel) -> [DiabetesAlert] {
        var alerts: [DiabetesAlert] = []
        let targets = DiabetesTargetEngine.shared.glucoseTargets(for: profile)
        
        // Find most recent glucose
        let glucoseResults = labResults.filter { 
            $0.testName.localizedCaseInsensitiveContains("glucose") ||
            $0.testName.localizedCaseInsensitiveContains("blood sugar")
        }
        
        guard let latest = glucoseResults.first else { return alerts }
        
        // Hypoglycemia
        if latest.value < 70 {
            alerts.append(DiabetesAlert(
                id: UUID().uuidString,
                title: "Hypoglycemia Detected",
                message: "Your glucose is \(Int(latest.value)) mg/dL which is below 70. Please take fast-acting carbs if experiencing symptoms.",
                severity: latest.value < 54 ? .critical : .warning,
                type: .hypoglycemia,
                actionRequired: "Take 15g of fast-acting carbs (juice, glucose tabs)",
                date: latest.testDate
            ))
        }
        
        // Hyperglycemia
        if latest.value > 250 {
            alerts.append(DiabetesAlert(
                id: UUID().uuidString,
                title: "Hyperglycemia Alert",
                message: "Your glucose is \(Int(latest.value)) mg/dL which is significantly elevated.",
                severity: latest.value > 400 ? .critical : .warning,
                type: .hyperglycemia,
                actionRequired: profile.diabetesType.contains("Type 1") ? 
                    "Check for ketones. Contact your doctor if ketones are present." :
                    "Drink water, monitor closely, contact doctor if persisting.",
                date: latest.testDate
            ))
        }
        
        // Repeated High Readings
        let recentHighs = glucoseResults.prefix(5).filter { $0.value > targets.postPrandialMax }
        if recentHighs.count >= 3 {
            alerts.append(DiabetesAlert(
                id: UUID().uuidString,
                title: "Pattern of High Glucose",
                message: "You've had \(recentHighs.count) high readings recently. This may indicate a need to review your management plan.",
                severity: .info,
                type: .pattern,
                actionRequired: "Discuss with your healthcare provider at your next appointment.",
                date: Date()
            ))
        }
        
        return alerts
    }
    
    // MARK: - HbA1c Checks
    
    private func checkHbA1cAlerts(labResults: [LabResultModel], profile: UserProfileModel) -> [DiabetesAlert] {
        var alerts: [DiabetesAlert] = []
        let targets = DiabetesTargetEngine.shared.glucoseTargets(for: profile)
        
        let hba1cResults = labResults.filter { 
            $0.testName.localizedCaseInsensitiveContains("hba1c") ||
            $0.testName.localizedCaseInsensitiveContains("a1c")
        }
        
        guard let latest = hba1cResults.first, let goal = targets.hba1cGoal else { return alerts }
        
        if latest.value > goal + 1.5 {
            alerts.append(DiabetesAlert(
                id: UUID().uuidString,
                title: "HbA1c Above Target",
                message: "Your HbA1c of \(String(format: "%.1f", latest.value))% is above your goal of \(String(format: "%.1f", goal))%.",
                severity: latest.value > 9.0 ? .warning : .info,
                type: .hba1c,
                actionRequired: "Review lifestyle factors and discuss treatment intensification with your doctor.",
                date: latest.testDate
            ))
        }
        
        // Check for worsening trend
        if hba1cResults.count >= 2 {
            let previous = hba1cResults[1]
            if latest.value > previous.value + 0.5 {
                alerts.append(DiabetesAlert(
                    id: UUID().uuidString,
                    title: "HbA1c Worsening",
                    message: "Your HbA1c has increased from \(String(format: "%.1f", previous.value))% to \(String(format: "%.1f", latest.value))%.",
                    severity: .info,
                    type: .trend,
                    actionRequired: "Identify factors that may have contributed. Schedule a review with your care team.",
                    date: latest.testDate
                ))
            }
        }
        
        return alerts
    }
    
    // MARK: - Medication Alerts
    
    private func checkMedicationAlerts(medications: [MedicationModel], profile: UserProfileModel) -> [DiabetesAlert] {
        var alerts: [DiabetesAlert] = []
        
        // Check for insulin without recent use
        let insulinMeds = medications.filter { 
            $0.name.localizedCaseInsensitiveContains("insulin") && $0.isActive
        }
        
        if profile.treatmentType.lowercased().contains("insulin") && insulinMeds.isEmpty {
            alerts.append(DiabetesAlert(
                id: UUID().uuidString,
                title: "No Active Insulin Recorded",
                message: "Your treatment plan includes insulin, but no active insulin is tracked.",
                severity: .info,
                type: .medication,
                actionRequired: "Add your insulin medication for better tracking.",
                date: Date()
            ))
        }
        
        // Check for expired medications
        let expiredMeds = medications.filter { med in
            if let endDate = med.endDate {
                return endDate < Date() && med.isActive
            }
            return false
        }
        
        for med in expiredMeds {
            alerts.append(DiabetesAlert(
                id: UUID().uuidString,
                title: "Medication May Need Refill",
                message: "\(med.name) end date has passed. Consider checking if you need a refill.",
                severity: .info,
                type: .medication,
                actionRequired: "Check with your pharmacy about refills.",
                date: Date()
            ))
        }
        
        return alerts
    }
    
    // MARK: - Kidney Alerts
    
    private func checkKidneyAlerts(labResults: [LabResultModel]) -> [DiabetesAlert] {
        var alerts: [DiabetesAlert] = []
        
        // Check eGFR
        let egfrResults = labResults.filter { 
            $0.testName.localizedCaseInsensitiveContains("egfr") ||
            $0.testName.localizedCaseInsensitiveContains("gfr")
        }
        
        if let latest = egfrResults.first {
            if latest.value < 30 {
                alerts.append(DiabetesAlert(
                    id: UUID().uuidString,
                    title: "Severely Reduced Kidney Function",
                    message: "Your eGFR of \(Int(latest.value)) indicates Stage 4 kidney disease.",
                    severity: .critical,
                    type: .kidney,
                    actionRequired: "This requires nephrology care. Contact your doctor urgently.",
                    date: latest.testDate
                ))
            } else if latest.value < 60 {
                alerts.append(DiabetesAlert(
                    id: UUID().uuidString,
                    title: "Reduced Kidney Function",
                    message: "Your eGFR of \(Int(latest.value)) indicates reduced kidney function.",
                    severity: .warning,
                    type: .kidney,
                    actionRequired: "Discuss kidney-protective strategies with your doctor.",
                    date: latest.testDate
                ))
            }
        }
        
        // Check Microalbumin
        let albuminResults = labResults.filter { 
            $0.testName.localizedCaseInsensitiveContains("microalbumin") ||
            $0.testName.localizedCaseInsensitiveContains("urine albumin")
        }
        
        if let latest = albuminResults.first, latest.value > 30 {
            alerts.append(DiabetesAlert(
                id: UUID().uuidString,
                title: "Elevated Urine Albumin",
                message: "Albumin in urine can be an early sign of kidney damage.",
                severity: .info,
                type: .kidney,
                actionRequired: "ACE inhibitors or ARBs may be protective. Discuss with your doctor.",
                date: latest.testDate
            ))
        }
        
        return alerts
    }
    
    // MARK: - Blood Pressure Alerts
    
    private func checkBPAlerts(labResults: [LabResultModel], profile: UserProfileModel) -> [DiabetesAlert] {
        var alerts: [DiabetesAlert] = []
        let bpTargets = DiabetesTargetEngine.shared.bpTargets(for: profile)
        
        let bpResults = labResults.filter { 
            $0.testName.localizedCaseInsensitiveContains("blood pressure") ||
            $0.testName.localizedCaseInsensitiveContains("bp") ||
            $0.testName.localizedCaseInsensitiveContains("systolic")
        }
        
        if let latest = bpResults.first {
            if latest.value > 180 {
                alerts.append(DiabetesAlert(
                    id: UUID().uuidString,
                    title: "Dangerously High Blood Pressure",
                    message: "BP of \(Int(latest.value)) mmHg is critically elevated.",
                    severity: .critical,
                    type: .bloodPressure,
                    actionRequired: "Seek medical attention if experiencing symptoms like headache, chest pain, or vision changes.",
                    date: latest.testDate
                ))
            } else if latest.value > Double(bpTargets.systolicMax) {
                alerts.append(DiabetesAlert(
                    id: UUID().uuidString,
                    title: "Blood Pressure Above Target",
                    message: "Your systolic BP of \(Int(latest.value)) exceeds target of \(bpTargets.systolicMax).",
                    severity: .info,
                    type: .bloodPressure,
                    actionRequired: "Lifestyle modifications and medication review may help.",
                    date: latest.testDate
                ))
            }
        }
        
        return alerts
    }
}

// MARK: - Alert Model

struct DiabetesAlert: Identifiable {
    let id: String
    let title: String
    let message: String
    let severity: AlertSeverity
    let type: AlertType
    let actionRequired: String
    let date: Date
    
    enum AlertSeverity: String, CaseIterable {
        case critical = "Critical"
        case warning = "Warning"
        case info = "Info"
        
        var order: Int {
            switch self {
            case .critical: return 0
            case .warning: return 1
            case .info: return 2
            }
        }
        
        var color: Color {
            switch self {
            case .critical: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .critical: return "exclamationmark.triangle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    enum AlertType: String {
        case hypoglycemia = "Hypoglycemia"
        case hyperglycemia = "Hyperglycemia"
        case hba1c = "HbA1c"
        case trend = "Trend"
        case pattern = "Pattern"
        case medication = "Medication"
        case kidney = "Kidney"
        case bloodPressure = "Blood Pressure"
    }
}

// MARK: - Alerts View

struct AlertsView: View {
    @Query(sort: \LabResultModel.testDate, order: .reverse) private var labResults: [LabResultModel]
    @Query(sort: \MedicationModel.startDate, order: .reverse) private var medications: [MedicationModel]
    @Query private var userProfiles: [UserProfileModel]
    
    @StateObject private var alertEngine = DiabetesAlertEngine.shared
    
    private var profile: UserProfileModel? { userProfiles.first }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if alertEngine.activeAlerts.isEmpty {
                        NoAlertsView()
                    } else {
                        ForEach(alertEngine.activeAlerts) { alert in
                            AlertCard(alert: alert)
                        }
                    }
                    
                    AlertInfoCard()
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Health Alerts")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if let profile = profile {
                    _ = alertEngine.generateAlerts(
                        labResults: labResults,
                        medications: medications,
                        profile: profile
                    )
                }
            }
        }
    }
}

// MARK: - Alert Card

struct AlertCard: View {
    let alert: DiabetesAlert
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 14) {
                    Image(systemName: alert.severity.icon)
                        .font(.title2)
                        .foregroundColor(alert.severity.color)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.title)
                            .font(.headline)
                            .foregroundColor(.black)
                        
                        Text(alert.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text(alert.severity.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(alert.severity.color)
                        .cornerRadius(8)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(alert.message)
                        .font(.subheadline)
                        .foregroundColor(.black.opacity(0.8))
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "hand.point.right.fill")
                            .foregroundColor(alert.severity.color)
                        Text(alert.actionRequired)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(alert.severity.color.opacity(0.08))
                    .cornerRadius(10)
                }
                .padding()
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(alert.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - No Alerts View

struct NoAlertsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("All Clear!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("No health alerts at this time. Keep up the good work!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(20)
    }
}

// MARK: - Alert Info Card

struct AlertInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("About Alerts")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Text("Alerts are generated based on your lab results, medications, and profile. They are for informational purposes only and do not replace professional medical advice.")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(14)
    }
}

#Preview {
    AlertsView()
}
