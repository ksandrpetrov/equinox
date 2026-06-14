import Foundation
import Network
import Security

final class McpAppBridgeServer {
    private static let stateFileName = "mcp-app-bridge.json"
    private static let tokenFileName = "mcp-app-bridge.token"
    private static let maxRequestBytes = 1_048_576

    private let bridgePath: String
    private let stateURL: URL
    private let token: String
    private let queue = DispatchQueue(label: "com.equinox.mcp-app-bridge")
    private var listener: NWListener?

    init?(bridgePath: String) {
        guard let supportURL = Self.applicationSupportURL(),
              let token = Self.loadOrCreateToken(in: supportURL) else { return nil }
        self.bridgePath = bridgePath
        self.stateURL = supportURL.appendingPathComponent(Self.stateFileName)
        self.token = token
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

            listener.start(queue: queue)
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
        connection.start(queue: queue)
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

            if let request = HTTPBridgeRequest(data: accumulated) {
                self.process(request, connection: connection)
                return
            }

            if isComplete {
                self.sendJSONError(code: "invalid_request", message: "Incomplete HTTP request.", status: 400, on: connection)
                return
            }

            self.receiveRequest(on: connection, buffer: accumulated)
        }
    }

    private func process(_ request: HTTPBridgeRequest, connection: NWConnection) {
        guard request.method == "POST", request.path == "/bridge" else {
            sendJSONError(code: "not_found", message: "Unknown MCP app bridge endpoint.", status: 404, on: connection)
            return
        }
        guard request.authorization == "Bearer \(token)" else {
            sendJSONError(code: "unauthorized", message: "Invalid MCP app bridge token.", status: 401, on: connection)
            return
        }
        guard let payload = String(data: request.body, encoding: .utf8), !payload.isEmpty else {
            sendJSONError(code: "invalid_request", message: "Bridge command must be UTF-8 JSON.", status: 400, on: connection)
            return
        }

        sendBridgeResponse(for: payload, on: connection)
    }

    private func sendBridgeResponse(for payload: String, on connection: NWConnection) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: bridgePath)
        process.arguments = [payload]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            sendJSONError(code: "bridge_launch_failed", message: error.localizedDescription, status: 502, on: connection)
            return
        }

        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
        guard (process.terminationStatus == 0 || process.terminationStatus == 1), !output.isEmpty else {
            let message = String(data: errorOutput + output, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            sendJSONError(
                code: "bridge_invocation_failed",
                message: message?.isEmpty == false ? message! : "equinox-bridge returned empty output.",
                status: 502,
                on: connection
            )
            return
        }

        sendHTTP(status: 200, body: output, on: connection)
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
        let url = support.appendingPathComponent(bundleID, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func loadOrCreateToken(in supportURL: URL) -> String? {
        let tokenURL = supportURL.appendingPathComponent(tokenFileName)
        if let token = try? String(contentsOf: tokenURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            return token
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return nil }
        let token = Data(bytes).base64EncodedString()
        do {
            try token.write(to: tokenURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenURL.path)
            return token
        } catch {
            return nil
        }
    }
}

private struct HTTPBridgeRequest {
    let method: String
    let path: String
    let authorization: String?
    let body: Data

    init?(data: Data) {
        let delimiter = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: delimiter) else { return nil }
        let headerEnd = headerRange.lowerBound
        let bodyStart = headerRange.upperBound
        guard let headerText = String(data: data[..<headerEnd], encoding: .utf8) else { return nil }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let requestParts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard requestParts.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let name = line[..<separator].lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        guard let contentLengthText = headers["content-length"],
              let contentLength = Int(contentLengthText),
              contentLength >= 0 else { return nil }
        let bodyEnd = bodyStart + contentLength
        guard data.count >= bodyEnd else { return nil }

        method = requestParts[0]
        path = requestParts[1]
        authorization = headers["authorization"]
        body = data[bodyStart..<bodyEnd]
    }
}

private enum HTTPBridgeResponseReason {
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
