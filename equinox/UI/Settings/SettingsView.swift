import SwiftUI

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
        .background(SettingsDesign.ColorToken.surfaceWindow)
        .searchable(text: $searchText, prompt: searchPrompt)
        .toolbarBackground(.visible, for: .windowToolbar)
        .frame(minWidth: SettingsDesign.windowMinWidth, minHeight: SettingsDesign.windowMinHeight)
        .environment(\.appState, appState)
        .onAppear {
            if let appState {
                selectedTab = appState.panel.settingsInitialTab
            }
        }
        .onChange(of: appState?.panel.settingsInitialTab) { _, newTab in
            if let newTab { selectedTab = newTab }
        }
        .onChange(of: selectedTab) { _, newTab in
            if let newTab { appState?.panel.settingsInitialTab = newTab }
        }
    }

    @ViewBuilder
    private var detailTab: some View {
        switch selectedTab ?? .general {
        case .general:
            if let appState {
                GeneralSettingsTab(searchText: searchText, appState: appState, prefs: preferencesStore)
            }
        case .calendars:
            if let appState {
                CalendarsSettingsTab(searchText: searchText, appState: appState)
            }
        case .appearance:
            AppearanceSettingsTab(searchText: searchText, prefs: preferencesStore)
        case .privacy:
            PrivacySettingsTab(searchText: searchText)
        case .shortcuts:
            ShortcutsSettingsTab(searchText: searchText)
        case .about:
            AboutSettingsTab(searchText: searchText)
        }
    }

    private var preferencesStore: PreferencesStore {
        appState?.preferences ?? PreferencesStore.shared
    }

    private var searchPrompt: String {
        let sectionTitle: String
        switch selectedTab ?? .general {
        case .general:
            sectionTitle = String(localized: "General", comment: "General prefs tab label")
        case .calendars:
            sectionTitle = String(localized: "Calendars", comment: "")
        case .appearance:
            sectionTitle = String(localized: "Appearance", comment: "Appearance prefs tab label")
        case .privacy:
            sectionTitle = String(localized: "Privacy", comment: "Privacy prefs tab label")
        case .shortcuts:
            sectionTitle = String(localized: "Shortcuts", comment: "Settings section: shortcuts")
        case .about:
            sectionTitle = String(localized: "About", comment: "About prefs tab label")
        }
        return String(
            format: String(localized: "Search %@", comment: "Settings search placeholder for current section"),
            sectionTitle
        )
    }
}
