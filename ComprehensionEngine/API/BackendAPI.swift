import Foundation

class BackendAPI {
    private let baseURLString: String
    private let authHeaderName: String?
    private let authHeaderValue: String?

    init() {
        self.baseURLString = BackendAPI.resolveBaseURLString() ?? ""
        // Resolve optional auth headers (prefer Info.plist, then environment)
        let plistApiKeyRaw = Bundle.main.object(forInfoDictionaryKey: "BACKEND_API_KEY") as? String
        let envApiKeyRaw = ProcessInfo.processInfo.environment["BACKEND_API_KEY"]
        let apiKey = (plistApiKeyRaw ?? envApiKeyRaw)?.trimmingCharacters(in: .whitespacesAndNewlines)

        let plistBearerRaw = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BEARER_TOKEN") as? String
        let envBearerRaw = ProcessInfo.processInfo.environment["BACKEND_BEARER_TOKEN"]
        let bearerToken = (plistBearerRaw ?? envBearerRaw)?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let apiKey, !apiKey.isEmpty {
            self.authHeaderName = "x-api-key"
            self.authHeaderValue = apiKey
        } else if let bearerToken, !bearerToken.isEmpty {
            self.authHeaderName = "Authorization"
            self.authHeaderValue = "Bearer \(bearerToken)"
        } else {
            self.authHeaderName = nil
            self.authHeaderValue = nil
        }

        let authSummary: String
        if authHeaderName == "x-api-key" { authSummary = "x-api-key: <set>" }
        else if authHeaderName == "Authorization" { authSummary = "Authorization: Bearer <set>" }
        else { authSummary = "<none>" }

        let plistURLRaw = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String
        let envURLRaw = ProcessInfo.processInfo.environment["BACKEND_BASE_URL"]
        print("🔍 DEBUG: BackendAPI resolved URLs — plist=\(plistURLRaw ?? "<nil>") env=\(envURLRaw ?? "<nil>") → using=\(self.baseURLString)")
        print("🔍 DEBUG: BackendAPI auth headers — \(authSummary)")
    }

    func sendMessage(message: String, history: [ChatMessage]) async throws -> ChatResponse {
        guard let endpointURL = buildURL(path: "/api/chat") else {
            throw APIError.missingBaseURL
        }

        let backendHistory: [BackendMsg] = history.map { msg in
            BackendMsg(role: msg.role.rawValue, content: msg.content)
        }

        let requestBody = BackendChatRequest(message: message, conversation_history: backendHistory)
        let jsonData = try JSONEncoder().encode(requestBody)

        do {
            let data = try await performPOST(url: endpointURL, body: jsonData)
            let backendResponse = try JSONDecoder().decode(BackendChatResponse.self, from: data)
            return ChatResponse(content: backendResponse.response, role: .assistant)
        } catch let nsError as NSError {
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCannotConnectToHost {
                if let alternateURL = buildAlternateURL(path: "/api/chat") {
                    let data = try await performPOST(url: alternateURL, body: jsonData)
                    let backendResponse = try JSONDecoder().decode(BackendChatResponse.self, from: data)
                    return ChatResponse(content: backendResponse.response, role: .assistant)
                }
            }
            throw nsError
        }
    }

    // MARK: - TTS
    func textToSpeech(text: String, voiceId: String) async throws -> Data {
        guard let endpointURL = buildURL(path: "/api/tts") else {
            throw APIError.missingBaseURL
        }

        struct TTSRequest: Codable { let text: String; let voice_id: String }
        let requestBody = TTSRequest(text: text, voice_id: voiceId)
        let jsonData = try JSONEncoder().encode(requestBody)

        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        applyAuthHeader(&urlRequest)
        urlRequest.httpBody = jsonData

        let data = try await performWithAuthRetry(request: urlRequest)
        return data
    }

    // MARK: - Conversations (Backend-backed history)
    func listConversations(limit: Int = 20, offset: Int = 0) async throws -> [ConversationSummaryDTO] {
        guard let url = buildURL(path: "/api/conversations?limit=\(limit)&offset=\(offset)") else {
            throw APIError.missingBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthHeader(&request)

        let data = try await performWithAuthRetry(request: request)
        do {
            return try JSONDecoder().decode([ConversationSummaryDTO].self, from: data)
        } catch {
            throw APIError.parsingError("Failed to decode conversations: \(error.localizedDescription)")
        }
    }

    func listConversationTurns(conversationId: String, limit: Int = 1, offset: Int = 0) async throws -> [ConversationTurnDTO] {
        guard let url = buildURL(path: "/api/conversations/\(conversationId)/turns?limit=\(limit)&offset=\(offset)") else {
            throw APIError.missingBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthHeader(&request)

        let data = try await performWithAuthRetry(request: request)
        do {
            return try JSONDecoder().decode([ConversationTurnDTO].self, from: data)
        } catch {
            throw APIError.parsingError("Failed to decode conversation turns: \(error.localizedDescription)")
        }
    }

    private func buildURL(path: String) -> URL? {
        guard !baseURLString.isEmpty else { return nil }
        var trimmed = baseURLString
        if trimmed.hasSuffix("/") { trimmed.removeLast() }
        return URL(string: trimmed + path)
    }

    private func buildAlternateURL(path: String) -> URL? {
        var alternate: String?
        if baseURLString.contains("127.0.0.1") {
            alternate = baseURLString.replacingOccurrences(of: "127.0.0.1", with: "localhost")
        } else if baseURLString.contains("localhost") {
            alternate = baseURLString.replacingOccurrences(of: "localhost", with: "127.0.0.1")
        }
        guard var alt = alternate else { return nil }
        if alt.hasSuffix("/") { alt.removeLast() }
        return URL(string: alt + path)
    }

    // Expose whether base URL is available to allow feature fallbacks
    var baseURLStringIsEmpty: Bool {
        return baseURLString.isEmpty
    }

    private func performPOST(url: URL, body: Data) async throws -> Data {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthHeader(&urlRequest)
        urlRequest.httpBody = body

        let data = try await performWithAuthRetry(request: urlRequest)
        return data
    }

    // MARK: - Auth
    private func applyAuthHeader(_ request: inout URLRequest) {
        // Prefer AuthManager tokens persisted in Keychain
        if let token: String = KeychainHelper.shared.read(key: "ce.access_token"), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return
        }
        if let name = authHeaderName, let value = authHeaderValue {
            request.setValue(value, forHTTPHeaderField: name)
        }
    }

    private func performWithAuthRetry(request: URLRequest) async throws -> Data {
        let (data, response) = try await execute(request: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if httpResponse.statusCode == 401 {
            let refreshed: Bool = await AuthManager.shared.forceRefresh()
            if refreshed {
                var retried = request
                // Clear any stale header and apply new token
                retried.setValue(nil, forHTTPHeaderField: "Authorization")
                applyAuthHeader(&retried)
                let (retryData, retryResponse) = try await execute(request: retried)
                guard let retryHttp = retryResponse as? HTTPURLResponse else { throw APIError.invalidResponse }
                guard (200...299).contains(retryHttp.statusCode) else {
                    let message = String(data: retryData, encoding: .utf8) ?? "Unknown error"
                    throw APIError.httpError(retryHttp.statusCode, message)
                }
                return retryData
            } else {
                // Propagate 401 as is
                let message = String(data: data, encoding: .utf8) ?? "Unauthorized"
                throw APIError.httpError(401, message)
            }
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(httpResponse.statusCode, message)
        }
        return data
    }

    private func execute(request: URLRequest) async throws -> (Data, URLResponse) {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)
        return try await session.data(for: request)
    }
}

// MARK: - Backend DTOs
private struct BackendChatRequest: Codable {
    let message: String
    let conversation_history: [BackendMsg]
}

private struct BackendMsg: Codable {
    let role: String
    let content: String
}

private struct BackendChatResponse: Codable {
    let response: String
    let conversation_id: String?
}

// MARK: - Error Handling
extension BackendAPI {
    enum APIError: Error, LocalizedError {
        case missingBaseURL
        case invalidResponse
        case httpError(Int, String)
        case parsingError(String)

        var errorDescription: String? {
            switch self {
            case .missingBaseURL:
                return "BACKEND_BASE_URL is not set in Info.plist or environment"
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let status, let message):
                return "HTTP Error \(status): \(message)"
            case .parsingError(let details):
                return "Failed to parse response: \(details)"
            }
        }
    }
}

// MARK: - Shared URL Resolution
extension BackendAPI {
    static func resolveBaseURLString() -> String? {
        let plistURLRaw = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String
        let plistURL = plistURLRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
        let envURLRaw = ProcessInfo.processInfo.environment["BACKEND_BASE_URL"]
        let envURL = envURLRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let plistURL, !plistURL.isEmpty {
            return plistURL
        } else if let envURL, !envURL.isEmpty {
            return envURL
        } else {
            #if DEBUG
            #if targetEnvironment(simulator)
            return "http://127.0.0.1:8000"
            #else
            return nil
            #endif
            #else
            return nil
            #endif
        }
    }
}

// MARK: - DTOs for backend conversation APIs
struct ConversationSummaryDTO: Codable {
    let id: String?
    let title: String?
    let topic: String?
    let created_at: String?
    let updated_at: String?
    let is_active: Bool?
    let last_turn_at: String?
    let turn_count: Int?
}

struct ConversationTurnDTO: Codable {
    let id: String?
    let turn_number: Int?
    let user_input: String
    let ai_response: String
    let timestamp: String?
    let comprehension_score: Int?
    let comprehension_notes: String?
}


