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

            ViewThatFits(in: .horizontal) {
                HStack(spacing: EquinoxDesign.spacingMD) { eventLabels }
                VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) { eventLabels }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var eventLabels: some View {
        EventDetailCalendarLabel(title: event.calendarTitle, color: event.swiftUIColor)
        if let status = event.participationStatus {
            EventDetailStatusLabel(status: status)
        }
    }
}

struct EventDetailCalendarLabel: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: EquinoxDesign.spacingXS) {
            Circle()
                .fill(color)
                .frame(width: EquinoxDesign.ChipMetrics.detailDotSize, height: EquinoxDesign.ChipMetrics.detailDotSize)
            Text(title)
                .lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

struct EventDetailStatusLabel: View {
    let status: EventParticipationStatus

    var body: some View {
        Label(status.detailStatusLabel, systemImage: status.detailSymbolName)
            .font(.caption)
            .foregroundStyle(status.chipForeground)
            .fixedSize()
    }
}

struct EventDetailMetadataCard: View {
    let rows: [EventDetailMetadataRowModel]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                EventDetailMetadataRow(model: row)
                if index < rows.count - 1 {
                    SettingsDivider()
                }
            }
        }
        .padding(.vertical, EquinoxDesign.spacingXS)
        .overlay(alignment: .top) { SettingsDivider() }
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
        .padding(.horizontal, EquinoxDesign.spacingXS)
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
        .padding(.vertical, EquinoxDesign.spacingMD)
        .padding(.horizontal, EquinoxDesign.spacingXS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { SettingsDivider() }
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
