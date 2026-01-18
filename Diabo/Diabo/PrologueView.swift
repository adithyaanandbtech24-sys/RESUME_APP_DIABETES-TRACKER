import SwiftUI

// Local Color Definitions
private let appPurple = Color(red: 0.8, green: 0.7, blue: 1.0)
private let vibrantPurple = Color(red: 0.65, green: 0.55, blue: 0.95)
private let darkPurple = Color(red: 0.45, green: 0.35, blue: 0.75) // New deeper shade for gradients

struct PrologueView: View {
    @State private var currentPage = 0
    @ObservedObject private var appManager = AppManager.shared
    
    // Toggles for Screen 3
    @State private var allowAI = true
    @State private var allowAnonymous = true
    
    var body: some View {
        ZStack {
            // Simplified Background
            vibrantPurple.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Paged Content
                TabView(selection: $currentPage) {
                    // Screen 1: Welcome
                    PrologueWelcomeView()
                        .tag(0)
                    
                    // Screen 2: Features
                    PrologueFeaturesView()
                        .tag(1)
                    
                    // Screen 3: Get Started
                    PrologueGetStartedView(allowAI: $allowAI, allowAnonymous: $allowAnonymous) {
                        appManager.completeAllInOneDashboard()
                    }
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Fixed Navigation Bar at the bottom
                if currentPage < 2 {
                    HStack {
                        // Page Indicators
                        HStack(spacing: 8) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        
                        Spacer()
                        
                        // Next Button
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text("Next")
                                    .fontWeight(.bold)
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Screen 1: Welcome (Mascot Hero)
struct PrologueWelcomeView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Mascot
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 340, height: 340)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0.0)
                
                Image("HealthOverviewPerson") // Reverted to original asset
                    .resizable()
                    .scaledToFit()
                    .frame(height: 500)
                    .offset(y: 40)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                    .scaleEffect(isAnimating ? 1.0 : 0.9)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1), value: isAnimating)
            }
            .padding(.bottom, 20)
            
            VStack(spacing: 24) {
                Text("Hi, I'm MediSync!")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("I'm here to help you organize your\nmedical history in one secure place.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)
            
            Spacer()
        }
        .onAppear { isAnimating = true }
    }
}

// MARK: - Screen 2: Features
struct PrologueFeaturesView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 15) {
                Text("What can I do?")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .shadow(radius: 4)
                
                VStack(spacing: 16) {
                    FeatureCard(icon: "doc.text.viewfinder", title: "Scan & Digitize", subtitle: "Turn paper reports into digital data.", delay: 0.1, isAnimating: isAnimating)
                    FeatureCard(icon: "chart.xyaxis.line", title: "Track Trends", subtitle: "See how your vitals change over time.", delay: 0.2, isAnimating: isAnimating)
                    FeatureCard(icon: "lock.shield", title: "Stay Private", subtitle: "Your data is encrypted and yours alone.", delay: 0.3, isAnimating: isAnimating)
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
            Spacer()
        }
        .onAppear { isAnimating = true }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let delay: Double
    var isAnimating: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(vibrantPurple)
                .frame(width: 54, height: 54)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .offset(x: isAnimating ? 0 : 50)
        .opacity(isAnimating ? 1.0 : 0.0)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay), value: isAnimating)
    }
}

// MARK: - Screen 3: Get Started
struct PrologueGetStartedView: View {
    @Binding var allowAI: Bool
    @Binding var allowAnonymous: Bool
    var onGetStarted: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Ready to start?")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Customize your privacy settings\nbefore we begin.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
            }
            .opacity(isAnimating ? 1.0 : 0.0)
            .animation(.easeOut.delay(0.1), value: isAnimating)
            
            VStack(spacing: 16) {
                // Privacy Cards
                PrivacyToggleCard(
                    title: "Enable AI Insights",
                    subtitle: "Get smart summaries of your reports.",
                    icon: "sparkles",
                    isOn: $allowAI
                )
                
                PrivacyToggleCard(
                    title: "Share Analytics",
                    subtitle: "Help improve MediSync (No PII).",
                    icon: "chart.bar.fill",
                    isOn: $allowAnonymous
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button(action: onGetStarted) {
                Text("Let's Go!")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(vibrantPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .onAppear { isAnimating = true }
    }
}

struct PrivacyToggleCard: View {
    let title: String
    let subtitle: String
    let icon: String // Added Icon
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isOn ? vibrantPurple : .gray)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.black)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: vibrantPurple))
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}
