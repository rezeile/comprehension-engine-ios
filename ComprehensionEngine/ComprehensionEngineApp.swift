import SwiftUI

@main
struct ComprehensionEngineApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AudioManager.shared)
                .environmentObject(ChatManager.shared)
                .environmentObject(AuthManager.shared)
                .onAppear {
                    print("🔍 DEBUG: App launched successfully")
                }
        }
    }
}
