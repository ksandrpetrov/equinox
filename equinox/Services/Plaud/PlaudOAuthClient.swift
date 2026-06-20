import AppKit
import Foundation

enum PlaudOAuthClient {
    private static let keychainAccount = "plaud-oauth-tokens"
    private static let loginTimeout: TimeInterval = 120
    private static let tokenVersion = 1

    static func loadTokens() -> PlaudOAuthTokenSet? {
        guard let data = KeychainStore.load(account: keychainAccount) else { return nil }
        return decodeTokens(from: data)
    }

    static func saveTokens(_ tokenSet: PlaudOAuthTokenSet) throws {
        var payload = tokenSet
        payload.version = Self.tokenVersion
        payload.savedAt = ISO8601DateFormatter().string(from: Date())
        let data = try JSONEncoder().encode(payload)
        try KeychainStore.save(data: data, account: keychainAccount)
    }

    static func clearTokens() {
        KeychainStore.delete(account: keychainAccount)
    }

    static func keychainTokenData() -> Data? {
        KeychainStore.load(account: keychainAccount)
    }

    static func decodeTokens(from data: Data) -> PlaudOAuthTokenSet? {
        guard let tokenSet = try? JSONDecoder().decode(PlaudOAuthTokenSet.self, from: data),
              !tokenSet.access_token.isEmpty else { return nil }
        return tokenSet
    }

    static func signIn() async throws {
        if loadTokens() != nil {
            if let existing = try? await validAccessToken(),
               (try? await validateAccessToken(existing)) == true {
                throw PlaudOAuthError.alreadySignedIn
            }
            clearTokens()
        }

        let request = PlaudOAuthPKCE.createAuthorizationRequest()
        let authorizationURL = request.url
        let result = await PlaudOAuthCallbackServer.run(
            expectedState: request.state,
            timeout: loginTimeout
        ) { code in
            _ = try await exchangeCode(code, codeVerifier: request.codeVerifier, state: request.state)
        } onListening: {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(authorizationURL)
            }
        }

        switch result {
        case .success:
            return
        case .denied(let error):
            throw PlaudOAuthError.authenticationDenied(error)
        case .timeout:
            throw PlaudOAuthError.authenticationTimeout
        case .exchangeFailed(let error):
            throw PlaudOAuthError.tokenExchangeFailed(error)
        case .listenFailed(let error):
            if error.localizedCaseInsensitiveContains("address already in use") {
                throw PlaudOAuthError.callbackPortInUse
            }
            throw PlaudOAuthError.callbackListenFailed(error)
        }
    }

    static func signOut() async {
        if let token = try? await validAccessToken() {
            await revokeSession(accessToken: token)
        }
        clearTokens()
    }

    static func validAccessToken() async throws -> String? {
        guard var tokenSet = loadTokens() else { return nil }

        if !tokenSet.isExpired {
            return tokenSet.access_token
        }

        guard let refreshToken = tokenSet.refresh_token, !refreshToken.isEmpty else {
            clearTokens()
            return nil
        }

        do {
            tokenSet = try await refreshTokens(refreshToken: refreshToken)
            try saveTokens(tokenSet)
            return tokenSet.access_token
        } catch {
            clearTokens()
            throw PlaudOAuthError.tokenRefreshFailed(error.localizedDescription)
        }
    }

    static func validateAccessToken(_ accessToken: String) async throws -> Bool {
        var request = URLRequest(url: PlaudOAuthPKCE.apiBase.appendingPathComponent("open/third-party/users/current"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        PlaudOAuthPKCE.applyBrowserHeaders(to: &request)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    private static func exchangeCode(_ code: String, codeVerifier: String, state: String) async throws -> PlaudOAuthTokenSet {
        let bodyItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: PlaudOAuthPKCE.redirectURI),
            URLQueryItem(name: "code_verifier", value: codeVerifier),
            URLQueryItem(name: "state", value: state),
        ]
        var components = URLComponents()
        components.queryItems = bodyItems
        let body = components.percentEncodedQuery ?? ""

        var request = URLRequest(url: PlaudOAuthPKCE.tokenURL)
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(basicAuthorizationHeader(), forHTTPHeaderField: "Authorization")
        PlaudOAuthPKCE.applyBrowserHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8) ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            throw PlaudOAuthError.tokenExchangeFailed(detail)
        }

        let tokenSet = try normalizeTokenResponse(data: data)
        try saveTokens(tokenSet)
        return tokenSet
    }

    private static func refreshTokens(refreshToken: String) async throws -> PlaudOAuthTokenSet {
        let body = "refresh_token=\(refreshToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? refreshToken)"
        var request = URLRequest(url: PlaudOAuthPKCE.refreshURL)
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        PlaudOAuthPKCE.applyBrowserHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8) ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            throw PlaudOAuthError.tokenRefreshFailed(detail)
        }

        var tokenSet = try normalizeTokenResponse(data: data)
        if tokenSet.refresh_token == nil {
            tokenSet.refresh_token = refreshToken
        }
        return tokenSet
    }

    private static func normalizeTokenResponse(data: Data) throws -> PlaudOAuthTokenSet {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              !accessToken.isEmpty else {
            throw PlaudOAuthError.tokenExchangeFailed("Missing access_token")
        }

        var expiresAt = json["expires_at"] as? Double
        if expiresAt == nil, let expiresIn = json["expires_in"] as? Double {
            expiresAt = Date().timeIntervalSince1970 * 1000 + expiresIn * 1000
        } else if expiresAt == nil, let expiresIn = json["expires_in"] as? Int {
            expiresAt = Date().timeIntervalSince1970 * 1000 + Double(expiresIn) * 1000
        }

        return PlaudOAuthTokenSet(
            access_token: accessToken,
            refresh_token: json["refresh_token"] as? String,
            token_type: json["token_type"] as? String ?? "Bearer",
            expires_at: expiresAt
        )
    }

    private static func revokeSession(accessToken: String) async {
        var request = URLRequest(
            url: PlaudOAuthPKCE.apiBase.appendingPathComponent("open/third-party/users/current/revoke")
        )
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        PlaudOAuthPKCE.applyBrowserHeaders(to: &request)
        _ = try? await URLSession.shared.data(for: request)
    }

    private static func basicAuthorizationHeader() -> String {
        let credentials = "\(PlaudOAuthPKCE.clientID):"
        let encoded = Data(credentials.utf8).base64EncodedString()
        return "Basic \(encoded)"
    }
}
