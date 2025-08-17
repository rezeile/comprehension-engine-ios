import SwiftUI

// MARK: - Modern Button
struct ModernButton: View {
    let title: String
    let style: ButtonStyle
    let size: ButtonSize
    let isFullWidth: Bool
    let isLoading: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        _ title: String,
        style: ButtonStyle = .primary,
        size: ButtonSize = .base,
        isFullWidth: Bool = false,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.isFullWidth = isFullWidth
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if !isLoading {
                action()
            }
        }) {
            HStack(spacing: AppSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: buttonTextColor))
                }
                
                Text(title)
                    .font(buttonFont)
                    .foregroundColor(buttonTextColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: buttonHeight)
            .padding(.horizontal, buttonHorizontalPadding)
            .background(buttonBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: buttonCornerRadius)
                    .stroke(buttonBorderColor, lineWidth: buttonBorderWidth)
            )
            .cornerRadius(buttonCornerRadius)
            .shadow(buttonShadow)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isLoading ? 0.7 : 1.0)
        }
        .disabled(isLoading)
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(AppAnimations.Preset.buttonPress) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    // MARK: - Computed Properties
    
    private var buttonFont: Font {
        switch size {
        case .small:
            return .buttonSmall()
        case .base:
            return .buttonBase()
        case .large:
            return .buttonLarge()
        }
    }
    
    private var buttonHeight: CGFloat {
        switch size {
        case .small:
            return AppSpacing.Component.buttonHeightSmall
        case .base:
            return AppSpacing.Component.buttonHeight
        case .large:
            return AppSpacing.Component.buttonHeight + 8
        }
    }
    
    private var buttonHorizontalPadding: CGFloat {
        switch size {
        case .small:
            return AppSpacing.Component.buttonPadding - 4
        case .base:
            return AppSpacing.Component.buttonPadding
        case .large:
            return AppSpacing.Component.buttonPadding + 4
        }
    }
    
    private var buttonCornerRadius: CGFloat {
        switch size {
        case .small:
            return AppSpacing.CornerRadius.sm
        case .base:
            return AppSpacing.CornerRadius.md
        case .large:
            return AppSpacing.CornerRadius.lg
        }
    }
    
    private var buttonBackgroundColor: Color {
        if isLoading {
            return AppColors.buttonBackground(for: style).opacity(0.8)
        }
        return AppColors.buttonBackground(for: style)
    }
    
    private var buttonTextColor: Color {
        return AppColors.buttonText(for: style)
    }
    
    private var buttonBorderColor: Color {
        switch style {
        case .primary, .destructive:
            return .clear
        case .secondary:
            return AppColors.systemGray4
        case .tertiary:
            return AppColors.primary.opacity(0.3)
        }
    }
    
    private var buttonBorderWidth: CGFloat {
        switch style {
        case .primary, .destructive:
            return 0
        case .secondary, .tertiary:
            return 1
        }
    }
    
    private var buttonShadow: ShadowStyle {
        switch style {
        case .primary:
            return AppSpacing.Shadow.medium
        case .secondary:
            return AppSpacing.Shadow.small
        case .tertiary:
            return AppSpacing.Shadow.small
        case .destructive:
            return AppSpacing.Shadow.medium
        }
    }
}

// MARK: - Button Size Enum
enum ButtonSize {
    case small
    case base
    case large
}

// MARK: - Icon Button
struct ModernIconButton: View {
    let icon: String
    let style: ButtonStyle
    let size: ButtonSize
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        icon: String,
        style: ButtonStyle = .secondary,
        size: ButtonSize = .base,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.style = style
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(iconFont)
                .foregroundColor(buttonTextColor)
                .frame(width: buttonSize, height: buttonSize)
                .background(buttonBackgroundColor)
                .overlay(
                    Circle()
                        .stroke(buttonBorderColor, lineWidth: buttonBorderWidth)
                )
                .clipShape(Circle())
                .shadow(buttonShadow)
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(AppAnimations.Preset.buttonPress) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    // MARK: - Computed Properties
    
    private var iconFont: Font {
        switch size {
        case .small:
            return .system(size: 16, weight: .medium)
        case .base:
            return .system(size: 18, weight: .medium)
        case .large:
            return .system(size: 22, weight: .medium)
        }
    }
    
    private var buttonSize: CGFloat {
        switch size {
        case .small:
            return 32
        case .base:
            return 44
        case .large:
            return 56
        }
    }
    
    private var buttonBackgroundColor: Color {
        return AppColors.buttonBackground(for: style)
    }
    
    private var buttonTextColor: Color {
        return AppColors.buttonText(for: style)
    }
    
    private var buttonBorderColor: Color {
        switch style {
        case .primary, .destructive:
            return .clear
        case .secondary:
            return AppColors.systemGray4
        case .tertiary:
            return AppColors.primary.opacity(0.3)
        }
    }
    
    private var buttonBorderWidth: CGFloat {
        switch style {
        case .primary, .destructive:
            return 0
        case .secondary, .tertiary:
            return 1
        }
    }
    
    private var buttonShadow: ShadowStyle {
        switch style {
        case .primary:
            return AppSpacing.Shadow.medium
        case .secondary:
            return AppSpacing.Shadow.small
        case .tertiary:
            return AppSpacing.Shadow.small
        case .destructive:
            return AppSpacing.Shadow.medium
        }
    }
}

// MARK: - Floating Action Button
struct ModernFloatingActionButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(icon: String, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(AppSpacing.Shadow.large)
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(AppAnimations.Preset.buttonPress) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: AppSpacing.lg) {
        Text("Modern Button Components")
            .heading1()
        
        VStack(spacing: AppSpacing.md) {
            Text("Button Styles")
                .heading3()
            
            VStack(spacing: AppSpacing.sm) {
                ModernButton("Primary Button", style: .primary) { }
                ModernButton("Secondary Button", style: .secondary) { }
                ModernButton("Tertiary Button", style: .tertiary) { }
                ModernButton("Destructive Button", style: .destructive) { }
            }
        }
        
        VStack(spacing: AppSpacing.md) {
            Text("Button Sizes")
                .heading3()
            
            VStack(spacing: AppSpacing.sm) {
                ModernButton("Small Button", size: .small) { }
                ModernButton("Base Button", size: .base) { }
                ModernButton("Large Button", size: .large) { }
            }
        }
        
        VStack(spacing: AppSpacing.md) {
            Text("Icon Buttons")
                .heading3()
            
            HStack(spacing: AppSpacing.md) {
                ModernIconButton(icon: "mic.fill", style: .primary) { }
                ModernIconButton(icon: "paperplane.fill", style: .secondary) { }
                ModernIconButton(icon: "plus", style: .tertiary) { }
                ModernIconButton(icon: "trash", style: .destructive) { }
            }
        }
        
        VStack(spacing: AppSpacing.md) {
            Text("Floating Action Button")
                .heading3()
            
            ModernFloatingActionButton(icon: "plus") { }
        }
        
        VStack(spacing: AppSpacing.md) {
            Text("Loading State")
                .heading3()
            
            ModernButton("Loading Button", isLoading: true) { }
        }
        
        VStack(spacing: AppSpacing.md) {
            Text("Full Width")
                .heading3()
            
            ModernButton("Full Width Button", isFullWidth: true) { }
        }
    }
    .padding()
    .background(AppColors.background)
}
