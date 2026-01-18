import SwiftUI

// MARK: - Intro Animation
// A professional, clean, and elegant intro sequence.

struct IntroView: View {
    var onFinish: () -> Void
    
    @State private var phase: Int = 0
    @State private var contentOpacity: Double = 0.0
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var viewOpacity: Double = 1.0
    
    // MARK: - Theme
    private let primaryColor = Color(red: 0.25, green: 0.15, blue: 0.45) // Deep professional purple
    private let secondaryColor = Color.gray
    
    var body: some View {
        ZStack {
            // Background - Clean White
            Color.white.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Logo - Persists but scales slightly
                if phase < 3 {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.4, green: 0.3, blue: 0.8), Color(red: 0.65, green: 0.55, blue: 0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                        .padding(.bottom, 20)
                }
                
                // Dynamic Text Content
                Group {
                    if phase == 0 {
                        VStack(spacing: 12) {
                            Text("Diabo")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .tracking(1)
                                .foregroundColor(primaryColor)
                        }
                    } else if phase == 1 {
                        VStack(spacing: 16) {
                            Text("Your Diabetes, Simplified")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundColor(primaryColor)
                        }
                        .padding(.horizontal, 40)
                    } else if phase == 2 {
                        VStack(spacing: 16) {
                            Text("Track Everything")
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundColor(primaryColor.opacity(0.8))
                            
                            Text("Glucose, meds, meals, and trends — all in one place.")
                                .font(.system(size: 22, weight: .regular, design: .default))
                                .multilineTextAlignment(.center)
                                .foregroundColor(secondaryColor)
                                .lineSpacing(6)
                        }
                        .padding(.horizontal, 40)
                    } else if phase == 3 {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 60))
                                .foregroundStyle(primaryColor.opacity(0.8))
                                .padding(.bottom, 10)
                            
                            Text("Smart Insights")
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundColor(primaryColor.opacity(0.8))
                            
                            Text("Upload your reports to get personalized insights instantly.")
                                .font(.system(size: 22, weight: .regular, design: .default))
                                .multilineTextAlignment(.center)
                                .foregroundColor(secondaryColor)
                                .lineSpacing(6)
                        }
                        .padding(.horizontal, 40)
                    }
                }
                .opacity(contentOpacity)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .id(phase) // Force transition when phase changes
                
                Spacer()
                Spacer()
            }
        }
        .opacity(viewOpacity)
        .onAppear {
            startAnimationSequence()
        }
        // Allow tap to skip
        .onTapGesture {
            finishAnimation()
        }
    }
    
    private func startAnimationSequence() {
        // Phase 0: Logo + Name
        withAnimation(.easeOut(duration: 0.8)) {
            logoOpacity = 1.0
            logoScale = 1.0
            contentOpacity = 1.0
        }
        
        // Advance to Phase 1 after 2.0s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            transitionToPhase(1, delay: 2.5)
        }
    }
    
    private func transitionToPhase(_ newPhase: Int, delay: Double) {
        // Fade out current
        withAnimation(.easeIn(duration: 0.5)) {
            contentOpacity = 0.0
        }
        
        // Change text and fade in new
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            phase = newPhase
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1.0
            }
            
            // Schedule next phase or finish
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if newPhase < 3 {
                    transitionToPhase(newPhase + 1, delay: 3.5) // Longer read time for longer text
                } else {
                    finishAnimation()
                }
            }
        }
    }
    
    private func finishAnimation() {
        withAnimation(.easeIn(duration: 0.5)) {
            viewOpacity = 0.0
            logoOpacity = 0.0
            contentOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onFinish()
        }
    }
}

#Preview {
    IntroView(onFinish: {})
}
