import Foundation
import XCTest
@testable import equinox

final class McpAppBridgeServerTests: XCTestCase {
    func testParserDistinguishesFragmentedHeaderAndBodyFromCompleteRequest() {
        let header = """
        POST /bridge HTTP/1.1\r
        Host: 127.0.0.1\r
        Authorization: Bearer token\r
        Content-Length: 5\r
        \r

        """

        XCTAssertEqual(
            HTTPBridgeRequestParser.parse(Data("POST /bridge HTTP/1.1\r\n".utf8)),
            .incomplete
        )
        XCTAssertEqual(
            HTTPBridgeRequestParser.parse(Data((header + "he").utf8)),
            .incomplete
        )
        XCTAssertEqual(
            HTTPBridgeRequestParser.parse(Data((header + "hello").utf8)),
            .complete(
                HTTPBridgeRequest(
                    method: "POST",
                    path: "/bridge",
                    authorization: "Bearer token",
                    body: Data("hello".utf8)
                )
            )
        )
    }

    func testParserRejectsMalformedRequestLineHeadersAndContentLengths() {
        let requests = [
            "POST /bridge\r\nContent-Length: 0\r\n\r\n",
            "POST /bridge FTP/1.0\r\nContent-Length: 0\r\n\r\n",
            "POST /bridge HTTP/1.1\r\nBroken header\r\nContent-Length: 0\r\n\r\n",
            "POST /bridge HTTP/1.1\r\n: value\r\nContent-Length: 0\r\n\r\n",
            "POST /bridge HTTP/1.1\r\nContent-Length: nope\r\n\r\n",
            "POST /bridge HTTP/1.1\r\nContent-Length: -1\r\n\r\n",
            "POST /bridge HTTP/1.1\r\nContent-Length: 1\r\nContent-Length: 1\r\n\r\na",
        ]

        for request in requests {
            XCTAssertEqual(
                HTTPBridgeRequestParser.parse(Data(request.utf8)),
                .invalid,
                "Expected malformed request to be rejected: \(request)"
            )
        }
    }

    func testEvaluatorValidatesEndpointAuthorizationAndUTF8Payload() {
        let valid = HTTPBridgeRequest(
            method: "POST",
            path: "/bridge",
            authorization: "Bearer secret",
            body: Data(#"{"command":"list_calendars"}"#.utf8)
        )
        XCTAssertEqual(
            McpAppBridgeRequestEvaluator.evaluate(valid, token: "secret"),
            .invoke(#"{"command":"list_calendars"}"#)
        )

        XCTAssertEqual(
            McpAppBridgeRequestEvaluator.evaluate(
                HTTPBridgeRequest(
                    method: "GET",
                    path: "/bridge",
                    authorization: "Bearer secret",
                    body: Data()
                ),
                token: "secret"
            ),
            .reject(
                McpAppBridgeRequestError(
                    code: "not_found",
                    message: "Unknown MCP app bridge endpoint.",
                    status: 404
                )
            )
        )
        XCTAssertEqual(
            McpAppBridgeRequestEvaluator.evaluate(
                HTTPBridgeRequest(
                    method: "POST",
                    path: "/bridge",
                    authorization: "Bearer wrong",
                    body: Data("{}".utf8)
                ),
                token: "secret"
            ),
            .reject(
                McpAppBridgeRequestError(
                    code: "unauthorized",
                    message: "Invalid MCP app bridge token.",
                    status: 401
                )
            )
        )
        XCTAssertEqual(
            McpAppBridgeRequestEvaluator.evaluate(
                HTTPBridgeRequest(
                    method: "POST",
                    path: "/bridge",
                    authorization: "Bearer secret",
                    body: Data([0xFF])
                ),
                token: "secret"
            ),
            .reject(
                McpAppBridgeRequestError(
                    code: "invalid_request",
                    message: "Bridge command must be UTF-8 JSON.",
                    status: 400
                )
            )
        )
    }

    func testServerReturnsFakeBridgeResponseAndPreservesPrivateFiles() async throws {
        try await withTemporaryServer(
            bridgeInvoker: { payload in
                .success(Data(#"{"ok":true,"payload":\#(String(reflecting: payload))}"#.utf8))
            }
        ) { server, state, supportURL in
            let requestBody = Data(#"{"command":"list_calendars"}"#.utf8)
            let response = try await Self.send(body: requestBody, state: state)

            XCTAssertEqual(response.status, 200)
            XCTAssertTrue(String(data: response.data, encoding: .utf8)?.contains(#""ok":true"#) == true)
            try assertPrivatePermissions(at: supportURL.appendingPathComponent("mcp-app-bridge.json"))
            try assertPrivatePermissions(at: supportURL.appendingPathComponent("mcp-app-bridge.token"))
            server.stop()
        }
    }

    func testRequestOverOneMiBIsRejected() async throws {
        try await withTemporaryServer(
            bridgeInvoker: { _ in
                XCTFail("Oversized request must not invoke bridge")
                return .success(Data())
            }
        ) { server, state, _ in
            let response = try await Self.send(
                body: Data(repeating: 0x61, count: 1_048_576),
                state: state
            )

            XCTAssertEqual(response.status, 413)
            server.stop()
        }
    }

    func testBlockedInvokerDoesNotBlockSecondRequestOrListenerStop() async throws {
        let blocker = BlockingBridgeInvoker()
        try await withTemporaryServer(
            bridgeInvoker: { payload in blocker.invoke(payload) }
        ) { server, state, supportURL in
            let firstRequest = Task {
                try await Self.send(
                    body: Data(#"{"command":"list_calendars"}"#.utf8),
                    state: state
                )
            }
            try await blocker.waitUntilEntered()

            var unauthorizedState = state
            unauthorizedState.token = "wrong"
            let secondResponse = try await Self.send(body: Data("{}".utf8), state: unauthorizedState)
            XCTAssertEqual(secondResponse.status, 401)

            server.stop()
            XCTAssertFalse(
                FileManager.default.fileExists(
                    atPath: supportURL.appendingPathComponent("mcp-app-bridge.json").path
                )
            )

            blocker.release()
            let firstResponse = try await firstRequest.value
            XCTAssertEqual(firstResponse.status, 200)
        }
    }

    private func withTemporaryServer(
        bridgeInvoker: @escaping @Sendable (String) -> McpAppBridgeInvocationResult,
        body: (
            McpAppBridgeServer,
            BridgeState,
            URL
        ) async throws -> Void
    ) async throws {
        let supportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("McpAppBridgeServerTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: supportURL) }

        guard let server = McpAppBridgeServer(
            bridgePath: "/unused/test/bridge",
            supportURL: supportURL,
            bridgeInvoker: bridgeInvoker
        ) else {
            return XCTFail("Could not create MCP app bridge server")
        }
        server.start()
        let state = try await waitForState(in: supportURL)
        try await body(server, state, supportURL)
        server.stop()
    }

    private func waitForState(in supportURL: URL) async throws -> BridgeState {
        let stateURL = supportURL.appendingPathComponent("mcp-app-bridge.json")
        for _ in 0..<100 {
            if let data = try? Data(contentsOf: stateURL),
               let state = try? JSONDecoder().decode(BridgeState.self, from: data) {
                return state
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw TestFailure.stateFileNotCreated
    }

    private static func send(
        body: Data,
        state: BridgeState
    ) async throws -> (data: Data, status: Int) {
        guard let url = URL(string: state.url) else { throw TestFailure.invalidStateURL }
        var request = URLRequest(url: url, timeoutInterval: 3)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("Bearer \(state.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TestFailure.missingHTTPResponse
        }
        return (data, http.statusCode)
    }

    private func assertPrivatePermissions(at url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        XCTAssertEqual(permissions, 0o600)
    }
}

private struct BridgeState: Codable, Sendable {
    var url: String
    var token: String
}

private enum TestFailure: Error {
    case invalidStateURL
    case missingHTTPResponse
    case stateFileNotCreated
}

private final class BlockingBridgeInvoker: @unchecked Sendable {
    private let lock = NSLock()
    private let releaseSemaphore = DispatchSemaphore(value: 0)
    private var entered = false

    func invoke(_ payload: String) -> McpAppBridgeInvocationResult {
        lock.withLock { entered = true }
        releaseSemaphore.wait()
        return .success(Data(#"{"ok":true}"#.utf8))
    }

    func waitUntilEntered() async throws {
        for _ in 0..<100 {
            if lock.withLock({ entered }) {
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw TestFailure.stateFileNotCreated
    }

    func release() {
        releaseSemaphore.signal()
    }
}
