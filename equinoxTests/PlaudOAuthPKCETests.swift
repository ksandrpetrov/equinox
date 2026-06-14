import CryptoKit
import XCTest
@testable import equinox

final class PlaudOAuthPKCETests: XCTestCase {
    func testCodeChallengeMatchesSHA256Base64URL() {
        let verifier = "test-verifier-value"
        let expectedDigest = SHA256.hash(data: Data(verifier.utf8))
        let expected = Data(expectedDigest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        XCTAssertEqual(PlaudOAuthPKCE.generateCodeChallenge(from: verifier), expected)
    }

    func testAuthorizationRequestIncludesPKCEParams() {
        let request = PlaudOAuthPKCE.createAuthorizationRequest()
        guard let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            return XCTFail("Missing query items")
        }

        let values = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(values["client_id"], PlaudOAuthPKCE.clientID)
        XCTAssertEqual(values["redirect_uri"], PlaudOAuthPKCE.redirectURI)
        XCTAssertEqual(values["response_type"], "code")
        XCTAssertEqual(values["code_challenge_method"], "S256")
        XCTAssertEqual(values["state"], request.state)
        XCTAssertEqual(
            values["code_challenge"],
            PlaudOAuthPKCE.generateCodeChallenge(from: request.codeVerifier)
        )
        XCTAssertFalse(request.codeVerifier.isEmpty)
        XCTAssertFalse(request.state.isEmpty)
    }

    func testApplyBrowserHeadersSetsCloudflareFriendlyFields() {
        var request = URLRequest(url: PlaudOAuthPKCE.apiBase)
        PlaudOAuthPKCE.applyBrowserHeaders(to: &request)

        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), PlaudOAuthPKCE.browserUserAgent)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), PlaudOAuthPKCE.webOrigin)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Referer"), "\(PlaudOAuthPKCE.webOrigin)/")
        XCTAssertTrue(request.value(forHTTPHeaderField: "User-Agent")?.contains("Mozilla/5.0") ?? false)
    }

    func testTokenSetExpiryUsesMillisecondEpoch() {
        let expiresAt = Date().timeIntervalSince1970 * 1000 + 120_000
        let tokenSet = PlaudOAuthTokenSet(
            access_token: "token",
            refresh_token: "refresh",
            token_type: "Bearer",
            expires_at: expiresAt
        )

        XCTAssertFalse(tokenSet.isExpired)
        XCTAssertNotNil(tokenSet.expiresAtDate)
    }
}
