import Foundation
import Combine
import UIKit

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    // MARK: - Published State
    @Published var isAuthenticated: Bool = false
    @Published var user: UserProfile? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var hasRestoredSession: Bool = false

    // MARK: - Token Storage (in-memory mirror of Keychain)
    fileprivate(set) var accessToken: String? = nil
    fileprivate(set) var refreshToken: String? = nil

    // MARK: - Constants
    private let keychainAccessTokenKey = "ce.access_token"
    private let keychainRefreshTokenKey = "ce.refresh_token"

    private init() {
        loadTokensFromKeychain()
        self.isAuthenticated = (accessToken?.isEmpty == false && refreshToken?.isEmpty == false)
        if isAuthenticated {
            Task { [weak self] in
                guard let self else { return }
                await self.validateAndRefreshSession()
                await MainActor.run { self.hasRestoredSession = true }
            }
        } else {
            self.hasRestoredSession = true
        }
    }

    // MARK: - Public API
    func startGoogleSignInFlow(presentingViewController: UIViewController?) async {
        #if canImport(GoogleSignIn)
        guard let presentingViewController = presentingViewController else {
            self.errorMessage = "No presenting view controller available for Google Sign-In"
            return
        }
        do {
            isLoading = true
            defer { isLoading = false }
            errorMessage = nil
            let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            let googleAccessToken = signInResult.user.accessToken.tokenString
            try await self.exchangeGoogleAccessToken(googleAccessToken)
            _ = await self.fetchCurrentUser()
            self.isAuthenticated = true
        } catch {
            self.errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
            self.isAuthenticated = false
        }
        #else
        self.errorMessage = "GoogleSignIn SDK not added. Add it via SPM to enable Google login."
        #endif
    }

    func logout() {
        KeychainHelper.shared.delete(key: keychainAccessTokenKey)
        KeychainHelper.shared.delete(key: keychainRefreshTokenKey)
        accessToken = nil
        refreshToken = nil
        isAuthenticated = false
        user = nil
    }

    func refreshTokensIfNeeded() async -> Bool {
        // For now, always attempt a refresh if we have a refresh token
        guard let refreshToken, !refreshToken.isEmpty else { return false }
        do {
            let pair = try await self.requestTokenRefresh(refreshToken: refreshToken)
            self.persistTokens(pair: pair)
            return true
        } catch {
            return false
        }
    }

    func forceRefresh() async -> Bool {
        guard let refreshToken, !refreshToken.isEmpty else { return false }
        do {
            let pair = try await self.requestTokenRefresh(refreshToken: refreshToken)
            self.persistTokens(pair: pair)
            return true
        } catch {
            return false
        }
    }

    // Exposed for API header injection
    func currentAccessToken() -> String? {
        return accessToken
    }

    // MARK: - Networking
    private func exchangeGoogleAccessToken(_ googleAccessToken: String) async throws {
        guard let base = BackendAPI.resolveBaseURLString(), let url = URL(string: base.trimmedTrailingSlash() + "/api/auth/mobile/google") else {
            throw AuthError.backendURLMissing
        }
        let requestBody = ["access_token": googleAccessToken]
        let data = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (respData, response) = try await perform(request: request, requestTimeout: 15, resourceTimeout: 30)
        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: respData, encoding: .utf8) ?? "Unknown error"
            throw AuthError.httpError(http.statusCode, message)
        }
        let pair = try JSONDecoder().decode(TokenPair.self, from: respData)
        persistTokens(pair: pair)
    }

    private func requestTokenRefresh(refreshToken: String) async throws -> TokenPair {
        guard let base = BackendAPI.resolveBaseURLString(), let url = URL(string: base.trimmedTrailingSlash() + "/api/auth/refresh") else {
            throw AuthError.backendURLMissing
        }
        let body = ["refresh_token": refreshToken]
        let data = try JSONSerialization.data(withJSONObject: body, options: [])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (respData, response) = try await perform(request: request, requestTimeout: 15, resourceTimeout: 30)
        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: respData, encoding: .utf8) ?? "Unknown error"
            throw AuthError.httpError(http.statusCode, message)
        }
        return try JSONDecoder().decode(TokenPair.self, from: respData)
    }

    func fetchCurrentUser() async -> Bool {
        guard let base = BackendAPI.resolveBaseURLString(), let url = URL(string: base.trimmedTrailingSlash() + "/api/auth/me") else {
            return false
        }
        guard let token = accessToken else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
            let profile = try JSONDecoder().decode(UserProfile.self, from: data)
            self.user = profile
            return true
        } catch {
            return false
        }
    }

    // MARK: - Keychain

    private func perform(request: URLRequest, requestTimeout: TimeInterval, resourceTimeout: TimeInterval) async throws -> (Data, URLResponse) {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = resourceTimeout
        let session = URLSession(configuration: config)
        return try await session.data(for: request)
    }
    private func loadTokensFromKeychain() {
        if let at: String = KeychainHelper.shared.read(key: keychainAccessTokenKey), let rt: String = KeychainHelper.shared.read(key: keychainRefreshTokenKey) {
            self.accessToken = at
            self.refreshToken = rt
        }
    }

    private func persistTokens(pair: TokenPair) {
        self.accessToken = pair.access_token
        self.refreshToken = pair.refresh_token
        KeychainHelper.shared.save(key: keychainAccessTokenKey, value: pair.access_token)
        KeychainHelper.shared.save(key: keychainRefreshTokenKey, value: pair.refresh_token)
        self.isAuthenticated = true
    }

    private func validateAndRefreshSession() async {
        let refreshed = await self.refreshTokensIfNeeded()
        if refreshed {
            _ = await self.fetchCurrentUser()
            return
        }

        let userValid = await self.fetchCurrentUser()
        if !userValid {
            await MainActor.run {
                self.logout()
            }
        }
    }
}

// MARK: - Models
struct TokenPair: Codable {
    let access_token: String
    let refresh_token: String
    let token_type: String?
    let expires_in: Int?
}

struct UserProfile: Codable, Equatable {
    let id: String?
    let email: String?
    let name: String?
    let picture: String?
}

// MARK: - Errors
extension AuthManager {
    enum AuthError: Error, LocalizedError {
        case backendURLMissing
        case invalidResponse
        case httpError(Int, String)

        var errorDescription: String? {
            switch self {
            case .backendURLMissing:
                return "BACKEND_BASE_URL missing; configure it in Info.plist"
            case .invalidResponse:
                return "Invalid response from server"
            case .httpError(let code, let msg):
                return "HTTP \(code): \(msg)"
            }
        }
    }
}

// MARK: - Helpers
private extension String {
    func trimmedTrailingSlash() -> String {
        if self.hasSuffix("/") { return String(self.dropLast()) }
        return self
    }
}


