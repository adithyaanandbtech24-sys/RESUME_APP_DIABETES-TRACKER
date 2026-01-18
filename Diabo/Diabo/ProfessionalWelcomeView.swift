import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Premium Onboarding View
// Multi-slide carousel showcasing app features with premium aesthetics

struct ProfessionalWelcomeView: View {
    @ObservedObject private var appManager = AppManager.shared
    @State private var currentPage = 0
    @State private var isAnimating = false
    
    // Theme Colors
    private let vibrantPurple = Color(red: 0.55, green: 0.40, blue: 0.95)
    private let deepPurple = Color(red: 0.35, green: 0.20, blue: 0.75)
    private let accentGold = Color(red: 0.95, green: 0.75, blue: 0.30)
    
    // Onboarding Slides
    private let slides: [(icon: String, title: String, subtitle: String, description: String)] = [
        (
            icon: "waveform.path.ecg.rectangle",
            title: "Track Your Health",
            subtitle: "All-in-One Dashboard",
            description: "Monitor glucose levels, blood pressure, and vital signs in a beautifully designed dashboard tailored for diabetes management."
        ),
        (
            icon: "brain.head.profile",
            title: "AI-Powered Insights",
            subtitle: "Smart Analysis",
            description: "Our advanced AI analyzes your medical reports and provides personalized recommendations to help you stay on top of your health."
        ),
        (
            icon: "lock.shield.fill",
            title: "Secure & Private",
            subtitle: "Your Data, Protected",
            description: "Bank-level encryption keeps your medical records safe. Your health data is never shared without your explicit consent."
        ),
        (
            icon: "chart.line.uptrend.xyaxis",
            title: "See Your Progress",
            subtitle: "Visual Health Timeline",
            description: "Track trends over time with interactive graphs. Understand how your lifestyle changes impact your glucose control."
        )
    ]
    
    var body: some View {
        ZStack {
            // Premium Gradient Background
            LinearGradient(
                colors: [deepPurple, vibrantPurple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip Button (Top Right)
                HStack {
                    Spacer()
                    if currentPage < slides.count - 1 {
                        Button(action: {
                            withAnimation(.spring()) {
                                currentPage = slides.count - 1
                            }
                        }) {
                            Text("Skip")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.trailing, 10)
                .frame(height: 50)
                
                // Icon Section
                ZStack {
                    // Glowing Background Circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 180, height: 180)
                        .blur(radius: 2)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                    
                    // Icon Container
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 140, height: 140)
                        
                        Image(systemName: slides[currentPage].icon)
                            .font(.system(size: 60, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, accentGold],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: accentGold.opacity(0.5), radius: 10, x: 0, y: 5)
                    }
                    .scaleEffect(isAnimating ? 1.0 : 0.9)
                    .opacity(isAnimating ? 1.0 : 0.0)
                }
                .frame(height: UIScreen.main.bounds.height * 0.32)
                
                // White Card Section
                ZStack {
                    Color.white
                        .clipShape(RoundedCorner(radius: 35, corners: [.topLeft, .topRight]))
                        .ignoresSafeArea(edges: .bottom)
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -10)
                    
                    VStack(spacing: 20) {
                        Spacer().frame(height: 35)
                        
                        // Subtitle Badge
                        Text(slides[currentPage].subtitle.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(vibrantPurple)
                            .tracking(2)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(vibrantPurple.opacity(0.1))
                            .clipShape(Capsule())
                            .opacity(isAnimating ? 1.0 : 0.0)
                            .offset(y: isAnimating ? 0 : 10)
                        
                        // Title
                        Text(slides[currentPage].title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.25))
                            .multilineTextAlignment(.center)
                            .opacity(isAnimating ? 1.0 : 0.0)
                            .offset(y: isAnimating ? 0 : 15)
                        
                        // Description
                        Text(slides[currentPage].description)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 35)
                            .opacity(isAnimating ? 1.0 : 0.0)
                            .offset(y: isAnimating ? 0 : 20)
                        
                        Spacer()
                        
                        // Page Indicators
                        HStack(spacing: 10) {
                            ForEach(0..<slides.count, id: \.self) { index in
                                Capsule()
                                    .fill(index == currentPage ? vibrantPurple : Color.gray.opacity(0.3))
                                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                                    .animation(.spring(), value: currentPage)
                            }
                        }
                        .padding(.bottom, 20)
                        
                        // Action Button
                        Button(action: {
                            if currentPage < slides.count - 1 {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    isAnimating = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    currentPage += 1
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                        isAnimating = true
                                    }
                                }
                            } else {
                                appManager.completeAllInOneDashboard()
                            }
                        }) {
                            HStack(spacing: 10) {
                                Text(currentPage == slides.count - 1 ? "Get Started" : "Continue")
                                    .font(.system(size: 18, weight: .semibold))
                                
                                Image(systemName: currentPage == slides.count - 1 ? "arrow.right.circle.fill" : "arrow.right")
                                    .font(.system(size: 18, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(
                                LinearGradient(
                                    colors: [vibrantPurple, deepPurple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(29)
                            .shadow(color: vibrantPurple.opacity(0.4), radius: 15, x: 0, y: 8)
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 40)
                        .opacity(isAnimating ? 1.0 : 0.0)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width < -threshold && currentPage < slides.count - 1 {
                        withAnimation(.spring()) {
                            isAnimating = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            currentPage += 1
                            withAnimation(.spring()) {
                                isAnimating = true
                            }
                        }
                    } else if value.translation.width > threshold && currentPage > 0 {
                        withAnimation(.spring()) {
                            isAnimating = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            currentPage -= 1
                            withAnimation(.spring()) {
                                isAnimating = true
                            }
                        }
                    }
                }
        )
    }
}

// Helper for rounded corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    ProfessionalWelcomeView()
}
