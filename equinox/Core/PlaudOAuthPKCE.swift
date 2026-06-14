import CryptoKit
import Foundation
import Security

struct PlaudOAuthAuthorizationRequest: Sendable, Equatable {
    let url: URL
    let codeVerifier: String
    let state: String
}

enum PlaudOAuthPKCE {
    static let clientID = "client_f9e0b214-c11f-434b-8b95-c4497d1feb81"
    static let callbackPort = 8199
    static let redirectURI = "http://localhost:\(callbackPort)/auth/callback"
    static let authorizationURL = URL(string: "https://web.plaud.ai/platform/oauth")!
    static let tokenURL = URL(string: "https://platform.plaud.ai/developer/api/oauth/third-party/access-token")!
    static let refreshURL = URL(string: "https://platform.plaud.ai/developer/api/oauth/third-party/access-token/refresh")!
    static let apiBase = URL(string: "https://platform.plaud.ai/developer/api")!

    static let webOrigin = "https://web.plaud.ai"
    // Plaud's API sits behind Cloudflare, which returns HTTP 403 (error 1010) to clients
    // without a browser-like User-Agent. Mirror browser headers so OAuth and API calls work.
    static let browserUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    /// Applies the Cloudflare-friendly headers required by all Plaud API requests.
    static func applyBrowserHeaders(to request: inout URLRequest) {
        request.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(webOrigin, forHTTPHeaderField: "Origin")
        request.setValue("\(webOrigin)/", forHTTPHeaderField: "Referer")
    }

    static func createAuthorizationRequest() -> PlaudOAuthAuthorizationRequest {
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        let state = generateState()

        var components = URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]

        return PlaudOAuthAuthorizationRequest(
            url: components.url!,
            codeVerifier: codeVerifier,
            state: state
        )
    }

    static func generateCodeVerifier() -> String {
        randomBase64URL(count: 32)
    }

    static func generateCodeChallenge(from verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    static func generateState() -> String {
        randomBase64URL(count: 16)
    }

    private static func randomBase64URL(count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
