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
    @Binding var expandedEventID: String?

    @State private var pendingDelete: PendingDeleteEvent?

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
                                if section.events.isEmpty && prefs.showDaysWithNoEvents {
                                    emptyDayRow
                                } else {
                                    ForEach(section.events) { event in
                                        AgendaEventCard(
                                            event: event,
                                            metrics: metrics,
                                            showLocation: prefs.showLocation,
                                            plaudMatch: appState.plaud.link(for: event),
                                            isExpanded: expandedEventID == event.id,
                                            onToggleExpand: {
                                                withAnimation(EquinoxDesign.expandAnimation) {
                                                    if expandedEventID == event.id {
                                                        expandedEventID = nil
                                                    } else {
                                                        expandedEventID = event.id
                                                        appState.panel.selectedEvent = event
                                                    }
                                                }
                                            },
                                            onRespond: { status in
                                                appState.panel.panelFeedback = nil
                                                if let error = await appState.respondToInvitation(event: event, status: status) {
                                                    appState.panel.panelFeedback = error
                                                }
                                            }
                                        )
                                        .simultaneousGesture(
                                            TapGesture(count: 1).onEnded {
                                                if expandedEventID == event.id {
                                                    appState.panel.selectedEvent = event
                                                    appState.panel.isEventDetailPresented = true
                                                }
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
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
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
                        } else if expandedEventID == eventID {
                            expandedEventID = nil
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
            appState.events.extendFetchRangeForAgendaIfNeeded()
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

    private var agendaSections: [(date: CalendarDate, events: [DayEvent])] {
        AgendaSections.sections(
            from: appState.events.selectedDate,
            days: prefs.showEventDays,
            showEmptyDays: prefs.showDaysWithNoEvents,
            eventsFor: appState.events.events(for:)
        )
    }
}
