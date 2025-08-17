import SwiftUI

// MARK: - Animation Manager
struct AppAnimations {
    
    // MARK: - Duration
    struct Duration {
        static let instant: Double = 0.0
        static let fast: Double = 0.15
        static let normal: Double = 0.25
        static let slow: Double = 0.35
        static let slower: Double = 0.5
        static let slowest: Double = 0.75
    }
    
    // MARK: - Easing
    struct Easing {
        static let linear = Animation.linear
        static let easeIn = Animation.easeIn
        static let easeOut = Animation.easeOut
        static let easeInOut = Animation.easeInOut
        
        static let spring = Animation.spring(
            response: 0.5,
            dampingFraction: 0.8,
            blendDuration: 0
        )
        
        static let bouncy = Animation.spring(
            response: 0.6,
            dampingFraction: 0.7,
            blendDuration: 0
        )
        
        static let smooth = Animation.interpolatingSpring(
            mass: 1.0,
            stiffness: 100.0,
            damping: 10.0,
            initialVelocity: 0.0
        )
    }
    
    // MARK: - Preset Animations
    struct Preset {
        // Message animations
        static let messageAppear = Animation.easeOut(duration: Duration.normal)
        static let messageDisappear = Animation.easeIn(duration: Duration.fast)
        
        // Input animations
        static let inputFocus = Animation.easeInOut(duration: Duration.fast)
        static let inputBlur = Animation.easeInOut(duration: Duration.fast)
        
        // Navigation animations
        static let navigationPush = Animation.easeInOut(duration: Duration.normal)
        static let navigationPop = Animation.easeInOut(duration: Duration.normal)
        
        // Button animations
        static let buttonPress = Animation.easeInOut(duration: Duration.fast)
        static let buttonRelease = Animation.easeInOut(duration: Duration.fast)
        
        // Loading animations
        static let loading = Animation.linear(duration: Duration.slowest).repeatForever(autoreverses: false)
        static let pulse = Animation.easeInOut(duration: Duration.normal).repeatForever(autoreverses: true)
        
        // Transition animations
        static let fadeIn = Animation.easeIn(duration: Duration.normal)
        static let fadeOut = Animation.easeOut(duration: Duration.fast)
        static let slideUp = Animation.easeOut(duration: Duration.normal)
        static let slideDown = Animation.easeIn(duration: Duration.normal)
        static let scaleIn = Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let scaleOut = Animation.easeIn(duration: Duration.fast)
    }
}

// MARK: - Animation Extensions
extension View {
    
    // MARK: - Message Animations
    func messageAppear() -> some View {
        self.transition(.asymmetric(
            insertion: .scale(scale: 0.8)
                .combined(with: .opacity)
                .combined(with: .offset(y: 20)),
            removal: .scale(scale: 0.8)
                .combined(with: .opacity)
                .combined(with: .offset(y: -20))
        ))
        .animation(AppAnimations.Preset.messageAppear, value: true)
    }
    
    func messageDisappear() -> some View {
        self.transition(.asymmetric(
            insertion: .scale(scale: 0.8)
                .combined(with: .opacity)
                .combined(with: .offset(y: 20)),
            removal: .scale(scale: 0.8)
                .combined(with: .opacity)
                .combined(with: .offset(y: -20))
        ))
        .animation(AppAnimations.Preset.messageDisappear, value: false)
    }
    
    // MARK: - Input Animations
    func inputFocus() -> some View {
        self.animation(AppAnimations.Preset.inputFocus, value: true)
    }
    
    func inputBlur() -> some View {
        self.animation(AppAnimations.Preset.inputBlur, value: false)
    }
    
    // MARK: - Button Animations
    func buttonPress() -> some View {
        self.scaleEffect(0.95)
            .animation(AppAnimations.Preset.buttonPress, value: true)
    }
    
    func buttonRelease() -> some View {
        self.scaleEffect(1.0)
            .animation(AppAnimations.Preset.buttonRelease, value: false)
    }
    
    // MARK: - Loading Animations
    func loading() -> some View {
        self.animation(AppAnimations.Preset.loading, value: true)
    }
    
    func pulse() -> some View {
        self.animation(AppAnimations.Preset.pulse, value: true)
    }
    
    // MARK: - Transition Animations
    func fadeIn() -> some View {
        self.transition(.opacity)
            .animation(AppAnimations.Preset.fadeIn, value: true)
    }
    
    func fadeOut() -> some View {
        self.transition(.opacity)
            .animation(AppAnimations.Preset.fadeOut, value: false)
    }
    
    func slideUp() -> some View {
        self.transition(.move(edge: .bottom))
            .animation(AppAnimations.Preset.slideUp, value: true)
    }
    
    func slideDown() -> some View {
        self.transition(.move(edge: .top))
            .animation(AppAnimations.Preset.slideDown, value: false)
    }
    
    func scaleIn() -> some View {
        self.transition(.scale(scale: 0.8).combined(with: .opacity))
            .animation(AppAnimations.Preset.scaleIn, value: true)
    }
    
    func scaleOut() -> some View {
        self.transition(.scale(scale: 0.8).combined(with: .opacity))
            .animation(AppAnimations.Preset.scaleOut, value: false)
    }
}

// MARK: - Staggered Animation
struct StaggeredAnimation<Content: View>: View {
    let delay: Double
    let content: Content
    
    init(delay: Double = 0.0, @ViewBuilder content: () -> Content) {
        self.delay = delay
        self.content = content()
    }
    
    var body: some View {
        content
            .opacity(0)
            .offset(y: 20)
            .onAppear {
                withAnimation(
                    AppAnimations.Preset.messageAppear
                        .delay(delay)
                ) {
                    // Animation will be handled by the parent view
                }
            }
    }
}

// MARK: - Animated Loading View
struct AnimatedLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(AppColors.primary)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .animation(
                    AppAnimations.Preset.pulse.delay(0.0),
                    value: isAnimating
                )
            
            Circle()
                .fill(AppColors.primary)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .animation(
                    AppAnimations.Preset.pulse.delay(0.1),
                    value: isAnimating
                )
            
            Circle()
                .fill(AppColors.primary)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .animation(
                    AppAnimations.Preset.pulse.delay(0.2),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Text("Claude is typing")
                .caption()
                .foregroundColor(AppColors.textSecondary)
            
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(AppColors.textTertiary)
                        .frame(width: 4, height: 4)
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .animation(
                            AppAnimations.Preset.pulse.delay(Double(index) * 0.1),
                            value: isAnimating
                        )
                }
            }
        }
        .padding(AppSpacing.Component.messageHorizontal)
        .background(AppColors.aiMessage)
        .cornerRadius(AppSpacing.CornerRadius.lg)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: AppSpacing.lg) {
        Text("Animation Manager Preview")
            .heading1()
        
        VStack(spacing: AppSpacing.md) {
            Text("Message Animation")
                .bodyBase()
                .padding()
                .background(AppColors.aiMessage)
                .cornerRadius(AppSpacing.CornerRadius.lg)
                .messageAppear()
            
            Text("Button Animation")
                .buttonBase()
                .padding()
                .background(AppColors.primary)
                .foregroundColor(.white)
                .cornerRadius(AppSpacing.CornerRadius.md)
                .buttonPress()
        }
        
        AnimatedLoadingView()
        
        TypingIndicator()
        
        HStack(spacing: AppSpacing.md) {
            Button("Fade In") { }
                .buttonBase()
                .padding()
                .background(AppColors.accent)
                .foregroundColor(.white)
                .cornerRadius(AppSpacing.CornerRadius.md)
                .fadeIn()
            
            Button("Scale In") { }
                .buttonBase()
                .padding()
                .background(AppColors.success)
                .foregroundColor(.white)
                .cornerRadius(AppSpacing.CornerRadius.md)
                .scaleIn()
        }
    }
    .padding()
    .background(AppColors.background)
}
