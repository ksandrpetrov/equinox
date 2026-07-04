import Foundation

@MainActor
protocol AgendaScrollContext: AnyObject {
    var todayDate: CalendarDate { get }
    var selectedDate: CalendarDate { get }
    var eventsByDate: [CalendarDate: [DayEvent]] { get }
    func events(for date: CalendarDate) -> [DayEvent]
    func syncSelectionFromAgendaScroll(_ date: CalendarDate)
    func updateAgendaVisibleRange(first: CalendarDate, last: CalendarDate)
}

extension EventsCoordinator: AgendaScrollContext {}

enum AgendaScrollTarget: Hashable {
    case day(julian: Int)
    case event(id: String)
}

@Observable
@MainActor
final class AgendaScrollCoordinator {
    var scrolledTarget: AgendaScrollTarget?
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

    func commitAgendaToCoordinator(_ events: AgendaScrollContext, anchor: CalendarDate) {
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

    func scrollToFocus(events: AgendaScrollContext) {
        let anchor = events.todayDate
        let selected = events.selectedDate
        bootstrapRangeIfNeeded(anchor: anchor)
        ensureDateInRange(selected, anchor: anchor)
        commitAgendaToCoordinator(events, anchor: anchor)
        isProgrammaticScroll = true
        programmaticScrollGeneration &+= 1
        let generation = programmaticScrollGeneration
        let target = focusTarget(events: events)
        scrollAgenda(to: target)
        DispatchQueue.main.asyncAfter(deadline: .now() + AgendaFocus.programmaticScrollSettleDelay) {
            if self.programmaticScrollGeneration == generation {
                self.isProgrammaticScroll = false
            }
        }
    }

    func handleAgendaScroll(to target: AgendaScrollTarget?, anchor: CalendarDate, events: AgendaScrollContext) {
        guard let target, let visibleDate = visibleDate(for: target, events: events) else { return }
        extendRangeIfNeeded(for: visibleDate, anchor: anchor)
    }

    func commitScrollSettle(events: AgendaScrollContext) {
        if isProgrammaticScroll {
            isProgrammaticScroll = false
            return
        }
        guard let target = scrolledTarget,
              let visibleDate = visibleDate(for: target, events: events) else { return }
        events.syncSelectionFromAgendaScroll(visibleDate)
        let anchor = events.todayDate
        let range = displayRange(anchor: anchor)
        if visibleDate == range.first {
            extendRangeIfNeeded(for: visibleDate, anchor: anchor)
        }
        commitAgendaToCoordinator(events, anchor: anchor)
    }

    private func focusTarget(events: AgendaScrollContext) -> AgendaScrollTarget {
        let selected = events.selectedDate
        let today = events.todayDate
        if selected == today,
           let eventID = AgendaFocus.focusEventID(
               from: today,
               through: displayRange(anchor: today).last,
               eventsFor: events.events(for:)
           ) {
            return .event(id: eventID)
        }
        return .day(julian: selected.julian)
    }

    private func visibleDate(for target: AgendaScrollTarget, events: AgendaScrollContext) -> CalendarDate? {
        switch target {
        case .day(let julian):
            return CalendarDate(julian: julian)
        case .event(let id):
            for (date, dayEvents) in events.eventsByDate {
                if dayEvents.contains(where: { $0.id == id }) {
                    return date
                }
            }
            return nil
        }
    }

    private func applyRange(first: CalendarDate, last: CalendarDate) {
        rangeFirst = first
        rangeLast = last
    }

    private func scrollAgenda(to target: AgendaScrollTarget) {
        guard scrolledTarget == target else {
            scrolledTarget = target
            return
        }
        scrolledTarget = nil
        DispatchQueue.main.async {
            self.scrolledTarget = target
        }
    }
}
