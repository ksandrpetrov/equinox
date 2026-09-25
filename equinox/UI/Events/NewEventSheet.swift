import SwiftUI

struct NewEventSheet: View {
    @Bindable var appState: AppState
    let metrics: SizeMetrics
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
    @State private var selectedCalendarIdentifier = ""
    @State private var showLocationSection = false
    @State private var showRepeatSection = false
    @State private var showAlertSection = false
    @State private var showNotesSection = false
    @State private var isSaving = false
    @State private var isDatePickerPresented = false
    @State private var saveError: String?

    init(appState: AppState, metrics: SizeMetrics) {
        self.appState = appState
        self.metrics = metrics

        let defaults = appState.smartDefaultEventDates()
        _startDate = State(initialValue: defaults.start)
        _endDate = State(initialValue: defaults.end)
        _recurrenceEndDate = State(initialValue: defaults.start)
    }

    private let recurrenceOptions = [
        String(localized: "None", bundle: .equinox, comment: "Recurrence"),
        String(localized: "Every Day", bundle: .equinox, comment: ""),
        String(localized: "Every Week", bundle: .equinox, comment: ""),
        String(localized: "Every 2 Weeks", bundle: .equinox, comment: ""),
        String(localized: "Every Month", bundle: .equinox, comment: ""),
        String(localized: "Every Year", bundle: .equinox, comment: "")
    ]

    private let recurrenceEndOptions = [
        String(localized: "Never", bundle: .equinox, comment: ""),
        String(localized: "On date", bundle: .equinox, comment: "")
    ]

    private let regularAlerts = [
        String(localized: "None", bundle: .equinox, comment: "Alert"),
        String(localized: "At time of event", bundle: .equinox, comment: ""),
        String(localized: "5 minutes before", bundle: .equinox, comment: ""),
        String(localized: "10 minutes before", bundle: .equinox, comment: ""),
        String(localized: "15 minutes before", bundle: .equinox, comment: ""),
        String(localized: "30 minutes before", bundle: .equinox, comment: ""),
        String(localized: "1 hour before", bundle: .equinox, comment: ""),
        String(localized: "2 hours before", bundle: .equinox, comment: ""),
        String(localized: "1 day before", bundle: .equinox, comment: ""),
        String(localized: "2 days before", bundle: .equinox, comment: "")
    ]

    var body: some View {
        EventDrawerScaffold(
            title: String(localized: "New Event", bundle: .equinox, comment: ""),
            metrics: metrics,
            confirmTitle: String(localized: "Add", bundle: .equinox, comment: ""),
            confirmDisabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !hasModifiableCalendars || isSaving,
            isConfirming: isSaving,
            isCancelShortcutEnabled: !isDatePickerPresented,
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
                    .disabled(isSaving)
            }
        }
        .onAppear {
            reconcileSelectedCalendar()
        }
        .task {
            await Task.yield()
            focusedField = .title
        }
        .onChange(of: modifiableCalendarIdentifiers) { _, _ in
            reconcileSelectedCalendar()
        }
        .onChange(of: appState.events.defaultCalendarIdentifierForNewEvents) { _, _ in
            reconcileSelectedCalendar()
        }
    }

    private var hasModifiableCalendars: Bool {
        !modifiableCalendars.isEmpty
    }

    private var formContent: some View {
        Form {
            Section(String(localized: "Event", bundle: .equinox, comment: "")) {
                TextField(String(localized: "Title", bundle: .equinox, comment: ""), text: $title)
                    .focused($focusedField, equals: .title)
            }

            Section(String(localized: "Date & Time", bundle: .equinox, comment: "")) {
                Toggle(String(localized: "All-day", bundle: .equinox, comment: ""), isOn: $isAllDay)
                    .onChange(of: isAllDay) { _, isAllDay in
                        endDate = EventDraftDefaults.endDateAfterChangingAllDay(
                            start: startDate, end: endDate, isAllDay: isAllDay, calendar: appState.calendar
                        )
                    }

                eventDatePicker(String(localized: "Starts", bundle: .equinox, comment: ""), selection: $startDate,
                                range: supportedDates, showsTime: !isAllDay)
                    .onChange(of: startDate) { old, new in
                        endDate = EventDraftDefaults.endDatePreservingDuration(
                            previousStart: old,
                            previousEnd: endDate,
                            newStart: new,
                            calendar: appState.calendar,
                            isAllDay: isAllDay
                        )
                        endDate = min(endDate, latestEndDate)
                        let earliestRecurrenceEnd = appState.calendar.startOfDay(for: new)
                        if recurrenceEndDate < earliestRecurrenceEnd {
                            recurrenceEndDate = earliestRecurrenceEnd
                        }
                    }

                eventDatePicker(String(localized: "Ends", bundle: .equinox, comment: ""), selection: $endDate,
                                range: supportedDates.lowerBound...latestEndDate, showsTime: !isAllDay)
            }

            Section(String(localized: "Calendar", bundle: .equinox, comment: "")) {
                if hasModifiableCalendars {
                    Picker(String(localized: "Calendar", bundle: .equinox, comment: ""), selection: $selectedCalendarIdentifier) {
                        ForEach(modifiableCalendars) { calendar in
                            HStack {
                                Circle()
                                    .fill(calendar.swiftUIColor)
                                    .frame(width: EquinoxDesign.ControlWidth.calendarColorDot, height: EquinoxDesign.ControlWidth.calendarColorDot)
                                Text(calendar.title)
                            }
                            .tag(calendar.id)
                        }
                    }
                } else {
                    ModalErrorBanner(
                        message: String(
                            localized: "No writable calendars available. Check Calendar access in Privacy settings.",
                            bundle: .equinox, comment: "New event empty calendar warning"
                        ),
                        style: .warning
                    )
                }
            }

            DisclosureGroup(String(localized: "Location & URL", bundle: .equinox, comment: "New event section"), isExpanded: $showLocationSection) {
                TextField(String(localized: "Location", bundle: .equinox, comment: ""), text: $location)
                TextField(String(localized: "URL", bundle: .equinox, comment: ""), text: $urlString)
            }

            DisclosureGroup(String(localized: "Repeat", bundle: .equinox, comment: ""), isExpanded: $showRepeatSection) {
                Picker(String(localized: "Repeat", bundle: .equinox, comment: ""), selection: $recurrenceIndex) {
                    ForEach(recurrenceOptions.indices, id: \.self) { i in
                        Text(recurrenceOptions[i]).tag(i)
                    }
                }

                if recurrenceIndex > 0 {
                    Picker(String(localized: "End repeat", bundle: .equinox, comment: ""), selection: $recurrenceEndIndex) {
                        ForEach(recurrenceEndOptions.indices, id: \.self) { i in
                            Text(recurrenceEndOptions[i]).tag(i)
                        }
                    }
                    if recurrenceEndIndex == 1 {
                        eventDatePicker(
                            String(localized: "End date", bundle: .equinox, comment: ""),
                            selection: $recurrenceEndDate,
                            range: earliestRecurrenceEndDate...supportedDates.upperBound,
                            showsTime: false
                        )
                    }
                }
            }

            DisclosureGroup(String(localized: "Alert", bundle: .equinox, comment: ""), isExpanded: $showAlertSection) {
                Picker(String(localized: "Alert", bundle: .equinox, comment: ""), selection: $alertIndex) {
                    ForEach(regularAlerts.indices, id: \.self) { i in
                        Text(regularAlerts[i]).tag(i)
                    }
                }
            }

            DisclosureGroup(String(localized: "Notes", bundle: .equinox, comment: ""), isExpanded: $showNotesSection) {
                TextField(String(localized: "Notes", bundle: .equinox, comment: ""), text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
    }

    private func close() {
        appState.dismissEventDrawer()
    }

    private func eventDatePicker(_ title: String, selection: Binding<Date>, range: ClosedRange<Date>, showsTime: Bool) -> some View {
        EventDatePicker(title: title, selection: selection, range: range, showsTime: showsTime,
                        calendar: appState.calendar, weekStartWeekday: appState.preferences.weekStartWeekday,
                        metrics: metrics, onPresentationChange: { isDatePickerPresented = $0 })
    }

    private var modifiableCalendars: [SelectableCalendar] {
        appState.events.calendarEntries.compactMap { entry in
            guard case .calendar(let cal) = entry, cal.allowsContentModifications else { return nil }
            return cal
        }
    }

    private var modifiableCalendarIdentifiers: [String] {
        modifiableCalendars.map(\.id)
    }

    private var earliestRecurrenceEndDate: Date {
        appState.calendar.startOfDay(for: startDate)
    }

    private var supportedDates: ClosedRange<Date> {
        EventDraftDefaults.supportedDateRange(calendar: appState.calendar)
    }

    private var latestEndDate: Date {
        supportedDates.upperBound.addingTimeInterval(isAllDay ? 0 : 1)
    }

    private func reconcileSelectedCalendar() {
        selectedCalendarIdentifier = EventDraftDefaults.preferredCalendarIdentifier(
            currentIdentifier: selectedCalendarIdentifier,
            defaultIdentifier: appState.events.defaultCalendarIdentifierForNewEvents,
            availableIdentifiers: modifiableCalendarIdentifiers
        )
    }

    private func save() {
        guard !isSaving else { return }
        guard let calendar = modifiableCalendars.first(where: { $0.id == selectedCalendarIdentifier }) else {
            saveError = String(localized: "The calendar could not be found.", bundle: .equinox, comment: "Create event error")
            return
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            saveError = String(localized: "Enter an event title.", bundle: .equinox, comment: "Create event title validation error")
            return
        }
        guard let normalizedDates = EventDraftDefaults.normalizedDates(
            calendar: appState.calendar,
            start: startDate,
            end: endDate,
            isAllDay: isAllDay
        ) else {
            saveError = String(localized: "End date must be after start date.", bundle: .equinox, comment: "Create event validation error")
            return
        }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let eventURL: URL?
        if trimmedURL.isEmpty {
            eventURL = nil
        } else if let validURL = EventDraftDefaults.absoluteURL(from: trimmedURL) {
            eventURL = validURL
        } else {
            saveError = String(localized: "Enter a valid URL including its scheme.", bundle: .equinox, comment: "Create event URL validation error")
            return
        }

        var recurrence: RecurrenceDraft?
        if recurrenceIndex > 0 {
            let recurrenceEnd: Date
            if recurrenceEndIndex == 1 {
                guard let normalizedEnd = EventDraftDefaults.normalizedRecurrenceEnd(
                    calendar: appState.calendar,
                    eventStart: normalizedDates.start,
                    selectedEnd: recurrenceEndDate
                ) else {
                    saveError = String(localized: "Repeat end date cannot be before event start.", bundle: .equinox, comment: "Create event recurrence validation error")
                    return
                }
                recurrenceEnd = normalizedEnd
            } else {
                recurrenceEnd = recurrenceEndDate
            }
            recurrence = EventDraftDefaults.recurrenceDraft(
                fromIndex: recurrenceIndex,
                endDateIndex: recurrenceEndIndex,
                endDate: recurrenceEnd
            )
        }

        let alertOffset = EventDraftDefaults.alertOffset(forPickerIndex: alertIndex)

        let draft = NewEventDraft(
            title: trimmedTitle,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            url: eventURL,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            isAllDay: isAllDay,
            startDate: normalizedDates.start,
            endDate: normalizedDates.end,
            calendarIdentifier: calendar.id,
            recurrence: recurrence,
            alertOffset: alertOffset
        )

        saveError = nil
        isSaving = true
        Task {
            if let error = await appState.createEvent(from: draft) {
                saveError = error
                isSaving = false
            } else {
                isSaving = false
                close()
            }
        }
    }
}

struct EventDatePicker: View {
    let title: String
    @Binding var selection: Date
    let range: ClosedRange<Date>
    let showsTime: Bool
    let calendar: Calendar
    let weekStartWeekday: Int
    let metrics: SizeMetrics
    let onPresentationChange: (Bool) -> Void
    @State private var isCalendarPresented = false

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: EquinoxDesign.spacingSM)
            HStack(spacing: EquinoxDesign.spacingSM) {
                Button {
                    isCalendarPresented = true
                } label: {
                    HStack(spacing: EquinoxDesign.spacingXS) {
                        Text(selection, format: .dateTime.day().month(.twoDigits).year())
                            .monospacedDigit()
                        Image(systemName: "calendar")
                    }
                }
                .buttonStyle(EquinoxButtonStyle(size: .small))
                .accessibilityLabel(title)
                .accessibilityValue(selection.formatted(date: .complete, time: .omitted))
                .popover(isPresented: $isCalendarPresented, arrowEdge: .trailing) {
                    EventDateCalendar(selection: $selection, range: range, calendar: calendar,
                                      weekStartWeekday: weekStartWeekday, metrics: metrics,
                                      onClose: { isCalendarPresented = false })
                }
                if showsTime {
                    DatePicker(title, selection: $selection, in: range, displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.field)
                        .labelsHidden()
                        .fixedSize()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .onChange(of: isCalendarPresented) { _, isPresented in
            onPresentationChange(isPresented)
        }
    }
}

struct EventDateCalendar: View {
    @Binding var selection: Date
    let range: ClosedRange<Date>
    let calendar: Calendar
    let weekStartWeekday: Int
    let metrics: SizeMetrics
    let onClose: () -> Void
    @State private var month: CalendarDate
    @FocusState private var isGridFocused: Bool

    init(selection: Binding<Date>, range: ClosedRange<Date>, calendar: Calendar,
         weekStartWeekday: Int, metrics: SizeMetrics, onClose: @escaping () -> Void) {
        _selection = selection
        self.range = range
        self.calendar = calendar
        self.weekStartWeekday = weekStartWeekday
        self.metrics = metrics
        self.onClose = onClose
        let initial = CalendarDate(date: selection.wrappedValue, calendar: calendar)
        _month = State(initialValue: CalendarDate(julian: min(max(initial.julian, CalendarDate.minimumSupported.julian), CalendarDate.maximumSupported.julian)))
    }

    private var selectedDay: CalendarDate { CalendarDate(date: selection, calendar: calendar) }
    private var firstDay: CalendarDate { CalendarDate(date: range.lowerBound, calendar: calendar) }
    private var lastDay: CalendarDate {
        CalendarDate(julian: min(CalendarDate(date: range.upperBound, calendar: calendar).julian, CalendarDate.maximumSupported.julian))
    }
    private var dates: [CalendarDate] {
        monthGridDates(monthDate: month, weekStartWeekday: weekStartWeekday, numRows: 6)
    }

    var body: some View {
        VStack(spacing: EquinoxDesign.spacingSM) {
            HStack(spacing: EquinoxDesign.spacingXS) {
                PanelIconButton(symbol: "chevron.left",
                                help: String(localized: "Previous month", bundle: .equinox, comment: ""),
                                buttonSize: metrics.toolbarButtonSize) { month = month.addingMonths(-1) }
                    .disabled(month.addingMonths(-1).julian < firstDay.addingMonths(0).julian)
                Menu {
                    ForEach(0..<12, id: \.self) { index in
                        Button(calendar.standaloneMonthSymbols[index]) {
                            month = boundedMonth(year: month.year, monthIndex: index)
                        }
                    }
                } label: {
                    Text(calendar.standaloneMonthSymbols[month.monthIndex])
                        .lineLimit(1)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                TextField(String(localized: "Year", bundle: .equinox, comment: "Date picker year"), value: Binding(
                    get: { month.year },
                    set: { month = boundedMonth(year: $0, monthIndex: month.monthIndex) }
                ), format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .frame(width: metrics.toolbarButtonSize * 2)
                PanelIconButton(symbol: "chevron.right",
                                help: String(localized: "Next month", bundle: .equinox, comment: ""),
                                buttonSize: metrics.toolbarButtonSize) { month = month.addingMonths(1) }
                    .disabled(month.addingMonths(1).julian > lastDay.addingMonths(0).julian)
            }
            VStack(spacing: EquinoxDesign.spacingMicro) {
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        Text(calendar.shortStandaloneWeekdaySymbols[weekdayForColumn(startDOW: weekStartWeekday, col: column)].uppercased())
                            .font(EquinoxDesign.weekdayHeaderFont())
                            .foregroundStyle(.secondary)
                            .frame(width: metrics.cellSize)
                    }
                }
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(Array(dates[(row * 7)..<(row * 7 + 7)]), id: \.julian) { day in
                            Button {
                                select(day)
                                onClose()
                            } label: {
                                Text("\(day.day)")
                                    .font(EquinoxDesign.dayNumeralFont(size: metrics.fontSize))
                                    .foregroundStyle(day.monthIndex == month.monthIndex ? Color.primary : .secondary)
                                    .frame(width: metrics.cellSize, height: metrics.cellSize)
                            }
                            .buttonStyle(PanelButtonStyle(isSelected: day == selectedDay))
                            .disabled(!isSelectable(day))
                            .focusable(false)
                            .accessibilityLabel(day.date(in: calendar).formatted(date: .complete, time: .omitted))
                            .accessibilityAddTraits(day == selectedDay ? .isSelected : [])
                        }
                    }
                }
            }
            .focusable()
            .focused($isGridFocused)
            .focusEffectDisabled()
            .accessibilityElement(children: .contain)
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow, .return]) { press in
                let offset: Int
                switch press.key {
                case .leftArrow: offset = -1
                case .rightArrow: offset = 1
                case .upArrow: offset = -7
                case .downArrow: offset = 7
                case .return: onClose(); return .handled
                default: return .ignored
                }
                let next = selectedDay.addingDays(offset)
                if isSelectable(next) { select(next); month = next }
                return .handled
            }
            Button(String(localized: "Today", bundle: .equinox, comment: "")) {
                select(CalendarDate.today(calendar: calendar))
                onClose()
            }
            .buttonStyle(EquinoxButtonStyle(variant: .plain, size: .small))
            .disabled(!isSelectable(CalendarDate.today(calendar: calendar)))
        }
        .padding(EquinoxDesign.spacingMD)
        .onAppear { isGridFocused = true }
        .onExitCommand(perform: onClose)
    }

    private func boundedMonth(year: Int, monthIndex: Int) -> CalendarDate {
        let proposed = CalendarDate(year: min(max(year, firstDay.year), lastDay.year), monthIndex: monthIndex, day: 1)
        return CalendarDate(julian: min(max(proposed.julian, firstDay.addingMonths(0).julian), lastDay.addingMonths(0).julian))
    }

    private func isSelectable(_ day: CalendarDate) -> Bool {
        day.isValid && day.julian >= firstDay.julian && day.julian <= lastDay.julian
    }

    private func select(_ day: CalendarDate) {
        guard isSelectable(day) else { return }
        selection = min(max(EventDraftDefaults.replacingDay(of: selection, with: day, calendar: calendar), range.lowerBound), range.upperBound)
    }
}
