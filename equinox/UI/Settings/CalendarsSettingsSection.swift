import SwiftUI

struct CalendarsSettingsSection: View {
    @Bindable var appState: AppState
    var filterText: String = ""
    @State private var selectedCalendarIDs: Set<String> = []

    private var entries: [CalendarListEntry] {
        appState.events.calendarEntries
    }

    var body: some View {
        let filteredEntries = filteredEntries
        return ScrollView {
            if entries.isEmpty {
                calendarListEmptyState
            } else if filteredEntries.isEmpty && !filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(
                    String(localized: "No Results", comment: "Settings search empty"),
                    systemImage: "magnifyingglass",
                    description: Text(String(localized: "Try a different search term.", comment: ""))
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, EquinoxDesign.spacingXL)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filteredEntries.enumerated()), id: \.offset) { index, item in
                        if index > 0, case .calendar = item, case .source = filteredEntries[index - 1] {
                            SettingsDivider()
                        }

                        switch item {
                        case .source(let source):
                            Text(source)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, index == 0 ? EquinoxDesign.spacingXS : EquinoxDesign.spacingMD)
                                .padding(.bottom, EquinoxDesign.spacingXS)
                        case .calendar(let calendar):
                            calendarRow(calendar)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: EquinoxDesign.settingsCalendarListMinHeight, maxHeight: EquinoxDesign.panelAgendaMaxHeight)
        .onAppear {
            reloadCalendars()
        }
        .onChange(of: appState.events.calendarEntries) { _, _ in
            reloadCalendars()
        }
    }

    private var filteredEntries: [CalendarListEntry] {
        CalendarListEntryFiltering.filter(entries, query: filterText)
    }

    @ViewBuilder
    private var calendarListEmptyState: some View {
        if !appState.events.calendarAccessStatus.isAuthorized {
            ContentUnavailableView {
                Label(
                    String(localized: "Calendar access required", comment: "Permission banner title"),
                    systemImage: "calendar.badge.exclamationmark"
                )
            } description: {
                Text(String(localized: "Enable Full Access for Equinox in System Settings.", comment: "Calendar privacy guidance"))
            } actions: {
                Button(String(localized: "Open System Settings", comment: "")) {
                    appState.openCalendarPrivacySettings()
                }
                .buttonStyle(EquinoxButtonStyle(variant: .bordered))
            }
        } else if let error = appState.events.lastFetchError {
            EquinoxBanner(
                message: error,
                style: .warning,
                actionTitle: String(localized: "Retry", comment: ""),
                action: { appState.events.retryFetchEvents() }
            )
        } else if appState.events.isFetchingEvents || !appState.events.hasCompletedInitialEventLoad {
            VStack(spacing: EquinoxDesign.spacingSM) {
                ProgressView()
                    .controlSize(.small)
                Text(String(localized: "Loading calendars", comment: "Calendar settings loading state"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        } else {
            ContentUnavailableView(
                String(localized: "No calendars available", comment: "Calendar settings empty state"),
                systemImage: "calendar.badge.minus",
                description: Text(String(localized: "No event calendars were found.", comment: "Calendar settings empty state"))
            )
        }
    }

    private func reloadCalendars() {
        selectedCalendarIDs = Set(
            entries.compactMap { entry -> String? in
                guard case .calendar(let cal) = entry, cal.isSelected else { return nil }
                return cal.id
            }
        )
    }

    private func calendarRow(_ calendar: SelectableCalendar) -> some View {
        Toggle(isOn: Binding(
            get: { selectedCalendarIDs.contains(calendar.id) },
            set: { newVal in
                if newVal {
                    selectedCalendarIDs.insert(calendar.id)
                } else {
                    selectedCalendarIDs.remove(calendar.id)
                }
                Task {
                    await appState.updateSelectedCalendar(
                        identifier: calendar.id,
                        selected: newVal
                    )
                }
            }
        )) {
            HStack(spacing: EquinoxDesign.spacingSM) {
                Circle()
                    .fill(calendar.swiftUIColor)
                    .frame(width: EquinoxDesign.ControlWidth.calendarColorDot, height: EquinoxDesign.ControlWidth.calendarColorDot)
                Text(calendar.title)
            }
        }
        .padding(.vertical, SettingsDesign.rowVerticalPadding)
    }
}
