import SwiftUI

struct EventDetailHeroHeader: View {
    let event: DayEvent
    var isCloseDisabled = false
    var onClose: (() -> Void)?

    private var isDeclined: Bool {
        event.participationStatus == .declined
    }

    var body: some View {
        HStack(alignment: .top, spacing: EquinoxDesign.spacingMD) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(event.swiftUIColor)
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                Text(event.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .opacity(isDeclined ? 0.65 : 1)
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

            if let onClose {
                EventDetailCloseButton(
                    isDisabled: isCloseDisabled,
                    action: onClose
                )
            }
        }
        .padding(EquinoxDesign.spacingMD)
        .background { EventDetailCardBackground() }
    }
}

private struct EventDetailCloseButton: View {
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: EquinoxDesign.toolbarButtonSize, height: EquinoxDesign.toolbarButtonSize)
                .background {
                    Circle()
                        .fill(Color.primary.opacity(isHovered ? 0.1 : 0.06))
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .keyboardShortcut(.cancelAction)
        .help(String(localized: "Close", comment: "Event detail close button help"))
        .accessibilityLabel(String(localized: "Close", comment: "Event detail close button"))
        .onHover { isHovered = $0 }
        .animation(EquinoxDesign.hoverAnimation, value: isHovered)
    }
}

struct EventDetailCalendarChip: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.05))
        }
    }
}

struct EventDetailStatusChip: View {
    let status: EventParticipationStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.detailSymbolName)
                .font(.caption2.weight(.semibold))
            Text(status.localizedLabel)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(status.chipForeground)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule(style: .continuous)
                .fill(status.chipBackground)
        }
    }
}

struct EventDetailMetadataCard: View {
    let rows: [EventDetailMetadataRowModel]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                EventDetailMetadataRow(model: row)
                if index < rows.count - 1 {
                    Divider()
                        .padding(.leading, 44)
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
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(model.tint.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.vertical, EquinoxDesign.spacingSM + 2)
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
                .foregroundStyle(.primary.opacity(0.9))
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

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: EquinoxDesign.spacingMD) {
                Image(systemName: JoinURLPresentation.meetingSystemImage(for: url))
                    .font(.title3.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 36, height: 36)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Join Meeting", comment: ""))
                        .font(.headline)
                    Text(JoinURLPresentation.meetingDisplayName(for: url))
                        .font(.caption)
                        .opacity(0.85)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, EquinoxDesign.spacingMD)
            .padding(.vertical, EquinoxDesign.spacingMD)
            .background {
                RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor,
                                Color.accentColor.opacity(isHovered ? 0.82 : 0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.accentColor.opacity(isHovered ? 0.35 : 0.22), radius: 8, y: 3)
            }
            .scaleEffect(isHovered && !reduceMotion ? 1.01 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isHovered)
        .accessibilityLabel(String(localized: "Join Meeting", comment: ""))
        .accessibilityHint(JoinURLPresentation.meetingDisplayName(for: url))
    }
}

struct EventDetailSecondaryActionButton: View {
    let title: String
    let symbol: String
    var subtitle: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: EquinoxDesign.spacingMD) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
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
            .padding(.vertical, EquinoxDesign.spacingSM + 2)
            .background {
                RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.07 : 0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(EquinoxDesign.hoverAnimation, value: isHovered)
    }
}

private struct EventDetailCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
            .fill(EquinoxDesign.ColorToken.surfaceSecondary.opacity(0.72))
            .overlay {
                RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
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
