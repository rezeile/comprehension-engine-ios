import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    var content: String
    let role: MessageRole
    var timestamp: Date
    let isFromUser: Bool
    
    init(content: String, role: MessageRole, isFromUser: Bool) {
        self.id = UUID()
        self.content = content
        self.role = role
        self.timestamp = Date()
        self.isFromUser = isFromUser
    }
}

enum MessageRole: String, Codable, CaseIterable {
    case user = "user"
    case assistant = "assistant"
    
    var displayName: String {
        switch self {
        case .user:
            return "You"
        case .assistant:
            return "Claude"
        }
    }
}

struct ChatRequest: Codable {
    let message: String
    var conversationHistory: [ChatMessage]
    let modelId: String
}

struct ChatResponse: Codable {
    let content: String
    let role: MessageRole
}

struct ChatSession: Identifiable, Codable {
    let id: UUID
    let title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    
    init(title: String = "New Chat") {
        self.id = UUID()
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - AI Model Selection
enum AIModel: String, CaseIterable, Codable, Identifiable {
    case claudeSonnet35 = "claude-3-5-sonnet-20241022"
    case claudeHaiku35 = "claude-3-5-haiku-20241022"
    case claudeOpus = "claude-3-opus-20240229"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeSonnet35:
            return "Claude Sonnet 3.5"
        case .claudeHaiku35:
            return "Claude Haiku 3.5"
        case .claudeOpus:
            return "Claude Opus 3"
        }
    }
}
