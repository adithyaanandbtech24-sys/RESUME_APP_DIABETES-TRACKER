
import SwiftUI

struct GuestLimitModal: View {
    @Binding var isPresented: Bool
    @ObservedObject var appManager = AppManager.shared
    
    // Theme colors
    private let gradientColors = [Color(red: 0.5, green: 0.4, blue: 0.9), Color(red: 0.7, green: 0.5, blue: 0.95)]
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // Modal Card
            VStack(spacing: 24) {
                // Header Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: gradientColors.map { $0.opacity(0.15) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.top, 24)
                
                // Title
                VStack(spacing: 8) {
                    Text("Guest Mode Limit Reached")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    
                    Text("Sign up or sign in to continue uploading reports and unlock all features.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                
                // Benefits
                VStack(alignment: .leading, spacing: 12) {
                    benefitRow(icon: "infinity", text: "Unlimited report uploads")
                    benefitRow(icon: "brain.head.profile", text: "Full AI analysis history")
                    benefitRow(icon: "chart.line.uptrend.xyaxis", text: "Long-term health trends")
                    benefitRow(icon: "icloud.and.arrow.up", text: "Cloud backup & sync")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(16)
                .padding(.horizontal, 16)
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Sign Up Button
                    Button(action: {
                        isPresented = false
                        // Navigate to auth screen
                        appManager.showAuthForSignUp()
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                            Text("Sign Up")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: gradientColors[0].opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    
                    // Sign In Button
                    Button(action: {
                        isPresented = false
                        // Navigate to auth screen
                        appManager.showAuthForSignIn()
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle")
                            Text("Already have an account? Sign In")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(gradientColors[0])
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(gradientColors[0], lineWidth: 2)
                        )
                        .cornerRadius(14)
                    }
                    
                    // Continue as Guest (limited)
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Continue with limited access")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 30, x: 0, y: 15)
            )
            .padding(.horizontal, 24)
        }
    }
    
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(gradientColors[0])
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.8))
            
            Spacer()
        }
    }
}
