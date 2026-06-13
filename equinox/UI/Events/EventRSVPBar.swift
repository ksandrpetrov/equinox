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

struct EventRSVPBar: View {
    let status: EventParticipationStatus?
    var isCompact: Bool = false
    var isResponding: Bool = false
    let onRespond: (EventParticipationStatus) -> Void

    var body: some View {
        HStack(spacing: isCompact ? 6 : 8) {
            rsvpButton(
                .accepted,
                symbol: "checkmark.circle.fill",
                label: String(localized: "Accept", comment: "RSVP accept"),
                tint: Color.green
            )
            rsvpButton(
                .tentative,
                symbol: "questionmark.circle",
                label: String(localized: "Maybe", comment: "RSVP maybe"),
                tint: Color.orange
            )
            rsvpButton(
                .declined,
                symbol: "xmark.circle",
                label: String(localized: "Decline", comment: "RSVP decline"),
                tint: Color.red
            )
        }
        .padding(.horizontal, isCompact ? 6 : 8)
        .padding(.vertical, isCompact ? 6 : 8)
        .background {
            RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                .fill(EquinoxDesign.ColorToken.surfaceSecondary.opacity(0.85))
                .overlay {
                    RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }
        }
        .opacity(isResponding ? 0.55 : 1)
        .disabled(isResponding)
        .animation(EquinoxDesign.hoverAnimation, value: isResponding)
    }

    private func rsvpButton(
        _ targetStatus: EventParticipationStatus,
        symbol: String,
        label: String,
        tint: Color
    ) -> some View {
        let isSelected = status == targetStatus
        return Button {
            onRespond(targetStatus)
        } label: {
            HStack(spacing: isCompact ? 4 : 6) {
                Image(systemName: symbol)
                    .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                if !isCompact || isSelected {
                    Text(label)
                        .font(isCompact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isSelected ? tint : .secondary)
            .frame(maxWidth: isCompact ? nil : .infinity)
            .padding(.horizontal, isCompact ? 8 : 10)
            .padding(.vertical, isCompact ? 6 : 8)
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

private extension EquinoxDesign.ColorToken {
    static let pendingBackground = Color("PendingBackgroundColor")
}
