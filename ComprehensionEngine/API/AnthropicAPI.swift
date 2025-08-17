import Foundation

class AnthropicAPI {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    init() {
        // In production, use proper key management
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String, !plistKey.isEmpty {
            self.apiKey = plistKey
        } else {
            self.apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        }
    }
    
    func sendMessage(_ request: ChatRequest) async throws -> ChatResponse {
        guard !apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }
        
        // Build full conversation history for Claud e Messages API
        let messagesPayload: [[String: Any]] = request.conversationHistory.map { message in
            [
                "role": message.role.rawValue,
                "content": [
                    [
                        "type": "text",
                        "text": message.content
                    ]
                ]
            ]
        }
        
        // Prepare the request body for Claude API
        let requestBody: [String: Any] = [
            "model": request.modelId,
            "max_tokens": 1000,
            "messages": messagesPayload
        ]
        
        // Convert to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Create URL request
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.httpBody = jsonData
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(httpResponse.statusCode, errorMessage)
        }
        
        // Parse response
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let contentBlocks = jsonResponse?["content"] as? [[String: Any]] else {
                throw APIError.invalidResponse
            }
            
            // Prefer the first text block; otherwise concatenate any text blocks
            if let firstText = contentBlocks.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String {
                return ChatResponse(content: firstText, role: .assistant)
            }
            
            let concatenated = contentBlocks.compactMap { block -> String? in
                guard let type = block["type"] as? String, type == "text" else { return nil }
                return block["text"] as? String
            }.joined(separator: "\n\n")
            
            guard !concatenated.isEmpty else { throw APIError.invalidResponse }
            return ChatResponse(content: concatenated, role: .assistant)
            
        } catch {
            throw APIError.parsingError(error.localizedDescription)
        }
    }
    
    // MARK: - Error Handling
    enum APIError: Error, LocalizedError {
        case missingAPIKey
        case invalidResponse
        case httpError(Int, String)
        case parsingError(String)
        case networkError
        
        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Anthropic API key is missing"
            case .invalidResponse:
                return "Invalid response from API"
            case .httpError(let statusCode, let message):
                return "HTTP Error \(statusCode): \(message)"
            case .parsingError(let details):
                return "Failed to parse response: \(details)"
            case .networkError:
                return "Network connection error"
            }
        }
    }
}
