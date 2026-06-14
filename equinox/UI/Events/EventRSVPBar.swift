import SwiftUI

struct EventRSVPRespondBadge: View {
    var body: some View {
        Text(String(localized: "Respond", comment: "RSVP pending badge"))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.primary.opacity(0.85))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule(style: .continuous)
                    .fill(EquinoxDesign.ColorToken.pendingBackground)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    }
            }
    }
}

enum EventRSVPBarLayout {
    case compact
    case standard
    case detail
}

struct EventRSVPBar: View {
    let status: EventParticipationStatus?
    var layout: EventRSVPBarLayout = .standard
    var isResponding: Bool = false
    let onRespond: (EventParticipationStatus) -> Void

    var body: some View {
        Group {
            switch layout {
            case .compact:
                compactBar
            case .standard:
                standardBar
            case .detail:
                detailBar
            }
        }
        .opacity(isResponding ? 0.55 : 1)
        .disabled(isResponding)
        .animation(EquinoxDesign.hoverAnimation, value: isResponding)
    }

    private var compactBar: some View {
        HStack(spacing: 6) {
            rsvpButton(.accepted, symbol: "checkmark.circle.fill", label: acceptLabel, tint: .green, compact: true)
            rsvpButton(.tentative, symbol: "questionmark.circle", label: maybeLabel, tint: .orange, compact: true)
            rsvpButton(.declined, symbol: "xmark.circle", label: declineLabel, tint: .red, compact: true)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background { barBackground }
    }

    private var standardBar: some View {
        HStack(spacing: 8) {
            rsvpButton(.accepted, symbol: "checkmark.circle.fill", label: acceptLabel, tint: .green, compact: false)
            rsvpButton(.tentative, symbol: "questionmark.circle", label: maybeLabel, tint: .orange, compact: false)
            rsvpButton(.declined, symbol: "xmark.circle", label: declineLabel, tint: .red, compact: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background { barBackground }
    }

    private var detailBar: some View {
        HStack(spacing: EquinoxDesign.spacingSM) {
            detailButton(.accepted, symbol: "checkmark", label: acceptLabel, tint: .green)
            detailButton(.tentative, symbol: "questionmark", label: maybeLabel, tint: .orange)
            detailButton(.declined, symbol: "xmark", label: declineLabel, tint: .red)
        }
        .padding(EquinoxDesign.spacingSM)
        .background { barBackground }
    }

    private var barBackground: some View {
        RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
            .fill(EquinoxDesign.ColorToken.surfaceSecondary.opacity(0.85))
            .overlay {
                RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }

    private var acceptLabel: String {
        String(localized: "Accept", comment: "RSVP accept")
    }

    private var maybeLabel: String {
        String(localized: "Maybe", comment: "RSVP maybe")
    }

    private var declineLabel: String {
        String(localized: "Decline", comment: "RSVP decline")
    }

    private func rsvpButton(
        _ targetStatus: EventParticipationStatus,
        symbol: String,
        label: String,
        tint: Color,
        compact: Bool
    ) -> some View {
        let isSelected = status == targetStatus
        return Button {
            onRespond(targetStatus)
        } label: {
            HStack(spacing: compact ? 4 : 6) {
                Image(systemName: symbol)
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                if !compact || isSelected {
                    Text(label)
                        .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(isSelected ? tint : .secondary)
            .frame(maxWidth: compact ? nil : .infinity)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 6 : 8)
            .background {
                RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.16) : Color.primary.opacity(0.04))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        .help(label)
    }

    private func detailButton(
        _ targetStatus: EventParticipationStatus,
        symbol: String,
        label: String,
        tint: Color
    ) -> some View {
        let isSelected = status == targetStatus
        return Button {
            onRespond(targetStatus)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                Text(label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? tint : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, EquinoxDesign.spacingSM + 2)
            .background {
                RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.16) : Color.primary.opacity(0.04))
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        .help(label)
    }
}
