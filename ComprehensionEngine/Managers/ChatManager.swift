import Foundation
import Combine
import UIKit

class ChatManager: ObservableObject {
    static let shared = ChatManager()
    
    // MARK: - Published Properties
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var currentSession: ChatSession = ChatSession()
    @Published var sessions: [ChatSession] = []
    @Published var selectedModel: AIModel = .claudeSonnet35
    
    // MARK: - Private Properties
    private let chatAPI = BackendAPI()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        print("🔍 DEBUG: ChatManager init started")
        loadSessions()
        print("🔍 DEBUG: ChatManager init completed")
    }
    
    // MARK: - Public Methods
    func sendMessage(_ content: String) async throws -> ChatMessage {
        // DEBUG BREAKPOINT 1: Method entry
        print("🔍 DEBUG: sendMessage called with content: \(content)")
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("🔍 DEBUG: Empty message detected")
            throw ChatError.emptyMessage
        }
        
        // Create user message
        let userMessage = ChatMessage(content: content, role: .user, isFromUser: true)
        print("🔍 DEBUG: User message created: \(userMessage)")
        
        // DEBUG BREAKPOINT 2: Before MainActor
        print("🔍 DEBUG: About to add user message on main actor")
        await MainActor.run {
            print("🔍 DEBUG: Inside MainActor.run - adding user message")
            self.currentSession.messages.append(userMessage)
            self.messages.append(userMessage)
            self.isLoading = true
            print("🔍 DEBUG: User message added successfully")
        }
        
        // DEBUG BREAKPOINT 3: Before API call
        print("🔍 DEBUG: Getting conversation history")
        let conversationHistory = await MainActor.run {
            return self.currentSession.messages
        }
        print("🔍 DEBUG: Conversation history count: \(conversationHistory.count)")
        
        do {
            print("🔍 DEBUG: About to call Backend API")
            let response = try await chatAPI.sendMessage(message: content, history: conversationHistory)
            print("🔍 DEBUG: API response received: \(response.content)")
            
            // Create assistant message
            let assistantMessage = ChatMessage(content: response.content, role: .assistant, isFromUser: false)
            print("🔍 DEBUG: Assistant message created")
            
            // DEBUG BREAKPOINT 4: Before UI update
            print("🔍 DEBUG: About to update UI with assistant message")
            await MainActor.run {
                print("🔍 DEBUG: Inside MainActor.run - adding assistant message")
                self.currentSession.messages.append(assistantMessage)
                self.messages.append(assistantMessage)
                self.isLoading = false
                
                // Update session timestamp
                self.currentSession.updatedAt = Date()
                
                // Save sessions
                self.saveSessions()
                print("🔍 DEBUG: Assistant message added and sessions saved")
            }
            
            return assistantMessage
            
        } catch {
            print("🔍 DEBUG: Error occurred: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
            throw error
        }
    }
    
    func createNewSession() {
        // Save current session if it has messages
        if !currentSession.messages.isEmpty {
            sessions.append(currentSession)
            saveSessions()
        }
        
        // Create new session
        currentSession = ChatSession()
        messages = []
    }
    
    func loadSession(_ session: ChatSession) {
        currentSession = session
        messages = session.messages
    }
    
    func deleteSession(_ session: ChatSession) {
        sessions.removeAll { $0.id == session.id }
        if currentSession.id == session.id {
            createNewSession()
        }
        saveSessions()
    }
    
    func clearCurrentSession() {
        currentSession.messages.removeAll()
        messages.removeAll()
        saveSessions()
    }
    
    // MARK: - Private Methods
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: "chat_sessions"),
           let decodedSessions = try? JSONDecoder().decode([ChatSession].self, from: data) {
            sessions = decodedSessions
        }
    }
    
    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "chat_sessions")
        }
    }
}

// MARK: - Error Handling
extension ChatManager {
    enum ChatError: Error, LocalizedError {
        case emptyMessage
        case apiError(String)
        case networkError
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .emptyMessage:
                return "Message cannot be empty"
            case .apiError(let message):
                return "API Error: \(message)"
            case .networkError:
                return "Network connection error"
            case .invalidResponse:
                return "Invalid response from server"
            }
        }
    }
}
