import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Haptic Feedback Utility
/// Centralized haptic feedback for smooth, premium feel throughout the app

enum HapticFeedback {
    case success
    case warning
    case error
    case light
    case medium
    case heavy
    case selection
    
    #if canImport(UIKit)
    func trigger() {
        switch self {
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
    #else
    func trigger() {
        // No haptics on non-UIKit platforms
    }
    #endif
}

// MARK: - View Extension for Easy Haptic Triggers
extension View {
    func hapticOnTap(_ feedback: HapticFeedback = .light) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                feedback.trigger()
            }
        )
    }
}
