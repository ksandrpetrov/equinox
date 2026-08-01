import Foundation
import Network

final class McpAppBridgeServer: @unchecked Sendable {
    private static let stateFileName = "mcp-app-bridge.json"
    private static let tokenFileName = "mcp-app-bridge.token"
    private static let maxRequestBytes = 1_048_576

    private let stateURL: URL
    private let token: String
    private let bridgeInvoker: @Sendable (String) -> McpAppBridgeInvocationResult
    private let networkQueue = DispatchQueue(label: "com.equinox.mcp-app-bridge.network")
    private let invocationQueue = DispatchQueue(label: "com.equinox.mcp-app-bridge.invocation")
    private var listener: NWListener?

    convenience init?(bridgePath: String) {
        guard let supportURL = Self.applicationSupportURL() else { return nil }
        self.init(bridgePath: bridgePath, supportURL: supportURL)
    }

    init?(
        bridgePath: String,
        supportURL: URL,
        bridgeInvoker: (@Sendable (String) -> McpAppBridgeInvocationResult)? = nil
    ) {
        do {
            try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        guard let token = Self.loadOrCreateToken(in: supportURL) else { return nil }

        self.stateURL = supportURL.appendingPathComponent(Self.stateFileName)
        self.token = token
        self.bridgeInvoker = bridgeInvoker ?? { payload in
            Self.invokeBridge(at: bridgePath, payload: payload)
        }
    }

    func start() {
        guard listener == nil else { return }

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: .ipv4(.loopback),
                port: .init(rawValue: 0)!
            )
            let listener = try NWListener(using: parameters)
            self.listener = listener

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    if let port = listener.port {
                        self.writeState(port: port)
                    }
                case .failed, .cancelled:
                    self.removeState()
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection: connection)
            }

            listener.start(queue: networkQueue)
        } catch {
            removeState()
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        removeState()
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
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: networkQueue)
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

            if accumulated.count > Self.maxRequestBytes {
                self.sendJSONError(code: "request_too_large", message: "MCP app bridge request is too large.", status: 413, on: connection)
                return
            }

            switch HTTPBridgeRequestParser.parse(accumulated) {
            case .complete(let request):
                self.process(request, connection: connection)
            case .invalid:
                self.sendJSONError(
                    code: "invalid_request",
                    message: "Malformed HTTP request.",
                    status: 400,
                    on: connection
                )
            case .incomplete:
                if isComplete {
                    self.sendJSONError(
                        code: "invalid_request",
                        message: "Incomplete HTTP request.",
                        status: 400,
                        on: connection
                    )
                } else {
                    self.receiveRequest(on: connection, buffer: accumulated)
                }
            }
        }
    }

    private func process(_ request: HTTPBridgeRequest, connection: NWConnection) {
        switch McpAppBridgeRequestEvaluator.evaluate(request, token: token) {
        case .invoke(let payload):
            invokeBridge(for: payload, on: connection)
        case .reject(let error):
            sendJSONError(
                code: error.code,
                message: error.message,
                status: error.status,
                on: connection
            )
        }
    }

    private func invokeBridge(for payload: String, on connection: NWConnection) {
        invocationQueue.async { [weak self] in
            guard let self else {
                connection.cancel()
                return
            }
            let result = self.bridgeInvoker(payload)
            self.networkQueue.async { [weak self] in
                guard let self else {
                    connection.cancel()
                    return
                }
                switch result {
                case .success(let output):
                    self.sendHTTP(status: 200, body: output, on: connection)
                case .failure(let code, let message):
                    self.sendJSONError(
                        code: code,
                        message: message,
                        status: 502,
                        on: connection
                    )
                }
            }
        }
    }

    private static func invokeBridge(at bridgePath: String, payload: String) -> McpAppBridgeInvocationResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: bridgePath)
        process.arguments = [payload]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let stdoutHandle = stdout.fileHandleForReading
        let stderrHandle = stderr.fileHandleForReading

        do {
            try process.run()
        } catch {
            return .failure(code: "bridge_launch_failed", message: error.localizedDescription)
        }

        let stderrGroup = DispatchGroup()
        let errorOutput = ProcessErrorOutput()
        stderrGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            errorOutput.store(stderrHandle.readDataToEndOfFile())
            stderrGroup.leave()
        }

        let output = stdoutHandle.readDataToEndOfFile()
        stderrGroup.wait()
        process.waitUntilExit()
        guard (process.terminationStatus == 0 || process.terminationStatus == 1), !output.isEmpty else {
            let message = String(data: errorOutput.load() + output, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(
                code: "bridge_invocation_failed",
                message: message?.isEmpty == false ? message! : "equinox-bridge returned empty output."
            )
        }

        return .success(output)
    }

    private func writeState(port: NWEndpoint.Port) {
        let object: [String: Any] = [
            "url": "http://127.0.0.1:\(port.rawValue)/bridge",
            "token": token,
            "pid": ProcessInfo.processInfo.processIdentifier,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else { return }
        do {
            try data.write(to: stateURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateURL.path)
        } catch {
            removeState()
        }
    }

    private func removeState() {
        try? FileManager.default.removeItem(at: stateURL)
    }

    private func sendJSONError(code: String, message: String, status: Int, on connection: NWConnection) {
        let bodyObject: [String: Any] = [
            "ok": false,
            "error": [
                "code": code,
                "message": message,
            ],
        ]
        let body = (try? JSONSerialization.data(withJSONObject: bodyObject, options: [.sortedKeys])) ?? Data()
        sendHTTP(status: status, body: body, on: connection)
    }

    private func sendHTTP(status: Int, body: Data, on connection: NWConnection) {
        let reason = HTTPBridgeResponseReason.phrase(for: status)
        let header = """
        HTTP/1.1 \(status) \(reason)\r
        Content-Type: application/json; charset=utf-8\r
        Content-Length: \(body.count)\r
        Connection: close\r
        \r

        """
        var response = Data(header.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func applicationSupportURL() -> URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let bundleID = Bundle.main.bundleIdentifier else { return nil }
        return support.appendingPathComponent(bundleID, isDirectory: true)
    }

    private static func loadOrCreateToken(in supportURL: URL) -> String? {
        let tokenURL = supportURL.appendingPathComponent(tokenFileName)
        if let token = try? String(contentsOf: tokenURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            return token
        }

        guard let bytes = try? SecureRandomBytes.generate(count: 32) else { return nil }
        let token = bytes.base64EncodedString()
        do {
            try token.write(to: tokenURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenURL.path)
            return token
        } catch {
            return nil
        }
    }
}

private final class ProcessErrorOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func store(_ data: Data) {
        lock.withLock {
            self.data = data
        }
    }

    func load() -> Data {
        lock.withLock {
            data
        }
    }
}

enum McpAppBridgeInvocationResult: Sendable, Equatable {
    case success(Data)
    case failure(code: String, message: String)
}

struct HTTPBridgeRequest: Sendable, Equatable {
    let method: String
    let path: String
    let authorization: String?
    let body: Data
}

enum HTTPBridgeRequestParseResult: Sendable, Equatable {
    case incomplete
    case invalid
    case complete(HTTPBridgeRequest)
}

enum HTTPBridgeRequestParser {
    private static let validHeaderNameCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%&'*+-.^_`|~"
    )

    static func parse(_ data: Data) -> HTTPBridgeRequestParseResult {
        let delimiter = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: delimiter) else { return .incomplete }
        let headerEnd = headerRange.lowerBound
        let bodyStart = headerRange.upperBound
        guard let headerText = String(data: data[..<headerEnd], encoding: .utf8) else {
            return .invalid
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return .invalid }
        let requestParts = requestLine.components(separatedBy: " ")
        guard requestParts.count == 3,
              requestParts.allSatisfy({ !$0.isEmpty }),
              requestParts[0].unicodeScalars.allSatisfy(validHeaderNameCharacters.contains),
              requestParts[1].hasPrefix("/"),
              requestParts[2] == "HTTP/1.1" || requestParts[2] == "HTTP/1.0" else {
            return .invalid
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":"), separator != line.startIndex else {
                return .invalid
            }
            let name = String(line[..<separator])
            guard name.unicodeScalars.allSatisfy(validHeaderNameCharacters.contains) else {
                return .invalid
            }
            let normalizedName = name.lowercased()
            guard headers[normalizedName] == nil else { return .invalid }
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            headers[normalizedName] = value
        }

        guard let contentLengthText = headers["content-length"],
              !contentLengthText.isEmpty,
              contentLengthText.allSatisfy(\.isNumber),
              let contentLength = Int(contentLengthText),
              contentLength >= 0 else {
            return .invalid
        }
        guard contentLength <= Int.max - bodyStart else { return .invalid }
        let bodyEnd = bodyStart + contentLength
        guard data.count >= bodyEnd else { return .incomplete }

        return .complete(
            HTTPBridgeRequest(
                method: requestParts[0],
                path: requestParts[1],
                authorization: headers["authorization"],
                body: data[bodyStart..<bodyEnd]
            )
        )
    }
}

struct McpAppBridgeRequestError: Sendable, Equatable {
    let code: String
    let message: String
    let status: Int
}

enum McpAppBridgeRequestEvaluation: Sendable, Equatable {
    case invoke(String)
    case reject(McpAppBridgeRequestError)
}

enum McpAppBridgeRequestEvaluator {
    static func evaluate(
        _ request: HTTPBridgeRequest,
        token: String
    ) -> McpAppBridgeRequestEvaluation {
        guard request.method == "POST", request.path == "/bridge" else {
            return .reject(
                McpAppBridgeRequestError(
                    code: "not_found",
                    message: "Unknown MCP app bridge endpoint.",
                    status: 404
                )
            )
        }
        guard request.authorization == "Bearer \(token)" else {
            return .reject(
                McpAppBridgeRequestError(
                    code: "unauthorized",
                    message: "Invalid MCP app bridge token.",
                    status: 401
                )
            )
        }
        guard let payload = String(data: request.body, encoding: .utf8), !payload.isEmpty else {
            return .reject(
                McpAppBridgeRequestError(
                    code: "invalid_request",
                    message: "Bridge command must be UTF-8 JSON.",
                    status: 400
                )
            )
        }
        return .invoke(payload)
    }
}

enum HTTPBridgeResponseReason {
    static func phrase(for status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 413: return "Payload Too Large"
        default: return "Bad Gateway"
        }
    }
}
