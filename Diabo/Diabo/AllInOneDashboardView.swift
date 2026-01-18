import SwiftUI

// MARK: - All-in-One Dashboard View
// Single animated page showcasing app features with checkmark animations

struct AllInOneDashboardView: View {
    @ObservedObject private var appManager = AppManager.shared
    
    // Animation states
    @State private var showFeature1 = false
    @State private var showFeature2 = false
    @State private var showFeature3 = false
    @State private var showFeature4 = false
    @State private var showContinueButton = false
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    
    // Theme Colors
    private let vibrantPurple = Color(red: 0.55, green: 0.40, blue: 0.95)
    private let deepPurple = Color(red: 0.35, green: 0.20, blue: 0.75)
    private let accentGold = Color(red: 0.95, green: 0.75, blue: 0.30)
    
    // Features to display
    private let features = [
        "Track glucose, blood pressure & vital signs",
        "AI-powered health insights",
        "Upload and analyze medical reports",
        "Personalized diabetes management"
    ]
    
    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                gradient: Gradient(colors: [deepPurple, vibrantPurple]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 160, height: 160)
                    
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentGold, accentGold.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                
                Spacer()
                    .frame(height: 50)
                
                // White Card Content
                VStack(spacing: 24) {
                    // Badge
                    Text("ALL-IN-ONE DASHBOARD")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(vibrantPurple)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .stroke(vibrantPurple.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Title
                    Text("Your Complete Health Companion")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                    
                    // Animated Feature List
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(text: features[0], isVisible: showFeature1, accentColor: vibrantPurple)
                        FeatureRow(text: features[1], isVisible: showFeature2, accentColor: vibrantPurple)
                        FeatureRow(text: features[2], isVisible: showFeature3, accentColor: vibrantPurple)
                        FeatureRow(text: features[3], isVisible: showFeature4, accentColor: vibrantPurple)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                        .frame(height: 20)
                    
                    // Continue Button
                    Button(action: {
                        appManager.completeAllInOneDashboard()
                    }) {
                        HStack {
                            Text("Continue")
                                .font(.system(size: 18, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [vibrantPurple, deepPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(30)
                        .shadow(color: vibrantPurple.opacity(0.4), radius: 15, y: 8)
                    }
                    .padding(.horizontal, 30)
                    .opacity(showContinueButton ? 1 : 0)
                    .offset(y: showContinueButton ? 0 : 20)
                }
                .padding(.top, 30)
                .padding(.bottom, 50)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 40)
                        .fill(Color.white)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Icon animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        
        // Staggered feature animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                showFeature1 = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                showFeature2 = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.4)) {
                showFeature3 = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.4)) {
                showFeature4 = true
            }
        }
        
        // Show continue button after all features
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.5)) {
                showContinueButton = true
            }
        }
    }
}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let text: String
    let isVisible: Bool
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 14) {
            // Checkmark Circle
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accentColor)
                    .scaleEffect(isVisible ? 1 : 0)
            }
            
            // Feature Text
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.black.opacity(0.8))
        }
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -20)
    }
}

#Preview {
    AllInOneDashboardView()
}
