import SwiftUI

struct ChatHistoryView: View {
    @EnvironmentObject var chatManager: ChatManager
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    let onSelect: ((ChatSession) -> Void)?
    let onDelete: ((ChatSession) -> Void)?
    let onClose: (() -> Void)?
    
    init(onSelect: ((ChatSession) -> Void)? = nil,
         onDelete: ((ChatSession) -> Void)? = nil,
         onClose: (() -> Void)? = nil) {
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onClose = onClose
    }
    
    var body: some View {
        NavigationStack {
            List(filteredSessions) { session in
                Button {
                    onSelect?(session)
                    onClose?()
                    dismiss()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(AppColors.primary.opacity(0.15))
                            .overlay(Image(systemName: "bubble.left.and.bubble.right.fill").foregroundColor(AppColors.primary))
                            .frame(width: 36, height: 36)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text(previewText(for: session))
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(2)
                            
                            Text(dateText(for: session))
                                .font(.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        Spacer()
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        onDelete?(session)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search chats")
            .navigationTitle("Chat History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        onClose?()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var filteredSessions: [ChatSession] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return chatManager.sessions.reversed() }
        let lower = query.lowercased()
        return chatManager.sessions.filter { session in
            if session.title.lowercased().contains(lower) { return true }
            return session.messages.contains { $0.content.lowercased().contains(lower) }
        }.reversed()
    }
    
    private func previewText(for session: ChatSession) -> String {
        guard let last = session.messages.last else { return "No messages yet" }
        return (last.isFromUser ? "You: " : "Claude: ") + last.content
    }
    
    private func dateText(for session: ChatSession) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: session.updatedAt)
    }
}

#if DEBUG
#Preview {
    let manager = ChatManager.shared
    return ChatHistoryView()
        .environmentObject(manager)
}
#endif


