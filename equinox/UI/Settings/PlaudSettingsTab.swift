import AppKit
import SwiftUI

struct PlaudSettingsTab: View {
    var searchText: String = ""
    @Environment(\.appState) private var appState

    @State private var setup = PlaudConfigurator.buildSetup()
    @State private var isPlaudEnabled = PreferencesStore.shared.isPlaudEnabled
    @State private var syncIndexPath = PreferencesStore.shared.plaudSyncIndexPath ?? ""
    @State private var exporterDataPath = PreferencesStore.shared.plaudExporterDataPath ?? ""
    @State private var statusMessage: String?
    @State private var isRefreshing = false
    @State private var isOAuthBusy = false

    var body: some View {
        SettingsDetailScaffold(title: String(localized: "Plaud", comment: "Plaud prefs tab label")) {
            if matches("enable", "integration", "plaud") {
                integrationSection
            }

            if matches("sync", "index", "path", "exporter", "data") {
                pathsSection
            }

            if matches("refresh", "status", "cache", "record") {
                statusSection
            }

            if matches("connect", "oauth", "live") {
                oauthSection
            }

            Button(String(localized: "Refresh Now", comment: "Plaud manual refresh")) {
                Task { await refresh(force: true) }
            }
            .buttonStyle(.bordered)
            .disabled(isRefreshing)
        }
        .onAppear {
            refreshSetup()
            syncFromPreferences()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshSetup()
        }
    }

    private var integrationSection: some View {
        SettingsSection(
            String(localized: "Plaud Integration", comment: "Plaud settings section"),
            subtitle: String(
                localized: "Match past calendar meetings with Plaud recordings and open them in the browser.",
                comment: "Plaud settings subtitle"
            )
        ) {
            SettingsRow(
                title: String(localized: "Enable Plaud integration", comment: ""),
                subtitle: isPlaudEnabled
                    ? String(localized: "Past meetings can show an Open in Plaud button.", comment: "")
                    : String(localized: "Turn on to link calendar events with Plaud recordings.", comment: "")
            ) {
                Toggle("", isOn: $isPlaudEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: isPlaudEnabled) { _, newValue in
                        PreferencesStore.shared.isPlaudEnabled = newValue
                        if newValue {
                            if syncIndexPath.isEmpty, let defaultPath = PlaudConfigurator.resolveDefaultSyncIndexPath() {
                                syncIndexPath = defaultPath
                                PreferencesStore.shared.plaudSyncIndexPath = defaultPath
                            }
                            if exporterDataPath.isEmpty, let defaultExporter = PlaudConfigurator.resolveExporterDataPath() {
                                exporterDataPath = defaultExporter
                                PreferencesStore.shared.plaudExporterDataPath = defaultExporter
                            }
                            Task { await refresh(force: true) }
                        } else {
                            appState?.refreshPlaudMatchesIfNeeded()
                            refreshSetup()
                        }
                    }
            }
        }
    }

    private var pathsSection: some View {
        VStack(alignment: .leading, spacing: SettingsDesign.sectionHeaderBottomPadding) {
            SettingsSection(
                String(localized: "Sync Index", comment: "Plaud sync index section"),
                subtitle: String(
                    localized: "Local sync-index.json from plaud-server-exporter or Syncthing.",
                    comment: "Plaud sync index subtitle"
                )
            ) {
                VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                    pathRow(
                        label: String(localized: "Index file", comment: ""),
                        path: syncIndexPath.isEmpty
                            ? (setup.defaultSyncIndexPath ?? String(localized: "Not selected", comment: ""))
                            : syncIndexPath,
                        isPlaceholder: syncIndexPath.isEmpty && setup.defaultSyncIndexPath != nil
                    )

                    HStack {
                        Button(String(localized: "Choose File…", comment: "Plaud index picker")) {
                            pickSyncIndex()
                        }
                        .buttonStyle(.bordered)

                        if !syncIndexPath.isEmpty || setup.hasSyncIndexBookmark {
                            Button(String(localized: "Clear", comment: "")) {
                                clearSyncIndex()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.vertical, SettingsDesign.rowVerticalPadding)
            }

            SettingsSection(
                String(localized: "Exporter Data (optional)", comment: "Plaud exporter data section"),
                subtitle: String(
                    localized: "server/.data directory for live refresh via existing Plaud OAuth session.",
                    comment: "Plaud exporter data subtitle"
                )
            ) {
                VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                    pathRow(
                        label: String(localized: "Data directory", comment: ""),
                        path: exporterDataPath.isEmpty
                            ? (PlaudConfigurator.resolveExporterDataPath()
                                ?? String(localized: "Not selected", comment: ""))
                            : exporterDataPath,
                        isPlaceholder: exporterDataPath.isEmpty
                    )

                    HStack {
                        Button(String(localized: "Choose Folder…", comment: "Plaud exporter picker")) {
                            pickExporterData()
                        }
                        .buttonStyle(.bordered)

                        if !exporterDataPath.isEmpty {
                            Button(String(localized: "Clear", comment: "")) {
                                exporterDataPath = ""
                                PreferencesStore.shared.plaudExporterDataPath = nil
                                refreshSetup()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.vertical, SettingsDesign.rowVerticalPadding)
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: SettingsDesign.sectionHeaderBottomPadding) {
            SettingsSection(String(localized: "Status", comment: "Plaud status section")) {
                statusRow(
                    label: String(localized: "Index ready", comment: ""),
                    ready: setup.isIndexReady
                )
                SettingsDivider()
                statusRow(
                    label: String(localized: "Recordings in index", comment: ""),
                    value: "\(setup.recordCount)"
                )
                if let modified = setup.indexModifiedAt {
                    SettingsDivider()
                    statusRow(
                        label: String(localized: "Index modified", comment: ""),
                        value: EquinoxFormatters.formatter(key: "plaud.index.modified") {
                            $0.dateStyle = .medium
                            $0.timeStyle = .short
                        }.string(from: modified)
                    )
                }
                SettingsDivider()
                statusRow(
                    label: String(localized: "Cached links", comment: ""),
                    value: "\(setup.cachePositiveCount) (\(setup.cacheManualCount) manual)"
                )
                SettingsDivider()
                statusRow(
                    label: String(localized: "No-recording cache", comment: ""),
                    value: "\(setup.cacheNegativeCount)"
                )
            }

            if let statusMessage {
                SettingsFooter(text: statusMessage)
            } else if let error = setup.lastError {
                SettingsFooter(text: error)
            }
        }
    }

    private var oauthSection: some View {
        SettingsSection(
            String(localized: "Live Refresh", comment: "Plaud OAuth section"),
            subtitle: String(
                localized: "Uses exporter oauth-tokens.json or Equinox Keychain tokens when the index is stale.",
                comment: "Plaud OAuth subtitle"
            )
        ) {
            VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                statusRow(
                    label: String(localized: "Exporter OAuth", comment: ""),
                    ready: setup.hasExporterOAuth
                )
                SettingsDivider()
                statusRow(
                    label: String(localized: "Equinox Keychain OAuth", comment: ""),
                    ready: setup.hasKeychainOAuth
                )

                if setup.hasKeychainOAuth {
                    if let expiresAt = setup.keychainOAuthExpiresAt {
                        SettingsDivider()
                        statusRow(
                            label: String(localized: "Token expires", comment: "Plaud OAuth expiry"),
                            value: EquinoxFormatters.formatter(key: "plaud.oauth.expires") {
                                $0.dateStyle = .medium
                                $0.timeStyle = .short
                            }.string(from: expiresAt)
                        )
                    } else if setup.keychainOAuthHasRefresh {
                        SettingsDivider()
                        statusRow(
                            label: String(localized: "Token refresh", comment: "Plaud OAuth refresh"),
                            value: String(localized: "available", comment: "Plaud OAuth refresh available")
                        )
                    }
                }

                HStack(spacing: EquinoxDesign.spacingSM) {
                    Button(String(localized: "Connect Plaud…", comment: "Plaud OAuth sign in")) {
                        Task { await connectPlaud() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isOAuthBusy || setup.hasKeychainOAuth)

                    Button(String(localized: "Disconnect", comment: "Plaud OAuth sign out")) {
                        Task { await disconnectPlaud() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isOAuthBusy || !setup.hasKeychainOAuth)
                }

                Text(String(
                    localized: "Sign in with your Plaud account to refresh recordings when the sync index is stale. Exporter oauth-tokens.json still works as a fallback.",
                    comment: "Plaud OAuth help"
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, SettingsDesign.rowVerticalPadding)
        }
    }

    private func statusRow(label: String, ready: Bool) -> some View {
        HStack {
            Image(systemName: ready ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ready ? .green : .secondary)
            Text(label)
            Spacer()
            Text(ready
                ? String(localized: "found", comment: "Plaud readiness found")
                : String(localized: "not found", comment: "Plaud readiness not found"))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, SettingsDesign.rowVerticalPadding)
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, SettingsDesign.rowVerticalPadding)
    }

    private func pathRow(label: String, path: String, isPlaceholder: Bool) -> some View {
        HStack(alignment: .top, spacing: EquinoxDesign.spacingSM) {
            Text("\(label):")
                .font(.footnote.weight(.medium))
            Text(path)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(isPlaceholder ? .tertiary : .secondary)
        }
    }

    private func pickSyncIndex() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        panel.prompt = String(localized: "Choose", comment: "File picker confirm")
        panel.message = String(localized: "Select sync-index.json", comment: "Plaud index picker message")

        if panel.runModal() == .OK, let url = panel.url {
            if let bookmark = PlaudCatalog.makeBookmark(for: url) {
                PreferencesStore.shared.plaudSyncIndexBookmark = bookmark
            }
            syncIndexPath = url.path
            PreferencesStore.shared.plaudSyncIndexPath = url.path
            statusMessage = String(localized: "Sync index path updated.", comment: "Plaud status")
            Task { await refresh(force: true) }
        }
    }

    private func pickExporterData() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Choose", comment: "Folder picker confirm")
        panel.message = String(localized: "Select plaud-server-exporter server/.data folder", comment: "")

        if panel.runModal() == .OK, let url = panel.url {
            exporterDataPath = url.path
            PreferencesStore.shared.plaudExporterDataPath = url.path
            statusMessage = String(localized: "Exporter data path updated.", comment: "Plaud status")
            refreshSetup()
        }
    }

    private func clearSyncIndex() {
        syncIndexPath = ""
        PreferencesStore.shared.plaudSyncIndexPath = nil
        PreferencesStore.shared.plaudSyncIndexBookmark = nil
        statusMessage = String(localized: "Sync index path cleared.", comment: "Plaud status")
        refreshSetup()
    }

    private func refreshSetup() {
        setup = PlaudConfigurator.buildSetup()
    }

    @MainActor
    private func connectPlaud() async {
        isOAuthBusy = true
        defer { isOAuthBusy = false }

        do {
            try await PlaudOAuthClient.signIn()
            refreshSetup()
            statusMessage = String(localized: "Plaud account connected.", comment: "Plaud OAuth status")
            if let appState {
                await appState.forceRefreshPlaud()
                setup = appState.plaudSetup
            }
        } catch {
            statusMessage = error.localizedDescription
            refreshSetup()
        }
    }

    @MainActor
    private func disconnectPlaud() async {
        isOAuthBusy = true
        defer { isOAuthBusy = false }

        await PlaudOAuthClient.signOut()
        refreshSetup()
        statusMessage = String(localized: "Plaud account disconnected.", comment: "Plaud OAuth status")
    }

    private func syncFromPreferences() {
        isPlaudEnabled = PreferencesStore.shared.isPlaudEnabled
        syncIndexPath = PreferencesStore.shared.plaudSyncIndexPath ?? ""
        exporterDataPath = PreferencesStore.shared.plaudExporterDataPath ?? ""
    }

    @MainActor
    private func refresh(force: Bool) async {
        isRefreshing = true
        defer { isRefreshing = false }

        if let appState {
            if force {
                await appState.forceRefreshPlaud()
            } else {
                appState.refreshPlaudMatchesIfNeeded()
                await appState.refreshPlaudSetup()
            }
            setup = appState.plaudSetup
            statusMessage = String(localized: "Plaud catalog refreshed.", comment: "Plaud status")
            return
        }

        if force {
            do {
                _ = try await PlaudCatalog().loadSnapshot(
                    indexPath: PreferencesStore.shared.plaudSyncIndexPath,
                    bookmarkData: PreferencesStore.shared.plaudSyncIndexBookmark
                )
                statusMessage = String(localized: "Plaud index reloaded.", comment: "Plaud status")
            } catch {
                statusMessage = error.localizedDescription
            }
        }
        refreshSetup()
    }

    private func matches(_ keywords: String...) -> Bool {
        guard !searchText.isEmpty else { return true }
        let query = searchText.lowercased()
        return keywords.contains { $0.lowercased().contains(query) || query.contains($0.lowercased()) }
    }
}
