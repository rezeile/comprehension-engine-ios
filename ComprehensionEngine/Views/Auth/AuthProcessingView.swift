import SwiftUI
import UIKit

struct AuthProcessingView: View {
    var body: some View {
        ZStack {
            AppColors.brandLinearGradient()
                .ignoresSafeArea()

            Color.black.opacity(0.25)
                .ignoresSafeArea()

            Group {
                if UIAccessibility.isReduceMotionEnabled {
                    ProgressView("Signing in…")
                        .progressViewStyle(.circular)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityLabel("Signing in")
                        .accessibilityHint("Please wait")
                        .foregroundColor(.white)
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    RotatingDiamond()
                        .frame(width: 96, height: 96)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .contain)
        }
        .accessibilityIdentifier("auth-processing-view")
    }
}

private struct RotatingDiamond: View {
    @State private var rotation: Angle = .degrees(0)

    var body: some View {
        TimelineView(.animation) { context in
            let _ = context.date
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.brandAngularGradient())
                .rotationEffect(.degrees(45))
                .shadow(color: AppColors.brandGlow, radius: 20)
                .onAppear {
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                        rotation = .degrees(360)
                    }
                }
                .rotationEffect(rotation)
        }
    }
}

#Preview {
    AuthProcessingView()
}


