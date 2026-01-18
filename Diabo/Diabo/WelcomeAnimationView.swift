import SwiftUI

// MARK: - Welcome Animation View
// Professional fade-in/out animation with "All Set, Welcome!" text

struct WelcomeAnimationView: View {
    var onComplete: () -> Void
    
    @State private var textOpacity: Double = 0.0
    
    // Theme
    private let vibrantPurple = Color(red: 0.65, green: 0.55, blue: 0.95)
    private let lightPurple = Color(red: 0.8, green: 0.7, blue: 1.0)
    
    var body: some View {
        ZStack {
            // Clean gradient background
            LinearGradient(
                colors: [vibrantPurple, lightPurple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // "All Set, Welcome!" Text - centered
            VStack(spacing: 16) {
                Text("All Set,")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("Welcome!")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .opacity(textOpacity)
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Phase 1: Fade in text (0.8s)
        withAnimation(.easeOut(duration: 0.8)) {
            textOpacity = 1.0
        }
        
        // Phase 2: Hold text visible (1.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            // Phase 3: Fade out text (0.8s)
            withAnimation(.easeIn(duration: 0.8)) {
                textOpacity = 0.0
            }
        }
        
        // Phase 4: Complete and proceed (total ~3.1s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            onComplete()
        }
    }
}

#Preview {
    WelcomeAnimationView(onComplete: {})
}
