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
            .refreshable {
                await chatManager.refreshSessions()
            }
            .navigationTitle("Chat History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        onClose?()
                        dismiss()
                    }
                }
            }
            .task {
                await chatManager.refreshSessions()
            }
        }
    }
    
    private var filteredSessions: [ChatSession] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return chatManager.sessions.sorted { $0.updatedAt > $1.updatedAt }
        }
        let lower = trimmed.lowercased()
        let filtered = chatManager.sessions.filter { session in
            if session.title.lowercased().contains(lower) { return true }
            return session.messages.contains { $0.content.lowercased().contains(lower) }
        }
        return filtered.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    private func previewText(for session: ChatSession) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            guard let last = session.messages.last else { return "No messages yet" }
            return (last.isFromUser ? "You: " : "Claude: ") + last.content
        }

        let lower = trimmed.lowercased()
        if let matched = session.messages.last(where: { $0.content.lowercased().contains(lower) }) {
            let snippet = snippet(from: matched.content, matching: lower, maxLength: 120)
            return (matched.isFromUser ? "You: " : "Claude: ") + snippet
        }

        // If only the title matched, or no message match was found, fall back to last message
        guard let last = session.messages.last else { return "No messages yet" }
        return (last.isFromUser ? "You: " : "Claude: ") + last.content
    }

    private func snippet(from text: String, matching needleLowercased: String, maxLength: Int) -> String {
        if maxLength <= 0 { return "" }
        guard let range = text.range(of: needleLowercased, options: .caseInsensitive) else {
            if text.count > maxLength { return String(text.prefix(maxLength)) + "…" }
            return text
        }

        let matchStart = range.lowerBound
        let matchEnd = range.upperBound
        let matchLength = text.distance(from: matchStart, to: matchEnd)
        let availableContext = max(0, maxLength - matchLength)
        let contextEachSide = availableContext / 2

        let distanceToStart = text.distance(from: text.startIndex, to: matchStart)
        let distanceToEnd = text.distance(from: matchEnd, to: text.endIndex)

        let takeBefore = min(contextEachSide, distanceToStart)
        let takeAfter = min(contextEachSide, distanceToEnd)

        let startIndex = text.index(matchStart, offsetBy: -takeBefore)
        let endIndex = text.index(matchEnd, offsetBy: takeAfter)

        var snippet = String(text[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)

        if takeBefore < distanceToStart { snippet = "…" + snippet }
        if takeAfter < distanceToEnd { snippet += "…" }

        return snippet
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



