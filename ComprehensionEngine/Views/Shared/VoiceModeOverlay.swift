import SwiftUI

struct VoiceModeOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    let content: () -> Content

    @State private var dragOffsetY: CGFloat = 0

    init(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self._isPresented = isPresented
        self.content = content
    }

    var body: some View {
        ZStack {
            // Fully opaque background to prevent any underlying view from peeking
            AppColors.background
                .ignoresSafeArea()

            // Content container with custom transition and interactive dismissal
            content()
                .scaleEffect(contentScale)
                .offset(y: dragOffsetY)
                .transition(
                    AnyTransition.asymmetric(
                        insertion: .scale(scale: 0.92, anchor: .center).combined(with: .opacity),
                        removal: .scale(scale: 0.92, anchor: .center).combined(with: .opacity)
                    )
                )
                .gesture(dragGesture)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.26), value: isPresented)
        .animation(.easeInOut(duration: 0.26), value: dragOffsetY)
        .zIndex(1000)
        .allowsHitTesting(true)
    }

    private var contentScale: CGFloat {
        // Slight scaling feedback during drag; caps at ~0.96 when fully dragged
        let dragProgress = min(max(dragOffsetY / 1000.0, 0), 0.04)
        return 1.0 - dragProgress
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .onChanged { value in
                // Only consider downward drags for dismissal
                dragOffsetY = max(0, value.translation.height)
            }
            .onEnded { value in
                let downwardTranslation = max(0, value.translation.height)
                let predictedDownward = max(0, value.predictedEndTranslation.height)
                let threshold: CGFloat = 120
                let predictedThreshold: CGFloat = 160

                if downwardTranslation > threshold || predictedDownward > predictedThreshold {
                    withAnimation(.easeInOut(duration: 0.26)) {
                        isPresented = false
                        dragOffsetY = 0
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.26)) {
                        dragOffsetY = 0
                    }
                }
            }
    }
}





