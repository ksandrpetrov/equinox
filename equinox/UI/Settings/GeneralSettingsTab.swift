import SwiftUI

struct GeneralSettingsTab: View {
    var searchText: String = ""
    @Bindable private var prefs = PreferencesStore.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var showResetConfirmation = false

    var body: some View {
        SettingsDetailScaffold(title: String(localized: "General", comment: "General prefs tab label")) {
            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Startup", "Launch") {
                SettingsSection(String(localized: "Startup", comment: "Settings section: startup")) {
                    SettingsLabeledToggle(
                        title: String(localized: "Launch at login", comment: ""),
                        subtitle: String(localized: "Open Equinox when you sign in", comment: "Launch at login subtitle"),
                        isOn: $launchAtLogin
                    )
                    .onChange(of: launchAtLogin) { _, v in LaunchAtLogin.setEnabled(v) }
                }
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Calendar", "week", "event", "list") {
                SettingsSection(String(localized: "Calendar", comment: "Settings section: calendar")) {
                    SettingsRow(title: String(localized: "First day of week:", comment: "")) {
                        Picker(String(localized: "First day of week", comment: ""), selection: Binding(
                            get: { prefs.weekStartWeekday },
                            set: { prefs.weekStartWeekday = $0 }
                        )) {
                            Text(String(localized: "Sunday", comment: "")).tag(0)
                            Text(String(localized: "Monday", comment: "")).tag(1)
                            Text(String(localized: "Tuesday", comment: "")).tag(2)
                            Text(String(localized: "Wednesday", comment: "")).tag(3)
                            Text(String(localized: "Thursday", comment: "")).tag(4)
                            Text(String(localized: "Friday", comment: "")).tag(5)
                            Text(String(localized: "Saturday", comment: "")).tag(6)
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }

                    SettingsDivider()

                    SettingsRow(title: String(localized: "Event list shows:", comment: "")) {
                        Picker(String(localized: "Event list shows", comment: ""), selection: Binding(
                            get: { prefs.showEventDays },
                            set: { prefs.showEventDays = $0 }
                        )) {
                            ForEach(0...9, id: \.self) { days in
                                if days == 0 {
                                    Text(String(localized: "No events", comment: "")).tag(days)
                                } else {
                                    Text("\(days) \(days == 1 ? String(localized: "day", comment: "") : String(localized: "days", comment: ""))").tag(days)
                                }
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }
                }
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Panel", "pin", "agenda") {
                SettingsSection(String(localized: "Panel", comment: "Panel settings section")) {
                    SettingsLabeledToggle(
                        title: String(localized: "Pin panel by default", comment: ""),
                        subtitle: String(localized: "Keep the calendar panel open as a floating window", comment: ""),
                        isOn: $prefs.isPanelPinned
                    )

                    SettingsDivider()

                    SettingsRow(
                        title: String(localized: "Agenda height", comment: ""),
                        subtitle: String(localized: "Default proportion of the agenda section", comment: "")
                    ) {
                        Slider(value: $prefs.agendaHeightRatio, in: 0.15...0.65)
                            .frame(width: 160)
                    }
                }
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Reset", "defaults", "factory") {
                SettingsSection(String(localized: "Advanced", comment: "")) {
                    Button(String(localized: "Reset All Settings to Defaults", comment: ""), role: .destructive) {
                        showResetConfirmation = true
                    }
                    .padding(.vertical, SettingsDesign.rowVerticalPadding)
                }
            }

            if !searchText.isEmpty && !hasVisibleSections {
                settingsSearchEmptyState
            }
        }
        .sheet(isPresented: $showResetConfirmation) {
            ModalConfirmDialog(
                title: String(localized: "Reset all settings?", comment: ""),
                message: String(localized: "This restores all preferences to their default values.", comment: ""),
                confirmTitle: String(localized: "Reset", comment: ""),
                onConfirm: {
                    prefs.resetToDefaults()
                    launchAtLogin = LaunchAtLogin.isEnabled
                    showResetConfirmation = false
                },
                onCancel: {
                    showResetConfirmation = false
                }
            )
            .equinoxSheetPresentation()
        }
    }

    private var hasVisibleSections: Bool {
        SettingsSearchFilter.matches(searchText: searchText, keywords: "Startup", "Launch")
            || SettingsSearchFilter.matches(searchText: searchText, keywords: "Calendar", "week", "event", "list")
            || SettingsSearchFilter.matches(searchText: searchText, keywords: "Panel", "pin", "agenda")
            || SettingsSearchFilter.matches(searchText: searchText, keywords: "Reset", "defaults", "factory")
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
}
