import SwiftUI

private struct PendingDeleteEvent: Identifiable {
    let id: String
    let eventIdentifier: String
    let occurrenceStartDate: Date
    let title: String
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
                                emptyDayRow
                            } else {
                                ForEach(section.events) { event in
                                    AgendaEventCard(
                                        event: event,
                                        metrics: metrics,
                                        showLocation: prefs.showLocation,
                                        now: appState.events.currentTime,
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
                .scrollIndicators(.hidden)
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
        .padding(.top, contentState == .hidden ? 0 : EquinoxDesign.spacingSM)
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
                title: String(localized: "Delete event?", comment: "Delete event confirmation title"),
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

    private var emptyDayRow: some View {
        HStack(spacing: EquinoxDesign.spacingSM) {
            Image(systemName: "calendar.badge.minus")
                .foregroundStyle(.tertiary)
            Text(String(localized: "No events", comment: "Agenda empty day"))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.leading, metrics.agendaEventLeadingMargin)
        .padding(.vertical, EquinoxDesign.spacingSM)
    }

    private var loadingAgenda: some View {
        Text(String(localized: "Loading events", comment: "Agenda initial loading state"))
            .font(.caption)
            .foregroundStyle(.secondary)
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

            VStack(spacing: EquinoxDesign.spacingMD) {
                Image(systemName: "calendar.badge.clock")
                    .font(EquinoxDesign.emptyStateIconFont())
                    .foregroundStyle(.tertiary)
                Text(String(localized: "No events", comment: "Agenda empty day"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    appState.panel.newEventInitialDate = appState.events.selectedDate
                    appState.panel.isNewEventSheetPresented = true
                } label: {
                    Text(String(localized: "New Event", comment: "Empty agenda CTA"))
                }
                .buttonStyle(EquinoxButtonStyle(variant: .prominent, size: .small))

                Button(String(localized: "Look Further", comment: "Extend empty agenda range")) {
                    let range = scrollCoordinator.displayRange(anchor: appState.events.todayDate)
                    scrollCoordinator.extendRangeIfNeeded(
                        for: range.last,
                        anchor: appState.events.todayDate
                    )
                    scrollCoordinator.commitAgendaToCoordinator(
                        appState.events,
                        anchor: appState.events.todayDate
                    )
                }
                .buttonStyle(EquinoxButtonStyle(variant: .bordered, size: .small))
                .disabled(
                    scrollCoordinator.displayRange(anchor: appState.events.todayDate).last
                        == CalendarDate.maximumSupported
                )
            }
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
}

private struct AgendaSectionHeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
