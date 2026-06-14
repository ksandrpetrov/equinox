import SwiftUI

struct NewEventSheet: View {
    @Bindable var appState: AppState
    let metrics: SizeMetrics
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case title
    }

    @State private var title = ""
    @State private var location = ""
    @State private var urlString = ""
    @State private var notes = ""
    @State private var isAllDay = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var recurrenceIndex = 0
    @State private var recurrenceEndIndex = 0
    @State private var recurrenceEndDate = Date()
    @State private var alertIndex = 0
    @State private var selectedCalendarIndex = 0
    @State private var showLocationSection = false
    @State private var showRepeatSection = false
    @State private var showAlertSection = false
    @State private var showNotesSection = false
    @State private var saveError: String?

    private let recurrenceOptions = [
        String(localized: "None", comment: "Recurrence"),
        String(localized: "Every Day", comment: ""),
        String(localized: "Every Week", comment: ""),
        String(localized: "Every 2 Weeks", comment: ""),
        String(localized: "Every Month", comment: ""),
        String(localized: "Every Year", comment: "")
    ]

    private let recurrenceEndOptions = [
        String(localized: "Never", comment: ""),
        String(localized: "On date", comment: "")
    ]

    private let regularAlerts = [
        String(localized: "None", comment: "Alert"),
        String(localized: "At time of event", comment: ""),
        String(localized: "5 minutes before", comment: ""),
        String(localized: "10 minutes before", comment: ""),
        String(localized: "15 minutes before", comment: ""),
        String(localized: "30 minutes before", comment: ""),
        String(localized: "1 hour before", comment: ""),
        String(localized: "2 hours before", comment: ""),
        String(localized: "1 day before", comment: ""),
        String(localized: "2 days before", comment: "")
    ]

    var body: some View {
        ModalSheetScaffold(
            title: String(localized: "New Event", comment: ""),
            metrics: metrics,
            confirmTitle: String(localized: "Add", comment: ""),
            confirmDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasModifiableCalendars,
            onCancel: { close() },
            onConfirm: { save() }
        ) {
            VStack(spacing: EquinoxDesign.spacingSM) {
                if let saveError {
                    ModalErrorBanner(message: saveError)
                        .padding(.horizontal, EquinoxDesign.spacingMD)
                        .padding(.top, EquinoxDesign.spacingSM)
                }
                formContent
            }
        }
        .onAppear {
            applySmartDefaults()
            focusedField = .title
        }
    }

    private var hasModifiableCalendars: Bool {
        !modifiableCalendars.isEmpty
    }

    private var formContent: some View {
        Form {
            Section(String(localized: "Event", comment: "")) {
                TextField(String(localized: "Title", comment: ""), text: $title)
                    .focused($focusedField, equals: .title)
            }

            Section(String(localized: "Date & Time", comment: "")) {
                Toggle(String(localized: "All-day", comment: ""), isOn: $isAllDay)

                DatePicker(String(localized: "Starts", comment: ""), selection: $startDate,
                           displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                    .onChange(of: startDate) { _, new in
                        endDate = appState.calendar.date(byAdding: .minute, value: 60, to: new) ?? new
                    }

                DatePicker(String(localized: "Ends", comment: ""), selection: $endDate,
                           displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
            }

            Section(String(localized: "Calendar", comment: "")) {
                if hasModifiableCalendars {
                    Picker(String(localized: "Calendar", comment: ""), selection: $selectedCalendarIndex) {
                        ForEach(modifiableCalendars.indices, id: \.self) { i in
                            HStack {
                                Circle()
                                    .fill(modifiableCalendars[i].swiftUIColor)
                                    .frame(width: 10, height: 10)
                                Text(modifiableCalendars[i].title)
                            }
                            .tag(i)
                        }
                    }
                } else {
                    ModalErrorBanner(
                        message: String(
                            localized: "No writable calendars available. Check Calendar access in Privacy settings.",
                            comment: "New event empty calendar warning"
                        ),
                        style: .warning
                    )
                }
            }

            DisclosureGroup(String(localized: "Location & URL", comment: "New event section"), isExpanded: $showLocationSection) {
                TextField(String(localized: "Location", comment: ""), text: $location)
                TextField(String(localized: "URL", comment: ""), text: $urlString)
            }

            DisclosureGroup(String(localized: "Repeat", comment: ""), isExpanded: $showRepeatSection) {
                Picker(String(localized: "Repeat", comment: ""), selection: $recurrenceIndex) {
                    ForEach(recurrenceOptions.indices, id: \.self) { i in
                        Text(recurrenceOptions[i]).tag(i)
                    }
                }

                if recurrenceIndex > 0 {
                    Picker(String(localized: "End repeat", comment: ""), selection: $recurrenceEndIndex) {
                        ForEach(recurrenceEndOptions.indices, id: \.self) { i in
                            Text(recurrenceEndOptions[i]).tag(i)
                        }
                    }
                    if recurrenceEndIndex == 1 {
                        DatePicker(String(localized: "End date", comment: ""), selection: $recurrenceEndDate, displayedComponents: [.date])
                    }
                }
            }

            DisclosureGroup(String(localized: "Alert", comment: ""), isExpanded: $showAlertSection) {
                Picker(String(localized: "Alert", comment: ""), selection: $alertIndex) {
                    ForEach(regularAlerts.indices, id: \.self) { i in
                        Text(regularAlerts[i]).tag(i)
                    }
                }
            }

            DisclosureGroup(String(localized: "Notes", comment: ""), isExpanded: $showNotesSection) {
                TextField(String(localized: "Notes", comment: ""), text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .formStyle(.grouped)
    }

    private func close() {
        dismiss()
    }

    private var modifiableCalendars: [SelectableCalendar] {
        appState.events.calendarEntries.compactMap { entry in
            guard case .calendar(let cal) = entry, cal.allowsContentModifications else { return nil }
            return cal
        }
    }

    private func applySmartDefaults() {
        let defaults = appState.smartDefaultEventDates()
        startDate = defaults.start
        endDate = defaults.end
    }

    private func save() {
        guard selectedCalendarIndex < modifiableCalendars.count else { return }
        let calendar = modifiableCalendars[selectedCalendarIndex]
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        var recurrence: RecurrenceDraft?
        if recurrenceIndex > 0 {
            recurrence = EventDraftDefaults.recurrenceDraft(
                fromIndex: recurrenceIndex,
                endDateIndex: recurrenceEndIndex,
                endDate: recurrenceEndDate
            )
        }

        let alertOffset = EventDraftDefaults.alertOffset(forPickerIndex: alertIndex)

        let draft = NewEventDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            url: trimmedURL.isEmpty ? nil : URL(string: trimmedURL),
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            isAllDay: isAllDay,
            startDate: startDate,
            endDate: endDate,
            calendarIdentifier: calendar.id,
            recurrence: recurrence,
            alertOffset: alertOffset
        )

        saveError = nil
        Task {
            if let error = await appState.events.createEvent(from: draft) {
                saveError = error
            } else {
                close()
            }
        }
    }
}
