import SwiftUI

struct EventDetailView: View {
    @Bindable var appState: AppState
    let event: DayEvent
    let metrics: SizeMetrics
    @Environment(\.dismiss) private var dismiss
    @State private var isResponding = false
    @State private var actionError: String?

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
                VStack(alignment: .leading, spacing: ModalDesign.sectionSpacing) {
                    if let actionError {
                        ModalErrorBanner(message: actionError)
                    }

                    HStack(spacing: EquinoxDesign.spacingSM) {
                        Circle()
                            .fill(event.swiftUIColor)
                            .frame(width: 12, height: 12)
                        Text(event.title)
                            .font(.title3.weight(.semibold))
                            .opacity(event.participationStatus == .declined ? 0.6 : 1)
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: EquinoxDesign.spacingMD) {
                        Label(whenString, systemImage: "clock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let location = event.location, !location.isEmpty {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                        }

                        Label(event.calendarTitle, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if event.showsRSVPControls, let status = event.participationStatus {
                            Label(status.detailStatusLabel, systemImage: "person.crop.circle.badge.clock")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let notes = event.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if event.showsRSVPControls {
                        EventRSVPBar(
                            status: event.participationStatus,
                            isCompact: false,
                            isResponding: isResponding
                        ) { status in
                            respond(to: status)
                        }
                    }

                    if let url = event.joinURL {
                        Button(String(localized: "Join Meeting", comment: "")) {
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(ModalDesign.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
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
            if let error = await appState.deleteEvent(identifier: id) {
                actionError = error
            } else {
                dismiss()
            }
        }
    }
}
