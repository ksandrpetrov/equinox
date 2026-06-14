import SwiftUI

enum SettingsTab: Hashable {
    case general
    case calendars
    case appearance
    case privacy
    case shortcuts
    case mcp
    case plaud
    case about
}

private struct AppStateEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppState? = nil
}

extension EnvironmentValues {
    var appState: AppState? {
        get { self[AppStateEnvironmentKey.self] }
        set { self[AppStateEnvironmentKey.self] = newValue }
    }
}

struct SettingsView: View {
    @Environment(\.appState) private var appState
    @State private var selectedTab: SettingsTab?
    @State private var searchText = ""

    init(initialTab: SettingsTab = .general) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                SettingsSidebarLabel(
                    title: String(localized: "General", comment: "General prefs tab label"),
                    symbol: "gearshape"
                )
                .tag(SettingsTab.general)

                SettingsSidebarLabel(
                    title: String(localized: "Calendars", comment: ""),
                    symbol: "calendar"
                )
                .tag(SettingsTab.calendars)

                SettingsSidebarLabel(
                    title: String(localized: "Appearance", comment: "Appearance prefs tab label"),
                    symbol: "paintpalette"
                )
                .tag(SettingsTab.appearance)

                SettingsSidebarLabel(
                    title: String(localized: "Privacy", comment: "Privacy prefs tab label"),
                    symbol: "hand.raised"
                )
                .tag(SettingsTab.privacy)

                SettingsSidebarLabel(
                    title: String(localized: "Shortcuts", comment: "Settings section: shortcuts"),
                    symbol: "command"
                )
                .tag(SettingsTab.shortcuts)

                SettingsSidebarLabel(
                    title: String(localized: "MCP", comment: "MCP prefs tab label"),
                    symbol: "puzzlepiece.extension"
                )
                .tag(SettingsTab.mcp)

                SettingsSidebarLabel(
                    title: String(localized: "Plaud", comment: "Plaud prefs tab label"),
                    symbol: "waveform"
                )
                .tag(SettingsTab.plaud)

                SettingsSidebarLabel(
                    title: String(localized: "About", comment: "About prefs tab label"),
                    symbol: "info.circle"
                )
                .tag(SettingsTab.about)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(
                min: SettingsDesign.sidebarWidth,
                ideal: SettingsDesign.sidebarWidth
            )
            .settingsToolbarScrollWorkaround()
        } detail: {
            NavigationStack {
                detailTab
            }
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $searchText, prompt: String(localized: "Search settings", comment: "Settings search placeholder"))
        .toolbarBackground(.visible, for: .windowToolbar)
        .frame(minWidth: 720, minHeight: 560)
        .environment(\.appState, appState)
        .onAppear {
            if let appState {
                selectedTab = appState.settingsInitialTab
            }
        }
        .onChange(of: appState?.settingsInitialTab) { _, newTab in
            if let newTab { selectedTab = newTab }
        }
    }

    @ViewBuilder
    private var detailTab: some View {
        switch selectedTab ?? .general {
        case .general:
            GeneralSettingsTab(searchText: searchText)
        case .calendars:
            CalendarsSettingsTab(searchText: searchText)
        case .appearance:
            AppearanceSettingsTab(searchText: searchText)
        case .privacy:
            PrivacySettingsTab(searchText: searchText)
        case .shortcuts:
            ShortcutsSettingsTab()
        case .mcp:
            McpSettingsTab(searchText: searchText)
        case .plaud:
            PlaudSettingsTab(searchText: searchText)
        case .about:
            AboutSettingsTab()
        }
    }
}
