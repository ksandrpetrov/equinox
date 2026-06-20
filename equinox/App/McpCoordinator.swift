import AppKit
import Foundation

@Observable
@MainActor
final class McpCoordinator {
    private let preferences: PreferencesStore

    var setup = McpConfigurator.buildSetup()
    var statusMessage: String?
    private(set) var isToggling = false

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    var isEnabled: Bool {
        get { preferences.isMcpEnabled }
        set { preferences.isMcpEnabled = newValue }
    }

    func refreshSetup() {
        setup = McpConfigurator.buildSetup(enabled: preferences.isMcpEnabled)
    }

    func syncToggleFromPreferences(currentValue: Bool) -> Bool? {
        guard !isToggling else { return nil }
        let persisted = preferences.isMcpEnabled
        guard currentValue != persisted else { return nil }
        return persisted
    }

    func setEnabled(_ enabled: Bool) async -> String? {
        isToggling = true
        statusMessage = nil
        defer { isToggling = false }

        do {
            try McpConfigurator.setEnabled(enabled)
            refreshSetup()
            statusMessage = enabled
                ? String(localized: "MCP enabled — Cursor and Claude Desktop configs updated.", comment: "MCP enabled status")
                : String(localized: "MCP disabled — Equinox Calendar removed from Cursor and Claude Desktop configs.", comment: "MCP disabled status")
            return nil
        } catch let error as McpSetupError where enabled {
            refreshSetup()
            statusMessage = error.localizedDescription
            return error.localizedDescription
        } catch {
            refreshSetup()
            statusMessage = error.localizedDescription
            return error.localizedDescription
        }
    }

    func copyConfigToClipboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        statusMessage = String(localized: "Config copied to clipboard.", comment: "MCP copy status")
    }
}
