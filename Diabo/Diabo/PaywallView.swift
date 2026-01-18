
import SwiftUI

struct PaywallView: View {
    @Binding var isPresented: Bool
    @ObservedObject var appManager = AppManager.shared
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Background Image/Gradient
            LinearGradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()
                
                Spacer()
                
                // Icon
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    .padding()
                    .background(Circle().fill(Color.white.opacity(0.1)))
                
                // Text
                Text("Unlock Premium")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Get unlimited uploads, advanced AI analysis, and personalized health trends.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal)
                
                // Features
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(text: "Unlimited Report Uploads")
                    FeatureRow(text: "Advanced AI Chat Analysis")
                    FeatureRow(text: "Long-term Trend Graphs")
                    FeatureRow(text: "PDF Export")
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.1)))
                .padding(.horizontal)
                
                Spacer()
                
                // CTA
                Button(action: {
                    // Simulate Purchase
                    appManager.enterDemoMode() // Use Demo Mode as "Premium" for now
                    isPresented = false
                }) {
                    Text("Upgrade for $9.99/mo")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
    
    struct FeatureRow: View {
        let text: String
        var body: some View {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(text)
                    .foregroundColor(.white)
            }
        }
    }
}
