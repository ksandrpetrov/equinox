import SwiftUI

struct CalendarGridView: View {
    @Bindable var appState: AppState
    let metrics: SizeMetrics

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isGridFocused: Bool

    private var prefs: PreferencesStore { appState.preferences }
    private var numRows: Int { prefs.calendarRowCount }

    private var gridDates: [CalendarDate] {
        appState.events.visibleGridDates
    }

    private var dowSymbols: [String] {
        let base = EquinoxFormatters.weekdaySymbols()
        return (0..<7).map { col in
            base[weekdayForColumn(startDOW: prefs.weekStartWeekday, col: col)]
        }
    }

    var body: some View {
        VStack(spacing: EquinoxDesign.spacingXS) {
            weekdayHeaderRow

            gridBody
                .id(appState.events.monthDate.julian)
                .transition(EquinoxDesign.monthTransition(forward: appState.events.monthNavigationDirection == .forward))
        }
        .padding(EquinoxDesign.spacingXS)
        .focusable()
        .focused($isGridFocused)
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow, .return]) { press in
            handleKeyPress(press)
        }
        .onAppear {
            appState.events.refreshVisibleGridRange()
            isGridFocused = true
        }
        .onChange(of: numRows) { _, _ in
            appState.events.refreshVisibleGridRange()
        }
        .onChange(of: appState.panel.isModalSheetPresented) { _, isPresented in
            if !isPresented {
                isGridFocused = true
            }
        }
        .animation(
            EquinoxDesign.animation(EquinoxDesign.expandAnimation, reduceMotion: reduceMotion),
            value: appState.events.monthDate.julian
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Calendar grid", comment: ""))
        .accessibilityHint(
            String(
                localized: "Use arrow keys to move between days. Hold Option for months and Shift-Option for years. Press Return to create an event.",
                comment: "Calendar grid keyboard hint"
            )
        )
    }

    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            if prefs.showWeeks {
                weekNumberHeader
            }
            ForEach(Array(dowSymbols.enumerated()), id: \.offset) { index, symbol in
                Text(symbol.uppercased())
                    .font(EquinoxDesign.weekdayHeaderFont())
                    .tracking(EquinoxDesign.weekdayHeaderTracking())
                    .foregroundStyle(prefs.isWeekdayHighlighted(index, weekStartWeekday: prefs.weekStartWeekday) ? Color.secondary : EquinoxDesign.ColorToken.weekdayDimmed)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var gridBody: some View {
        VStack(spacing: EquinoxDesign.spacingXS) {
            ForEach(0..<numRows, id: \.self) { row in
                HStack(spacing: 0) {
                    if prefs.showWeeks {
                        weekNumberCell(row: row)
                    }
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col
                        let date = gridDates[index]
                        let events = appState.events.events(for: date)
                        let dots: [Color]? = prefs.showEventDots
                            ? DayEvent.makeSwiftUIDotColors(for: events)
                            : nil
                        let (boundaryStart, boundaryEnd) = monthBoundaryFlags(for: date, col: col, row: row)
                        DayCellView(
                            date: date,
                            isToday: date.isSameCalendarDay(as: appState.events.todayDate),
                            isSelected: date.isSameCalendarDay(as: appState.events.selectedDate),
                            isKeyboardFocused: isGridFocused
                                && date.isSameCalendarDay(as: appState.events.selectedDate),
                            isInCurrentMonth: date.monthIndex == appState.events.monthDate.monthIndex
                                && date.year == appState.events.monthDate.year,
                            isHighlighted: prefs.isWeekdayHighlighted(col, weekStartWeekday: prefs.weekStartWeekday),
                            isMonthBoundaryStart: boundaryStart,
                            isMonthBoundaryEnd: boundaryEnd,
                            eventCount: events.count,
                            dotColors: dots,
                            metrics: metrics,
                            calendar: appState.calendar,
                            onSelect: {
                                appState.selectDate(date)
                                isGridFocused = true
                            },
                            onDoubleClick: {
                                appState.panel.newEventInitialDate = date
                                appState.panel.isNewEventSheetPresented = true
                            }
                        )
                        .id(date.julian)
                    }
                }
            }
        }
    }

    private var weekNumberHeader: some View {
        Text("#")
            .font(EquinoxDesign.weekdayHeaderFont())
            .foregroundStyle(.tertiary)
            .frame(width: metrics.weekColumnWidth)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(EquinoxDesign.ColorToken.separator)
                    .frame(width: EquinoxDesign.monthBoundaryWidth)
            }
            .accessibilityLabel(String(localized: "Week number", comment: "Calendar week column header"))
    }

    private func weekNumberCell(row: Int) -> some View {
        let mondayColumn = columnForWeekday(startDOW: prefs.weekStartWeekday, dow: 1)
        let weekDate = gridDates[row * 7 + mondayColumn]
        let weekNumber = CalendarDate.weekOfYear(
            year: weekDate.year,
            monthIndex: weekDate.monthIndex,
            day: weekDate.day
        )
        let rowDates = gridDates[(row * 7)..<(row * 7 + 7)]
        let isSelectedWeek = rowDates.contains(appState.events.selectedDate)

        return Text("\(weekNumber)")
            .font(EquinoxDesign.weekNumberFont(size: metrics.fontSize))
            .foregroundStyle(
                isSelectedWeek
                    ? EquinoxDesign.ColorToken.action
                    : EquinoxDesign.ColorToken.weekdayDimmed
            )
            .contentTransition(.numericText())
            .frame(width: metrics.weekColumnWidth, height: metrics.cellSize)
            .background {
                if isSelectedWeek {
                    RoundedRectangle(cornerRadius: EquinoxDesign.chipRadius, style: .continuous)
                        .fill(EquinoxDesign.ColorToken.accentSoft)
                        .padding(EquinoxDesign.spacingMicro)
                }
            }
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(EquinoxDesign.ColorToken.separator)
                    .frame(width: EquinoxDesign.monthBoundaryWidth)
            }
            .accessibilityLabel(
                String(
                    format: String(localized: "Week %lld", comment: "Calendar week number"),
                    Int64(weekNumber)
                )
            )
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let current = appState.events.selectedDate
        if press.modifiers.contains(.option) {
            let monthStep = press.modifiers.contains(.shift) ? 12 : 1
            switch press.key {
            case .leftArrow:
                appState.selectDate(
                    current.addingMonthsPreservingDay(-monthStep, calendar: appState.calendar)
                )
                return .handled
            case .rightArrow:
                appState.selectDate(
                    current.addingMonthsPreservingDay(monthStep, calendar: appState.calendar)
                )
                return .handled
            default:
                break
            }
        }
        let next: CalendarDate?
        switch press.key {
        case .leftArrow:
            next = current.addingDays(-1)
        case .rightArrow:
            next = current.addingDays(1)
        case .upArrow:
            next = current.addingDays(-7)
        case .downArrow:
            next = current.addingDays(7)
        case .return:
            appState.panel.newEventInitialDate = current
            appState.panel.isNewEventSheetPresented = true
            return .handled
        default:
            return .ignored
        }
        if let next, next.isValid {
            appState.selectDate(next)
            return .handled
        }
        return .ignored
    }

    private func monthBoundaryFlags(for date: CalendarDate, col: Int, row: Int) -> (Bool, Bool) {
        let flags = monthGridBoundaryFlags(
            for: date,
            monthIndex: appState.events.monthDate.monthIndex,
            col: col,
            row: row,
            gridDates: gridDates,
            showMonthBoundaries: prefs.showMonthBoundaries
        )
        return (flags.start, flags.end)
    }
}
