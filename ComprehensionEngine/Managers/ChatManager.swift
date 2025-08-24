import Foundation
import Combine
import UIKit
import os

class ChatManager: ObservableObject {
    static let shared = ChatManager()
    
    // MARK: - Published Properties
    // Phase A: Use a single visible window for UI to reduce memory
    @Published var visibleMessages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var currentSession: ChatSession = ChatSession()
    @Published var sessions: [ChatSession] = []
    
    // MARK: - Private Properties
    private let chatAPI = BackendAPI()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Performance Controls (Phase A)
    private let boundedHistoryEnabled: Bool = true
    private let windowCap: Int = 100 // total ChatMessage items retained for UI window
    // In-memory caps for the active session (device-aware)
    private let messageCountCapPhone: Int = 100
    private let messageCountCapPad: Int = 180
    private let charCapPhone: Int = 300_000 // ~300k characters
    private let charCapPad: Int = 400_000   // ~400k characters on iPad

    private var currentMessageCountCap: Int {
        return UIDevice.current.userInterfaceIdiom == .pad ? messageCountCapPad : messageCountCapPhone
    }
    private var currentCharCap: Int {
        return UIDevice.current.userInterfaceIdiom == .pad ? charCapPad : charCapPhone
    }

    // MARK: - Telemetry (Phase B)
    private let telemetryEnabled: Bool = true
    private var metrics = ChatHistoryMetrics()
    private let chatLogger = Logger(subsystem: "com.brightspring.ComprehensionEngine", category: "ChatHistory")
    private lazy var signposter = OSSignposter(logger: chatLogger)
    
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
            if self.boundedHistoryEnabled {
                self.appendToVisible(userMessage)
            } else {
                self.visibleMessages.append(userMessage)
            }
            self.isLoading = true
            print("🔍 DEBUG: User message added successfully")
            // Enforce in-memory caps after append
            self.enforceSessionCaps()
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
            let response = try await chatAPI.sendMessage(
                message: content,
                history: historyExcludingPending,
                conversationId: currentSession.remoteId,
                mode: "voice"
            )
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
                if self.boundedHistoryEnabled {
                    self.appendToVisible(assistantMessage)
                } else {
                    self.visibleMessages.append(assistantMessage)
                }
                self.isLoading = false
                
                // Update session timestamp and adopt remote conversation id if provided
                self.currentSession.updatedAt = Date()
                if let cid = response.conversationId, !cid.isEmpty {
                    self.currentSession.remoteId = cid
                }
                
                // Save sessions
                self.saveSessions()
                print("🔍 DEBUG: Assistant message added and sessions saved")
                // Enforce in-memory caps after append
                self.enforceSessionCaps()
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
    
    // Expose a public refresh to update sessions from backend on demand
    @MainActor
    func refreshSessions() async {
        await refreshSessionsFromBackend()
    }
    
    func createNewSession() {
        // Save current session if it has messages
        if !currentSession.messages.isEmpty {
            sessions.append(currentSession)
            saveSessions()
        }
        
        // Create new session
        currentSession = ChatSession()
        visibleMessages = []
    }
    
    func loadSession(_ session: ChatSession) {
        currentSession = session
        // Build a visible window (tail) for UI
        if boundedHistoryEnabled {
            rebuildVisibleWindowFromTail()
        } else {
            visibleMessages = session.messages
        }

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
        visibleMessages.removeAll()
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
            // Phase A/B: Limit turns fetched to the latest window
            // Try to infer a sane offset by first fetching conversation summaries (if available)
            let desiredTurns = max(1, windowCap / 2) // ~2 ChatMessage per turn
            var turns: [ConversationTurnDTO] = []
            if let summaries = try? await chatAPI.listConversations(limit: 200, offset: 0),
               let summary = summaries.first(where: { $0.id == remoteId }),
               let total = summary.turn_count, total > 0 {
                let startOffset = max(0, total - desiredTurns)
                turns = try await chatAPI.listConversationTurns(conversationId: remoteId, limit: desiredTurns, offset: startOffset)
            } else {
                // Fallback: step through pages until we find the last (bounded by a safety cap)
                let pageSize = desiredTurns
                var offset = 0
                var lastPage: [ConversationTurnDTO] = []
                var safetyCounter = 0
                while true {
                    let page = try await chatAPI.listConversationTurns(conversationId: remoteId, limit: pageSize, offset: offset)
                    safetyCounter &+= 1
                    if page.isEmpty { break }
                    lastPage = page
                    if page.count < pageSize { break } // reached the last page
                    offset &+= pageSize
                    if safetyCounter > 50 { break } // safety cap to avoid unbounded loops
                }
                turns = lastPage
            }
            if telemetryEnabled {
                metrics.pageFetches &+= 1
                metrics.lastFetchedPageSize = turns.count
                metrics.totalFetchedMessages &+= (turns.count * 2)
                signposter.emitEvent("chat.page_fetch")
            }
            var rebuilt: [ChatMessage] = []
            rebuilt.reserveCapacity(turns.count * 2)
            for t in turns {
                rebuilt.append(ChatMessage(content: t.user_input, role: .user, isFromUser: true))
                rebuilt.append(ChatMessage(content: t.ai_response, role: .assistant, isFromUser: false))
            }
            // Replace preview-only history with fetched window if larger
            if self.currentSession.messages.isEmpty || rebuilt.count >= self.currentSession.messages.count {
                self.currentSession.messages = rebuilt
            }
            // Refresh the visible window from tail
            if self.boundedHistoryEnabled {
                self.rebuildVisibleWindowFromTail()
            } else {
                self.visibleMessages = self.currentSession.messages
            }
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

// MARK: - Phase A Helpers (Bounded UI Window)
private extension ChatManager {
    /// Trim the active session's messages to respect device-aware count and character caps.
    /// Oldest messages are evicted first. Rebuilds the visible window from the tail afterward.
    @MainActor
    func enforceSessionCaps() {
        var totalChars: Int = 0
        // Compute once to avoid repeated O(n) sums in loop
        for msg in currentSession.messages { totalChars &+= msg.content.count }

        let countCap = currentMessageCountCap
        let charCap = currentCharCap
        var didTrim = false

        while (!currentSession.messages.isEmpty) &&
                (currentSession.messages.count > countCap || totalChars > charCap) {
            let removed = currentSession.messages.removeFirst()
            totalChars &-= removed.content.count
            didTrim = true
        }

        if boundedHistoryEnabled {
            rebuildVisibleWindowFromTail()
        } else {
            visibleMessages = currentSession.messages
        }

        if didTrim {
            saveSessions()
        }
    }
    func appendToVisible(_ message: ChatMessage) {
        visibleMessages.append(message)
        if telemetryEnabled {
            metrics.messagesAppended &+= 1
        }
        enforceCapIfNeeded()
    }
    func rebuildVisibleWindowFromTail() {
        if currentSession.messages.count <= windowCap {
            visibleMessages = currentSession.messages
        } else {
            visibleMessages = Array(currentSession.messages.suffix(windowCap))
        }
        if telemetryEnabled {
            metrics.windowCurrentCount = visibleMessages.count
            if metrics.windowCurrentCount > metrics.windowPeakCount {
                metrics.windowPeakCount = metrics.windowCurrentCount
            }
        }
    }
    func enforceCapIfNeeded() {
        guard boundedHistoryEnabled, visibleMessages.count > windowCap else { return }
        let overflow = visibleMessages.count - windowCap
        if overflow > 0 {
            if telemetryEnabled {
                metrics.evictionsCount &+= 1
                metrics.totalEvictedMessages &+= overflow
                signposter.emitEvent("chat.window_evict")
            }
            visibleMessages.removeFirst(overflow)
        }
        if telemetryEnabled {
            metrics.windowCurrentCount = visibleMessages.count
            if metrics.windowCurrentCount > metrics.windowPeakCount {
                metrics.windowPeakCount = metrics.windowCurrentCount
            }
        }
    }
}

// MARK: - Telemetry Models & Snapshot (Phase B)
private struct ChatHistoryMetrics {
    var windowPeakCount: Int = 0
    var windowCurrentCount: Int = 0
    var messagesAppended: Int = 0
    var evictionsCount: Int = 0
    var totalEvictedMessages: Int = 0
    var pageFetches: Int = 0
    var lastFetchedPageSize: Int = 0
    var totalFetchedMessages: Int = 0
}

struct ChatHistoryMetricsSnapshot: Codable, Equatable {
    let windowPeakCount: Int
    let windowCurrentCount: Int
    let messagesAppended: Int
    let evictionsCount: Int
    let totalEvictedMessages: Int
    let pageFetches: Int
    let lastFetchedPageSize: Int
    let totalFetchedMessages: Int
}

extension ChatManager {
    @MainActor
    func metricsSnapshot() -> ChatHistoryMetricsSnapshot {
        return ChatHistoryMetricsSnapshot(
            windowPeakCount: metrics.windowPeakCount,
            windowCurrentCount: metrics.windowCurrentCount,
            messagesAppended: metrics.messagesAppended,
            evictionsCount: metrics.evictionsCount,
            totalEvictedMessages: metrics.totalEvictedMessages,
            pageFetches: metrics.pageFetches,
            lastFetchedPageSize: metrics.lastFetchedPageSize,
            totalFetchedMessages: metrics.totalFetchedMessages
        )
    }

    /// Appends a local user message (e.g., finalized voice transcript on exit) without sending to backend.
    @MainActor
    func appendLocalUserMessage(_ content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let localMessage = ChatMessage(content: trimmed, role: .user, isFromUser: true)
        currentSession.messages.append(localMessage)
        if boundedHistoryEnabled {
            appendToVisible(localMessage)
        } else {
            visibleMessages.append(localMessage)
        }
        currentSession.updatedAt = Date()
        enforceSessionCaps()
        saveSessions()
    }
}
