import XCTest
@testable import equinox

final class PlaudOAuthPKCETests: XCTestCase {
    func testCodeChallengeMatchesRFCPKCEVector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        XCTAssertEqual(
            PlaudOAuthPKCE.generateCodeChallenge(from: verifier),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        )
    }

    func testAuthorizationRequestFactoryUsesInjectedRandomBytes() throws {
        let verifierBytes = Data(0..<32)
        let stateBytes = Data(32..<48)
        let request = try PlaudOAuthAuthorizationRequestFactory.make { count in
            switch count {
            case 32: return verifierBytes
            case 16: return stateBytes
            default: XCTFail("Unexpected byte count \(count)"); return Data()
            }
        }
        guard let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            return XCTFail("Missing query items")
        }

        let values = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(request.codeVerifier, PlaudOAuthPKCE.base64URLEncoded(verifierBytes))
        XCTAssertEqual(request.state, PlaudOAuthPKCE.base64URLEncoded(stateBytes))
        XCTAssertEqual(values["client_id"], PlaudOAuthConfiguration.clientID)
        XCTAssertEqual(values["redirect_uri"], PlaudOAuthConfiguration.redirectURI)
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

    func testAuthorizationRequestFactoryMapsRandomFailure() {
        enum TestError: Error { case failed }

        XCTAssertThrowsError(
            try PlaudOAuthAuthorizationRequestFactory.make { _ in throw TestError.failed }
        ) { error in
            guard case PlaudOAuthError.secureRandomGenerationFailed = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testApplyBrowserHeadersSetsCloudflareFriendlyFields() {
        var request = URLRequest(url: PlaudOAuthConfiguration.apiBase)
        PlaudOAuthConfiguration.applyBrowserHeaders(to: &request)

        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), PlaudOAuthConfiguration.browserUserAgent)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Origin"), PlaudOAuthConfiguration.webOrigin)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Referer"), "\(PlaudOAuthConfiguration.webOrigin)/")
        XCTAssertTrue(request.value(forHTTPHeaderField: "User-Agent")?.contains("Mozilla/5.0") ?? false)
    }

    func testCallbackParserAcceptsValidCodeAndState() {
        XCTAssertEqual(
            PlaudOAuthCallbackParser.parse(
                target: "/auth/callback?code=authorization-code&state=expected",
                expectedState: "expected"
            ),
            .authorizationCode("authorization-code")
        )
    }

    func testCallbackParserRejectsMismatchedOrMissingState() {
        XCTAssertEqual(
            PlaudOAuthCallbackParser.parse(
                target: "/auth/callback?code=authorization-code&state=wrong",
                expectedState: "expected"
            ),
            .denied("OAuth state mismatch.")
        )
        XCTAssertEqual(
            PlaudOAuthCallbackParser.parse(
                target: "/auth/callback?code=authorization-code",
                expectedState: "expected"
            ),
            .denied("OAuth state mismatch.")
        )
    }

    func testCallbackParserHandlesMissingCodeAndAuthorizationError() {
        XCTAssertEqual(
            PlaudOAuthCallbackParser.parse(
                target: "/auth/callback?state=expected",
                expectedState: "expected"
            ),
            .missingCode
        )
        XCTAssertEqual(
            PlaudOAuthCallbackParser.parse(
                target: "/auth/callback?error=access_denied",
                expectedState: "expected"
            ),
            .denied("access_denied")
        )
    }

    func testCallbackParserRejectsEveryDuplicateQueryParameter() {
        for parameter in ["code", "state", "error", "other"] {
            let target =
                "/auth/callback?code=value&state=expected&\(parameter)=first&\(parameter)=second"
            XCTAssertEqual(
                PlaudOAuthCallbackParser.parse(target: target, expectedState: "expected"),
                .invalid,
                "Expected duplicate \(parameter) to be rejected"
            )
        }
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
