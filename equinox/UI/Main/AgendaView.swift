import SwiftUI

private struct PendingDeleteEvent: Identifiable {
    let id: String
    let eventIdentifier: String
    let title: String
}

struct AgendaView: View {
    @Bindable var appState: AppState
    let metrics: SizeMetrics
    let height: CGFloat

    @State private var pendingDelete: PendingDeleteEvent?
    @State private var scrolledSectionID: Int?
    @State private var rangeFirst: CalendarDate?
    @State private var rangeLast: CalendarDate?
    @State private var isProgrammaticScroll = false

    private var prefs: PreferencesStore { appState.preferences }
    private var backgroundStyle: BackgroundStyle {
        BackgroundStyle(rawValue: prefs.backgroundStyle) ?? .glass
    }

    var body: some View {
        let sections = agendaSections
        Group {
            if sections.isEmpty {
                emptyAgenda
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: EquinoxDesign.spacingXS, pinnedViews: [.sectionHeaders]) {
                        ForEach(sections, id: \.date) { section in
                            Section {
                            if section.events.isEmpty
                                && (prefs.showDaysWithNoEvents || section.date == appState.events.selectedDate) {
                                emptyDayRow
                            } else {
                                ForEach(section.events) { event in
                                    AgendaEventCard(
                                        event: event,
                                        metrics: metrics,
                                        showLocation: prefs.showLocation,
                                        plaudMatch: appState.plaud.link(for: event),
                                        onTap: {
                                            appState.panel.selectedEvent = event
                                            appState.panel.isEventDetailPresented = true
                                        }
                                    )
                                    .contextMenu {
                                        Button(String(localized: "Show Details", comment: "Agenda context menu")) {
                                            appState.panel.selectedEvent = event
                                            appState.panel.isEventDetailPresented = true
                                        }
                                        if event.allowsContentModifications, let eventIdentifier = event.eventIdentifier {
                                            Button(String(localized: "Delete…", comment: ""), role: .destructive) {
                                                pendingDelete = PendingDeleteEvent(
                                                    id: event.id,
                                                    eventIdentifier: eventIdentifier,
                                                    title: event.title
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                            } header: {
                                AgendaSectionHeader(
                                    date: section.date,
                                    calendar: appState.calendar,
                                    backgroundStyle: backgroundStyle
                                )
                                .id(section.date.julian)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollPosition(id: $scrolledSectionID, anchor: .top)
                .onAppear {
                    bootstrapAgendaRangeIfNeeded()
                    scrollAgendaToSelectedDate()
                }
                .onChange(of: appState.panel.agendaScrollGeneration) { _, _ in
                    scrollAgendaToSelectedDate()
                }
                .onChange(of: appState.events.agendaScrollToken) { _, _ in
                    scrollAgendaToSelectedDate()
                }
                .onChange(of: scrolledSectionID) { _, julian in
                    handleAgendaScroll(to: julian)
                }
                .onScrollPhaseChange { _, newPhase in
                    if newPhase == .idle {
                        commitScrollSettle()
                    }
                }
            }
        }
        .frame(height: height)
        .sheet(item: $pendingDelete) { pending in
            ModalConfirmDialog(
                title: String(localized: "Delete event?", comment: "Delete event confirmation title"),
                message: pending.title,
                confirmTitle: String(localized: "Delete", comment: ""),
                onConfirm: {
                    let eventIdentifier = pending.eventIdentifier
                    let eventID = pending.id
                    pendingDelete = nil
                    Task {
                        appState.panel.panelFeedback = nil
                        if let error = await appState.events.deleteEvent(identifier: eventIdentifier) {
                            appState.panel.panelFeedback = error
                        } else if appState.panel.selectedEvent?.id == eventID {
                            appState.panel.selectedEvent = nil
                        }
                    }
                },
                onCancel: {
                    pendingDelete = nil
                }
            )
            .equinoxSheetPresentation()
        }
        .onChange(of: prefs.showEventDays) { _, _ in
            bootstrapAgendaRangeIfNeeded(force: true)
            scrollAgendaToSelectedDate()
        }
    }

    private var emptyDayRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.minus")
                .foregroundStyle(.tertiary)
            Text(String(localized: "No events", comment: "Agenda empty day"))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.leading, metrics.agendaEventLeadingMargin)
        .padding(.vertical, 8)
    }

    private var emptyAgenda: some View {
        VStack(spacing: EquinoxDesign.spacingMD) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(String(localized: "No upcoming events", comment: "Agenda empty list"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                appState.panel.newEventInitialDate = appState.events.selectedDate
                appState.panel.isNewEventSheetPresented = true
            } label: {
                Text(String(localized: "Create Event", comment: "Empty agenda CTA"))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var displayRange: (first: CalendarDate, last: CalendarDate) {
        if let rangeFirst, let rangeLast {
            return (rangeFirst, rangeLast)
        }
        return AgendaDisplayRange.initialRange(anchor: appState.events.todayDate)
    }

    private var agendaSections: [(date: CalendarDate, events: [DayEvent])] {
        let range = displayRange
        return AgendaSections.sections(
            from: range.first,
            through: range.last,
            pinnedDate: appState.events.selectedDate,
            showEmptyDays: prefs.showDaysWithNoEvents,
            eventsFor: appState.events.events(for:)
        )
    }

    private func bootstrapAgendaRangeIfNeeded(force: Bool = false) {
        if !force, rangeFirst != nil, rangeLast != nil { return }
        let range = AgendaDisplayRange.initialRange(anchor: appState.events.todayDate)
        applyAgendaRange(first: range.first, last: range.last)
        commitAgendaToCoordinator()
    }

    private func ensureDateInRange(_ date: CalendarDate) {
        let current = displayRange
        let expanded = AgendaDisplayRange.rangeCovering(
            date: date,
            first: current.first,
            last: current.last
        )
        if expanded.first != current.first || expanded.last != current.last {
            applyAgendaRange(first: expanded.first, last: expanded.last)
        }
    }

    private func applyAgendaRange(first: CalendarDate, last: CalendarDate) {
        rangeFirst = first
        rangeLast = last
    }

    private func commitAgendaToCoordinator() {
        let range = displayRange
        appState.events.updateAgendaVisibleRange(first: range.first, last: range.last)
    }

    private func extendRangeIfNeeded(for visibleDate: CalendarDate) {
        let current = displayRange
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
            applyAgendaRange(first: first, last: last)
        }
    }

    private func scrollAgendaToSelectedDate() {
        bootstrapAgendaRangeIfNeeded()
        ensureDateInRange(appState.events.selectedDate)
        commitAgendaToCoordinator()
        isProgrammaticScroll = true
        scrollAgenda(to: appState.events.selectedDate.julian)
        DispatchQueue.main.async {
            isProgrammaticScroll = false
        }
    }

    /// Forces `scrollPosition` to re-scroll even when the target id equals the current value
    /// (e.g. when `onAppear` set the id before sections existed). Resetting to `nil` first makes
    /// the binding change, so a stale value no longer suppresses the scroll-to-selected-date.
    private func scrollAgenda(to julian: Int) {
        scrolledSectionID = nil
        DispatchQueue.main.async {
            scrolledSectionID = julian
        }
    }

    private func handleAgendaScroll(to julian: Int?) {
        guard let julian else { return }
        let visibleDate = CalendarDate(julian: julian)
        extendRangeIfNeeded(for: visibleDate)
    }

    private func commitScrollSettle() {
        guard !isProgrammaticScroll else { return }
        guard let julian = scrolledSectionID else { return }
        let visibleDate = CalendarDate(julian: julian)
        appState.events.syncSelectionFromAgendaScroll(visibleDate)
        let range = displayRange
        if visibleDate == range.first {
            extendRangeIfNeeded(for: visibleDate)
        }
        commitAgendaToCoordinator()
    }
}
