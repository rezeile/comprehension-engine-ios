import SwiftUI

// MARK: - Color Scheme
struct AppColors {
    
    // MARK: - Primary Colors
    static let primary = Color(hex: "007AFF")
    static let primaryLight = Color(hex: "5AC8FA")
    static let primaryDark = Color(hex: "0056CC")
    
    // MARK: - Secondary Colors
    static let secondary = Color(hex: "F2F2F7")
    static let secondaryLight = Color(hex: "F9F9F9")
    static let secondaryDark = Color(hex: "E5E5EA")
    
    // MARK: - Background Colors
    static let background = Color(hex: "FFFFFF")
    static let backgroundSecondary = Color(hex: "FAFAFA")
    static let backgroundTertiary = Color(hex: "F5F5F5")
    
    // MARK: - Text Colors
    static let textPrimary = Color(hex: "1C1C1E")
    static let textSecondary = Color(hex: "3C3C43")
    static let textTertiary = Color(hex: "8E8E93")
    static let textQuaternary = Color(hex: "C7C7CC")
    
    // MARK: - Accent Colors
    static let accent = Color(hex: "FF9500")
    static let accentLight = Color(hex: "FFB340")
    static let accentDark = Color(hex: "E6850E")
    
    // MARK: - Status Colors
    static let success = Color(hex: "34C759")
    static let successLight = Color(hex: "5CD666")
    static let warning = Color(hex: "FF9500")
    static let error = Color(hex: "FF3B30")
    static let errorLight = Color(hex: "FF6961")
    
    // MARK: - Chat Colors
    static let userMessage = Color(hex: "007AFF")
    static let userMessageLight = Color(hex: "5AC8FA")
    static let aiMessage = Color(hex: "F2F2F7")
    static let aiMessageBorder = Color(hex: "E5E5EA")
    
    // MARK: - System Colors
    static let systemGray = Color(hex: "8E8E93")
    static let systemGray2 = Color(hex: "AEAEB2")
    static let systemGray3 = Color(hex: "C7C7CC")
    static let systemGray4 = Color(hex: "D1D1D6")
    static let systemGray5 = Color(hex: "E5E5EA")
    static let systemGray6 = Color(hex: "F2F2F7")
    
    // MARK: - Shadow Colors
    static let shadowLight = Color.black.opacity(0.05)
    static let shadowMedium = Color.black.opacity(0.1)
    static let shadowDark = Color.black.opacity(0.15)
    
    // MARK: - Overlay Colors
    static let overlay = Color.black.opacity(0.4)
    static let overlayLight = Color.black.opacity(0.2)

    // MARK: - Brand / Marketing
    static var brandGradientStops: [Color] {
        [
            Color(hex: "7C3AED"), // violet
            Color(hex: "EC4899"), // pink
            Color(hex: "22D3EE"), // cyan
            Color(hex: "F59E0B")  // amber
        ]
    }

    static func brandLinearGradient() -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: AppColors.brandGradientStops),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func brandAngularGradient() -> AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: AppColors.brandGradientStops),
            center: .center
        )
    }

    static let brandGlow = Color.white.opacity(0.25)
    static let focusRing = Color(hex: "60A5FA") // light blue focus ring
}

// MARK: - Color Extensions
extension Color {
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

// MARK: - Semantic Color Usage
extension AppColors {
    
    // MARK: - Message Colors
    static func messageBackground(for isFromUser: Bool) -> Color {
        return isFromUser ? userMessage : aiMessage
    }
    
    static func messageText(for isFromUser: Bool) -> Color {
        return isFromUser ? .white : textPrimary
    }
    
    static func messageBorder(for isFromUser: Bool) -> Color {
        return isFromUser ? .clear : aiMessageBorder
    }
    
    // MARK: - Input Colors
    static let inputBackground = background
    static let inputBorder = systemGray5
    static let inputBorderFocused = primary
    static let inputPlaceholder = textTertiary
    
    // MARK: - Button Colors
    static func buttonBackground(for style: ButtonStyle) -> Color {
        switch style {
        case .primary:
            return primary
        case .secondary:
            return secondary
        case .tertiary:
            return .clear
        case .destructive:
            return error
        }
    }
    
    static func buttonText(for style: ButtonStyle) -> Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return textPrimary
        case .tertiary:
            return primary
        case .destructive:
            return .white
        }
    }
}

// MARK: - Button Style Enum
enum ButtonStyle {
    case primary
    case secondary
    case tertiary
    case destructive
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        Text("Color Scheme Preview")
            .font(.title)
            .foregroundColor(AppColors.textPrimary)
        
        HStack {
            Circle()
                .fill(AppColors.primary)
                .frame(width: 40, height: 40)
            Text("Primary")
                .foregroundColor(AppColors.textPrimary)
        }
        
        HStack {
            Circle()
                .fill(AppColors.accent)
                .frame(width: 40, height: 40)
            Text("Accent")
                .foregroundColor(AppColors.textPrimary)
        }
        
        HStack {
            Circle()
                .fill(AppColors.success)
                .frame(width: 40, height: 40)
            Text("Success")
                .foregroundColor(AppColors.textPrimary)
        }
        
        HStack {
            Circle()
                .fill(AppColors.error)
                .frame(width: 40, height: 40)
            Text("Error")
                .foregroundColor(AppColors.textPrimary)
        }
    }
    .padding()
    .background(AppColors.background)
}
