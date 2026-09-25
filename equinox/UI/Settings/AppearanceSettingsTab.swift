import SwiftUI

struct AppearanceSettingsTab: View {
    var searchText: String = ""
    @Bindable var prefs: PreferencesStore

    private let clockFormatOptions = [
        (nil as String?, String(localized: "None", bundle: .equinox, comment: "Clock format option")),
        ("h:mm", String(localized: "12-hour", bundle: .equinox, comment: "Clock format")),
        ("HH:mm", String(localized: "24-hour", bundle: .equinox, comment: "Clock format")),
    ]

    var body: some View {
        SettingsDetailScaffold(title: String(localized: "Appearance", bundle: .equinox, comment: "Appearance prefs tab label")) {
            if showsPreview { AppearancePreview(prefs: prefs) }
            if showsTheme { themeSection }
            if showsMenuBar { menuBarSection }
            if showsCalendar { calendarSection }
            if showsAgenda { agendaSection }
            if !searchText.isEmpty && !hasVisibleSections { settingsSearchEmptyState }
        }
    }

    private var themeSection: some View {
        SettingsSection(String(localized: "Theme", bundle: .equinox, comment: "")) {
            SettingsRow(title: String(localized: "Appearance", bundle: .equinox, comment: "Appearance setting")) {
                SettingsSegmentedPicker(
                    label: String(localized: "Appearance", bundle: .equinox, comment: "Appearance setting"),
                    options: [
                        String(localized: "System", bundle: .equinox, comment: "Appearance option"),
                        String(localized: "Light", bundle: .equinox, comment: "Appearance option"),
                        String(localized: "Dark", bundle: .equinox, comment: "Appearance option")
                    ],
                    selection: $prefs.themePreference
                )
                .fixedSize()
            }
            SettingsDivider()
            SettingsRow(title: String(localized: "Background", bundle: .equinox, comment: "Appearance setting")) {
                SettingsSegmentedPicker(
                    label: String(localized: "Background", bundle: .equinox, comment: "Appearance setting"),
                    options: [
                        String(localized: "Glass", bundle: .equinox, comment: "Appearance option"),
                        String(localized: "Solid", bundle: .equinox, comment: "Appearance option")
                    ],
                    selection: $prefs.backgroundStyle
                )
                .fixedSize()
            }
            SettingsDivider()
            SettingsRow(title: String(localized: "Size", bundle: .equinox, comment: "Appearance setting")) {
                SettingsSegmentedPicker(
                    label: String(localized: "Size", bundle: .equinox, comment: "Appearance setting"),
                    options: [
                        String(localized: "Small", bundle: .equinox, comment: "Appearance option"),
                        String(localized: "Medium", bundle: .equinox, comment: "Appearance option"),
                        String(localized: "Large", bundle: .equinox, comment: "Appearance option")
                    ],
                    selection: $prefs.sizePreference
                )
                .fixedSize()
            }
        }
    }

    private var menuBarSection: some View {
        SettingsSection(String(localized: "Menu Bar", bundle: .equinox, comment: "")) {
            VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                Text(String(localized: "Menu Bar Icon", bundle: .equinox, comment: "Settings section: menu bar icon"))
                    .font(.body)
                MenuBarIconPicker(prefs: prefs)
            }
            .padding(.vertical, SettingsDesign.rowVerticalPadding)
            SettingsDivider()
            SettingsLabeledToggle(
                title: String(localized: "Show month in icon", bundle: .equinox, comment: "Appearance setting"),
                isOn: $prefs.showMonthInIcon
            )
            SettingsDivider()
            SettingsLabeledToggle(
                title: String(localized: "Show day of week in icon", bundle: .equinox, comment: "Appearance setting"),
                isOn: $prefs.showDayOfWeekInIcon
            )
            SettingsDivider()
            SettingsLabeledToggle(
                title: String(localized: "Hide date icon", bundle: .equinox, comment: "Appearance setting"),
                subtitle: String(localized: "Keep the clock and meeting indicator when enabled", bundle: .equinox, comment: "Menu bar hidden date setting"),
                isOn: $prefs.isIconHidden
            )
            SettingsDivider()
            SettingsLabeledToggle(
                title: String(localized: "Show meeting indicator", bundle: .equinox, comment: "Appearance setting"),
                subtitle: String(localized: "Camera icon when a meeting is starting soon", bundle: .equinox, comment: "Meeting indicator toggle subtitle"),
                isOn: $prefs.showMeetingIndicator
            )
            SettingsDivider()
            SettingsRow(title: String(localized: "Clock format", bundle: .equinox, comment: "")) {
                Picker(String(localized: "Clock format", bundle: .equinox, comment: ""), selection: clockFormatBinding) {
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
        SettingsSection(String(localized: "Calendar Display", bundle: .equinox, comment: "Settings calendar display section")) {
            SettingsRow(title: String(localized: "First day of week:", bundle: .equinox, comment: "")) {
                Picker(String(localized: "First day of week", bundle: .equinox, comment: ""), selection: Binding(
                    get: { prefs.weekStartWeekday },
                    set: { prefs.weekStartWeekday = $0 }
                )) {
                    Text(String(localized: "Sunday", bundle: .equinox, comment: "")).tag(0)
                    Text(String(localized: "Monday", bundle: .equinox, comment: "")).tag(1)
                    Text(String(localized: "Tuesday", bundle: .equinox, comment: "")).tag(2)
                    Text(String(localized: "Wednesday", bundle: .equinox, comment: "")).tag(3)
                    Text(String(localized: "Thursday", bundle: .equinox, comment: "")).tag(4)
                    Text(String(localized: "Friday", bundle: .equinox, comment: "")).tag(5)
                    Text(String(localized: "Saturday", bundle: .equinox, comment: "")).tag(6)
                }
                .labelsHidden()
                .frame(width: EquinoxDesign.ControlWidth.settingsPicker)
            }
            SettingsDivider()
            SettingsLabeledToggle(
                title: String(localized: "Show event dots", bundle: .equinox, comment: "Appearance setting"),
                isOn: $prefs.showEventDots
            )
            SettingsDivider()
            SettingsLabeledToggle(
                title: String(localized: "Show calendar weeks", bundle: .equinox, comment: "Appearance setting"),
                isOn: $prefs.showWeeks
            )
            SettingsDivider()
            SettingsLabeledToggle(
                title: String(localized: "Show month boundaries", bundle: .equinox, comment: "Appearance setting"),
                isOn: $prefs.showMonthBoundaries
            )
            SettingsDivider()
            SettingsRow(title: String(localized: "Calendar rows", bundle: .equinox, comment: "Number of rows in month grid")) {
                Stepper(value: $prefs.calendarRowCount, in: 6...10) {
                    Text("\(prefs.calendarRowCount)")
                        .monospacedDigit()
                        .frame(width: EquinoxDesign.ControlWidth.trailingLabel, alignment: .trailing)
                }
            }
            SettingsDivider()
            VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                Text(String(localized: "Highlight days", bundle: .equinox, comment: "Weekend highlight picker label"))
                WeekendHighlightPicker(preferences: prefs)
            }
            .padding(.vertical, SettingsDesign.rowVerticalPadding)
        }
    }

    private var agendaSection: some View {
        SettingsSection(String(localized: "Agenda", bundle: .equinox, comment: "Agenda section label")) {
            SettingsLabeledToggle(
                title: String(localized: "Show agenda", bundle: .equinox, comment: "Agenda visibility setting"),
                isOn: $prefs.showsAgenda
            )
            Group {
                SettingsDivider()
                SettingsLabeledToggle(
                    title: String(localized: "Show event location", bundle: .equinox, comment: "Appearance setting"),
                    isOn: $prefs.showLocation
                )
                SettingsDivider()
                SettingsLabeledToggle(
                    title: String(localized: "Show days with no events", bundle: .equinox, comment: "Appearance setting"),
                    isOn: $prefs.showDaysWithNoEvents
                )
                SettingsDivider()
                SettingsRow(title: String(localized: "Agenda height", bundle: .equinox, comment: "")) {
                    Slider(value: $prefs.agendaHeightRatio, in: AgendaLayout.defaultHeightRatio...AgendaLayout.maximumHeightRatio)
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
            String(localized: "No Results", bundle: .equinox, comment: "Settings search empty"),
            systemImage: "magnifyingglass",
            description: Text(String(localized: "Try a different search term.", bundle: .equinox, comment: ""))
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, EquinoxDesign.spacingXL)
    }
}
