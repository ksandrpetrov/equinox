import SwiftUI

struct AppearanceSettingsTab: View {
    var searchText: String = ""
    @Bindable var prefs: PreferencesStore

    private let clockFormatOptions = [
        (nil as String?, String(localized: "None", comment: "Clock format option")),
        ("h:mm", String(localized: "12-hour", comment: "Clock format")),
        ("HH:mm", String(localized: "24-hour", comment: "Clock format")),
    ]

    var body: some View {
        SettingsDetailScaffold(title: String(localized: "Appearance", comment: "Appearance prefs tab label")) {
            if showsPreview { AppearancePreview(prefs: prefs) }
            if showsTheme { themeSection }
            if showsMenuBar { menuBarSection }
            if showsCalendar { calendarSection }
            if showsAgenda { agendaSection }
            if !searchText.isEmpty && !hasVisibleSections { settingsSearchEmptyState }
        }
    }

    private var themeSection: some View {
        SettingsSection(String(localized: "Theme", comment: "")) {
            SettingsRow(title: String(localized: "Appearance", comment: "Appearance setting")) {
                SettingsSegmentedPicker(
                    label: String(localized: "Appearance", comment: "Appearance setting"),
                    options: [
                        String(localized: "System", comment: "Appearance option"),
                        String(localized: "Light", comment: "Appearance option"),
                        String(localized: "Dark", comment: "Appearance option")
                    ],
                    selection: $prefs.themePreference
                )
                .frame(width: EquinoxDesign.ControlWidth.settingsPicker)
            }
            SettingsDivider()
            SettingsRow(title: String(localized: "Background", comment: "Appearance setting")) {
                SettingsSegmentedPicker(
                    label: String(localized: "Background", comment: "Appearance setting"),
                    options: [
                        String(localized: "Glass", comment: "Appearance option"),
                        String(localized: "Solid", comment: "Appearance option")
                    ],
                    selection: $prefs.backgroundStyle
                )
                .frame(width: EquinoxDesign.ControlWidth.settingsPicker)
            }
            SettingsDivider()
            SettingsRow(title: String(localized: "Size", comment: "Appearance setting")) {
                SettingsSegmentedPicker(
                    label: String(localized: "Size", comment: "Appearance setting"),
                    options: [
                        String(localized: "Small", comment: "Appearance option"),
                        String(localized: "Medium", comment: "Appearance option"),
                        String(localized: "Large", comment: "Appearance option")
                    ],
                    selection: $prefs.sizePreference
                )
                .frame(width: EquinoxDesign.ControlWidth.settingsPicker)
            }
        }
    }

    private var menuBarSection: some View {
        SettingsSection(String(localized: "Menu Bar", comment: "")) {
            VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                Text(String(localized: "Menu Bar Icon", comment: "Settings section: menu bar icon"))
                    .font(.body)
                MenuBarIconPicker(prefs: prefs)
            }
            .padding(.vertical, SettingsDesign.rowVerticalPadding)
            SettingsDivider()
            SettingsLabeledToggle(
                title: String(localized: "Show month in icon", comment: "Appearance setting"),
                isOn: $prefs.showMonthInIcon
            )
            SettingsDivider()
            SettingsLabeledToggle(
                title: String(localized: "Show day of week in icon", comment: "Appearance setting"),
                isOn: $prefs.showDayOfWeekInIcon
            )
            SettingsDivider()
            SettingsLabeledToggle(
                title: String(localized: "Hide date icon", comment: "Appearance setting"),
                subtitle: String(localized: "Keep the clock and meeting indicator when enabled", comment: "Menu bar hidden date setting"),
                isOn: $prefs.isIconHidden
            )
            SettingsDivider()
            SettingsLabeledToggle(
                title: String(localized: "Show meeting indicator", comment: "Appearance setting"),
                subtitle: String(localized: "Camera icon when a meeting is starting soon", comment: "Meeting indicator toggle subtitle"),
                isOn: $prefs.showMeetingIndicator
            )
            SettingsDivider()
            SettingsRow(title: String(localized: "Clock format", comment: "")) {
                Picker(String(localized: "Clock format", comment: ""), selection: clockFormatBinding) {
                    ForEach(clockFormatOptions.indices, id: \.self) { i in
                        Text(clockFormatOptions[i].1).tag(i)
                    }
                }
                .labelsHidden()
                .frame(width: EquinoxDesign.ControlWidth.settingsPicker)
            }
        }
    }

    private var calendarSection: some View {
        SettingsSection(String(localized: "Calendar Display", comment: "Settings calendar display section")) {
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
                title: String(localized: "Show event dots", comment: "Appearance setting"),
                isOn: $prefs.showEventDots
            )
            SettingsDivider()
            SettingsLabeledToggle(
                title: String(localized: "Show calendar weeks", comment: "Appearance setting"),
                isOn: $prefs.showWeeks
            )
            SettingsDivider()
            SettingsLabeledToggle(
                title: String(localized: "Show month boundaries", comment: "Appearance setting"),
                isOn: $prefs.showMonthBoundaries
            )
            SettingsDivider()
            SettingsRow(title: String(localized: "Calendar rows", comment: "Number of rows in month grid")) {
                Stepper(value: $prefs.calendarRowCount, in: 6...10) {
                    Text("\(prefs.calendarRowCount)")
                        .monospacedDigit()
                        .frame(width: EquinoxDesign.ControlWidth.trailingLabel, alignment: .trailing)
                }
            }
            SettingsDivider()
            VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                Text(String(localized: "Highlight days", comment: "Weekend highlight picker label"))
                WeekendHighlightPicker(preferences: prefs)
            }
            .padding(.vertical, SettingsDesign.rowVerticalPadding)
        }
    }

    private var agendaSection: some View {
        SettingsSection(String(localized: "Agenda", comment: "Agenda section label")) {
            SettingsLabeledToggle(
                title: String(localized: "Show agenda", comment: "Agenda visibility setting"),
                isOn: $prefs.showsAgenda
            )
            Group {
                SettingsDivider()
                SettingsLabeledToggle(
                    title: String(localized: "Show event location", comment: "Appearance setting"),
                    isOn: $prefs.showLocation
                )
                SettingsDivider()
                SettingsLabeledToggle(
                    title: String(localized: "Show days with no events", comment: "Appearance setting"),
                    isOn: $prefs.showDaysWithNoEvents
                )
                SettingsDivider()
                SettingsRow(title: String(localized: "Agenda height", comment: "")) {
                    Slider(value: $prefs.agendaHeightRatio, in: AgendaLayout.minimumHeightRatio...AgendaLayout.maximumHeightRatio)
                        .frame(width: EquinoxDesign.ControlWidth.settingsPicker)
                }
            }
            .disabled(!prefs.showsAgenda)
        }
    }

    private var showsPreview: Bool {
        SettingsSearchFilter.matches(searchText: searchText, keywords: "Preview", "Appearance")
    }
    private var showsTheme: Bool {
        SettingsSearchFilter.matches(searchText: searchText, keywords: "Theme", "Appearance", "Background", "Size", "Glass", "Solid", "System", "Light", "Dark", "Small", "Medium", "Large")
    }
    private var showsMenuBar: Bool {
        SettingsSearchFilter.matches(searchText: searchText, keywords: "Menu Bar", "Menu Bar Icon", "Show month in icon", "Show day of week in icon", "Hide date icon", "Show meeting indicator", "Clock format")
    }
    private var showsCalendar: Bool {
        SettingsSearchFilter.matches(searchText: searchText, keywords: "Calendar Display", "First day of week:", "Show event dots", "Show calendar weeks", "Show month boundaries", "Calendar rows", "Highlight days")
    }
    private var showsAgenda: Bool {
        SettingsSearchFilter.matches(searchText: searchText, keywords: "Agenda", "Show agenda", "Agenda height", "Show event location", "Show days with no events")
    }
    private var hasVisibleSections: Bool {
        showsPreview || showsTheme || showsMenuBar || showsCalendar || showsAgenda
    }

    private var clockFormatBinding: Binding<Int> {
        Binding(
            get: {
                let current = prefs.clockFormat
                return clockFormatOptions.firstIndex { $0.0 == current } ?? 0
            },
            set: { index in
                prefs.clockFormat = clockFormatOptions[index].0
            }
        )
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
