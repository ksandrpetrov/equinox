import AppKit
import SwiftUI

struct McpSettingsTab: View {
    var searchText: String = ""

    @Bindable private var prefs = PreferencesStore.shared
    @State private var setup = McpConfigurator.buildSetup()
    @State private var toggling = false
    @State private var suppressToggleChange = false
    @State private var statusMessage: String?

    var body: some View {
        SettingsDetailScaffold(title: String(localized: "MCP", comment: "MCP prefs tab label")) {
            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Cursor", "Codex", "Claude", "MCP", "LLM", "AI", "connect") {
                clientIntegrationSection
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "ready", "node", "bridge", "server", "build") {
                readinessSection
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "connect", "setup", "config", "cursor", "codex", "claude") {
                instructionsSection
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "config", "json", "copy") {
                configSection
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "tools", "calendar", "events", "analytics") {
                toolsSection
            }

            Button(String(localized: "Check Again", comment: "MCP readiness refresh")) {
                refreshSetup()
            }
            .buttonStyle(.bordered)
        }
        .onAppear {
            refreshSetup()
            syncToggleFromPreferences()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshSetup()
            syncToggleFromPreferences()
        }
    }

    private var clientIntegrationSection: some View {
        VStack(alignment: .leading, spacing: SettingsDesign.sectionHeaderBottomPadding) {
            SettingsSection(
                String(localized: "AI Client Integration", comment: "MCP clients section"),
                subtitle: String(
                    localized: "Connect Cursor, Codex, or Claude to your macOS calendars through Equinox Bridge.",
                    comment: "MCP clients section subtitle"
                )
            ) {
                SettingsRow(
                    title: String(localized: "Auto-configure Cursor and Claude", comment: ""),
                    subtitle: prefs.isMcpEnabled
                        ? String(
                            localized: "Equinox Calendar is registered in Cursor and Claude Desktop config files.",
                            comment: "MCP enabled subtitle"
                        )
                        : String(
                            localized: "Writes the Equinox Calendar server into Cursor and Claude Desktop configs.",
                            comment: "MCP disabled subtitle"
                        )
                ) {
                    Toggle("", isOn: $prefs.isMcpEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!setup.isReady || toggling)
                        .onChange(of: prefs.isMcpEnabled) { oldValue, newValue in
                            guard !suppressToggleChange, oldValue != newValue else { return }
                            Task { @MainActor in
                                await applyMcpToggle(newValue, revertingTo: oldValue)
                            }
                        }
                        .overlay {
                            if toggling {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                }
            }

            if let statusMessage {
                SettingsFooter(text: statusMessage)
            }
        }
    }

    private var readinessSection: some View {
        SettingsSection(String(localized: "Readiness", comment: "MCP readiness section")) {
            readinessRow(
                label: String(localized: "Node.js", comment: ""),
                ready: setup.isNodeReady,
                readyText: String(localized: "found", comment: "MCP readiness found"),
                notReadyText: String(localized: "not found", comment: "MCP readiness not found")
            )
            SettingsDivider()
            readinessRow(
                label: String(localized: "MCP server", comment: ""),
                ready: setup.isServerReady,
                readyText: String(localized: "found", comment: "MCP readiness found"),
                notReadyText: String(localized: "not found", comment: "MCP readiness not found")
            )
            SettingsDivider()
            readinessRow(
                label: String(localized: "Equinox Bridge", comment: ""),
                ready: setup.isBridgeReady,
                readyText: String(localized: "found", comment: "MCP readiness found"),
                notReadyText: String(localized: "not found", comment: "MCP readiness not found")
            )
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: SettingsDesign.sectionHeaderBottomPadding) {
            SettingsSection(String(localized: "How to Connect", comment: "MCP setup instructions")) {
                VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                    instructionStep(String(
                        localized: "1. Build the MCP stack once with ./scripts/build-mcp.sh in the Equinox project.",
                        comment: "MCP setup step"
                    ))
                    instructionStep(String(
                        localized: "2. Enable the toggle above for Cursor and Claude Desktop, or copy the configs below.",
                        comment: "MCP setup step"
                    ))
                    instructionStep(String(
                        localized: "3. Cursor: Settings → MCP, or edit \(setup.cursorUserConfigPath).",
                        comment: "MCP setup step"
                    ))
                    instructionStep(String(
                        localized: "4. Claude Desktop: edit \(setup.claudeDesktopConfigPath).",
                        comment: "MCP setup step"
                    ))
                    instructionStep(String(
                        localized: "5. Codex: add the TOML snippet below to \(setup.codexConfigPath).",
                        comment: "MCP setup step"
                    ))
                    instructionStep(String(
                        localized: "6. Restart the client or reload MCP servers. macOS will ask Equinox Bridge for calendar access separately from Equinox.",
                        comment: "MCP setup step"
                    ))
                }
                .padding(.vertical, SettingsDesign.rowVerticalPadding)
            }

            if !setup.isNodeReady {
                SettingsFooter(text: String(
                    localized: "Install Node.js first, for example: brew install node",
                    comment: "MCP Node.js hint"
                ))
            } else if !setup.isServerReady || !setup.isBridgeReady {
                SettingsFooter(text: String(
                    localized: "Run ./scripts/build-mcp.sh from the Equinox repository to build Equinox Bridge and the MCP server.",
                    comment: "MCP build hint"
                ))
            }
        }
    }

    private var configSection: some View {
        VStack(alignment: .leading, spacing: SettingsDesign.sectionHeaderBottomPadding) {
            SettingsSection(
                String(localized: "Cursor and Claude Config", comment: "MCP JSON config section"),
                subtitle: String(
                    localized: "JSON for Cursor (~/.cursor/mcp.json) and Claude Desktop.",
                    comment: "MCP JSON config subtitle"
                )
            ) {
                VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                    HStack {
                        Spacer()
                        Button(String(localized: "Copy JSON", comment: "")) {
                            copyText(setup.clientConfigString)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Text(setup.clientConfigString)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EquinoxDesign.spacingSM)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM))

                    if let serverPath = setup.serverPath {
                        pathLine(String(localized: "Server", comment: "MCP path label"), serverPath)
                    }
                    if let bridgePath = setup.bridgePath {
                        pathLine(String(localized: "Bridge", comment: "MCP path label"), bridgePath)
                    }
                    if let nodePath = setup.nodePath {
                        pathLine(String(localized: "Node", comment: "MCP path label"), nodePath)
                    }
                }
                .padding(.vertical, SettingsDesign.rowVerticalPadding)
            }

            SettingsSection(
                String(localized: "Codex Config", comment: "MCP Codex config section"),
                subtitle: String(
                    localized: "TOML snippet for ~/.codex/config.toml.",
                    comment: "MCP Codex config subtitle"
                )
            ) {
                VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                    HStack {
                        Spacer()
                        Button(String(localized: "Copy TOML", comment: "")) {
                            copyText(setup.codexConfigSnippet)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Text(setup.codexConfigSnippet)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EquinoxDesign.spacingSM)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM))
                }
                .padding(.vertical, SettingsDesign.rowVerticalPadding)
            }

            SettingsFooter(text: String(
                localized: "Config paths — Cursor: \(setup.cursorUserConfigPath), Claude: \(setup.claudeDesktopConfigPath), Codex: \(setup.codexConfigPath)",
                comment: "MCP client config paths"
            ))
        }
    }

    private var toolsSection: some View {
        SettingsSection(String(localized: "Available Tools", comment: "MCP tools section")) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: EquinoxDesign.spacingSM)], spacing: EquinoxDesign.spacingSM) {
                ForEach(McpConfigurator.toolNames, id: \.self) { tool in
                    Text(tool)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, EquinoxDesign.spacingSM)
                        .padding(.vertical, EquinoxDesign.spacingXS)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM))
                }
            }
            .padding(.vertical, SettingsDesign.rowVerticalPadding)
        }
    }

    @MainActor
    private func applyMcpToggle(_ enabled: Bool, revertingTo previousValue: Bool) async {
        toggling = true
        statusMessage = nil
        defer { toggling = false }

        do {
            try McpConfigurator.setEnabled(enabled)
            refreshSetup()
            statusMessage = enabled
                ? String(localized: "MCP enabled — Cursor and Claude Desktop configs updated.", comment: "MCP enabled status")
                : String(localized: "MCP disabled — Equinox Calendar removed from Cursor and Claude Desktop configs.", comment: "MCP disabled status")
        } catch let error as McpSetupError where enabled {
            refreshSetup()
            statusMessage = error.localizedDescription
            revertToggle(to: previousValue)
        } catch {
            statusMessage = error.localizedDescription
            refreshSetup()
            revertToggle(to: previousValue)
        }
    }

    private func revertToggle(to value: Bool) {
        suppressToggleChange = true
        prefs.isMcpEnabled = value
        suppressToggleChange = false
    }

    private func syncToggleFromPreferences() {
        guard !toggling else { return }
        let persisted = PreferencesStore.shared.isMcpEnabled
        guard prefs.isMcpEnabled != persisted else { return }
        revertToggle(to: persisted)
    }

    private func readinessRow(label: String, ready: Bool, readyText: String, notReadyText: String) -> some View {
        HStack {
            Image(systemName: ready ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ready ? .green : .secondary)
            Text(label)
            Spacer()
            Text(ready ? readyText : notReadyText)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, SettingsDesign.rowVerticalPadding)
    }

    private func instructionStep(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func pathLine(_ label: String, _ path: String) -> some View {
        HStack(alignment: .top, spacing: EquinoxDesign.spacingSM) {
            Text("\(label):")
                .font(.footnote.weight(.medium))
            Text(path)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.secondary)
        }
    }

    private func copyText(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        statusMessage = String(localized: "Config copied to clipboard.", comment: "MCP copy status")
    }

    private func refreshSetup() {
        setup = McpConfigurator.buildSetup()
    }
}
