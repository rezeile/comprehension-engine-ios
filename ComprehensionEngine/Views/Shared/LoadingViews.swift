import SwiftUI

// MARK: - Loading Views
struct LoadingViews {
    
    // MARK: - Circular Loading
    struct Circular: View {
        let size: LoadingSize
        let color: Color
        let isAnimating: Bool
        
        init(
            size: LoadingSize = .medium,
            color: Color = .blue,
            isAnimating: Bool = true
        ) {
            self.size = size
            self.color = color
            self.isAnimating = isAnimating
        }
        
        var body: some View {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: color))
                .scaleEffect(scaleFactor)
                .animation(
                    isAnimating ? AppAnimations.Preset.loading : .linear(duration: 0),
                    value: isAnimating
                )
        }
        
        private var scaleFactor: CGFloat {
            switch size {
            case .small:
                return 0.6
            case .medium:
                return 1.0
            case .large:
                return 1.4
            }
        }
    }
    
    // MARK: - Lightweight Waveform (bars)
    struct WaveformBars: View {
        let level: Float // 0..1
        let barCount: Int
        let color: Color
        
        init(level: Float, barCount: Int = 24, color: Color = AppColors.primary) {
            self.level = level
            self.barCount = barCount
            self.color = color
        }
        
        var body: some View {
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: 4, height: barHeight(for: index))
                        .animation(AppAnimations.Preset.pulse.speed(1.2).delay(Double(index) * 0.02), value: level)
                }
            }
        }
        
        private func barHeight(for index: Int) -> CGFloat {
            let normalizedIndex = Double(index) / Double(max(1, barCount - 1))
            let envelope = sin(normalizedIndex * .pi)
            let base: CGFloat = 8
            let amplitude: CGFloat = CGFloat(level) * 48
            return base + CGFloat(envelope) * amplitude
        }
    }
    
    // MARK: - Dots Loading
    struct Dots: View {
        let count: Int
        let color: Color
        let spacing: CGFloat
        let isAnimating: Bool
        
        @State private var animationPhase: CGFloat = 0
        
        init(
            count: Int = 3,
            color: Color = .blue,
            spacing: CGFloat = 4,
            isAnimating: Bool = true
        ) {
            self.count = count
            self.color = color
            self.spacing = spacing
            self.isAnimating = isAnimating
        }
        
        var body: some View {
            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { index in
                    Circle()
                        .fill(color)
                        .frame(width: dotSize, height: dotSize)
                        .scaleEffect(scaleEffect(for: index))
                        .animation(
                            isAnimating ? AppAnimations.Preset.pulse.delay(Double(index) * 0.1) : .linear(duration: 0),
                            value: isAnimating
                        )
                }
            }
            .onAppear {
                if isAnimating {
                    startAnimation()
                }
            }
        }
        
        private var dotSize: CGFloat {
            return 8
        }
        
        private func scaleEffect(for index: Int) -> CGFloat {
            guard isAnimating else { return 1.0 }
            let delay = Double(index) * 0.1
            let phase = (animationPhase + delay).truncatingRemainder(dividingBy: 1.0)
            return 0.5 + 0.5 * sin(phase * 2 * .pi)
        }
        
        private func startAnimation() {
            withAnimation(AppAnimations.Preset.pulse) {
                animationPhase = 1.0
            }
        }
    }
    
    // MARK: - Typing Indicator (3 dots)
    struct TypingIndicator: View {
        var body: some View {
            HStack(spacing: 6) {
                LoadingDot(delay: 0.0)
                LoadingDot(delay: 0.2)
                LoadingDot(delay: 0.4)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.systemGray5, lineWidth: 1)
            )
            .shadow(AppSpacing.Shadow.small)
        }
    }
    
    private struct LoadingDot: View {
        let delay: Double
        @State private var scale: CGFloat = 0.6
        
        var body: some View {
            Circle()
                .fill(AppColors.systemGray3)
                .frame(width: 8, height: 8)
                .scaleEffect(scale)
                .onAppear {
                    withAnimation(AppAnimations.Preset.pulse.delay(delay)) {
                        scale = 1.0
                    }
                }
        }
    }
    
    // MARK: - Wave Loading
    struct Wave: View {
        let count: Int
        let color: Color
        let isAnimating: Bool
        
        @State private var animationPhase: CGFloat = 0
        
        init(
            count: Int = 5,
            color: Color = .blue,
            isAnimating: Bool = true
        ) {
            self.count = count
            self.color = color
            self.isAnimating = isAnimating
        }
        
        var body: some View {
            HStack(spacing: 2) {
                ForEach(0..<count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: 3, height: waveHeight(for: index))
                        .animation(
                            isAnimating ? AppAnimations.Preset.pulse.delay(Double(index) * 0.1) : .linear(duration: 0),
                            value: isAnimating
                        )
                }
            }
            .onAppear {
                if isAnimating {
                    startAnimation()
                }
            }
        }
        
        private func waveHeight(for index: Int) -> CGFloat {
            guard isAnimating else { return 20 }
            let delay = Double(index) * 0.1
            let phase = (animationPhase + delay).truncatingRemainder(dividingBy: 1.0)
            return 8 + 24 * sin(phase * 2 * .pi)
        }
        
        private func startAnimation() {
            withAnimation(AppAnimations.Preset.pulse) {
                animationPhase = 1.0
            }
        }
    }
    
    // MARK: - Pulse Loading
    struct Pulse: View {
        let color: Color
        let isAnimating: Bool
        
        @State private var isPulsing = false
        
        init(
            color: Color = .blue,
            isAnimating: Bool = true
        ) {
            self.color = color
            self.isAnimating = isAnimating
        }
        
        var body: some View {
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
                .scaleEffect(isPulsing ? 1.2 : 0.8)
                .opacity(isPulsing ? 0.6 : 1.0)
                .animation(
                    isAnimating ? AppAnimations.Preset.pulse : .linear(duration: 0),
                    value: isAnimating
                )
                .onAppear {
                    if isAnimating {
                        isPulsing = true
                    }
                }
        }
    }
    
    // MARK: - Skeleton Loading
    struct Skeleton: View {
        let width: CGFloat?
        let height: CGFloat
        let cornerRadius: CGFloat
        let isAnimating: Bool
        
        @State private var animationPhase: CGFloat = 0
        
        init(
            width: CGFloat? = nil,
            height: CGFloat = 20,
            cornerRadius: CGFloat = 4,
            isAnimating: Bool = true
        ) {
            self.width = width
            self.height = height
            self.cornerRadius = cornerRadius
            self.isAnimating = isAnimating
        }
        
        var body: some View {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemGray5),
                            Color(.systemGray6),
                            Color(.systemGray5)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: height)
                .mask(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .white,
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: -((width ?? 0)) + ((width ?? 0)) * animationPhase)
                )
                .animation(
                    isAnimating ? AppAnimations.Preset.loading : .linear(duration: 0),
                    value: isAnimating
                )
                .onAppear {
                    if isAnimating {
                        startAnimation()
                    }
                }
        }
        
        private func startAnimation() {
            withAnimation(AppAnimations.Preset.loading) {
                animationPhase = 2.0
            }
        }
    }
}

// MARK: - Loading Size Enum
enum LoadingSize {
    case small
    case medium
    case large
}

// MARK: - Loading State View
struct LoadingStateView: View {
    let title: String
    let subtitle: String?
    let loadingType: LoadingType
    let isAnimating: Bool
    
    init(
        title: String,
        subtitle: String? = nil,
        loadingType: LoadingType = .default,
        isAnimating: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.loadingType = loadingType
        self.isAnimating = isAnimating
    }
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            loadingView
            
            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .bodyLarge()
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(AppSpacing.Component.cardPadding)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(AppSpacing.Component.cardCornerRadius)
        .shadow(AppSpacing.Shadow.small)
    }
    
    @ViewBuilder
    private var loadingView: some View {
        switch loadingType {
        case .circular(let size, let color):
            LoadingViews.Circular(size: size, color: color, isAnimating: isAnimating)
        case .dots(let count, let color, let spacing):
            LoadingViews.Dots(count: count, color: color, spacing: spacing, isAnimating: isAnimating)
        case .wave(let count, let color):
            LoadingViews.Wave(count: count, color: color, isAnimating: isAnimating)
        case .pulse(let color):
            LoadingViews.Pulse(color: color, isAnimating: isAnimating)
        case .skeleton(let width, let height, let cornerRadius):
            LoadingViews.Skeleton(width: width, height: height, cornerRadius: cornerRadius, isAnimating: isAnimating)
        }
    }
}

// MARK: - Loading Type Enum
enum LoadingType {
    case circular(size: LoadingSize = .medium, color: Color = .blue)
    case dots(count: Int = 3, color: Color = .blue, spacing: CGFloat = 4)
    case wave(count: Int = 5, color: Color = .blue)
    case pulse(color: Color = .blue)
    case skeleton(width: CGFloat? = nil, height: CGFloat = 20, cornerRadius: CGFloat = 4)
    
    static let `default` = LoadingType.circular()
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    let isLoading: Bool
    let loadingType: LoadingType
    let backgroundColor: Color
    
    init(
        isLoading: Bool,
        loadingType: LoadingType = .default,
        backgroundColor: Color = .black.opacity(0.5)
    ) {
        self.isLoading = isLoading
        self.loadingType = loadingType
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        if isLoading {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                
                LoadingStateView(
                    title: "Loading...",
                    loadingType: loadingType
                )
            }
            .transition(.opacity)
            .animation(AppAnimations.Preset.fadeIn, value: isLoading)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: AppSpacing.lg) {
        Text("Loading Views Preview")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(spacing: AppSpacing.md) {
            Text("Circular Loading")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack(spacing: AppSpacing.md) {
                LoadingViews.Circular(size: .small)
                LoadingViews.Circular(size: .medium)
                LoadingViews.Circular(size: .large)
            }
        }
        
        VStack(spacing: AppSpacing.md) {
            Text("Dots Loading")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack(spacing: AppSpacing.md) {
                LoadingViews.Dots(count: 3)
                LoadingViews.Dots(count: 5, color: .green)
                LoadingViews.Dots(count: 7, color: .orange)
            }
        }
        
        VStack(spacing: AppSpacing.md) {
            Text("Wave Loading")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack(spacing: AppSpacing.md) {
                LoadingViews.Wave(count: 3)
                LoadingViews.Wave(count: 5, color: .green)
                LoadingViews.Wave(count: 7, color: .orange)
            }
        }
        
        VStack(spacing: AppSpacing.md) {
            Text("Pulse Loading")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack(spacing: AppSpacing.md) {
                LoadingViews.Pulse(color: .blue)
                LoadingViews.Pulse(color: .green)
                LoadingViews.Pulse(color: .orange)
            }
        }
        
        VStack(spacing: AppSpacing.md) {
            Text("Skeleton Loading")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: AppSpacing.sm) {
                LoadingViews.Skeleton(width: 200, height: 20)
                LoadingViews.Skeleton(width: 150, height: 16)
                LoadingViews.Skeleton(width: 250, height: 24)
            }
        }
        
        VStack(spacing: AppSpacing.md) {
            Text("Loading State View")
                .font(.title2)
                .fontWeight(.semibold)
            
            LoadingStateView(
                title: "Processing your request",
                subtitle: "This may take a few moments",
                loadingType: .circular(size: .large, color: .blue)
            )
        }
    }
    .padding()
    .background(Color(.systemBackground))
}
