import Foundation

class BackendAPI {
    private let baseURLString: String

    init() {
        // Prefer Info.plist value, then environment. Trim whitespace to avoid false negatives.
        let plistURLRaw = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String
        let plistURL = plistURLRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
        let envURLRaw = ProcessInfo.processInfo.environment["BACKEND_BASE_URL"]
        let envURL = envURLRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let plistURL, !plistURL.isEmpty {
            self.baseURLString = plistURL
        } else if let envURL, !envURL.isEmpty {
            self.baseURLString = envURL
        } else {
            #if DEBUG
            #if targetEnvironment(simulator)
            self.baseURLString = "http://127.0.0.1:8000"
            #else
            // On physical devices, require explicit LAN IP/host in Info.plist or env
            self.baseURLString = ""
            #endif
            #else
            self.baseURLString = ""
            #endif
        }
        print("🔍 DEBUG: BackendAPI resolved URLs — plist=\(plistURLRaw ?? "<nil>") env=\(envURLRaw ?? "<nil>") → using=\(self.baseURLString)")
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
        urlRequest.httpBody = jsonData

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(httpResponse.statusCode, errorMessage)
        }
        return data
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
        urlRequest.httpBody = body

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30

        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(httpResponse.statusCode, errorMessage)
        }
        return data
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


