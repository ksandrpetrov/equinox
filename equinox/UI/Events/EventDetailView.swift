import SwiftUI

struct EventDetailView: View {
    @Bindable var appState: AppState
    let event: DayEvent
    let metrics: SizeMetrics
    @Environment(\.dismiss) private var dismiss
    @State private var isResponding = false
    @State private var actionError: String?
    @State private var manualPlaudURL = ""
    @State private var showManualPlaudLink = false

    private var plaudMatch: PlaudEventMatch? {
        appState.plaud.link(for: event)
    }

    private var isPastEvent: Bool {
        event.endDate < Date()
    }

    private var displayNotes: String? {
        JoinURLDetection.notesForDisplay(notes: event.notes, excludingJoinURL: event.joinURL)
    }

    var body: some View {
        ModalSheetScaffold(
            title: String(localized: "Event Details", comment: "Event detail sheet title"),
            metrics: metrics,
            destructiveTitle: event.allowsContentModifications
                ? String(localized: "Delete", comment: "")
                : nil,
            minHeight: nil,
            onCancel: { dismiss() },
            onDestructive: event.allowsContentModifications ? { deleteEvent() } : nil
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: EquinoxDesign.spacingLG) {
                    if let actionError {
                        ModalErrorBanner(message: actionError)
                    }

                    EventDetailHeroHeader(event: event)

                    EventDetailMetadataCard(rows: metadataRows)

                    if let displayNotes {
                        EventDetailNotesCard(notes: displayNotes)
                    }

                    if event.showsRSVPControls {
                        EventDetailSection(
                            title: String(localized: "Your response", comment: "Event detail RSVP section")
                        ) {
                            EventRSVPBar(
                                status: event.participationStatus,
                                layout: .detail,
                                isResponding: isResponding
                            ) { status in
                                respond(to: status)
                            }
                        }
                    }

                    if hasActionSection {
                        VStack(spacing: EquinoxDesign.spacingSM) {
                            if let url = event.joinURL {
                                EventDetailJoinButton(url: url) {
                                    URLOpener.open(url)
                                }
                            }

                            if isPastEvent, appState.preferences.isPlaudEnabled {
                                plaudSection
                            }
                        }
                    }
                }
                .padding(ModalDesign.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            appState.plaud.refreshMatchesIfNeeded()
        }
    }

    private var hasActionSection: Bool {
        event.joinURL != nil || (isPastEvent && appState.preferences.isPlaudEnabled)
    }

    private var metadataRows: [EventDetailMetadataRowModel] {
        var rows: [EventDetailMetadataRowModel] = [
            EventDetailMetadataRowModel(
                symbol: "clock",
                title: String(localized: "When", comment: "Event detail metadata label"),
                value: whenString,
                tint: .secondary
            )
        ]

        if let location = event.location, !location.isEmpty {
            rows.append(
                EventDetailMetadataRowModel(
                    symbol: "mappin.and.ellipse",
                    title: String(localized: "Location", comment: "Event detail metadata label"),
                    value: location,
                    tint: .secondary
                )
            )
        }

        if event.showsRSVPControls, let status = event.participationStatus {
            rows.append(
                EventDetailMetadataRowModel(
                    symbol: "person.crop.circle.badge.clock",
                    title: String(localized: "Attendance", comment: "Event detail metadata label"),
                    value: status.detailStatusLabel,
                    tint: status.chipForeground
                )
            )
        }

        return rows
    }

    @ViewBuilder
    private var plaudSection: some View {
        if let match = plaudMatch {
            EventDetailSecondaryActionButton(
                title: String(localized: "Open in Plaud", comment: "Plaud recording button"),
                symbol: "waveform",
                subtitle: String(localized: "Recording available", comment: "Plaud match subtitle")
            ) {
                URLOpener.open(match.webURL)
            }
        } else if showManualPlaudLink {
            VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                TextField(
                    String(localized: "https://web.plaud.ai/file/…", comment: "Plaud manual link placeholder"),
                    text: $manualPlaudURL
                )
                .textFieldStyle(.roundedBorder)

                HStack {
                    Button(String(localized: "Save Link", comment: "Plaud manual link save")) {
                        saveManualPlaudLink()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(manualPlaudURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(String(localized: "Cancel", comment: "")) {
                        showManualPlaudLink = false
                        manualPlaudURL = ""
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(EquinoxDesign.spacingMD)
            .background {
                RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                    .fill(EquinoxDesign.ColorToken.surfaceSecondary.opacity(0.72))
            }
        } else {
            EventDetailSecondaryActionButton(
                title: String(localized: "Link Plaud recording…", comment: "Plaud manual link action"),
                symbol: "link.badge.plus"
            ) {
                showManualPlaudLink = true
            }
        }
    }

    private func saveManualPlaudLink() {
        let trimmed = manualPlaudURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            actionError = String(
                localized: "Paste a Plaud URL like https://web.plaud.ai/file/…",
                comment: "Plaud manual link error"
            )
            return
        }
        actionError = nil
        Task {
            if let error = await appState.plaud.saveManualLink(for: event, url: url) {
                actionError = error
            } else {
                showManualPlaudLink = false
                manualPlaudURL = ""
            }
        }
    }

    private var whenString: String {
        if event.isEventAllDay { return String(localized: "All-day", comment: "") }
        return EquinoxFormatters.mediumDateTime(from: event.startDate, to: event.endDate)
    }

    private func respond(to status: EventParticipationStatus) {
        isResponding = true
        actionError = nil
        Task {
            if let error = await appState.respondToInvitation(event: event, status: status) {
                actionError = error
            }
            isResponding = false
        }
    }

    private func deleteEvent() {
        actionError = nil
        Task {
            guard let id = event.eventIdentifier else { return }
            if let error = await appState.events.deleteEvent(identifier: id) {
                actionError = error
            } else {
                dismiss()
            }
        }
    }
}

private extension EventParticipationStatus {
    var chipForeground: Color {
        switch self {
        case .unknown, .pending: .primary.opacity(0.85)
        case .accepted: .green
        case .tentative: .orange
        case .declined: .red
        }
    }
}
