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
                                    metrics: metrics,
                                    backgroundStyle: backgroundStyle
                                )
                                .id(AgendaScrollTarget.day(julian: section.date.julian))
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollPosition(id: $scrollCoordinator.scrolledTarget, anchor: .top)
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
                    let eventID = pending.id
                    pendingDelete = nil
                    Task {
                        appState.panel.panelFeedback = nil
                        if let error = await appState.deleteEvent(identifier: eventIdentifier) {
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
            scrollCoordinator.bootstrapRangeIfNeeded(anchor: appState.events.todayDate, force: true)
            scrollCoordinator.scrollToFocus(events: appState.events)
        }
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
