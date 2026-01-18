import SwiftUI
import SwiftData

// MARK: - Medication Tracking View
// Comprehensive medication management for diabetes patients.

struct MedicationTrackingView: View {
    @Query(sort: \MedicationModel.startDate, order: .reverse) private var medications: [MedicationModel]
    @Query private var userProfiles: [UserProfileModel]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showAddMedication = false
    @State private var selectedMedication: MedicationModel?
    
    private var profile: UserProfileModel? { userProfiles.first }
    
    // MARK: - Medication Categories
    private var insulinMeds: [MedicationModel] {
        medications.filter { med in
            let name = med.name.lowercased()
            return name.contains("insulin") || name.contains("lantus") || 
                   name.contains("humalog") || name.contains("novolog") ||
                   name.contains("levemir") || name.contains("tresiba") ||
                   name.contains("afrezza")
        }
    }
    
    private var oralMeds: [MedicationModel] {
        medications.filter { med in
            let name = med.name.lowercased()
            return name.contains("metformin") || name.contains("glipizide") ||
                   name.contains("glimepiride") || name.contains("sitagliptin") ||
                   name.contains("empagliflozin") || name.contains("jardiance") ||
                   name.contains("dapagliflozin") || name.contains("farxiga")
        }
    }
    
    private var injectableMeds: [MedicationModel] {
        medications.filter { med in
            let name = med.name.lowercased()
            return name.contains("ozempic") || name.contains("wegovy") ||
                   name.contains("trulicity") || name.contains("victoza") ||
                   name.contains("rybelsus") || name.contains("mounjaro") ||
                   name.contains("semaglutide") || name.contains("dulaglutide")
        }
    }
    
    private var otherMeds: [MedicationModel] {
        medications.filter { med in
            !insulinMeds.contains(where: { $0.id == med.id }) &&
            !oralMeds.contains(where: { $0.id == med.id }) &&
            !injectableMeds.contains(where: { $0.id == med.id })
        }
    }
    
    // MARK: - Theme
    private let deepPurple = Color(red: 0.25, green: 0.15, blue: 0.45)
    private let vibrantPurple = Color(red: 0.65, green: 0.55, blue: 0.95)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Treatment Overview
                    if let profile = profile {
                        TreatmentBanner(profile: profile)
                    }
                    
                    // Medication Categories
                    if medications.isEmpty {
                        EmptyMedicationsView()
                    } else {
                        // Insulin Section
                        if !insulinMeds.isEmpty {
                            MedicationSection(
                                title: "Insulin Therapy",
                                icon: "syringe.fill",
                                color: .blue,
                                medications: insulinMeds,
                                onSelect: { selectedMedication = $0 }
                            )
                        }
                        
                        // Injectable GLP-1 Section
                        if !injectableMeds.isEmpty {
                            MedicationSection(
                                title: "Injectable (GLP-1)",
                                icon: "cross.vial.fill",
                                color: .green,
                                medications: injectableMeds,
                                onSelect: { selectedMedication = $0 }
                            )
                        }
                        
                        // Oral Medications Section
                        if !oralMeds.isEmpty {
                            MedicationSection(
                                title: "Oral Medications",
                                icon: "pills.fill",
                                color: .orange,
                                medications: oralMeds,
                                onSelect: { selectedMedication = $0 }
                            )
                        }
                        
                        // Other Medications
                        if !otherMeds.isEmpty {
                            MedicationSection(
                                title: "Other Medications",
                                icon: "pill.fill",
                                color: .purple,
                                medications: otherMeds,
                                onSelect: { selectedMedication = $0 }
                            )
                        }
                    }
                    
                    // Safety Note
                    SafetyNoteCard()
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Medications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddMedication = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(vibrantPurple)
                    }
                }
            }
            .sheet(item: $selectedMedication) { medication in
                MedicationDetailSheet(medication: medication)
            }
        }
    }
}

// MARK: - Treatment Banner

struct TreatmentBanner: View {
    let profile: UserProfileModel
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: treatmentIcon)
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(treatmentColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Treatment Plan")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.45))
                
                Text(profile.treatmentType)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(profile.diabetesType)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.65, green: 0.55, blue: 0.95))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
    
    private var treatmentIcon: String {
        let t = profile.treatmentType.lowercased()
        if t.contains("insulin") { return "syringe.fill" }
        if t.contains("oral") { return "pills.fill" }
        if t.contains("injectable") || t.contains("glp") { return "cross.vial.fill" }
        return "leaf.fill"
    }
    
    private var treatmentColor: Color {
        let t = profile.treatmentType.lowercased()
        if t.contains("insulin") { return .blue }
        if t.contains("oral") { return .orange }
        if t.contains("injectable") { return .green }
        return .mint
    }
}

// MARK: - Medication Section

struct MedicationSection: View {
    let title: String
    let icon: String
    let color: Color
    let medications: [MedicationModel]
    let onSelect: (MedicationModel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.45))
                
                Spacer()
                
                Text("\(medications.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.8))
                    .cornerRadius(6)
            }
            
            // Medication Cards
            ForEach(medications) { med in
                Button(action: { onSelect(med) }) {
                    MedicationCard(medication: med, accentColor: color)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Medication Card

struct MedicationCard: View {
    let medication: MedicationModel
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: "pills.fill")
                .font(.title3)
                .foregroundColor(accentColor)
                .frame(width: 44, height: 44)
                .background(accentColor.opacity(0.12))
                .clipShape(Circle())
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(medication.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                
                HStack(spacing: 8) {
                    Text(medication.dosage)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text(medication.frequency)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Status
            VStack(alignment: .trailing, spacing: 4) {
                Circle()
                    .fill(medication.isActive ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                
                Text(medication.isActive ? "Active" : "Inactive")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Medication Detail Sheet

struct MedicationDetailSheet: View {
    let medication: MedicationModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack {
                        Image(systemName: "pills.fill")
                            .font(.largeTitle)
                            .foregroundColor(.purple)
                            .frame(width: 70, height: 70)
                            .background(Color.purple.opacity(0.1))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(medication.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(medication.source)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Dosage Info
                    DetailSection(title: "Dosage & Frequency") {
                        DetailRow(label: "Dosage", value: medication.dosage)
                        DetailRow(label: "Frequency", value: medication.frequency)
                        if let instructions = medication.instructions {
                            DetailRow(label: "Instructions", value: instructions)
                        }
                    }
                    
                    // Dates
                    DetailSection(title: "Timeline") {
                        DetailRow(label: "Start Date", value: medication.startDate.formatted(date: .abbreviated, time: .omitted))
                        if let endDate = medication.endDate {
                            DetailRow(label: "End Date", value: endDate.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                    
                    // Notes
                    if let notes = medication.notes, !notes.isEmpty {
                        DetailSection(title: "Notes") {
                            Text(notes)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Safety Note
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("This app does not provide dosage recommendations. Always follow your doctor's instructions.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Medication Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.45))
            
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(14)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Safety Note Card

struct SafetyNoteCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.title3)
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Important Safety Notice")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                
                Text("MediSync tracks your medications but never suggests dosage changes. Always consult your healthcare provider before making any changes to your medication regimen.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Empty State

struct EmptyMedicationsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pills.circle")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.4))
            
            Text("No Medications Tracked")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Add your medications manually or upload a prescription to start tracking.")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(40)
        .background(Color.white)
        .cornerRadius(20)
    }
}

#Preview {
    MedicationTrackingView()
}
