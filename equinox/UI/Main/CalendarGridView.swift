import SwiftUI

struct CalendarGridView: View {
    @Bindable var appState: AppState
    let metrics: SizeMetrics

    private var prefs: PreferencesStore { appState.preferences }
    private var numRows: Int { prefs.calendarRowCount }

    private var gridDates: [CalendarDate] {
        monthGridDates(
            monthDate: appState.monthDate,
            weekStartWeekday: prefs.weekStartWeekday,
            numRows: numRows
        )
    }

    private var dowSymbols: [String] {
        let base = EquinoxFormatters.weekdaySymbols()
        return (0..<7).map { col in
            base[weekdayForColumn(startDOW: prefs.weekStartWeekday, col: col)]
        }
    }

    var body: some View {
        VStack(spacing: EquinoxDesign.spacingXS) {
            HStack(spacing: 0) {
                if prefs.showWeeks {
                    Color.clear.frame(width: 24)
                }
                ForEach(Array(dowSymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(prefs.isWeekdayHighlighted(index, weekStartWeekday: prefs.weekStartWeekday) ? Color.secondary : Color.secondary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<numRows, id: \.self) { row in
                HStack(spacing: 0) {
                    if prefs.showWeeks {
                        let mondayCol = columnForWeekday(startDOW: prefs.weekStartWeekday, dow: 1)
                        let weekDate = gridDates[row * 7 + mondayCol]
                        Text("\(CalendarDate.weekOfYear(year: weekDate.year, monthIndex: weekDate.monthIndex, day: weekDate.day))")
                            .font(.system(size: metrics.fontSize - 1, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .contentTransition(.numericText())
                            .frame(width: 24)
                    }
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col
                        let date = gridDates[index]
                        let dots: [Color]? = prefs.showEventDots
                            ? DayEvent.makeSwiftUIDotColors(for: appState.events(for: date))
                            : nil
                        let (boundaryStart, boundaryEnd) = monthBoundaryFlags(for: date, col: col, row: row)
                        DayCellView(
                            date: date,
                            isToday: date.isSameCalendarDay(as: appState.todayDate),
                            isSelected: date.isSameCalendarDay(as: appState.selectedDate),
                            isInCurrentMonth: date.monthIndex == appState.monthDate.monthIndex
                                && date.year == appState.monthDate.year,
                            isHighlighted: prefs.isWeekdayHighlighted(col, weekStartWeekday: prefs.weekStartWeekday),
                            isMonthBoundaryStart: boundaryStart,
                            isMonthBoundaryEnd: boundaryEnd,
                            dotColors: dots,
                            hoverEvents: appState.events(for: date),
                            showHoverPreview: prefs.showsDayHoverPreview,
                            metrics: metrics,
                            calendar: appState.calendar,
                            onSelect: { appState.selectDate(date) },
                            onDoubleClick: {
                                appState.newEventInitialDate = date
                                appState.isNewEventSheetPresented = true
                            }
                        )
                        .id(date.julian)
                    }
                }
            }
        }
        .padding(EquinoxDesign.spacingXS)
        .background {
            RoundedRectangle(cornerRadius: EquinoxDesign.radiusMD, style: .continuous)
                .fill(EquinoxDesign.ColorToken.surfaceSecondary)
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow, .return]) { press in
            handleKeyPress(press)
        }
        .onAppear {
            Task { @MainActor in updateVisibleRange() }
        }
        .onChange(of: appState.monthDate) { _, _ in
            Task { @MainActor in updateVisibleRange() }
        }
        .onChange(of: numRows) { _, _ in
            Task { @MainActor in updateVisibleRange() }
        }
        .onChange(of: appState.selectedDate) { _, _ in
            Task { @MainActor in appState.extendFetchRangeForAgendaIfNeeded() }
        }
        .accessibilityLabel(String(localized: "Calendar grid", comment: ""))
        .accessibilityHint(String(localized: "Use arrow keys to move between days", comment: ""))
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let current = appState.selectedDate
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
            return .handled
        default:
            return .ignored
        }
        if let next {
            appState.selectDate(next)
            return .handled
        }
        return .ignored
    }

    private func monthBoundaryFlags(for date: CalendarDate, col: Int, row: Int) -> (Bool, Bool) {
        guard prefs.showMonthBoundaries else { return (false, false) }
        let inMonth = date.monthIndex == appState.monthDate.monthIndex
        guard inMonth else { return (false, false) }

        let index = row * 7 + col
        let prevInMonth: Bool = {
            if col == 0 { return false }
            return gridDates[index - 1].monthIndex == appState.monthDate.monthIndex
        }()
        let nextInMonth: Bool = {
            if col == 6 { return false }
            return gridDates[index + 1].monthIndex == appState.monthDate.monthIndex
        }()

        let start = col == 0 || !prevInMonth
        let end = col == 6 || !nextInMonth
        return (start, end)
    }

    private func updateVisibleRange() {
        guard let first = gridDates.first, let last = gridDates.last else { return }
        appState.updateVisibleRange(first: first, last: last)
    }
}
