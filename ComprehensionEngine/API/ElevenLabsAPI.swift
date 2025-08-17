import Foundation

class ElevenLabsAPI {
    private let apiKey: String
    private let baseURL = "https://api.elevenlabs.io/v1"
    
    init() {
        // In production, use proper key management
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "ELEVENLABS_API_KEY") as? String, !plistKey.isEmpty {
            self.apiKey = plistKey
        } else {
            self.apiKey = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] ?? ""
        }
    }
    
    func generateSpeech(text: String, voiceId: String) async throws -> Data {
        guard !apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.emptyText
        }
        
        // Prepare the request body
        let requestBody: [String: Any] = [
            "text": text,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]
        
        // Convert to JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Create URL request
        let urlString = "\(baseURL)/text-to-speech/\(voiceId)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
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
        
        // Return audio data
        return data
    }
    
    func getVoices() async throws -> [Voice] {
        guard !apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }
        
        // Create URL request
        let urlString = "\(baseURL)/voices"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
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
            
            guard let voicesData = jsonResponse?["voices"] as? [[String: Any]] else {
                throw APIError.invalidResponse
            }
            
            let voices = voicesData.compactMap { voiceData -> Voice? in
                guard let id = voiceData["voice_id"] as? String,
                      let name = voiceData["name"] as? String,
                      let category = voiceData["category"] as? String,
                      let description = voiceData["description"] as? String else {
                    return nil
                }
                
                return Voice(
                    id: id,
                    name: name,
                    category: category,
                    description: description,
                    previewURL: voiceData["preview_url"] as? String
                )
            }
            
            return voices
            
        } catch {
            throw APIError.parsingError(error.localizedDescription)
        }
    }
    
    // MARK: - Error Handling
    enum APIError: Error, LocalizedError {
        case missingAPIKey
        case emptyText
        case invalidURL
        case invalidResponse
        case httpError(Int, String)
        case parsingError(String)
        case networkError
        
        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "ElevenLabs API key is missing"
            case .emptyText:
                return "Text cannot be empty"
            case .invalidURL:
                return "Invalid URL"
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
