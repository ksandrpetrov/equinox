import SwiftUI

struct CalendarsSettingsSection: View {
    @Bindable var appState: AppState
    var filterText: String = ""
    @State private var selectedCalendarIDs: Set<String> = []

    private var entries: [CalendarListEntry] {
        appState.events.calendarEntries
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(filteredEntries.enumerated()), id: \.offset) { index, item in
                    if index > 0, case .calendar = item, case .source = filteredEntries[index - 1] {
                        SettingsDivider()
                    }

                    switch item {
                    case .source(let source):
                        Text(NSLocalizedString(source, comment: "Calendar source/account name"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, index == 0 ? 4 : 12)
                            .padding(.bottom, 4)
                    case .calendar(let calendar):
                        calendarRow(calendar)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 200, maxHeight: 400)
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
                    await appState.events.updateSelectedCalendar(
                        identifier: calendar.id,
                        selected: newVal
                    )
                }
            }
        )) {
            HStack(spacing: 8) {
                Circle()
                    .fill(calendar.swiftUIColor)
                    .frame(width: 10, height: 10)
                Text(calendar.title)
            }
        }
        .padding(.vertical, SettingsDesign.rowVerticalPadding)
    }
}
