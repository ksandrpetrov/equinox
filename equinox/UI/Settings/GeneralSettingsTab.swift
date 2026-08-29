import AppKit
import SwiftUI

struct GeneralSettingsTab: View {
    var searchText: String = ""
    @Bindable var appState: AppState
    @Bindable var prefs: PreferencesStore
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginMessage: String?
    @State private var launchAtLoginMessageIsError = false
    @State private var showResetConfirmation = false

    var body: some View {
        SettingsDetailScaffold(title: String(localized: "General", comment: "General prefs tab label")) {
            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Startup", "Launch at login", "Open Equinox when you sign in") {
                SettingsSection(String(localized: "Startup", comment: "Settings section: startup")) {
                    SettingsLabeledToggle(
                        title: String(localized: "Launch at login", comment: ""),
                        subtitle: String(localized: "Open Equinox when you sign in", comment: "Launch at login subtitle"),
                        isOn: Binding(
                            get: { launchAtLogin },
                            set: { updateLaunchAtLogin($0) }
                        )
                    )
                    if let launchAtLoginMessage {
                        SettingsFooter(
                            text: launchAtLoginMessage,
                            style: launchAtLoginMessageIsError ? .error : .secondary
                        )
                        .padding(.bottom, SettingsDesign.rowVerticalPadding)
                    }
                }
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Calendar", "First day of week:", "Show agenda") {
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
                        .frame(width: EquinoxDesign.ControlWidth.settingsPicker)
                    }

                    SettingsDivider()

                    SettingsLabeledToggle(
                        title: String(localized: "Show agenda", comment: "Agenda visibility setting"),
                        subtitle: String(localized: "Show the event timeline below the calendar", comment: "Agenda visibility subtitle"),
                        isOn: $prefs.showsAgenda
                    )
                }
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Panel", "Pin panel by default", "Agenda height") {
                SettingsSection(String(localized: "Panel", comment: "Panel settings section")) {
                    SettingsLabeledToggle(
                        title: String(localized: "Pin panel by default", comment: ""),
                        subtitle: String(localized: "Keep the calendar panel open as a floating window", comment: ""),
                        isOn: Binding(
                            get: { appState.isPinned },
                            set: { appState.setPinned($0) }
                        )
                    )

                    SettingsDivider()

                    SettingsRow(
                        title: String(localized: "Agenda height", comment: ""),
                        subtitle: String(localized: "Default proportion of the agenda section", comment: "")
                    ) {
                        Slider(
                            value: $prefs.agendaHeightRatio,
                            in: AgendaLayout.minimumHeightRatio...AgendaLayout.maximumHeightRatio
                        )
                            .frame(width: EquinoxDesign.ControlWidth.settingsPicker)
                    }
                    .disabled(!prefs.showsAgenda)
                    .opacity(prefs.showsAgenda ? 1 : EquinoxDesign.StateOpacity.disabled)
                }
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Advanced", "Reset", "Reset All Settings to Defaults") {
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
                    Task {
                        let resetError = await appState.resetPreferencesToDefaults()
                        launchAtLogin = LaunchAtLogin.isEnabled
                        launchAtLoginMessage = resetError
                        launchAtLoginMessageIsError = resetError != nil
                        showResetConfirmation = false
                    }
                },
                onCancel: {
                    showResetConfirmation = false
                }
            )
            .equinoxSheetPresentation()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin = LaunchAtLogin.isEnabled
            if launchAtLogin {
                launchAtLoginMessage = nil
                launchAtLoginMessageIsError = false
            }
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginMessage = nil
        launchAtLoginMessageIsError = false
        do {
            let status = try LaunchAtLogin.setEnabled(enabled)
            launchAtLogin = status == .enabled
            if enabled, status == .requiresApproval {
                launchAtLoginMessage = String(
                    localized: "Allow Equinox in System Settings → General → Login Items.",
                    comment: "Launch at login approval guidance"
                )
            }
        } catch {
            launchAtLogin = LaunchAtLogin.isEnabled
            launchAtLoginMessageIsError = true
            launchAtLoginMessage = String(
                format: String(localized: "Could not update Launch at Login: %@", comment: "Launch at login error"),
                error.localizedDescription
            )
        }
    }

    private var hasVisibleSections: Bool {
        SettingsSearchFilter.matches(searchText: searchText, keywords: "Startup", "Launch at login", "Open Equinox when you sign in")
            || SettingsSearchFilter.matches(searchText: searchText, keywords: "Calendar", "First day of week:", "Show agenda")
            || SettingsSearchFilter.matches(searchText: searchText, keywords: "Panel", "Pin panel by default", "Agenda height")
            || SettingsSearchFilter.matches(searchText: searchText, keywords: "Advanced", "Reset", "Reset All Settings to Defaults")
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
