import SwiftUI

private struct PendingDeleteEvent: Identifiable {
    let id: String
    let eventIdentifier: String
    let occurrenceStartDate: Date
    let title: String
    let isRecurring: Bool
}

enum AgendaContentState: Equatable {
    case hidden
    case loading
    case empty
    case content

    static func resolve(
        accessStatus: CalendarAccessStatus,
        hasCompletedInitialLoad: Bool,
        hasFetchError: Bool,
        hasVisibleEvents: Bool,
        hasSelectedCalendars: Bool = true
    ) -> AgendaContentState {
        guard accessStatus == .authorized, hasSelectedCalendars else {
            return .hidden
        }
        if hasCompletedInitialLoad {
            return hasVisibleEvents ? .content : .empty
        }
        return hasFetchError ? .hidden : .loading
    }
}

struct AgendaView: View {
    @Bindable var appState: AppState
    let metrics: SizeMetrics
    let height: CGFloat

    @State private var pendingDelete: PendingDeleteEvent?
    @State private var scrollCoordinator = AgendaScrollCoordinator()
    @State private var sectionHeaderHeight: CGFloat = 0

    private var prefs: PreferencesStore { appState.preferences }
    var body: some View {
        let displayRange = scrollCoordinator.displayRange(anchor: appState.events.todayDate)
        let sections = agendaSections
        let focusedEventID = agendaFocusEventID(in: displayRange)
        VStack(spacing: 0) {
            if contentState != .hidden {
                AgendaHorizonControl(
                    heightRatio: agendaHeightBinding,
                    metrics: metrics,
                    onHide: { prefs.showsAgenda = false }
                )
            }

            Group {
                switch contentState {
                case .hidden:
                    Color.clear
                case .loading:
                    loadingAgenda
                case .empty:
                    emptyAgenda
                case .content:
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: EquinoxDesign.spacingXS, pinnedViews: [.sectionHeaders]) {
                            agendaBoundaryMarker(displayRange.first)
                            ForEach(sections, id: \.date) { section in
                                Section {
                                    if section.events.isEmpty
                                        && (prefs.showDaysWithNoEvents || section.date == appState.events.selectedDate) {
                                        emptyDayRow(for: section.date)
                                    } else {
                                        ForEach(Array(section.events.enumerated()), id: \.element.id) { index, event in
                                            AgendaEventCard(
                                                event: event,
                                                metrics: metrics,
                                                showLocation: prefs.showLocation,
                                                now: appState.events.currentTime,
                                                isFirstInSection: index == section.events.startIndex,
                                                isLastInSection: index == section.events.index(before: section.events.endIndex),
                                                isFocusedEvent: event.id == focusedEventID,
                                                onTap: {
                                                    appState.panel.selectedEvent = event
                                                    appState.panel.isEventDetailPresented = true
                                                }
                                            )
                                            .id(AgendaScrollTarget.event(id: event.id))
                                            .contextMenu {
                                                Button(String(localized: "Show Details", comment: "Agenda context menu")) {
                                                    appState.panel.selectedEvent = event
                                                    appState.panel.isEventDetailPresented = true
                                                }
                                                if event.allowsDeletion, let eventIdentifier = event.eventIdentifier {
                                                    Button(String(localized: "Delete…", comment: ""), role: .destructive) {
                                                        pendingDelete = PendingDeleteEvent(
                                                            id: event.id,
                                                            eventIdentifier: eventIdentifier,
                                                            occurrenceStartDate: event.startDate,
                                                            title: event.title,
                                                            isRecurring: event.isRecurring
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
                                        metrics: metrics,
                                        eventCount: section.events.count,
                                        isSelected: section.date == appState.events.selectedDate
                                    )
                                    .id(AgendaScrollTarget.day(julian: section.date.julian))
                                    .background {
                                        GeometryReader { geometry in
                                            Color.clear.preference(
                                                key: AgendaSectionHeaderHeightKey.self,
                                                value: geometry.size.height
                                            )
                                        }
                                    }
                                }
                            }
                            agendaBoundaryMarker(displayRange.last)
                        }
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.automatic)
                    .scrollPosition(id: $scrollCoordinator.scrolledTarget, anchor: agendaScrollAnchor)
                    .onPreferenceChange(AgendaSectionHeaderHeightKey.self) { height in
                        sectionHeaderHeight = height
                    }
                    .onChange(of: scrollCoordinator.scrolledTarget) { _, target in
                        scrollCoordinator.handleAgendaScroll(to: target, anchor: appState.events.todayDate, events: appState.events)
                    }
                    .onScrollPhaseChange { _, newPhase in
                        if newPhase == .idle {
                            scrollCoordinator.commitScrollSettle(events: appState.events)
                        }
                    }
                }
            }
            .frame(height: contentHeight)
        }
        .onAppear {
            scrollCoordinator.bootstrapRangeIfNeeded(anchor: appState.events.todayDate)
            scrollCoordinator.commitAgendaToCoordinator(appState.events, anchor: appState.events.todayDate)
            if contentState == .content {
                scrollCoordinator.scrollToFocus(events: appState.events)
            }
        }
        .onChange(of: contentState) { _, state in
            if state == .content {
                scrollCoordinator.scrollToFocus(events: appState.events)
            }
        }
        .onChange(of: appState.events.agendaScrollToken) { _, _ in
            scrollCoordinator.scrollToFocus(events: appState.events)
        }
        .sheet(item: $pendingDelete) { pending in
            ModalConfirmDialog(
                title: EventDeletionConfirmation.title(isRecurring: pending.isRecurring),
                message: pending.title,
                confirmTitle: String(localized: "Delete", comment: ""),
                onConfirm: {
                    let eventIdentifier = pending.eventIdentifier
                    let occurrenceStartDate = pending.occurrenceStartDate
                    pendingDelete = nil
                    Task {
                        appState.panel.panelFeedback = nil
                        if let error = await appState.deleteEvent(
                            identifier: eventIdentifier,
                            occurrenceStartDate: occurrenceStartDate
                        ) {
                            appState.panel.panelFeedback = error
                        }
                    }
                },
                onCancel: {
                    pendingDelete = nil
                }
            )
            .equinoxSheetPresentation()
        }
    }

    private var agendaScrollAnchor: UnitPoint {
        if case .event = scrollCoordinator.scrolledTarget {
            guard height > 0 else { return .top }
            return UnitPoint(x: 0.5, y: min(0.5, agendaHeaderClearance / height))
        }
        return .top
    }

    private func agendaBoundaryMarker(_ date: CalendarDate) -> some View {
        Color.clear
            .frame(height: EquinoxDesign.spacingMicro)
            .id(AgendaScrollTarget.boundary(julian: date.julian))
            .accessibilityHidden(true)
    }

    private var agendaHeaderClearance: CGFloat {
        max(sectionHeaderHeight, estimatedSectionHeaderHeight) + EquinoxDesign.spacingXS
    }

    private var estimatedSectionHeaderHeight: CGFloat {
        metrics.fontSize
            + 1
            + EquinoxDesign.spacingSM
            + EquinoxDesign.agendaHeaderVerticalPadding * 2
            + EquinoxDesign.spacingXS
    }

    private func emptyDayRow(for date: CalendarDate) -> some View {
        HStack(spacing: EquinoxDesign.spacingSM) {
            Image(systemName: "calendar.badge.minus")
                .foregroundStyle(.tertiary)
            Text(String(localized: "No events", comment: "Agenda empty day"))
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
            if date == appState.events.selectedDate {
                Button {
                    presentNewEvent(on: date)
                } label: {
                    Label(String(localized: "New Event", comment: "Agenda empty day action"), systemImage: "plus")
                }
                .buttonStyle(EquinoxButtonStyle(variant: .plain, size: .small))
            }
        }
        .padding(.horizontal, EquinoxDesign.spacingSM)
        .padding(.vertical, EquinoxDesign.spacingSM)
    }

    private var loadingAgenda: some View {
        HStack(spacing: EquinoxDesign.spacingSM) {
            ProgressView()
                .controlSize(.small)
            Text(String(localized: "Loading events", comment: "Agenda initial loading state"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyAgenda: some View {
        VStack(spacing: 0) {
            AgendaSectionHeader(
                date: appState.events.selectedDate,
                calendar: appState.calendar,
                metrics: metrics,
                eventCount: 0,
                isSelected: true
            )

            VStack(spacing: EquinoxDesign.spacingSM) {
                HStack(spacing: EquinoxDesign.spacingSM) {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundStyle(EquinoxDesign.ColorToken.action)
                    Text(String(localized: "No events", comment: "Agenda empty day"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button {
                        presentNewEvent(on: appState.events.selectedDate)
                    } label: {
                        Text(String(localized: "New Event", comment: "Empty agenda CTA"))
                    }
                    .buttonStyle(EquinoxButtonStyle(variant: .prominent, size: .small))
                }

                Button {
                    let range = scrollCoordinator.displayRange(anchor: appState.events.todayDate)
                    scrollCoordinator.extendRangeIfNeeded(
                        for: range.last,
                        anchor: appState.events.todayDate
                    )
                    scrollCoordinator.commitAgendaToCoordinator(
                        appState.events,
                        anchor: appState.events.todayDate
                    )
                } label: {
                    HStack(spacing: EquinoxDesign.spacingXS) {
                        Text(String(localized: "Show next 30 days", comment: "Extend empty agenda range"))
                        Group {
                            if appState.events.isFetchingEvents {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: EquinoxDesign.spacingMD, height: EquinoxDesign.spacingMD)
                        .accessibilityHidden(true)
                    }
                }
                .buttonStyle(EquinoxButtonStyle(variant: .bordered, size: .small))
                .accessibilityLabel(
                    String(localized: "Show next 30 days", comment: "Extend empty agenda range")
                )
                .disabled(
                    appState.events.isFetchingEvents
                        || scrollCoordinator.displayRange(anchor: appState.events.todayDate).last
                            == CalendarDate.maximumSupported
                )
            }
            .padding(.horizontal, EquinoxDesign.spacingSM)
            .padding(.vertical, EquinoxDesign.spacingSM)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var agendaSections: [(date: CalendarDate, events: [DayEvent])] {
        let range = scrollCoordinator.displayRange(anchor: appState.events.todayDate)
        return AgendaSections.sections(
            from: range.first,
            through: range.last,
            pinnedDate: appState.events.selectedDate,
            showEmptyDays: prefs.showDaysWithNoEvents,
            eventsFor: appState.events.events(for:)
        )
    }

    private var contentState: AgendaContentState {
        AgendaContentState.resolve(
            accessStatus: appState.events.calendarAccessStatus,
            hasCompletedInitialLoad: appState.events.hasCompletedInitialEventLoad,
            hasFetchError: appState.events.lastFetchError != nil,
            hasVisibleEvents: agendaSections.contains { !$0.events.isEmpty },
            hasSelectedCalendars: appState.events.hasSelectedCalendars
        )
    }

    private var contentHeight: CGFloat {
        contentState == .hidden ? 0 : height
    }

    private var agendaHeightBinding: Binding<Double> {
        Binding(
            get: { prefs.agendaHeightRatio },
            set: { prefs.agendaHeightRatio = $0 }
        )
    }

    private func agendaFocusEventID(
        in range: (first: CalendarDate, last: CalendarDate)
    ) -> String? {
        guard appState.events.selectedDate == appState.events.todayDate else { return nil }
        return AgendaFocus.focusEventID(
            from: appState.events.todayDate,
            through: range.last,
            eventsFor: appState.events.events(for:),
            now: appState.events.currentTime
        )
    }

    private func presentNewEvent(on date: CalendarDate) {
        appState.panel.newEventInitialDate = date
        appState.panel.isNewEventSheetPresented = true
    }
}

private struct AgendaSectionHeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
