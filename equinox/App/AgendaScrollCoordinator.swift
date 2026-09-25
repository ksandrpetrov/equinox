import Foundation

@MainActor
protocol AgendaScrollContext: AnyObject {
    var todayDate: CalendarDate { get }
    var selectedDate: CalendarDate { get }
    var agendaScrollToken: Int { get }
    var agendaFocusesDayStart: Bool { get }
    var eventsByDate: [CalendarDate: [DayEvent]] { get }
    func events(for date: CalendarDate) -> [DayEvent]
    func syncSelectionFromAgendaScroll(_ date: CalendarDate)
    func updateAgendaVisibleRange(first: CalendarDate, last: CalendarDate)
}

extension EventsCoordinator: AgendaScrollContext {}

enum AgendaScrollTarget: Hashable {
    case day(julian: Int)
    case event(id: String)
    case boundary(julian: Int)
}

@Observable
@MainActor
final class AgendaScrollCoordinator {
    var scrolledTarget: AgendaScrollTarget?
    private(set) var requestedTarget: AgendaScrollTarget?
    private(set) var rangeFirst: CalendarDate?
    private(set) var rangeLast: CalendarDate?

    private var userScrollToken: Int?
    private var topVisibleDate: CalendarDate?
    private var programmaticScrollGeneration = 0
    private var pendingFocus: Task<Void, Never>?

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
            let extended = AgendaDisplayRange.extendedPast(from: first)
            if extended != first {
                first = extended
                changed = true
            }
        }
        if AgendaDisplayRange.shouldExtendFuture(visible: visibleDate, rangeLast: last) {
            let extended = AgendaDisplayRange.extendedFuture(from: last)
            if extended != last {
                last = extended
                changed = true
            }
        }

        if changed {
            applyRange(first: first, last: last)
        }
    }

    func scheduleScrollToFocus(events: AgendaScrollContext) {
        pendingFocus?.cancel()
        pendingFocus = Task { [weak self] in
            do {
                try await Task.sleep(for: AgendaFocus.navigationCoalescingDelay)
            } catch {
                return
            }
            self?.scrollToFocus(events: events)
        }
    }

    func scrollToFocus(events: AgendaScrollContext) {
        pendingFocus?.cancel()
        pendingFocus = nil
        let anchor = events.todayDate
        let selected = events.selectedDate
        bootstrapRangeIfNeeded(anchor: anchor)
        ensureDateInRange(selected, anchor: anchor)
        commitAgendaToCoordinator(events, anchor: anchor)
        userScrollToken = nil
        programmaticScrollGeneration &+= 1
        let target = focusTarget(events: events)
        requestedTarget = target
        scrollAgenda(to: target)
    }

    func beginUserScroll(events: AgendaScrollContext) {
        pendingFocus?.cancel()
        pendingFocus = nil
        if userScrollToken != events.agendaScrollToken {
            programmaticScrollGeneration &+= 1
            userScrollToken = events.agendaScrollToken
        }
        // Cancel a pending fetch-driven refocus even if the first visible day
        // still matches the selection when the user starts scrolling.
        events.syncSelectionFromAgendaScroll(events.selectedDate)
        synchronizeVisibleDate(events: events)
    }

    func updateVisibleDate(_ date: CalendarDate?, events: AgendaScrollContext) {
        topVisibleDate = date
        synchronizeVisibleDate(events: events)
    }

    private func synchronizeVisibleDate(events: AgendaScrollContext) {
        guard userScrollToken == events.agendaScrollToken,
              let date = topVisibleDate, date.isValid else { return }
        if events.selectedDate != date {
            events.syncSelectionFromAgendaScroll(date)
        }
        extendRangeIfNeeded(for: date, anchor: events.todayDate)
    }

    func handleAgendaScroll(to target: AgendaScrollTarget?, anchor: CalendarDate, events: AgendaScrollContext) {
        guard let target, let visibleDate = visibleDate(for: target, events: events) else { return }
        extendRangeIfNeeded(for: visibleDate, anchor: anchor)
    }

    func commitScrollSettle(events: AgendaScrollContext) {
        if case .boundary(let julian) = scrolledTarget {
            extendRangeIfNeeded(for: CalendarDate(julian: julian), anchor: events.todayDate)
            commitAgendaToCoordinator(events, anchor: events.todayDate)
            return
        }
        guard userScrollToken == events.agendaScrollToken else { return }
        synchronizeVisibleDate(events: events)
        commitAgendaToCoordinator(events, anchor: events.todayDate)
    }

    private func focusTarget(events: AgendaScrollContext) -> AgendaScrollTarget {
        let selected = events.selectedDate
        let today = events.todayDate
        if !events.agendaFocusesDayStart, selected == today,
           let eventID = AgendaFocus.focusEventID(in: events.events(for: today)) {
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
        case .boundary(let julian):
            return CalendarDate(julian: julian)
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
        let generation = programmaticScrollGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.programmaticScrollGeneration == generation else { return }
            self.scrolledTarget = target
        }
    }
}
