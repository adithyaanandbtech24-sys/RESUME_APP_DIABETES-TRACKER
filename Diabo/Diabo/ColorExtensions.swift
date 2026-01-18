import SwiftUI

extension Color {
    // Exact colors matching reference image
    static let appPurple = Color(red: 0.8, green: 0.7, blue: 1.0)
    static let appPink = Color(red: 1.0, green: 0.85, blue: 0.9)
    static let appYellow = Color(red: 0.98, green: 0.75, blue: 0.45)
    static let appOrange = Color(red: 1.0, green: 0.7, blue: 0.4)
    static let appBlue = Color(red: 0.8, green: 0.9, blue: 1.0)
    static let appGreen = Color(red: 0.7, green: 0.9, blue: 0.7)
    static let appLightBlue = Color(red: 0.7, green: 0.8, blue: 1.0)
    static let appGray = Color.gray.opacity(0.5)
    static let appRed = Color(red: 1.0, green: 0.6, blue: 0.6)
    static let tabBarBlack = Color.black.opacity(0.8)
    
    // Darker colors for Upload Options
    static let uploadBlue = Color(red: 0.4, green: 0.7, blue: 0.95)
    static let uploadPurple = Color(red: 0.6, green: 0.5, blue: 0.95)
    
    // NEW: Unified Professional Medical Palette (Harmonized with appPurple)
    static let medicalPurpleDeep = Color(red: 0.25, green: 0.15, blue: 0.45) // Professional dark text
    static let medicalPurpleLight = Color(red: 0.94, green: 0.92, blue: 0.98) // Soft card background
    static let medicalPurpleMedium = Color(red: 0.82, green: 0.75, blue: 0.94) // Subtle highlight
    static let vibrantPurple = Color(red: 0.65, green: 0.55, blue: 0.95) // Darker, more professional action color
    
    // Hex Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
