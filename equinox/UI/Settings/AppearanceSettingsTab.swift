import SwiftUI

struct AppearanceSettingsTab: View {
    var searchText: String = ""
    @Bindable private var prefs = PreferencesStore.shared

    private let clockFormatOptions = [
        (nil as String?, String(localized: "None", comment: "Clock format option")),
        ("h:mm", String(localized: "12-hour", comment: "Clock format")),
        ("HH:mm", String(localized: "24-hour", comment: "Clock format")),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Preview", "Appearance") {
                AppearancePreview(prefs: prefs)
                    .padding(SettingsDesign.detailPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background)
                Divider()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: SettingsDesign.sectionSpacing) {
                    settingsSections

                    if !searchText.isEmpty && !hasVisibleSections {
                        settingsSearchEmptyState
                    }
                }
                .padding(SettingsDesign.detailPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .settingsToolbarScrollWorkaround()
        }
        .navigationTitle(String(localized: "Appearance", comment: "Appearance prefs tab label"))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var settingsSections: some View {
            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Menu Bar", "icon", "month", "meeting", "clock", "hide") {
                SettingsSection(String(localized: "Menu Bar", comment: "")) {
                    VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                        Text(String(localized: "Menu Bar Icon", comment: "Settings section: menu bar icon"))
                            .font(.subheadline.weight(.semibold))
                        MenuBarIconPicker(selection: Binding(
                            get: { prefs.menuBarIconType },
                            set: { prefs.menuBarIconType = $0 }
                        ))
                    }
                    .padding(.vertical, EquinoxDesign.spacingSM)

                    SettingsDivider()

                    SettingsLabeledToggle(
                        title: String(localized: "Show month in icon", comment: ""),
                        isOn: $prefs.showMonthInIcon
                    )
                    SettingsDivider()
                    SettingsLabeledToggle(
                        title: String(localized: "Show day of week in icon", comment: ""),
                        isOn: $prefs.showDayOfWeekInIcon
                    )
                }

                SettingsSection(
                    String(localized: "Menu Bar (Advanced)", comment: ""),
                    subtitle: String(localized: "Additional menu bar options", comment: "")
                ) {
                    SettingsLabeledToggle(
                        title: String(localized: "Hide menu bar icon", comment: ""),
                        subtitle: String(localized: "Access Equinox via keyboard shortcut only", comment: ""),
                        isOn: $prefs.isIconHidden
                    )
                    SettingsDivider()
                    SettingsLabeledToggle(
                        title: String(localized: "Show meeting indicator", comment: ""),
                        subtitle: String(localized: "Dot when a meeting is starting soon", comment: ""),
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
                        .frame(width: 140)
                    }
                }
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Calendar", "dots", "week", "weekend", "boundary", "location", "events", "hover") {
                SettingsSection(
                    String(localized: "Calendar Display", comment: "Settings calendar display section"),
                    subtitle: String(localized: "Customize the calendar grid and agenda", comment: "")
                ) {
                    SettingsLabeledToggle(
                        title: String(localized: "Show event dots", comment: ""),
                        isOn: $prefs.showEventDots
                    )
                    SettingsDivider()
                    SettingsLabeledToggle(
                        title: String(localized: "Show calendar weeks", comment: ""),
                        isOn: $prefs.showWeeks
                    )
                    SettingsDivider()
                    SettingsLabeledToggle(
                        title: String(localized: "Show event location", comment: ""),
                        isOn: $prefs.showLocation
                    )
                    SettingsDivider()
                    SettingsLabeledToggle(
                        title: String(localized: "Show days with no events", comment: ""),
                        isOn: $prefs.showDaysWithNoEvents
                    )
                    SettingsDivider()
                    SettingsLabeledToggle(
                        title: String(localized: "Show month boundaries", comment: "Positive phrasing for month outline"),
                        isOn: $prefs.showMonthBoundaries
                    )
                    SettingsDivider()

                    VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                        Text(String(localized: "Highlight days", comment: "Weekend highlight picker label"))
                            .font(.body)
                        WeekendHighlightPicker()
                    }
                    .padding(.vertical, SettingsDesign.rowVerticalPadding)
                }
            }

            if SettingsSearchFilter.matches(searchText: searchText, keywords: "Theme", "Appearance", "Background", "Size", "Glass", "Light", "Dark") {
                SettingsSection(String(localized: "Theme", comment: "")) {
                    VStack(alignment: .leading, spacing: EquinoxDesign.spacingMD) {
                        Text(String(localized: "Appearance", comment: ""))
                            .font(.body)
                        SettingsSegmentedPicker(
                            label: String(localized: "Appearance", comment: ""),
                            options: [
                                String(localized: "System", comment: ""),
                                String(localized: "Light", comment: ""),
                                String(localized: "Dark", comment: "")
                            ],
                            selection: $prefs.themePreference
                        )

                        Text(String(localized: "Background", comment: ""))
                            .font(.body)
                        SettingsSegmentedPicker(
                            label: String(localized: "Background", comment: ""),
                            options: [
                                String(localized: "Glass", comment: ""),
                                String(localized: "Solid", comment: "")
                            ],
                            selection: $prefs.backgroundStyle
                        )

                        Text(String(localized: "Size", comment: ""))
                            .font(.body)
                        SettingsSegmentedPicker(
                            label: String(localized: "Size", comment: ""),
                            options: [
                                String(localized: "Small", comment: ""),
                                String(localized: "Medium", comment: ""),
                                String(localized: "Large", comment: "")
                            ],
                            selection: $prefs.sizePreference
                        )
                    }
                    .padding(.vertical, SettingsDesign.rowVerticalPadding)
                }
            }
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

    private var hasVisibleSections: Bool {
        SettingsSearchFilter.matches(searchText: searchText, keywords: "Menu Bar", "icon", "month", "meeting", "clock", "hide")
            || SettingsSearchFilter.matches(searchText: searchText, keywords: "Calendar", "dots", "week", "weekend", "boundary", "location", "events", "hover")
            || SettingsSearchFilter.matches(searchText: searchText, keywords: "Theme", "Appearance", "Background", "Size", "Glass", "Light", "Dark")
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
