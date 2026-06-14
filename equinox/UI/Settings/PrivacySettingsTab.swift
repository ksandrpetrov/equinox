import SwiftUI

struct PrivacySettingsTab: View {
    var searchText: String = ""
    @Environment(\.appState) private var appState

    var body: some View {
        if let appState {
            privacyContent(appState: appState)
        } else {
            SettingsDetailScaffold(title: String(localized: "Privacy", comment: "Privacy prefs tab label")) {
                SettingsFooter(text: String(localized: "App state unavailable.", comment: ""))
            }
        }
    }

    @ViewBuilder
    private func privacyContent(appState: AppState) -> some View {
        SettingsDetailScaffold(title: String(localized: "Privacy", comment: "Privacy prefs tab label")) {
            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Calendar", "access", "privacy", "permission") {
                SettingsSection(
                    String(localized: "Calendar Access", comment: "Privacy section"),
                    subtitle: String(localized: "Equinox reads events from your system calendars.", comment: "")
                ) {
                    LabeledContent {
                        HStack(spacing: EquinoxDesign.spacingXS) {
                            Image(systemName: statusSymbol(for: appState.events.calendarAccessStatus))
                                .foregroundStyle(statusColor(for: appState.events.calendarAccessStatus))
                            Text(appState.events.calendarAccessStatus.localizedLabel)
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        Text(String(localized: "Equinox app", comment: "App calendar access label"))
                    }
                    .padding(.vertical, SettingsDesign.rowVerticalPadding)
                    .accessibilityElement(children: .combine)

                    SettingsDivider()

                    SettingsFooter(
                        text: String(
                            localized: "MCP calendar tools use Equinox while it is running, so macOS applies the Equinox Calendar permission.",
                            comment: "Bridge TCC note"
                        )
                    )
                    .padding(.vertical, EquinoxDesign.spacingSM)

                    SettingsDivider()

                    HStack(spacing: EquinoxDesign.spacingMD) {
                        Button(String(localized: "Request Access", comment: "")) {
                            appState.events.requestCalendarAccessIfNeeded()
                        }
                        .buttonStyle(.borderedProminent)

                        Button(String(localized: "Open System Settings", comment: "")) {
                            appState.openCalendarPrivacySettings()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, SettingsDesign.rowVerticalPadding)
                }
            } else if !searchText.isEmpty {
                settingsSearchEmptyState
            }
        }
        .onAppear {
            Task { await appState.events.refreshCalendarAccessStatus() }
        }
    }

    private var settingsSearchEmptyState: some View {
        ContentUnavailableView(
            String(localized: "No Results", comment: "Settings search empty"),
            systemImage: "magnifyingglass",
            description: Text(String(localized: "Try a different search term.", comment: ""))
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
        case .authorized: return .green
        case .denied, .restricted: return .red
        case .notDetermined: return .orange
        }
    }
}
