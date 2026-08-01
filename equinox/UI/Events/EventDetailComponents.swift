import SwiftUI

struct EventDetailHeroHeader: View {
    let event: DayEvent

    private var isDeclined: Bool {
        event.participationStatus == .declined
    }

    var body: some View {
        HStack(alignment: .top, spacing: EquinoxDesign.spacingMD) {
            EventStripeView(
                color: event.swiftUIColor,
                width: EquinoxDesign.EventStripe.widthHero,
                verticalPadding: EquinoxDesign.spacingMicro
            )

            VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                Text(event.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .opacity(isDeclined ? EquinoxDesign.StateOpacity.declined : 1)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: EquinoxDesign.spacingSM) {
                    EventDetailCalendarChip(
                        title: event.calendarTitle,
                        color: event.swiftUIColor
                    )

                    if event.showsRSVPControls, let status = event.participationStatus {
                        EventDetailStatusChip(status: status)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                .background {
                    Circle()
                        .fill(model.tint.opacity(EquinoxDesign.StateOpacity.metadataIconBackground))
                }

            VStack(alignment: .leading, spacing: EquinoxDesign.spacingMicro) {
                if let title = model.title {
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
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

struct EventDetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, EquinoxDesign.spacingXS)

            content()
        }
    }
}

struct EventDetailNotesCard: View {
    let notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
            Label(String(localized: "Notes", comment: "Event detail notes section"), systemImage: "note.text")
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

struct EventDetailSecondaryActionButton: View {
    let title: String
    let symbol: String
    var subtitle: String? = nil
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: EquinoxDesign.spacingMD) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: EquinoxDesign.ControlWidth.metadataIcon, height: EquinoxDesign.ControlWidth.metadataIcon)

                VStack(alignment: .leading, spacing: EquinoxDesign.spacingMicro) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, EquinoxDesign.spacingMD)
            .padding(.vertical, EquinoxDesign.spacingSM + EquinoxDesign.spacingMicro)
            .equinoxCard(style: .row, isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isHovered)
    }
}

private extension EventParticipationStatus {
    var detailSymbolName: String {
        switch self {
        case .unknown, .pending: "clock.badge.questionmark"
        case .accepted: "checkmark.circle.fill"
        case .tentative: "questionmark.circle.fill"
        case .declined: "xmark.circle.fill"
        }
    }
}
