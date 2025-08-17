import SwiftUI

// MARK: - Typography System
struct AppTypography {
    
    // MARK: - Font Families
    static let displayFont = "SF Pro Display"
    static let textFont = "SF Pro Text"
    
    // MARK: - Font Weights
    static let regular = Font.Weight.regular
    static let medium = Font.Weight.medium
    static let semibold = Font.Weight.semibold
    static let bold = Font.Weight.bold
    
    // MARK: - Font Sizes
    struct Size {
        static let xs: CGFloat = 10
        static let sm: CGFloat = 12
        static let base: CGFloat = 14
        static let lg: CGFloat = 16
        static let xl: CGFloat = 18
        static let xxl: CGFloat = 20
        static let xxxl: CGFloat = 24
        static let display: CGFloat = 32
        static let hero: CGFloat = 48
    }
    
    // MARK: - Line Heights
    struct LineHeight {
        static let tight: CGFloat = 1.2
        static let normal: CGFloat = 1.4
        static let relaxed: CGFloat = 1.6
        static let loose: CGFloat = 1.8
    }
    
    // MARK: - Letter Spacing
    struct LetterSpacing {
        static let tight: CGFloat = -0.5
        static let normal: CGFloat = 0
        static let wide: CGFloat = 0.5
        static let wider: CGFloat = 1.0
    }
}

// MARK: - Typography Extensions
extension Font {
    
    // MARK: - Display Fonts
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        // Use system font so SwiftUI applies weight without logging errors
        return .system(size: size, weight: weight, design: .default)
    }
    
    static func displayHero() -> Font {
        return .display(AppTypography.Size.hero, weight: .bold)
    }
    
    static func displayLarge() -> Font {
        return .display(AppTypography.Size.display, weight: .bold)
    }
    
    static func displayMedium() -> Font {
        return .display(AppTypography.Size.xxxl, weight: .semibold)
    }
    
    static func displaySmall() -> Font {
        return .display(AppTypography.Size.xxl, weight: .semibold)
    }
    
    // MARK: - Text Fonts
    static func text(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Use system font so SwiftUI applies weight without logging errors
        return .system(size: size, weight: weight, design: .default)
    }
    
    static func textLarge() -> Font {
        return .text(AppTypography.Size.xl, weight: .medium)
    }
    
    static func textBase() -> Font {
        return .text(AppTypography.Size.base, weight: .regular)
    }
    
    static func textSmall() -> Font {
        return .text(AppTypography.Size.sm, weight: .regular)
    }
    
    static func textExtraSmall() -> Font {
        return .text(AppTypography.Size.xs, weight: .regular)
    }
    
    // MARK: - Heading Fonts
    static func heading1() -> Font {
        return .display(AppTypography.Size.xxxl, weight: .bold)
    }
    
    static func heading2() -> Font {
        return .display(AppTypography.Size.xxl, weight: .semibold)
    }
    
    static func heading3() -> Font {
        return .display(AppTypography.Size.xl, weight: .semibold)
    }
    
    static func heading4() -> Font {
        return .text(AppTypography.Size.lg, weight: .medium)
    }
    
    // MARK: - Body Fonts
    static func bodyLarge() -> Font {
        return .text(AppTypography.Size.lg, weight: .regular)
    }
    
    static func bodyBase() -> Font {
        return .text(AppTypography.Size.base, weight: .regular)
    }
    
    static func bodySmall() -> Font {
        return .text(AppTypography.Size.sm, weight: .regular)
    }
    
    // MARK: - Caption Fonts
    static func caption() -> Font {
        return .text(AppTypography.Size.sm, weight: .regular)
    }
    
    static func captionSmall() -> Font {
        return .text(AppTypography.Size.xs, weight: .regular)
    }
    
    // MARK: - Button Fonts
    static func buttonLarge() -> Font {
        return .text(AppTypography.Size.lg, weight: .semibold)
    }
    
    static func buttonBase() -> Font {
        return .text(AppTypography.Size.base, weight: .semibold)
    }
    
    static func buttonSmall() -> Font {
        return .text(AppTypography.Size.sm, weight: .medium)
    }
}

// MARK: - Text Style Modifiers
struct TypographyModifier: ViewModifier {
    let font: Font
    let lineHeight: CGFloat
    let letterSpacing: CGFloat
    let color: Color
    
    init(
        font: Font,
        lineHeight: CGFloat = AppTypography.LineHeight.normal,
        letterSpacing: CGFloat = AppTypography.LetterSpacing.normal,
        color: Color = AppColors.textPrimary
    ) {
        self.font = font
        self.lineHeight = lineHeight
        self.letterSpacing = letterSpacing
        self.color = color
    }
    
    func body(content: Content) -> some View {
        content
            .font(font)
            .lineSpacing(lineHeight - 1.0)
            .tracking(letterSpacing)
            .foregroundColor(color)
    }
}

// MARK: - Typography Presets
extension View {
    
    // MARK: - Display Styles
    func displayHero() -> some View {
        modifier(TypographyModifier(
            font: .displayHero(),
            lineHeight: AppTypography.LineHeight.tight,
            letterSpacing: AppTypography.LetterSpacing.tight
        ))
    }
    
    func displayLarge() -> some View {
        modifier(TypographyModifier(
            font: .displayLarge(),
            lineHeight: AppTypography.LineHeight.tight,
            letterSpacing: AppTypography.LetterSpacing.tight
        ))
    }
    
    func displayMedium() -> some View {
        modifier(TypographyModifier(
            font: .displayMedium(),
            lineHeight: AppTypography.LineHeight.tight,
            letterSpacing: AppTypography.LetterSpacing.normal
        ))
    }
    
    func displaySmall() -> some View {
        modifier(TypographyModifier(
            font: .displaySmall(),
            lineHeight: AppTypography.LineHeight.normal,
            letterSpacing: AppTypography.LetterSpacing.normal
        ))
    }
    
    // MARK: - Heading Styles
    func heading1() -> some View {
        modifier(TypographyModifier(
            font: .heading1(),
            lineHeight: AppTypography.LineHeight.tight,
            letterSpacing: AppTypography.LetterSpacing.tight
        ))
    }
    
    func heading2() -> some View {
        modifier(TypographyModifier(
            font: .heading2(),
            lineHeight: AppTypography.LineHeight.tight,
            letterSpacing: AppTypography.LetterSpacing.normal
        ))
    }
    
    func heading3() -> some View {
        modifier(TypographyModifier(
            font: .heading3(),
            lineHeight: AppTypography.LineHeight.normal,
            letterSpacing: AppTypography.LetterSpacing.normal
        ))
    }
    
    func heading4() -> some View {
        modifier(TypographyModifier(
            font: .heading4(),
            lineHeight: AppTypography.LineHeight.normal,
            letterSpacing: AppTypography.LetterSpacing.normal
        ))
    }
    
    // MARK: - Body Styles
    func bodyLarge() -> some View {
        modifier(TypographyModifier(
            font: .bodyLarge(),
            lineHeight: AppTypography.LineHeight.relaxed,
            letterSpacing: AppTypography.LetterSpacing.normal
        ))
    }
    
    func bodyBase() -> some View {
        modifier(TypographyModifier(
            font: .bodyBase(),
            lineHeight: AppTypography.LineHeight.relaxed,
            letterSpacing: AppTypography.LetterSpacing.normal
        ))
    }
    
    func bodySmall() -> some View {
        modifier(TypographyModifier(
            font: .bodySmall(),
            lineHeight: AppTypography.LineHeight.relaxed,
            letterSpacing: AppTypography.LetterSpacing.normal
        ))
    }
    
    // MARK: - Caption Styles
    func caption() -> some View {
        modifier(TypographyModifier(
            font: .caption(),
            lineHeight: AppTypography.LineHeight.normal,
            letterSpacing: AppTypography.LetterSpacing.wide,
            color: AppColors.textSecondary
        ))
    }
    
    func captionSmall() -> some View {
        modifier(TypographyModifier(
            font: .captionSmall(),
            lineHeight: AppTypography.LineHeight.normal,
            letterSpacing: AppTypography.LetterSpacing.wide,
            color: AppColors.textTertiary
        ))
    }
    
    // MARK: - Button Styles
    func buttonLarge() -> some View {
        modifier(TypographyModifier(
            font: .buttonLarge(),
            lineHeight: AppTypography.LineHeight.tight,
            letterSpacing: AppTypography.LetterSpacing.wide
        ))
    }
    
    func buttonBase() -> some View {
        modifier(TypographyModifier(
            font: .buttonBase(),
            lineHeight: AppTypography.LineHeight.tight,
            letterSpacing: AppTypography.LetterSpacing.wide
        ))
    }
    
    func buttonSmall() -> some View {
        modifier(TypographyModifier(
            font: .buttonSmall(),
            lineHeight: AppTypography.LineHeight.tight,
            letterSpacing: AppTypography.LetterSpacing.wide
        ))
    }
}

// MARK: - Preview
#Preview {
    VStack(alignment: .leading, spacing: 20) {
        Text("Typography System Preview")
            .displayHero()
        
        Text("Display Large")
            .displayLarge()
        
        Text("Display Medium")
            .displayMedium()
        
        Text("Display Small")
            .displaySmall()
        
        Text("Heading 1")
            .heading1()
        
        Text("Heading 2")
            .heading2()
        
        Text("Heading 3")
            .heading3()
        
        Text("Heading 4")
            .heading4()
        
        Text("Body Large - This is a longer text to demonstrate line height and spacing in the body large style.")
            .bodyLarge()
        
        Text("Body Base - This is a longer text to demonstrate line height and spacing in the body base style.")
            .bodyBase()
        
        Text("Body Small - This is a longer text to demonstrate line height and spacing in the body small style.")
            .bodySmall()
        
        Text("Caption text")
            .caption()
        
        Text("Small caption text")
            .captionSmall()
        
        Button("Button Large") { }
            .buttonLarge()
        
        Button("Button Base") { }
            .buttonBase()
        
        Button("Button Small") { }
            .buttonSmall()
    }
    .padding()
    .background(AppColors.background)
}
