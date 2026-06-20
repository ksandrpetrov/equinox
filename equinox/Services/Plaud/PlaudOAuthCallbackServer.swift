import AppKit
import Foundation
import Network

enum PlaudOAuthCallbackServer {
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
            sendResponse(on: connection, statusCode: 404, html: Self.errorHTML(String(localized: "Not found", comment: "Plaud OAuth HTTP 404")))
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
            sendResponse(on: connection, statusCode: 400, html: Self.errorHTML(String(localized: "State mismatch.", comment: "Plaud OAuth state mismatch")))
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

    private static var successHTML: String {
        let title = String(localized: "Authorization successful!", comment: "Plaud OAuth success page")
        let message = String(localized: "You can close this tab.", comment: "Plaud OAuth success page")
        return "<!doctype html><html><head><meta charset=\"utf-8\"><title>Plaud</title></head>" +
            "<body style=\"font-family:system-ui;padding:2rem;text-align:center;\">" +
            "<h1>\(title)</h1><p>\(message)</p></body></html>"
    }

    private static var neutralHTML: String {
        let title = String(localized: "Continue authorization in the original window.", comment: "Plaud OAuth neutral page")
        let message = String(localized: "This page can be closed.", comment: "Plaud OAuth neutral page")
        return "<!doctype html><html><head><meta charset=\"utf-8\"><title>Plaud</title></head>" +
            "<body style=\"font-family:system-ui;padding:2rem;text-align:center;\">" +
            "<h1>\(title)</h1><p>\(message)</p></body></html>"
    }

    private static func errorHTML(_ message: String) -> String {
        let title = String(localized: "Authorization failed", comment: "Plaud OAuth error page")
        let escaped = message
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return "<!doctype html><html><head><meta charset=\"utf-8\"><title>Plaud</title></head>" +
            "<body style=\"font-family:system-ui;padding:2rem;text-align:center;\">" +
            "<h1>\(title)</h1><pre style=\"white-space:pre-wrap;\">\(escaped)</pre>" +
            "</body></html>"
    }
}
