import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        Group {
            if requireLoginEnabled() {
                if !auth.hasRestoredSession {
                    AuthProcessingView()
                        .transition(rootTransition)
                } else if auth.isAuthenticated {
                    ContentView()
                        .transition(rootTransition)
                } else {
                    LoginView()
                        .transition(rootTransition)
                }
            } else {
                ContentView()
                    .transition(rootTransition)
            }
        }
        .animation(.easeInOut(duration: UIAccessibility.isReduceMotionEnabled ? 0.15 : 0.25), value: auth.isAuthenticated)
    }
}

private func requireLoginEnabled() -> Bool {
    if let value = Bundle.main.object(forInfoDictionaryKey: "REQUIRE_LOGIN") as? Bool {
        return value
    }
    if let stringValue = Bundle.main.object(forInfoDictionaryKey: "REQUIRE_LOGIN") as? String {
        return (stringValue as NSString).boolValue
    }
    return false
}

#Preview {
    RootView()
        .environmentObject(AuthManager.shared)
        .environmentObject(AudioManager.shared)
        .environmentObject(ChatManager.shared)
}

private var rootTransition: AnyTransition {
    if UIAccessibility.isReduceMotionEnabled {
        return .opacity
    }
    return .opacity.combined(with: .scale(scale: 0.98))
}


