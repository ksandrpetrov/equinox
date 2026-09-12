import SwiftUI

struct EventDetailHeroHeader: View {
    let event: DayEvent

    private var isDeclined: Bool {
        event.participationStatus == .declined
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
            Text(event.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .opacity(isDeclined ? EquinoxDesign.StateOpacity.declined : 1)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: EquinoxDesign.spacingXS) {
                EventDetailCalendarChip(
                    title: event.calendarTitle,
                    color: event.swiftUIColor
                )

                if let status = event.participationStatus {
                    EventDetailStatusChip(status: status)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EventDetailCalendarChip: View {
    let title: String
    let color: Color

    var body: some View {
        EquinoxChip(
            text: title,
            dotColor: color,
            foreground: .secondary,
            background: EquinoxDesign.ColorToken.interactionRest,
            usesCapsule: true
        )
    }
}

struct EventDetailStatusChip: View {
    let status: EventParticipationStatus

    var body: some View {
        EquinoxChip(
            text: status.localizedLabel,
            symbol: status.detailSymbolName,
            foreground: status.chipForeground,
            background: status.chipBackground,
            usesCapsule: true
        )
    }
}

struct EventDetailMetadataCard: View {
    let rows: [EventDetailMetadataRowModel]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                EventDetailMetadataRow(model: row)
                if index < rows.count - 1 {
                    Rectangle()
                        .fill(EquinoxDesign.ColorToken.separator)
                        .frame(height: 1)
                        .padding(.leading, EquinoxDesign.ControlWidth.metadataIcon + EquinoxDesign.spacingMD)
                }
            }
        }
        .padding(.vertical, EquinoxDesign.spacingXS)
        .background { EventDetailCardBackground() }
    }
}

struct EventDetailMetadataRowModel {
    let symbol: String
    let title: String?
    let value: String
    var tint: Color = .secondary
}

struct EventDetailMetadataRow: View {
    let model: EventDetailMetadataRowModel

    var body: some View {
        HStack(alignment: .top, spacing: EquinoxDesign.spacingMD) {
            Image(systemName: model.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(model.tint)
                .frame(width: EquinoxDesign.ControlWidth.metadataIcon, height: EquinoxDesign.ControlWidth.metadataIcon)

            VStack(alignment: .leading, spacing: EquinoxDesign.spacingMicro) {
                if let title = model.title {
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(model.value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, EquinoxDesign.spacingMD)
        .padding(.vertical, EquinoxDesign.spacingSM + EquinoxDesign.spacingMicro)
    }
}

struct EventDetailNotesCard: View {
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
            Label(String(localized: "Notes", bundle: .equinox, comment: "Event detail notes section"), systemImage: "note.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(notes)
                .font(.body)
                .foregroundStyle(.primary.opacity(EquinoxDesign.StateOpacity.notesBody))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EquinoxDesign.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { EventDetailCardBackground() }
    }
}

struct EventDetailJoinButton: View {
    let url: URL
    let action: () -> Void

    var body: some View {
        EquinoxJoinButton(url: url, variant: .full, action: action)
    }
}

private extension EventParticipationStatus {
    var detailSymbolName: String {
        switch self {
        case .unknown, .pending: "clock.badge.questionmark"
        case .accepted: "checkmark.circle.fill"
        case .tentative: "questionmark.circle.fill"
        case .declined: "xmark.circle.fill"
        case .delegated: "person.2.fill"
        case .completed: "checkmark.circle.fill"
        case .inProcess: "clock.arrow.circlepath"
        }
    }
}
