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
        // Prefer backend sessions; fall back to local if unavailable
        Task { [weak self] in
            await self?.refreshSessionsFromBackend()
        }
        print("🔍 DEBUG: ChatManager init completed")
    }
    
    // MARK: - Public Methods
    func sendMessage(_ content: String) async throws -> ChatMessage {
        // DEBUG BREAKPOINT 1: Method entry
        print("🔍 DEBUG: sendMessage called with content: \(content)")
        // ⏱️ LATENCY: sending message to Claude/backend
        let _latencyClaudeSendTs = Date().timeIntervalSince1970
        print("⏱️ LATENCY [voice] claude_send_initiated: \(_latencyClaudeSendTs)")
        
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
        // Avoid sending the just-appended user message twice (both as `message` and in history)
        let historyExcludingPending = Array(conversationHistory.dropLast())
        print("🔍 DEBUG: Conversation history count total=\(conversationHistory.count) sending=\(historyExcludingPending.count)")
        
        do {
            print("🔍 DEBUG: About to call Backend API")
            let response = try await chatAPI.sendMessage(message: content, history: historyExcludingPending)
            print("🔍 DEBUG: API response received: \(response.content)")
            // ⏱️ LATENCY: message received from Claude/backend
            let _latencyClaudeRecvTs = Date().timeIntervalSince1970
            print("⏱️ LATENCY [voice] claude_response_received: \(_latencyClaudeRecvTs) delta=\(_latencyClaudeRecvTs - _latencyClaudeSendTs)s")
            
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

        // If this session originated from the backend, fetch full history
        if let remoteId = session.remoteId, !remoteId.isEmpty {
            Task { [weak self] in
                await self?.loadFullSessionFromBackend(remoteId: remoteId)
            }
        }
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
        // Legacy local persistence (kept as fallback only)
        if let data = UserDefaults.standard.data(forKey: "chat_sessions"),
           let decodedSessions = try? JSONDecoder().decode([ChatSession].self, from: data) {
            sessions = decodedSessions
        }
    }

    private func saveSessions() {
        // Keep local persistence for backward compatibility only
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "chat_sessions")
        }
    }

    // MARK: - Backend Sessions
    private func iso8601ToDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        // Try without fractional seconds
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: s)
    }

    @MainActor
    private func refreshSessionsFromBackend() async {
        do {
            // If backend not configured, fall back to local
            if chatAPI.baseURLStringIsEmpty {
                loadSessions()
                return
            }

            // Fetch conversation summaries
            let summaries = try await chatAPI.listConversations(limit: 20, offset: 0)

            var builtSessions: [ChatSession] = []
            builtSessions.reserveCapacity(summaries.count)

            for summary in summaries {
                // Create a display session; note: ChatSession.id is client-generated
                var session = ChatSession(title: (summary.title?.isEmpty == false ? summary.title! : "New Chat"))
                session.remoteId = summary.id
                if let updated = iso8601ToDate(summary.updated_at) { session.updatedAt = updated }

                // Build preview by fetching the last turn only when available
                if let turnCount = summary.turn_count, turnCount > 0, let convoId = summary.id {
                    let offset = max(0, turnCount - 1)
                    do {
                        let lastTurns = try await chatAPI.listConversationTurns(conversationId: convoId, limit: 1, offset: offset)
                        if let t = lastTurns.first {
                            // Append last user + assistant messages for preview
                            session.messages.append(ChatMessage(content: t.user_input, role: .user, isFromUser: true))
                            session.messages.append(ChatMessage(content: t.ai_response, role: .assistant, isFromUser: false))
                        }
                    } catch {
                        // Non-fatal; continue without preview
                    }
                }

                builtSessions.append(session)
            }

            // Sort by updatedAt desc to match server ordering
            builtSessions.sort { $0.updatedAt > $1.updatedAt }
            self.sessions = builtSessions
        } catch {
            // Fallback to local storage if backend fails
            loadSessions()
        }
    }

    @MainActor
    private func loadFullSessionFromBackend(remoteId: String) async {
        do {
            // Fetch up to 500 turns in order; paginate later if needed
            let turns = try await chatAPI.listConversationTurns(conversationId: remoteId, limit: 500, offset: 0)
            var rebuilt: [ChatMessage] = []
            rebuilt.reserveCapacity(turns.count * 2)
            for t in turns {
                rebuilt.append(ChatMessage(content: t.user_input, role: .user, isFromUser: true))
                rebuilt.append(ChatMessage(content: t.ai_response, role: .assistant, isFromUser: false))
            }
            self.currentSession.messages = rebuilt
            self.messages = rebuilt
        } catch {
            // Non-fatal: keep whatever we had (preview or empty)
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
