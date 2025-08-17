import SwiftUI

struct ContentView: View {
    var body: some View {
        ChatView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioManager.shared)
        .environmentObject(ChatManager.shared)
}
