import AppKit
import SwiftUI

struct PlaudSettingsTab: View {
    var searchText: String = ""
    @Environment(\.appState) private var appState
    @Bindable var prefs: PreferencesStore
    @State private var setup = PlaudConfigurator.buildSetup()
    @State private var statusMessage: String?
    @State private var oauthStatusMessage: String?
    @State private var isRefreshing = false
    @State private var isOAuthBusy = false

    var body: some View {
        SettingsDetailScaffold(title: String(localized: "Plaud", comment: "Plaud prefs tab label")) {
            if SettingsSearchFilter.matches(searchText: searchText, keywords: "enable", "integration", "plaud") {
                integrationSection
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "connect", "oauth", "account", "sign", "подключить", "отключить") {
                accountSection
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "refresh", "status", "cache", "record") {
                statusSection
            }

            Button(String(localized: "Refresh Now", comment: "Plaud manual refresh")) {
                Task { await refresh(force: true) }
            }
            .buttonStyle(EquinoxButtonStyle(variant: .bordered))
            .disabled(isRefreshing || !setup.hasKeychainOAuth)
        }
        .onAppear {
            refreshSetup()
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
                subtitle: prefs.isPlaudEnabled
                    ? String(localized: "Past meetings can show an Open in Plaud button.", comment: "")
                    : String(localized: "Turn on to link calendar events with Plaud recordings.", comment: "")
            ) {
                Toggle("", isOn: $prefs.isPlaudEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: prefs.isPlaudEnabled) { _, newValue in
                        if newValue, setup.hasKeychainOAuth {
                            Task { await refresh(force: true) }
                        } else {
                            appState?.plaud.refreshMatchesIfNeeded()
                            refreshSetup()
                        }
                    }
            }

            if prefs.isPlaudEnabled, !setup.hasKeychainOAuth {
                Text(String(
                    localized: "Connect your Plaud account below to fetch recordings.",
                    comment: "Plaud sign-in hint"
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, EquinoxDesign.spacingXS)
            }
        }
    }

    private var accountSection: some View {
        SettingsSection(
            String(localized: "Plaud Account", comment: "Plaud OAuth section"),
            subtitle: String(
                localized: "Sign in with your Plaud account to fetch recordings directly from Plaud.",
                comment: "Plaud OAuth subtitle"
            )
        ) {
            VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                statusRow(
                    label: String(localized: "Account", comment: "Plaud account status"),
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
                    .buttonStyle(EquinoxButtonStyle(variant: .prominent))
                    .disabled(isOAuthBusy)

                    Button(String(localized: "Disconnect", comment: "Plaud OAuth sign out")) {
                        Task { await disconnectPlaud() }
                    }
                    .buttonStyle(EquinoxButtonStyle(variant: .bordered))
                    .disabled(isOAuthBusy || !setup.hasKeychainOAuth)
                }

                if isOAuthBusy {
                    HStack(spacing: EquinoxDesign.spacingXS) {
                        ProgressView()
                            .controlSize(.small)
                        Text(String(
                            localized: "Waiting for Plaud sign-in in your browser…",
                            comment: "Plaud OAuth in progress"
                        ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                if let oauthStatusMessage {
                    SettingsFooter(text: oauthStatusMessage)
                }
            }
            .padding(.vertical, SettingsDesign.rowVerticalPadding)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: SettingsDesign.sectionHeaderBottomPadding) {
            SettingsSection(String(localized: "Status", comment: "Plaud status section")) {
                statusRow(
                    label: String(localized: "Recordings", comment: "Plaud recordings count"),
                    value: "\(setup.recordCount)"
                )
                if let refreshed = setup.lastRefreshAt {
                    SettingsDivider()
                    statusRow(
                        label: String(localized: "Last refreshed", comment: "Plaud catalog last refresh"),
                        value: EquinoxFormatters.formatter(key: "plaud.catalog.refreshed") {
                            $0.dateStyle = .medium
                            $0.timeStyle = .short
                        }.string(from: refreshed)
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

    private func statusRow(label: String, ready: Bool) -> some View {
        HStack {
            Image(systemName: ready ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ready ? EquinoxDesign.ColorToken.semanticGreen : .secondary)
            Text(label)
            Spacer()
            Text(ready
                ? String(localized: "Connected", comment: "Plaud account connected status")
                : String(localized: "Not connected", comment: "Plaud account not connected"))
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

    private func refreshSetup() {
        guard let appState else { return }
        Task {
            await appState.plaud.refreshSetupForSettings()
            setup = appState.plaud.setup
        }
    }

    @MainActor
    private func connectPlaud() async {
        isOAuthBusy = true
        oauthStatusMessage = nil
        defer { isOAuthBusy = false }

        do {
            try await appState?.plaud.signIn()
            refreshSetup()
            let message = String(localized: "Plaud account connected.", comment: "Plaud OAuth status")
            oauthStatusMessage = message
            statusMessage = message
            if let appState {
                await appState.plaud.forceRefresh()
                setup = appState.plaud.setup
            }
        } catch PlaudOAuthError.alreadySignedIn {
            refreshSetup()
            let message = String(
                localized: "Plaud account is already connected. Disconnect first to switch accounts.",
                comment: "Plaud OAuth already connected"
            )
            oauthStatusMessage = message
            statusMessage = message
        } catch {
            oauthStatusMessage = error.localizedDescription
            statusMessage = error.localizedDescription
            refreshSetup()
        }
    }

    @MainActor
    private func disconnectPlaud() async {
        isOAuthBusy = true
        oauthStatusMessage = nil
        defer { isOAuthBusy = false }

        await appState?.plaud.signOut()
        refreshSetup()
        let message = String(localized: "Plaud account disconnected.", comment: "Plaud OAuth status")
        oauthStatusMessage = message
        statusMessage = message
    }

    @MainActor
    private func refresh(force: Bool) async {
        isRefreshing = true
        defer { isRefreshing = false }

        guard let appState else {
            refreshSetup()
            return
        }

        if force {
            await appState.plaud.forceRefresh()
        } else {
            appState.plaud.refreshMatchesIfNeeded()
            await appState.plaud.refreshSetupForSettings()
        }
        setup = appState.plaud.setup
        statusMessage = String(localized: "Plaud catalog refreshed.", comment: "Plaud status")
    }
}
