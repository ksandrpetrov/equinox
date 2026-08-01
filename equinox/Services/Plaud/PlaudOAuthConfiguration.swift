import Foundation

struct PlaudOAuthAuthorizationRequest: Sendable, Equatable {
    let url: URL
    let codeVerifier: String
    let state: String
}

enum PlaudOAuthConfiguration {
    static let clientID = "client_f9e0b214-c11f-434b-8b95-c4497d1feb81"
    static let callbackPort = 8199
    static let redirectURI = "http://localhost:\(callbackPort)/auth/callback"
    static let authorizationURL = URL(string: "https://web.plaud.ai/platform/oauth")!
    static let tokenURL = URL(string: "https://platform.plaud.ai/developer/api/oauth/third-party/access-token")!
    static let refreshURL = URL(string: "https://platform.plaud.ai/developer/api/oauth/third-party/access-token/refresh")!
    static let apiBase = URL(string: "https://platform.plaud.ai/developer/api")!

    static let webOrigin = "https://web.plaud.ai"
    static let browserUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    static func applyBrowserHeaders(to request: inout URLRequest) {
        request.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(webOrigin, forHTTPHeaderField: "Origin")
        request.setValue("\(webOrigin)/", forHTTPHeaderField: "Referer")
    }
}

enum PlaudOAuthAuthorizationRequestFactory {
    typealias RandomBytesGenerator = (_ count: Int) throws -> Data

    static func make(
        randomBytes: RandomBytesGenerator = SecureRandomBytes.generate(count:)
    ) throws -> PlaudOAuthAuthorizationRequest {
        do {
            let verifierBytes = try randomBytes(32)
            let stateBytes = try randomBytes(16)
            guard verifierBytes.count == 32, stateBytes.count == 16 else {
                throw PlaudOAuthError.secureRandomGenerationFailed
            }

            let codeVerifier = PlaudOAuthPKCE.base64URLEncoded(verifierBytes)
            let state = PlaudOAuthPKCE.base64URLEncoded(stateBytes)
            let codeChallenge = PlaudOAuthPKCE.generateCodeChallenge(from: codeVerifier)

            var components = URLComponents(
                url: PlaudOAuthConfiguration.authorizationURL,
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: PlaudOAuthConfiguration.clientID),
                URLQueryItem(name: "redirect_uri", value: PlaudOAuthConfiguration.redirectURI),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "code_challenge", value: codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "state", value: state),
            ]

            guard let url = components.url else {
                throw PlaudOAuthError.secureRandomGenerationFailed
            }
            return PlaudOAuthAuthorizationRequest(
                url: url,
                codeVerifier: codeVerifier,
                state: state
            )
        } catch let error as PlaudOAuthError {
            throw error
        } catch {
            throw PlaudOAuthError.secureRandomGenerationFailed
        }
    }
}
