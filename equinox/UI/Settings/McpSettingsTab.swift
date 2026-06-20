import AppKit
import SwiftUI

struct McpSettingsTab: View {
    var searchText: String = ""

    @Environment(\.appState) private var appState
    @State private var suppressToggleChange = false

    var body: some View {
        if let appState {
            mcpContent(appState: appState)
        } else {
            SettingsDetailScaffold(title: String(localized: "MCP", comment: "MCP prefs tab label")) {
                SettingsFooter(text: String(localized: "Open settings from the Equinox menu bar.", comment: "Settings unavailable without app state"))
            }
        }
    }

    @ViewBuilder
    private func mcpContent(appState: AppState) -> some View {
        @Bindable var mcp = appState.mcp
        @Bindable var prefs = appState.preferences

        SettingsDetailScaffold(title: String(localized: "MCP", comment: "MCP prefs tab label")) {
            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Cursor", "Codex", "Claude", "MCP", "LLM", "AI", "connect") {
                clientIntegrationSection(mcp: mcp, prefs: prefs)
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "ready", "node", "bridge", "server", "build") {
                readinessSection(mcp: mcp)
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "connect", "setup", "config", "cursor", "codex", "claude") {
                instructionsSection(mcp: mcp)
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "config", "json", "copy") {
                configSection(mcp: mcp)
            }

            if SettingsSearchFilter.matches(
                searchText: searchText,
                keywords: "tools", "calendar", "events", "analytics", "access", "conflicts", "free time", "schedule", "create", "delete"
            ) {
                toolsSection
            }

            Button(String(localized: "Check Again", comment: "MCP readiness refresh")) {
                mcp.refreshSetup()
            }
            .buttonStyle(.bordered)
        }
        .onAppear {
            mcp.refreshSetup()
            syncToggleFromPreferences(mcp: mcp, prefs: prefs)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            mcp.refreshSetup()
            syncToggleFromPreferences(mcp: mcp, prefs: prefs)
        }
    }

    private func clientIntegrationSection(mcp: McpCoordinator, prefs: PreferencesStore) -> some View {
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
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { prefs.isMcpEnabled },
                            set: { prefs.isMcpEnabled = $0 }
                        )
                    )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!mcp.setup.isReady || mcp.isToggling)
                        .onChange(of: prefs.isMcpEnabled) { oldValue, newValue in
                            guard !suppressToggleChange, oldValue != newValue else { return }
                            Task { @MainActor in
                                await applyMcpToggle(newValue, revertingTo: oldValue, mcp: mcp, prefs: prefs)
                            }
                        }
                        .overlay {
                            if mcp.isToggling {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                }
            }

            if let statusMessage = mcp.statusMessage {
                SettingsFooter(text: statusMessage)
            }
        }
    }

    private func readinessSection(mcp: McpCoordinator) -> some View {
        SettingsSection(String(localized: "Readiness", comment: "MCP readiness section")) {
            readinessRow(
                label: String(localized: "Node.js", comment: ""),
                ready: mcp.setup.isNodeReady,
                readyText: String(localized: "found", comment: "MCP readiness found"),
                notReadyText: String(localized: "not found", comment: "MCP readiness not found")
            )
            SettingsDivider()
            readinessRow(
                label: String(localized: "MCP server", comment: ""),
                ready: mcp.setup.isServerReady,
                readyText: String(localized: "found", comment: "MCP readiness found"),
                notReadyText: String(localized: "not found", comment: "MCP readiness not found")
            )
            SettingsDivider()
            readinessRow(
                label: String(localized: "Equinox Bridge", comment: ""),
                ready: mcp.setup.isBridgeReady,
                readyText: String(localized: "found", comment: "MCP readiness found"),
                notReadyText: String(localized: "not found", comment: "MCP readiness not found")
            )
        }
    }

    private func instructionsSection(mcp: McpCoordinator) -> some View {
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
                        localized: "3. Cursor: Settings → MCP, or edit \(mcp.setup.cursorUserConfigPath).",
                        comment: "MCP setup step"
                    ))
                    instructionStep(String(
                        localized: "4. Claude Desktop: edit \(mcp.setup.claudeDesktopConfigPath).",
                        comment: "MCP setup step"
                    ))
                    instructionStep(String(
                        localized: "5. Codex: add the TOML snippet below to \(mcp.setup.codexConfigPath).",
                        comment: "MCP setup step"
                    ))
                    instructionStep(String(
                        localized: "6. Restart the client or reload MCP servers, then keep Equinox running while using calendar tools.",
                        comment: "MCP setup step"
                    ))
                }
                .padding(.vertical, SettingsDesign.rowVerticalPadding)
            }

            if !mcp.setup.isNodeReady {
                SettingsFooter(text: String(
                    localized: "Install Node.js first, for example: brew install node",
                    comment: "MCP Node.js hint"
                ))
            } else if !mcp.setup.isServerReady || !mcp.setup.isBridgeReady {
                SettingsFooter(text: String(
                    localized: "Run ./scripts/build-mcp.sh from the Equinox repository to build Equinox Bridge and the MCP server.",
                    comment: "MCP build hint"
                ))
            }
        }
    }

    private func configSection(mcp: McpCoordinator) -> some View {
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
                            mcp.copyConfigToClipboard(mcp.setup.clientConfigString)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Text(mcp.setup.clientConfigString)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EquinoxDesign.spacingSM)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM))

                    if let serverPath = mcp.setup.serverPath {
                        pathLine(String(localized: "Server", comment: "MCP path label"), serverPath)
                    }
                    if let bridgePath = mcp.setup.bridgePath {
                        pathLine(String(localized: "Bridge", comment: "MCP path label"), bridgePath)
                    }
                    if let nodePath = mcp.setup.nodePath {
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
                            mcp.copyConfigToClipboard(mcp.setup.codexConfigSnippet)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Text(mcp.setup.codexConfigSnippet)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(EquinoxDesign.spacingSM)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM))
                }
                .padding(.vertical, SettingsDesign.rowVerticalPadding)
            }

            SettingsFooter(text: String(
                localized: "Config paths — Cursor: \(mcp.setup.cursorUserConfigPath), Claude: \(mcp.setup.claudeDesktopConfigPath), Codex: \(mcp.setup.codexConfigPath)",
                comment: "MCP client config paths"
            ))
        }
    }

    private var toolsSection: some View {
        SettingsSection(
            String(localized: "Available Tools", comment: "MCP tools section"),
            subtitle: String(
                localized: "Commands your AI assistant can use to view and manage your macOS calendars through Equinox. Nothing changes in your calendar until you ask the assistant to create, update, or delete an event.",
                comment: "MCP tools section subtitle"
            )
        ) {
            VStack(alignment: .leading, spacing: EquinoxDesign.spacingMD) {
                ForEach(McpToolCatalog.groups, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(group.category.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, EquinoxDesign.spacingXS)

                        ForEach(Array(group.tools.enumerated()), id: \.element.id) { index, tool in
                            mcpToolRow(tool)
                            if index < group.tools.count - 1 {
                                SettingsDivider()
                            }
                        }
                    }
                }
            }
            .padding(.vertical, SettingsDesign.rowVerticalPadding)
        }
    }

    private func mcpToolRow(_ tool: McpToolCatalogEntry) -> some View {
        VStack(alignment: .leading, spacing: EquinoxDesign.spacingXS) {
            HStack(alignment: .firstTextBaseline, spacing: EquinoxDesign.spacingSM) {
                Text(tool.title)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: EquinoxDesign.spacingSM)
                Text(tool.id)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Text(tool.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, SettingsDesign.rowVerticalPadding)
    }

    @MainActor
    private func applyMcpToggle(_ enabled: Bool, revertingTo previousValue: Bool, mcp: McpCoordinator, prefs: PreferencesStore) async {
        if await mcp.setEnabled(enabled) != nil {
            revertToggle(to: previousValue, prefs: prefs)
        }
    }

    private func revertToggle(to value: Bool, prefs: PreferencesStore) {
        suppressToggleChange = true
        prefs.isMcpEnabled = value
        suppressToggleChange = false
    }

    private func syncToggleFromPreferences(mcp: McpCoordinator, prefs: PreferencesStore) {
        guard let persisted = mcp.syncToggleFromPreferences(currentValue: prefs.isMcpEnabled) else { return }
        revertToggle(to: persisted, prefs: prefs)
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
}
