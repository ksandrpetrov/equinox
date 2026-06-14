import AppKit
import Foundation
import Network

struct PlaudOAuthTokenSet: Codable, Sendable, Equatable {
    var access_token: String
    var refresh_token: String?
    var token_type: String?
    var expires_at: Double?
    var version: Int?
    var savedAt: String?

    var expiresAtDate: Date? {
        guard let expires_at else { return nil }
        return Date(timeIntervalSince1970: expires_at / 1000)
    }

    var isExpired: Bool {
        guard let expires_at else { return false }
        return Date().timeIntervalSince1970 * 1000 > expires_at - 60_000
    }

    var hasRefreshToken: Bool {
        guard let refresh_token else { return false }
        return !refresh_token.isEmpty
    }
}

enum PlaudOAuthError: LocalizedError {
    case callbackPortInUse
    case callbackListenFailed(String)
    case authenticationDenied(String?)
    case authenticationTimeout
    case tokenExchangeFailed(String)
    case tokenRefreshFailed(String)
    case credentialsMissing
    case alreadySignedIn

    var errorDescription: String? {
        switch self {
        case .callbackPortInUse:
            return String(
                localized: "OAuth callback port 8199 is already in use. Stop the other OAuth client and try again.",
                comment: "Plaud OAuth port error"
            )
        case .callbackListenFailed(let detail):
            return String(
                localized: "Could not start OAuth callback server: \(detail)",
                comment: "Plaud OAuth listen error"
            )
        case .authenticationDenied(let reason):
            if let reason, !reason.isEmpty {
                return String(
                    localized: "Plaud sign-in was denied: \(reason)",
                    comment: "Plaud OAuth denied"
                )
            }
            return String(localized: "Plaud sign-in was denied.", comment: "Plaud OAuth denied")
        case .authenticationTimeout:
            return String(
                localized: "Plaud sign-in timed out after 2 minutes.",
                comment: "Plaud OAuth timeout"
            )
        case .tokenExchangeFailed(let detail):
            return String(
                localized: "Plaud token exchange failed: \(detail)",
                comment: "Plaud OAuth exchange error"
            )
        case .tokenRefreshFailed(let detail):
            return String(
                localized: "Plaud token refresh failed: \(detail)",
                comment: "Plaud OAuth refresh error"
            )
        case .credentialsMissing:
            return String(
                localized: "Plaud live credentials not found.",
                comment: "Plaud OAuth missing credentials"
            )
        case .alreadySignedIn:
            return String(
                localized: "Already signed in to Plaud. Disconnect first to switch accounts.",
                comment: "Plaud OAuth already signed in"
            )
        }
    }
}

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

private enum PlaudOAuthCallbackServer {
    enum Result: Sendable {
        case success
        case denied(String?)
        case timeout
        case exchangeFailed(String)
        case listenFailed(String)
    }

    static func run(
        expectedState: String,
        timeout: TimeInterval,
        exchangeCode: @escaping @Sendable (String) async throws -> Void,
        onListening: @escaping @Sendable () -> Void
    ) async -> Result {
        await withCheckedContinuation { continuation in
            let handler = CallbackHandler(
                expectedState: expectedState,
                timeout: timeout,
                exchangeCode: exchangeCode,
                onListening: onListening,
                finish: { result in
                    continuation.resume(returning: result)
                }
            )
            handler.start()
        }
    }
}

private final class CallbackHandler: @unchecked Sendable {
    private let expectedState: String
    private let timeout: TimeInterval
    private let exchangeCode: @Sendable (String) async throws -> Void
    private let onListening: @Sendable () -> Void
    private let finish: @Sendable (PlaudOAuthCallbackServer.Result) -> Void

    private var listener: NWListener?
    private var timeoutTask: Task<Void, Never>?
    private var finished = false
    private var exchangeStarted = false
    private var exchangeSucceeded = false
    private let lock = NSLock()
    // PlaudOAuthCallbackServer.run() does not retain the handler, and every callback below holds
    // only [weak self]. Without this self-retain the handler deallocates as soon as start() returns,
    // so the listener's .ready never fires onListening() (browser never opens) and the timeout can
    // never resume the continuation (sign-in spins forever). Cleared in complete().
    private var keepAlive: CallbackHandler?

    init(
        expectedState: String,
        timeout: TimeInterval,
        exchangeCode: @escaping @Sendable (String) async throws -> Void,
        onListening: @escaping @Sendable () -> Void,
        finish: @escaping @Sendable (PlaudOAuthCallbackServer.Result) -> Void
    ) {
        self.expectedState = expectedState
        self.timeout = timeout
        self.exchangeCode = exchangeCode
        self.onListening = onListening
        self.finish = finish
    }

    func start() {
        keepAlive = self
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            // requiredLocalEndpoint already pins the loopback host+port. Passing the same
            // port again via `on:` makes Network framework reject the duplicate with
            // NWError.posix(.EINVAL) ("Invalid argument", code 22), so the listener never
            // starts and the browser never opens.
            parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: .ipv4(.loopback),
                port: .init(rawValue: UInt16(PlaudOAuthPKCE.callbackPort))!
            )
            listener = try NWListener(using: parameters)
        } catch {
            complete(.listenFailed(error.localizedDescription))
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.onListening()
            case .failed(let error):
                self.complete(.listenFailed(error.localizedDescription))
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }

        listener?.start(queue: .global(qos: .userInitiated))

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.timeout ?? 120))
            self?.complete(.timeout)
        }
    }

    private func handle(connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else {
                connection.cancel()
                return
            }
            switch state {
            case .ready:
                self.receiveRequest(on: connection, buffer: Data())
            case .failed:
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            if error != nil {
                connection.cancel()
                return
            }

            var accumulated = buffer
            if let data {
                accumulated.append(data)
            }

            guard !accumulated.isEmpty else {
                if isComplete {
                    connection.cancel()
                } else {
                    self.receiveRequest(on: connection, buffer: accumulated)
                }
                return
            }

            guard let request = String(data: accumulated, encoding: .utf8) else {
                connection.cancel()
                return
            }

            if !request.contains("\r\n\r\n"), !isComplete {
                self.receiveRequest(on: connection, buffer: accumulated)
                return
            }

            self.processRequest(request, connection: connection)
        }
    }

    private func processRequest(_ request: String, connection: NWConnection) {
        guard let requestLine = request.split(separator: "\r\n", omittingEmptySubsequences: false).first else {
            connection.cancel()
            return
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            connection.cancel()
            return
        }

        if parts[0] == "OPTIONS" {
            sendOptionsResponse(on: connection)
            connection.cancel()
            return
        }

        let target = String(parts[1])
        guard target.hasPrefix("/auth/callback") else {
            sendResponse(on: connection, statusCode: 404, html: Self.errorHTML("Not found"))
            connection.cancel()
            return
        }

        guard let components = URLComponents(string: "http://127.0.0.1\(target)") else {
            connection.cancel()
            return
        }

        let params = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )

        if let error = params["error"] {
            sendResponse(on: connection, statusCode: 400, html: Self.errorHTML(error))
            connection.cancel()
            complete(.denied(error))
            return
        }

        guard let code = params["code"] else {
            sendResponse(on: connection, statusCode: 200, html: Self.neutralHTML)
            connection.cancel()
            return
        }

        guard params["state"] == expectedState else {
            sendResponse(on: connection, statusCode: 400, html: Self.errorHTML("State mismatch."))
            connection.cancel()
            complete(.denied("OAuth state mismatch."))
            return
        }

        lock.lock()
        if exchangeStarted {
            let html = exchangeSucceeded ? Self.successHTML : Self.neutralHTML
            lock.unlock()
            sendResponse(on: connection, statusCode: 200, html: html)
            connection.cancel()
            return
        }
        exchangeStarted = true
        lock.unlock()

        Task {
            do {
                try await exchangeCode(code)
                markExchangeSucceeded()
                sendResponse(on: connection, statusCode: 200, html: Self.successHTML)
                connection.cancel()
                complete(.success)
            } catch {
                sendResponse(on: connection, statusCode: 500, html: Self.errorHTML(error.localizedDescription))
                connection.cancel()
                complete(.exchangeFailed(error.localizedDescription))
            }
        }
    }

    private func markExchangeSucceeded() {
        lock.lock()
        exchangeSucceeded = true
        lock.unlock()
    }

    private func sendOptionsResponse(on connection: NWConnection) {
        let header = """
        HTTP/1.1 204 No Content\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, OPTIONS\r
        Access-Control-Allow-Headers: *\r
        Connection: close\r
        \r
        """
        connection.send(content: Data(header.utf8), completion: .contentProcessed { _ in })
    }

    private func sendResponse(on connection: NWConnection, statusCode: Int, html: String) {
        let statusText = statusCode == 200 ? "OK" : statusCode == 400 ? "Bad Request" : statusCode == 404 ? "Not Found" : "Error"
        let body = Data(html.utf8)
        let header = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.count)\r
        Connection: close\r
        Access-Control-Allow-Origin: *\r
        \r
        """
        connection.send(content: Data(header.utf8) + body, completion: .contentProcessed { _ in })
    }

    private func complete(_ result: PlaudOAuthCallbackServer.Result) {
        lock.lock()
        if finished {
            lock.unlock()
            return
        }
        finished = true
        timeoutTask?.cancel()
        listener?.cancel()
        listener = nil
        lock.unlock()
        finish(result)
        keepAlive = nil
    }

    private static let successHTML =
        "<!doctype html><html><head><meta charset=\"utf-8\"><title>Plaud</title></head>" +
        "<body style=\"font-family:system-ui;padding:2rem;text-align:center;\">" +
        "<h1>Authorization successful!</h1><p>You can close this tab.</p></body></html>"

    private static let neutralHTML =
        "<!doctype html><html><head><meta charset=\"utf-8\"><title>Plaud</title></head>" +
        "<body style=\"font-family:system-ui;padding:2rem;text-align:center;\">" +
        "<h1>Continue authorization in the original window.</h1>" +
        "<p>This page can be closed.</p></body></html>"

    private static func errorHTML(_ message: String) -> String {
        let escaped = message
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return "<!doctype html><html><head><meta charset=\"utf-8\"><title>Plaud</title></head>" +
            "<body style=\"font-family:system-ui;padding:2rem;text-align:center;\">" +
            "<h1>Authorization failed</h1><pre style=\"white-space:pre-wrap;\">\(escaped)</pre>" +
            "</body></html>"
    }
}
