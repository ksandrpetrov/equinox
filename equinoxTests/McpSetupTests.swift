import XCTest
@testable import equinox

final class McpSetupTests: XCTestCase {
    func testBuildClientConfigJSONUsesResolvedPaths() throws {
        let json = McpConfigurator.buildClientConfigJSON(
            nodePath: "/opt/homebrew/bin/node",
            serverPath: "/tmp/equinox/mcp/dist/server.js",
            bridgePath: "/tmp/equinox/build/equinox-bridge"
        )

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let servers = try XCTUnwrap(object["mcpServers"] as? [String: Any])
        let equinox = try XCTUnwrap(servers["equinox-calendar"] as? [String: Any])
        let env = try XCTUnwrap(equinox["env"] as? [String: String])

        XCTAssertEqual(equinox["command"] as? String, "/opt/homebrew/bin/node")
        XCTAssertEqual(equinox["args"] as? [String], ["/tmp/equinox/mcp/dist/server.js"])
        XCTAssertEqual(env["EQUINOX_BRIDGE_PATH"], "/tmp/equinox/build/equinox-bridge")
    }

    func testBuildCodexConfigSnippetUsesResolvedPaths() {
        let snippet = McpConfigurator.buildCodexConfigSnippet(
            nodePath: "/opt/homebrew/bin/node",
            serverPath: "/tmp/equinox/mcp/dist/server.js",
            bridgePath: "/tmp/equinox/build/equinox-bridge"
        )

        XCTAssertTrue(snippet.contains("[mcp_servers.equinox-calendar]"))
        XCTAssertTrue(snippet.contains("command = \"/opt/homebrew/bin/node\""))
        XCTAssertTrue(snippet.contains("args = [\"/tmp/equinox/mcp/dist/server.js\"]"))
        XCTAssertTrue(snippet.contains("EQUINOX_BRIDGE_PATH = \"/tmp/equinox/build/equinox-bridge\""))
    }

    func testInstallCursorConfigMergesWithoutDroppingOtherServers() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("equinox-mcp-config-test-\(ProcessInfo.processInfo.processIdentifier)")
        let cursorDir = home.appendingPathComponent(".cursor")
        try FileManager.default.createDirectory(at: cursorDir, withIntermediateDirectories: true)
        let configPath = cursorDir.appendingPathComponent("mcp.json")
        try """
        {"mcpServers":{"other":{"command":"echo","args":["hi"]}}}
        """.write(to: configPath, atomically: true, encoding: .utf8)

        let previousHome = ProcessInfo.processInfo.environment["HOME"]
        setenv("HOME", home.path, 1)
        defer {
            if let previousHome {
                setenv("HOME", previousHome, 1)
            } else {
                unsetenv("HOME")
            }
            try? FileManager.default.removeItem(at: home)
        }

        try McpConfigurator.installCursorConfig(
            nodePath: "/opt/homebrew/bin/node",
            serverPath: "/tmp/equinox/mcp/dist/server.js",
            bridgePath: "/tmp/equinox/build/equinox-bridge"
        )

        let raw = try String(contentsOf: configPath, encoding: .utf8)
        let object = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
        let servers = object?["mcpServers"] as? [String: Any]

        XCTAssertNotNil(servers?["other"])
        XCTAssertEqual(servers?["equinox-calendar"] as? [String: Any]? != nil, true)
        let equinox = servers?["equinox-calendar"] as? [String: Any]
        XCTAssertEqual(equinox?["command"] as? String, "/opt/homebrew/bin/node")
    }

    func testInstallClaudeDesktopConfigMergesWithoutDroppingOtherServers() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("equinox-mcp-claude-test-\(ProcessInfo.processInfo.processIdentifier)")
        let claudeDir = home
            .appendingPathComponent("Library/Application Support/Claude")
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        let configPath = claudeDir.appendingPathComponent("claude_desktop_config.json")
        try """
        {"mcpServers":{"other":{"command":"echo","args":["hi"]}}}
        """.write(to: configPath, atomically: true, encoding: .utf8)

        let previousHome = ProcessInfo.processInfo.environment["HOME"]
        setenv("HOME", home.path, 1)
        defer {
            if let previousHome {
                setenv("HOME", previousHome, 1)
            } else {
                unsetenv("HOME")
            }
            try? FileManager.default.removeItem(at: home)
        }

        try McpConfigurator.installClaudeDesktopConfig(
            nodePath: "/opt/homebrew/bin/node",
            serverPath: "/tmp/equinox/mcp/dist/server.js",
            bridgePath: "/tmp/equinox/build/equinox-bridge"
        )

        let raw = try String(contentsOf: configPath, encoding: .utf8)
        let object = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
        let servers = object?["mcpServers"] as? [String: Any]

        XCTAssertNotNil(servers?["other"])
        XCTAssertEqual(servers?["equinox-calendar"] as? [String: Any]? != nil, true)
    }

    func testInstallClaudeDesktopConfigNormalizesNullMCPServers() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("equinox-mcp-claude-null-test-\(ProcessInfo.processInfo.processIdentifier)")
        let claudeDir = home
            .appendingPathComponent("Library/Application Support/Claude")
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        let configPath = claudeDir.appendingPathComponent("claude_desktop_config.json")
        try """
        {"preferences":{"sidebarMode":"chat"},"mcpServers":null}
        """.write(to: configPath, atomically: true, encoding: .utf8)

        let previousHome = ProcessInfo.processInfo.environment["HOME"]
        setenv("HOME", home.path, 1)
        defer {
            if let previousHome {
                setenv("HOME", previousHome, 1)
            } else {
                unsetenv("HOME")
            }
            try? FileManager.default.removeItem(at: home)
        }

        try McpConfigurator.installClaudeDesktopConfig(
            nodePath: "/opt/homebrew/bin/node",
            serverPath: "/tmp/equinox/mcp/dist/server.js",
            bridgePath: "/tmp/equinox/build/equinox-bridge"
        )

        let raw = try String(contentsOf: configPath, encoding: .utf8)
        let object = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
        let servers = object?["mcpServers"] as? [String: Any]
        let preferences = object?["preferences"] as? [String: Any]

        XCTAssertEqual(preferences?["sidebarMode"] as? String, "chat")
        XCTAssertNotNil(servers?["equinox-calendar"])
    }

    func testMcpToolCatalogMatchesGeneratedToolNames() {
        XCTAssertEqual(Set(McpToolCatalog.allToolIDs), Set(McpToolNames.all))
        XCTAssertEqual(McpToolCatalog.allToolIDs.count, McpToolNames.all.count)
    }
}
