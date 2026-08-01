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
    @State private var scrollCoordinator = AgendaScrollCoordinator()
    @State private var sectionHeaderHeight: CGFloat = 0

    private var prefs: PreferencesStore { appState.preferences }
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
                                    .id(AgendaScrollTarget.event(id: event.id))
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
                                    metrics: metrics
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
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollPosition(id: $scrollCoordinator.scrolledTarget, anchor: agendaScrollAnchor)
                .onPreferenceChange(AgendaSectionHeaderHeightKey.self) { height in
                    sectionHeaderHeight = height
                }
                .onAppear {
                    scrollCoordinator.bootstrapRangeIfNeeded(anchor: appState.events.todayDate)
                    scrollCoordinator.commitAgendaToCoordinator(appState.events, anchor: appState.events.todayDate)
                    scrollCoordinator.scrollToFocus(events: appState.events)
                }
                .onChange(of: appState.events.agendaScrollToken) { _, _ in
                    scrollCoordinator.scrollToFocus(events: appState.events)
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
        .frame(height: height)
        .sheet(item: $pendingDelete) { pending in
            ModalConfirmDialog(
                title: String(localized: "Delete event?", comment: "Delete event confirmation title"),
                message: pending.title,
                confirmTitle: String(localized: "Delete", comment: ""),
                onConfirm: {
                    let eventIdentifier = pending.eventIdentifier
                    pendingDelete = nil
                    Task {
                        appState.panel.panelFeedback = nil
                        if let error = await appState.deleteEvent(identifier: eventIdentifier) {
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
        .onChange(of: prefs.showEventDays) { _, _ in
            scrollCoordinator.bootstrapRangeIfNeeded(anchor: appState.events.todayDate, force: true)
            scrollCoordinator.scrollToFocus(events: appState.events)
        }
    }

    private var agendaScrollAnchor: UnitPoint {
        if case .event = scrollCoordinator.scrolledTarget {
            guard height > 0 else { return .top }
            return UnitPoint(x: 0.5, y: min(0.5, agendaHeaderClearance / height))
        }
        return .top
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

    private var emptyAgenda: some View {
        VStack(spacing: EquinoxDesign.spacingMD) {
            Image(systemName: "calendar.badge.clock")
                .font(EquinoxDesign.emptyStateIconFont())
                .foregroundStyle(.tertiary)
            Text(String(localized: "No upcoming events.", comment: "Agenda empty list"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                appState.panel.newEventInitialDate = appState.events.selectedDate
                appState.panel.isNewEventSheetPresented = true
            } label: {
                Text(String(localized: "New Event", comment: "Empty agenda CTA"))
            }
            .buttonStyle(EquinoxButtonStyle(variant: .prominent, size: .small))
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
}

private struct AgendaSectionHeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
