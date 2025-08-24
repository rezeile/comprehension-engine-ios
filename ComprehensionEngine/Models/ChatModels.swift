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
    let conversationId: String?
}

struct ChatSession: Identifiable, Codable {
    let id: UUID
    var remoteId: String?
    let title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    
    init(title: String = "New Chat") {
        self.id = UUID()
        self.remoteId = nil
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

 
