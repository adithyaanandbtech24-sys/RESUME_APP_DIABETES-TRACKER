import SwiftUI
import Charts
import SwiftData

struct HbA1cAnalysisView: View {
    let result: LabResultModel
    let profile: UserProfileModel?
    let engine: DiabetesTargetEngine
    
    // Default profile for calculation if missing
    private var safeProfile: UserProfileModel {
        profile ?? UserProfileModel(name: "Guest", age: 45, gender: "Male", diabetesType: "Type 2")
    }
    
    private var comparisonStats: DiabetesTargetEngine.HbA1cPopulationStats {
        engine.getIndianPopulationStats(for: safeProfile.age)
    }
    
    private var userGoal: Double {
        engine.glucoseTargets(for: safeProfile).hba1cGoal ?? 7.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HbA1c Analysis")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", result.value))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(statusColor)
                        
                        Text("%")
                            .font(.body)
                            .foregroundColor(.gray)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                // Context Chip
                Text(comparisonText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Chart
            if #available(iOS 16.0, *) {
                Chart {
                    // 1. User Value
                    BarMark(
                        x: .value("Category", "You"),
                        y: .value("HbA1c", result.value)
                    )
                    .foregroundStyle(statusColor.gradient)
                    .annotation(position: .top) {
                        Text("\(String(format: "%.1f", result.value))%")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(statusColor)
                    }
                    
                    // 2. Goal
                    RuleMark(
                        y: .value("Goal", userGoal)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundStyle(.green)
                    .annotation(position: .leading, alignment: .bottom) {
                        Text("Goal < \(String(format: "%.1f", userGoal))")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    // 3. Indian Avg (Diabetic)
                    BarMark(
                        x: .value("Category", "Avg (India)"),
                        y: .value("HbA1c", comparisonStats.diabeticAverage)
                    )
                    .foregroundStyle(Color.gray.opacity(0.3).gradient)
                    .annotation(position: .top) {
                        Text("\(String(format: "%.1f", comparisonStats.diabeticAverage))%")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    // 4. Normal Baseline
                    RuleMark(
                        y: .value("Normal", comparisonStats.normalAverage)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .foregroundStyle(.blue.opacity(0.5))
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            } else {
                // Fallback for older iOS (using ProgressView logic if needed, but sticking to simple text here)
                Text("Update iOS to see interactive charts")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Insight Text
            Text(insightMessage)
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Helpers
    
    private var statusColor: Color {
        if result.value <= 5.7 { return .green }
        if result.value <= 6.4 { return .orange }
        if result.value <= userGoal { return .teal } // Good control for diabetic
        return .red
    }
    
    private var comparisonText: String {
        let diff = result.value - comparisonStats.diabeticAverage
        if diff < -0.5 {
            return "Better than Avg"
        } else if diff > 0.5 {
            return "Above Avg"
        } else {
            return "Average"
        }
    }
    
    private var insightMessage: String {
        let diff = comparisonStats.diabeticAverage - result.value
        if diff > 0 {
            return "Great job! Your HbA1c is lower than the average diabetic in India (age \(comparisonStats.ageGroup))."
        } else {
            return "Your levels are higher than the average. Consider adjustments to reach your goal of \(String(format: "%.1f", userGoal))%."
        }
    }
}
