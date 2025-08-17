import SwiftUI

// MARK: - Spacing System
struct AppSpacing {
    
    // MARK: - Base Unit
    static let baseUnit: CGFloat = 8
    
    // MARK: - Spacing Scale
    static let xs: CGFloat = baseUnit * 0.5      // 4
    static let sm: CGFloat = baseUnit            // 8
    static let md: CGFloat = baseUnit * 2        // 16
    static let lg: CGFloat = baseUnit * 3        // 24
    static let xl: CGFloat = baseUnit * 4        // 32
    static let xxl: CGFloat = baseUnit * 6       // 48
    static let xxxl: CGFloat = baseUnit * 8      // 64
    
    // MARK: - Component Spacing
    struct Component {
        // Chat message spacing
        static let messageVertical: CGFloat = 12
        static let messageHorizontal: CGFloat = 16
        static let messageGroup: CGFloat = 24
        
        // Input area spacing
        static let inputPadding: CGFloat = 16
        static let inputSpacing: CGFloat = 12
        static let inputHeight: CGFloat = 44
        
        // Navigation spacing
        static let navigationPadding: CGFloat = 16
        static let navigationSpacing: CGFloat = 12
        
        // Button spacing
        static let buttonPadding: CGFloat = 16
        static let buttonSpacing: CGFloat = 12
        static let buttonHeight: CGFloat = 44
        static let buttonHeightSmall: CGFloat = 36
        
        // Card spacing
        static let cardPadding: CGFloat = 20
        static let cardSpacing: CGFloat = 16
        static let cardCornerRadius: CGFloat = 16
        
        // List spacing
        static let listSpacing: CGFloat = 8
        static let listPadding: CGFloat = 16
        static let listSeparator: CGFloat = 1
    }
    
    // MARK: - Layout Spacing
    struct Layout {
        // Screen margins
        static let screenMargin: CGFloat = 20
        static let screenMarginSmall: CGFloat = 16
        static let screenMarginLarge: CGFloat = 24
        
        // Section spacing
        static let sectionSpacing: CGFloat = 32
        static let sectionSpacingLarge: CGFloat = 48
        
        // Content spacing
        static let contentSpacing: CGFloat = 24
        static let contentSpacingLarge: CGFloat = 32
        
        // Header spacing
        static let headerSpacing: CGFloat = 16
        static let headerSpacingLarge: CGFloat = 24
    }
    
    // MARK: - Safe Area
    struct SafeArea {
        static let top: CGFloat = 44
        static let bottom: CGFloat = 34
        static let horizontal: CGFloat = 20
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let round: CGFloat = 50
        static let pill: CGFloat = 25
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let small = ShadowStyle(
            radius: 2,
            x: 0,
            y: 1,
            opacity: 0.05
        )
        
        static let medium = ShadowStyle(
            radius: 4,
            x: 0,
            y: 2,
            opacity: 0.1
        )
        
        static let large = ShadowStyle(
            radius: 8,
            x: 0,
            y: 4,
            opacity: 0.15
        )
        
        static let extraLarge = ShadowStyle(
            radius: 16,
            x: 0,
            y: 8,
            opacity: 0.2
        )
    }
}

// MARK: - Shadow Style
struct ShadowStyle {
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    let opacity: Double
}

// MARK: - Spacing Extensions
extension View {
    
    // MARK: - Shadow Extensions
    func shadow(_ shadow: ShadowStyle) -> some View {
        self.shadow(
            color: .black.opacity(shadow.opacity),
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
}

// Intentionally no custom initializers for stack/grid types to avoid recursion with SwiftUI's built-in inits

// MARK: - Spacing Modifiers
struct SpacingModifier: ViewModifier {
    let spacing: CGFloat
    
    func body(content: Content) -> some View {
        content
            .padding(spacing)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: AppSpacing.lg) {
        Text("Spacing System Preview")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(spacing: AppSpacing.Component.messageVertical) {
            Text("Message 1")
                .padding(AppSpacing.Component.messageHorizontal)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(AppSpacing.CornerRadius.lg)
            
            Text("Message 2")
                .padding(AppSpacing.Component.messageHorizontal)
                .background(Color.green.opacity(0.1))
                .foregroundColor(.primary)
                .cornerRadius(AppSpacing.CornerRadius.lg)
        }
        
        HStack(spacing: AppSpacing.Component.buttonSpacing) {
            Button("Button 1") { }
                .padding(AppSpacing.Component.buttonPadding)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(AppSpacing.CornerRadius.md)
                .shadow(AppSpacing.Shadow.medium)
            
            Button("Button 2") { }
                .padding(AppSpacing.Component.buttonPadding)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(AppSpacing.CornerRadius.md)
                .shadow(AppSpacing.Shadow.small)
        }
        
        Text("This demonstrates the consistent spacing system throughout the app.")
            .font(.body)
            .padding(AppSpacing.Component.cardPadding)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(AppSpacing.Component.cardCornerRadius)
            .shadow(AppSpacing.Shadow.small)
    }
    .padding(AppSpacing.Layout.screenMargin)
    .background(Color(.systemBackground))
}
