import Foundation

struct McpSetup: Equatable {
    var isEnabled: Bool
    var serverPath: String?
    var isServerReady: Bool
    var bridgePath: String?
    var isBridgeReady: Bool
    var nodePath: String?
    var isNodeReady: Bool
    var clientConfigString: String
    var codexConfigSnippet: String
    var cursorUserConfigPath: String
    var codexConfigPath: String
    var claudeDesktopConfigPath: String

    var isReady: Bool { isServerReady && isBridgeReady && isNodeReady }
}

enum McpConfigurator {
    static let serverName = "equinox-calendar"

    static func buildSetup(enabled: Bool? = nil) -> McpSetup {
        ensureBundledBridgeInstalled()
        let serverPath = resolveServerPath()
        let bridgePath = resolveBridgePath()
        let nodePath = resolveNodeExecutable()
        let isServerReady = serverPath.map { FileManager.default.isExecutableFile(atPath: $0) || FileManager.default.fileExists(atPath: $0) } ?? false
        let isBridgeReady = bridgePath.map { FileManager.default.isExecutableFile(atPath: $0) } ?? false
        let isNodeReady = nodePath.map { FileManager.default.isExecutableFile(atPath: $0) } ?? false
        let isEnabled = enabled ?? PreferencesStore.shared.isMcpEnabled

        return McpSetup(
            isEnabled: isEnabled,
            serverPath: serverPath,
            isServerReady: isServerReady,
            bridgePath: bridgePath,
            isBridgeReady: isBridgeReady,
            nodePath: nodePath,
            isNodeReady: isNodeReady,
            clientConfigString: buildClientConfigJSON(nodePath: nodePath, serverPath: serverPath, bridgePath: bridgePath),
            codexConfigSnippet: buildCodexConfigSnippet(nodePath: nodePath, serverPath: serverPath, bridgePath: bridgePath),
            cursorUserConfigPath: cursorUserConfigPath(),
            codexConfigPath: codexConfigPath(),
            claudeDesktopConfigPath: claudeDesktopConfigPath()
        )
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try ensureCursorConfig()
            var claudeConfigurationError: Error?
            do {
                try ensureClaudeDesktopConfig()
            } catch {
                claudeConfigurationError = error
            }
            PreferencesStore.shared.isMcpEnabled = true
            if let claudeConfigurationError {
                throw McpSetupError.claudeConfigurationFailed(underlying: claudeConfigurationError)
            }
        } else {
            try removeCursorConfig()
            try? removeClaudeDesktopConfig()
            PreferencesStore.shared.isMcpEnabled = false
        }
    }

    static func ensureCursorConfigIfEnabled() {
        guard PreferencesStore.shared.isMcpEnabled else { return }
        try? ensureCursorConfig()
        try? ensureClaudeDesktopConfig()
    }

    static func ensureCursorConfig() throws {
        try ensureClientConfig(at: cursorUserConfigPath())
    }

    static func ensureClaudeDesktopConfig() throws {
        try ensureClientConfig(at: claudeDesktopConfigPath())
    }

    static func installCursorConfig(nodePath: String, serverPath: String, bridgePath: String) throws {
        try installClientConfig(at: cursorUserConfigPath(), nodePath: nodePath, serverPath: serverPath, bridgePath: bridgePath)
    }

    static func installClaudeDesktopConfig(nodePath: String, serverPath: String, bridgePath: String) throws {
        try installClientConfig(at: claudeDesktopConfigPath(), nodePath: nodePath, serverPath: serverPath, bridgePath: bridgePath)
    }

    static func removeCursorConfig() throws {
        try removeClientConfig(at: cursorUserConfigPath())
    }

    static func removeClaudeDesktopConfig() throws {
        try removeClientConfig(at: claudeDesktopConfigPath())
    }

    private static func ensureClientConfig(at configPath: String) throws {
        let setup = buildSetup()
        guard setup.isServerReady, setup.isBridgeReady, setup.isNodeReady else {
            throw McpSetupError.notReady
        }
        guard let node = setup.nodePath, let server = setup.serverPath, let bridge = setup.bridgePath else {
            throw McpSetupError.notReady
        }
        try installClientConfig(at: configPath, nodePath: node, serverPath: server, bridgePath: bridge)
    }

    private static func installClientConfig(
        at configPath: String,
        nodePath: String,
        serverPath: String,
        bridgePath: String
    ) throws {
        let path = URL(fileURLWithPath: configPath)
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        var root = try readClientConfig(at: path)
        guard var servers = root["mcpServers"] as? [String: Any] else {
            throw McpSetupError.invalidConfigFormat
        }
        servers[serverName] = [
            "command": nodePath,
            "args": [serverPath],
            "env": ["EQUINOX_BRIDGE_PATH": bridgePath],
        ]
        root["mcpServers"] = servers
        try writeJSONAtomic(root, to: path)
    }

    private static func removeClientConfig(at configPath: String) throws {
        let path = URL(fileURLWithPath: configPath)
        guard FileManager.default.fileExists(atPath: path.path) else { return }
        guard var root = try? readClientConfig(at: path) else { return }
        guard var servers = root["mcpServers"] as? [String: Any] else { return }
        servers.removeValue(forKey: serverName)
        root["mcpServers"] = servers
        try writeJSONAtomic(root, to: path)
    }

    static func buildClientConfigJSON(
        nodePath: String?,
        serverPath: String?,
        bridgePath: String?
    ) -> String {
        let config: [String: Any]
        if let nodePath, let serverPath, let bridgePath {
            config = [
                "mcpServers": [
                    serverName: [
                        "command": nodePath,
                        "args": [serverPath],
                        "env": ["EQUINOX_BRIDGE_PATH": bridgePath],
                    ],
                ],
            ]
        } else {
            config = [
                "mcpServers": [
                    serverName: [
                        "command": "node",
                        "args": ["/path/to/equinox/mcp/dist/server.js"],
                        "env": ["EQUINOX_BRIDGE_PATH": "/path/to/equinox-bridge"],
                    ],
                ],
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func buildCodexConfigSnippet(
        nodePath: String?,
        serverPath: String?,
        bridgePath: String?
    ) -> String {
        let node = nodePath ?? "node"
        let server = serverPath ?? "/path/to/equinox/mcp/dist/server.js"
        let bridge = bridgePath ?? "/path/to/equinox-bridge"
        return """
        [mcp_servers.\(serverName)]
        command = "\(node)"
        args = ["\(server)"]

        [mcp_servers.\(serverName).env]
        EQUINOX_BRIDGE_PATH = "\(bridge)"
        """
    }

    static let toolNames = McpToolNames.all

    // MARK: - Path resolution

    static func resolveServerPath() -> String? {
        candidateURLs(for: serverCandidates()).first { FileManager.default.fileExists(atPath: $0.path) }
            .map(canonicalPath)
    }

    static func resolveBridgePath() -> String? {
        candidateURLs(for: bridgeCandidates()).first { FileManager.default.isExecutableFile(atPath: $0.path) }
            .map(canonicalPath)
    }

    static func resolveNodeExecutable() -> String? {
        candidateURLs(for: nodeCandidates()).first { FileManager.default.isExecutableFile(atPath: $0.path) }
            .map(canonicalPath)
    }

    static func cursorUserConfigPath() -> String {
        homeDirectory().appendingPathComponent(".cursor/mcp.json").path
    }

    static func codexConfigPath() -> String {
        homeDirectory().appendingPathComponent(".codex/config.toml").path
    }

    static func claudeDesktopConfigPath() -> String {
        homeDirectory()
            .appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
            .path
    }

    private static func serverCandidates() -> [URL] {
        var candidates: [URL] = []
        if let override = ProcessInfo.processInfo.environment["EQUINOX_MCP_SERVER_PATH"] {
            candidates.append(URL(fileURLWithPath: override))
        }
        if let resource = Bundle.main.resourceURL {
            candidates.append(resource.appendingPathComponent("mcp/dist/server.js"))
        }
        if let workspace = workspaceRoot() {
            candidates.append(workspace.appendingPathComponent("mcp/dist/server.js"))
        }
        return candidates
    }

    private static func bridgeCandidates() -> [URL] {
        var candidates: [URL] = []
        if let override = ProcessInfo.processInfo.environment["EQUINOX_BRIDGE_PATH"] {
            candidates.append(URL(fileURLWithPath: override))
        }
        if let appSupport = applicationSupportBridgeURL() {
            candidates.append(appSupport)
        }
        if let bundled = bundledBridgeURL() {
            candidates.append(bundled)
        }
        let appMacOS = Bundle.main.bundleURL.deletingLastPathComponent()
        candidates.append(appMacOS.appendingPathComponent("equinox-bridge"))
        if let workspace = workspaceRoot() {
            candidates.append(workspace.appendingPathComponent("build/DerivedData/Build/Products/Release/equinox-bridge"))
        }
        return candidates
    }

    private static func nodeCandidates() -> [URL] {
        var candidates: [URL] = []
        if let override = ProcessInfo.processInfo.environment["EQUINOX_MCP_NODE_PATH"] {
            candidates.append(URL(fileURLWithPath: override))
        }
        if let which = whichExecutable("node") {
            candidates.append(which)
        }
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/node"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/node"))
        return candidates
    }

    private static func workspaceRoot() -> URL? {
        var current = Bundle.main.bundleURL
        for _ in 0..<8 {
            current.deleteLastPathComponent()
            let marker = current.appendingPathComponent("mcp/dist/server.js")
            if FileManager.default.fileExists(atPath: marker.path) {
                return current
            }
        }
        return nil
    }

    private static func applicationSupportBridgeURL() -> URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let bundleID = Bundle.main.bundleIdentifier else { return nil }
        return support.appendingPathComponent(bundleID).appendingPathComponent("equinox-bridge")
    }

    private static func bundledBridgeURL() -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent("equinox-bridge")
    }

    static func ensureBundledBridgeInstalled() {
        guard let bundled = bundledBridgeURL(),
              FileManager.default.isExecutableFile(atPath: bundled.path),
              let destination = applicationSupportBridgeURL() else { return }

        let destinationURL = destination
        let destinationDirectory = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        if shouldInstallBridge(from: bundled, to: destinationURL) {
            try? FileManager.default.removeItem(at: destinationURL)
            try? FileManager.default.copyItem(at: bundled, to: destinationURL)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationURL.path)
        }
    }

    private static func shouldInstallBridge(from source: URL, to destination: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: destination.path) else { return true }
        guard FileManager.default.isExecutableFile(atPath: destination.path) else { return true }
        guard let sourceAttributes = try? FileManager.default.attributesOfItem(atPath: source.path),
              let destinationAttributes = try? FileManager.default.attributesOfItem(atPath: destination.path),
              let sourceSize = sourceAttributes[.size] as? NSNumber,
              let destinationSize = destinationAttributes[.size] as? NSNumber,
              let sourceModified = sourceAttributes[.modificationDate] as? Date,
              let destinationModified = destinationAttributes[.modificationDate] as? Date else {
            return true
        }
        return sourceSize != destinationSize || sourceModified > destinationModified
    }

    private static func candidateURLs(for urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { url in
            let key = url.standardizedFileURL.path
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private static func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private static func homeDirectory() -> URL {
        if let home = ProcessInfo.processInfo.environment["HOME"], !home.isEmpty {
            return URL(fileURLWithPath: home)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private static func whichExecutable(_ name: String) -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return URL(fileURLWithPath: text)
    }

    private static func defaultClientConfig() -> [String: Any] {
        ["mcpServers": [String: Any]()]
    }

    private static func readClientConfig(at path: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: path.path) else {
            return defaultClientConfig()
        }
        guard let data = try? Data(contentsOf: path),
              let object = try? JSONSerialization.jsonObject(with: data),
              var root = object as? [String: Any] else {
            throw McpSetupError.invalidConfigFormat
        }
        normalizeMCPServers(in: &root)
        return root
    }

    private static func normalizeMCPServers(in root: inout [String: Any]) {
        if root["mcpServers"] as? [String: Any] == nil {
            root["mcpServers"] = [String: Any]()
        }
    }

    private static func writeJSONAtomic(_ object: [String: Any], to path: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let temp = path.deletingLastPathComponent().appendingPathComponent(".mcp.json.\(ProcessInfo.processInfo.processIdentifier).tmp")
        try data.write(to: temp, options: .atomic)
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
        try FileManager.default.moveItem(at: temp, to: path)
    }
}

enum McpSetupError: LocalizedError {
    case notReady
    case invalidConfigFormat
    case claudeConfigurationFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notReady:
            return String(
                localized: "MCP is not ready yet. Install Node.js and run ./scripts/build-mcp.sh.",
                comment: "MCP setup not ready error"
            )
        case .invalidConfigFormat:
            return String(
                localized: "Invalid MCP client config format.",
                comment: "MCP config format error"
            )
        case .claudeConfigurationFailed(let underlying):
            return String(
                localized: "MCP enabled for Cursor, but Claude Desktop config could not be updated: \(underlying.localizedDescription)",
                comment: "MCP Claude config partial failure"
            )
        }
    }
}
