import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var isProcessing: Bool = false

    var body: some View {
        ZStack {
            AppColors.brandLinearGradient()
                .ignoresSafeArea()
                .accessibilityHidden(true)

            // Contrast overlay for legibility
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                // Header
                MarketingHeader()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 18) // increased by ~50%
                    .padding(.bottom, 36) // increased by ~50%
                    .accessibilitySortPriority(1)

                Spacer(minLength: 0)

                // Center content
                VStack(spacing: 16) {
                    Text("Learn Faster, Deeper")
                        .displayHero(color: .white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)

                    Text("Your AI learning companion that helps you understand anything.")
                        .bodyLarge(color: .white)
                        .multilineTextAlignment(.center)
                        .accessibilityHint("Introductory description")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .accessibilityIdentifier("login-center-stack")

                Spacer(minLength: 96)

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                        .accessibilityIdentifier("login-error")
                }

                // Bottom CTA pinned near bottom with ~50% of button height padding
                GoogleSignInFlatButton(onTap: {
                    // Flip processing immediately for perceived responsiveness
                    isProcessing = true
                })
                .accessibilityLabel("Continue with Google")
                .accessibilityHint("Sign in using your Google account")
                .accessibilitySortPriority(2)
                .padding(.horizontal, 24)
                .padding(.bottom, 26)
                .padding(.top, 96)
            }
            .padding(.horizontal, 20)

            if isProcessing || auth.isLoading {
                AuthProcessingView()
                    .transition(.opacity)
            }
        }
        .onChange(of: auth.errorMessage) { new in
            if new != nil {
                isProcessing = false
            }
        }
        .onChange(of: auth.isAuthenticated) { new in
            if new { isProcessing = false }
        }
    }
}

private struct GoogleSignInFlatButton: View {
    @EnvironmentObject var auth: AuthManager
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: {
            onTap?()
            Task { await signIn() }
        }) {
            HStack(spacing: 8) {
                googleLogo
                    .resizable()
                    .renderingMode(.original)
                    .frame(width: 25, height: 25)
                    .accessibilityHidden(true)
                Text("Continue with Google")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .padding(.vertical, 10) 
            .background(.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.35), lineWidth: 3)
            )
            .cornerRadius(14)
            .shadow(color: AppColors.shadowDark, radius: 10, x: 0, y: 6)
        }
        .disabled(auth.isLoading)
    }

    private func signIn() async {
        let presenter = UIApplication.shared.topMostViewController()
        await auth.startGoogleSignInFlow(presentingViewController: presenter)
    }
    
    private var googleLogo: Image {
        if let uiImage = UIImage(named: "google_g") {
            return Image(uiImage: uiImage)
        } else {
            return Image(systemName: "g.circle")
        }
    }
}

private extension UIApplication {
    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC: UIViewController?
        if let base {
            baseVC = base
        } else {
            baseVC = connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController
        }
        guard let root = baseVC else { return nil }
        if let nav = root as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(base: selected)
        }
        if let presented = root.presentedViewController {
            return topMostViewController(base: presented)
        }
        return root
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}


