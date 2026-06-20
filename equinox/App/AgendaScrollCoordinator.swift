import Foundation

@Observable
@MainActor
final class AgendaScrollCoordinator {
    var scrolledSectionID: Int?
    private(set) var rangeFirst: CalendarDate?
    private(set) var rangeLast: CalendarDate?

    private var isProgrammaticScroll = false
    private var programmaticScrollGeneration = 0

    func displayRange(anchor: CalendarDate) -> (first: CalendarDate, last: CalendarDate) {
        if let rangeFirst, let rangeLast {
            return (rangeFirst, rangeLast)
        }
        return AgendaDisplayRange.initialRange(anchor: anchor)
    }

    func bootstrapRangeIfNeeded(anchor: CalendarDate, force: Bool = false) {
        if !force, rangeFirst != nil, rangeLast != nil { return }
        let range = AgendaDisplayRange.initialRange(anchor: anchor)
        applyRange(first: range.first, last: range.last)
    }

    func ensureDateInRange(_ date: CalendarDate, anchor: CalendarDate) {
        let current = displayRange(anchor: anchor)
        let expanded = AgendaDisplayRange.rangeCovering(
            date: date,
            first: current.first,
            last: current.last
        )
        if expanded.first != current.first || expanded.last != current.last {
            applyRange(first: expanded.first, last: expanded.last)
        }
    }

    func commitAgendaToCoordinator(_ events: EventsCoordinator, anchor: CalendarDate) {
        let range = displayRange(anchor: anchor)
        events.updateAgendaVisibleRange(first: range.first, last: range.last)
    }

    func extendRangeIfNeeded(for visibleDate: CalendarDate, anchor: CalendarDate) {
        let current = displayRange(anchor: anchor)
        var first = current.first
        var last = current.last
        var changed = false

        if AgendaDisplayRange.shouldExtendPast(visible: visibleDate, rangeFirst: first) {
            first = AgendaDisplayRange.extendedPast(from: first)
            changed = true
        }
        if AgendaDisplayRange.shouldExtendFuture(visible: visibleDate, rangeLast: last) {
            last = AgendaDisplayRange.extendedFuture(from: last)
            changed = true
        }

        if changed {
            applyRange(first: first, last: last)
        }
    }

    func scrollToSelectedDate(appState: AppState) {
        let anchor = appState.events.todayDate
        bootstrapRangeIfNeeded(anchor: anchor)
        ensureDateInRange(appState.events.selectedDate, anchor: anchor)
        commitAgendaToCoordinator(appState.events, anchor: anchor)
        isProgrammaticScroll = true
        programmaticScrollGeneration &+= 1
        let generation = programmaticScrollGeneration
        scrollAgenda(to: appState.events.selectedDate.julian)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if self.programmaticScrollGeneration == generation {
                self.isProgrammaticScroll = false
            }
        }
    }

    func handleAgendaScroll(to julian: Int?, anchor: CalendarDate) {
        guard let julian else { return }
        let visibleDate = CalendarDate(julian: julian)
        extendRangeIfNeeded(for: visibleDate, anchor: anchor)
    }

    func commitScrollSettle(appState: AppState) {
        if isProgrammaticScroll {
            isProgrammaticScroll = false
            return
        }
        guard let julian = scrolledSectionID else { return }
        let visibleDate = CalendarDate(julian: julian)
        appState.events.syncSelectionFromAgendaScroll(visibleDate)
        let anchor = appState.events.todayDate
        let range = displayRange(anchor: anchor)
        if visibleDate == range.first {
            extendRangeIfNeeded(for: visibleDate, anchor: anchor)
        }
        commitAgendaToCoordinator(appState.events, anchor: anchor)
    }

    private func applyRange(first: CalendarDate, last: CalendarDate) {
        rangeFirst = first
        rangeLast = last
    }

    private func scrollAgenda(to julian: Int) {
        guard scrolledSectionID == julian else {
            scrolledSectionID = julian
            return
        }
        scrolledSectionID = nil
        DispatchQueue.main.async {
            self.scrolledSectionID = julian
        }
    }
}
