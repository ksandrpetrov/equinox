import SwiftUI

struct EventRSVPRespondBadge: View {
    var body: some View {
        EquinoxBadge(
            text: String(localized: "Respond", comment: "RSVP pending badge"),
            tint: EquinoxDesign.ColorToken.accent
        )
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .opacity(isResponding ? EquinoxDesign.StateOpacity.responding : 1)
        .disabled(isResponding)
        .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isResponding)
    }

    private var compactBar: some View {
        HStack(spacing: EquinoxDesign.spacingSM - 2) {
            rsvpButton(.accepted, symbol: "checkmark.circle.fill", label: acceptLabel, tint: EquinoxDesign.ColorToken.semanticGreen, compact: true)
            rsvpButton(.tentative, symbol: "questionmark.circle", label: maybeLabel, tint: EquinoxDesign.ColorToken.semanticOrange, compact: true)
            rsvpButton(.declined, symbol: "xmark.circle", label: declineLabel, tint: EquinoxDesign.ColorToken.semanticRed, compact: true)
        }
        .padding(.horizontal, EquinoxDesign.spacingSM - 2)
        .padding(.vertical, EquinoxDesign.spacingSM - 2)
    }

    private var standardBar: some View {
        HStack(spacing: EquinoxDesign.spacingSM) {
            rsvpButton(.accepted, symbol: "checkmark.circle.fill", label: acceptLabel, tint: EquinoxDesign.ColorToken.semanticGreen, compact: false)
            rsvpButton(.tentative, symbol: "questionmark.circle", label: maybeLabel, tint: EquinoxDesign.ColorToken.semanticOrange, compact: false)
            rsvpButton(.declined, symbol: "xmark.circle", label: declineLabel, tint: EquinoxDesign.ColorToken.semanticRed, compact: false)
        }
        .padding(.horizontal, EquinoxDesign.spacingSM)
        .padding(.vertical, EquinoxDesign.spacingSM)
    }

    private var detailBar: some View {
        HStack(spacing: EquinoxDesign.spacingSM) {
            detailButton(.accepted, symbol: "checkmark", label: acceptLabel, tint: EquinoxDesign.ColorToken.semanticGreen)
            detailButton(.tentative, symbol: "questionmark", label: maybeLabel, tint: EquinoxDesign.ColorToken.semanticOrange)
            detailButton(.declined, symbol: "xmark", label: declineLabel, tint: EquinoxDesign.ColorToken.semanticRed)
        }
        .padding(EquinoxDesign.spacingSM)
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
            HStack(spacing: compact ? EquinoxDesign.spacingXS : EquinoxDesign.spacingSM - 2) {
                Image(systemName: symbol)
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                if !compact || isSelected {
                    Text(label)
                        .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(isSelected ? tint : .secondary)
            .frame(maxWidth: compact ? nil : .infinity)
            .padding(.horizontal, compact ? EquinoxDesign.spacingSM : EquinoxDesign.spacingSM + 2)
            .padding(.vertical, compact ? EquinoxDesign.spacingSM - 2 : EquinoxDesign.spacingSM)
            .background {
                RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                    .fill(isSelected ? tint.opacity(EquinoxDesign.StateOpacity.selectionTint) : EquinoxDesign.ColorToken.interactionSubtle)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                                .strokeBorder(tint.opacity(EquinoxDesign.StateOpacity.selectionBorder), lineWidth: 1)
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
            VStack(spacing: EquinoxDesign.spacingSM - 2) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                Text(label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? tint : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, EquinoxDesign.spacingSM + EquinoxDesign.spacingMicro)
            .background {
                RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                    .fill(isSelected ? tint.opacity(EquinoxDesign.StateOpacity.selectionTint) : EquinoxDesign.ColorToken.interactionSubtle)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                                .strokeBorder(tint.opacity(EquinoxDesign.StateOpacity.selectionBorder), lineWidth: 1)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        .help(label)
    }
}
