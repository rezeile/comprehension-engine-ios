import SwiftUI

@main
struct ComprehensionEngineApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AudioManager.shared)
                .environmentObject(ChatManager.shared)
                .onAppear {
                    print("🔍 DEBUG: App launched successfully")
                }
        }
    }
}
