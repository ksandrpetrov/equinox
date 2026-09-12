import SwiftUI

struct PrivacySettingsTab: View {
    var searchText: String = ""
    @Environment(\.appState) private var appState

    var body: some View {
        if let appState {
            privacyContent(appState: appState)
        } else {
            SettingsDetailScaffold(title: String(localized: "Privacy", bundle: .equinox, comment: "Privacy prefs tab label")) {
                SettingsFooter(text: String(localized: "App state unavailable.", bundle: .equinox, comment: ""))
            }
        }
    }

    @ViewBuilder
    private func privacyContent(appState: AppState) -> some View {
        SettingsDetailScaffold(title: String(localized: "Privacy", bundle: .equinox, comment: "Privacy prefs tab label")) {
            if SettingsSearchFilter.matches(
                searchText: searchText,
                keywords: "Privacy", "Calendar Access", "Request Access", "Open System Settings"
            ) {
                SettingsSection(
                    String(localized: "Calendar Access", bundle: .equinox, comment: "Privacy section"),
                    subtitle: String(localized: "Equinox reads events from your system calendars.", bundle: .equinox, comment: "")
                ) {
                    LabeledContent {
                        HStack(spacing: EquinoxDesign.spacingXS) {
                            Image(systemName: statusSymbol(for: appState.events.calendarAccessStatus))
                                .foregroundStyle(statusColor(for: appState.events.calendarAccessStatus))
                            Text(appState.events.calendarAccessStatus.localizedLabel)
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        Text(String(localized: "Equinox app", bundle: .equinox, comment: "App calendar access label"))
                    }
                    .padding(.vertical, SettingsDesign.rowVerticalPadding)
                    .accessibilityElement(children: .combine)

                    SettingsDivider()

                    HStack(spacing: EquinoxDesign.spacingMD) {
                        if appState.events.calendarAccessStatus == .notDetermined {
                            Button(String(localized: "Request Access", bundle: .equinox, comment: "")) {
                                appState.requestCalendarAccessIfNeeded()
                            }
                            .buttonStyle(EquinoxButtonStyle(variant: .prominent))
                        }

                        Button(String(localized: "Open System Settings", bundle: .equinox, comment: "")) {
                            appState.openCalendarPrivacySettings()
                        }
                        .buttonStyle(EquinoxButtonStyle(variant: .bordered))
                    }
                    .padding(.vertical, SettingsDesign.rowVerticalPadding)

                    SettingsDivider()
                    SettingsFooter(text: accessGuidance(for: appState.events.calendarAccessStatus))
                        .padding(.vertical, SettingsDesign.rowVerticalPadding)
                }
            } else if !searchText.isEmpty {
                settingsSearchEmptyState
            }
        }
        .onAppear {
            Task { await appState.refreshCalendarAccessStatus() }
        }
    }

    private var settingsSearchEmptyState: some View {
        ContentUnavailableView(
            String(localized: "No Results", bundle: .equinox, comment: "Settings search empty"),
            systemImage: "magnifyingglass",
            description: Text(String(localized: "Try a different search term.", bundle: .equinox, comment: ""))
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, EquinoxDesign.spacingXL)
    }

    private func statusSymbol(for status: CalendarAccessStatus) -> String {
        switch status {
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        case .restricted: return "lock.circle.fill"
        }
    }

    private func statusColor(for status: CalendarAccessStatus) -> Color {
        switch status {
        case .authorized: return EquinoxDesign.ColorToken.success
        case .denied, .restricted: return EquinoxDesign.ColorToken.error
        case .notDetermined: return EquinoxDesign.ColorToken.warning
        }
    }

    private func accessGuidance(for status: CalendarAccessStatus) -> String {
        switch status {
        case .authorized:
            String(localized: "Full calendar access is enabled.", bundle: .equinox, comment: "Calendar privacy guidance")
        case .notDetermined:
            String(localized: "macOS will ask you to grant Full Access.", bundle: .equinox, comment: "Calendar privacy guidance")
        case .denied:
            String(localized: "Enable Full Access for Equinox in System Settings.", bundle: .equinox, comment: "Calendar privacy guidance")
        case .restricted:
            String(localized: "Access is restricted by system policy and cannot be requested here.", bundle: .equinox, comment: "Calendar privacy guidance")
        }
    }
}
