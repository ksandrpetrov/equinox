import SwiftUI

// MARK: - Button styles

enum EquinoxButtonVariant {
    case prominent
    case bordered
    case plain
    case destructive
}

enum EquinoxButtonSize {
    case regular
    case small
}

struct EquinoxButtonStyle: ButtonStyle {
    var variant: EquinoxButtonVariant = .bordered
    var size: EquinoxButtonSize = .regular

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size == .small ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .foregroundStyle(foregroundColor(isPressed: configuration.isPressed))
            .background { background(isPressed: configuration.isPressed) }
            .overlay { borderOverlay(isPressed: configuration.isPressed) }
            .scaleEffect(pressScale(isPressed: configuration.isPressed))
            .opacity(isEnabled ? 1 : EquinoxDesign.StateOpacity.disabled)
            .onHover { isHovered = $0 }
            .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: configuration.isPressed)
            .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isHovered)
    }

    private var horizontalPadding: CGFloat {
        size == .small ? EquinoxDesign.spacingSM : EquinoxDesign.spacingMD
    }

    private var verticalPadding: CGFloat {
        size == .small ? EquinoxDesign.spacingXS : EquinoxDesign.spacingSM - 2
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .prominent:
            return EquinoxDesign.onAccentForeground
        case .destructive:
            return EquinoxDesign.ColorToken.semanticRed
        case .bordered, .plain:
            return .primary
        }
    }

    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
        switch variant {
        case .prominent:
            shape.fill(isPressed || isHovered ? EquinoxDesign.ColorToken.accentStrong : EquinoxDesign.ColorToken.accent)
        case .destructive:
            shape.fill(EquinoxDesign.ColorToken.semanticRed.opacity(interactionFill(isPressed: isPressed)))
        case .bordered, .plain:
            if variant == .plain && !isPressed && !isHovered {
                shape.fill(Color.clear)
            } else {
                shape.fill(interactionColor(isPressed: isPressed))
            }
        }
    }

    @ViewBuilder
    private func borderOverlay(isPressed: Bool) -> some View {
        if variant == .bordered || variant == .destructive {
            RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                .strokeBorder(
                    variant == .destructive
                        ? EquinoxDesign.ColorToken.semanticRed.opacity(EquinoxDesign.StateOpacity.selectionBorder)
                        : EquinoxDesign.ColorToken.hairlineBorder,
                    lineWidth: 1
                )
        }
    }

    private func interactionColor(isPressed: Bool) -> Color {
        if isPressed { return EquinoxDesign.ColorToken.interactionPress }
        if isHovered { return EquinoxDesign.ColorToken.interactionHover }
        return EquinoxDesign.ColorToken.interactionRest
    }

    private func interactionFill(isPressed: Bool) -> Double {
        if isPressed { return EquinoxDesign.StateOpacity.selectionTint }
        if isHovered { return EquinoxDesign.StateOpacity.selectionTint - 0.02 }
        return EquinoxDesign.StateOpacity.selectionTint - 0.04
    }

    private func pressScale(isPressed: Bool) -> CGFloat {
        guard isEnabled, isPressed, !reduceMotion else { return 1 }
        return EquinoxDesign.pressScale
    }
}

// MARK: - Card modifier

enum EquinoxCardStyle {
    case secondary
    case subtle
    case raised
}

struct EquinoxCardModifier: ViewModifier {
    var style: EquinoxCardStyle = .subtle
    var cornerRadius: CGFloat = EquinoxDesign.cardRadius
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isHovered ? EquinoxDesign.ColorToken.interactionHover : EquinoxDesign.ColorToken.hairlineBorder,
                        lineWidth: 1
                    )
            }
    }

    private var fillColor: Color {
        switch style {
        case .secondary:
            EquinoxDesign.ColorToken.surfaceSecondary.opacity(EquinoxDesign.StateOpacity.disabled)
        case .subtle:
            EquinoxDesign.ColorToken.interactionSubtle
        case .raised:
            EquinoxDesign.ColorToken.surfaceRaised
        }
    }
}

extension View {
    func equinoxCard(
        style: EquinoxCardStyle = .subtle,
        cornerRadius: CGFloat = EquinoxDesign.cardRadius,
        isHovered: Bool = false
    ) -> some View {
        modifier(EquinoxCardModifier(style: style, cornerRadius: cornerRadius, isHovered: isHovered))
    }
}

// MARK: - Badge & Chip

struct EquinoxBadge: View {
    let text: String
    var tint: Color = EquinoxDesign.ColorToken.accent

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, EquinoxDesign.ChipMetrics.badgeHorizontalPadding)
            .padding(.vertical, EquinoxDesign.ChipMetrics.badgeVerticalPadding)
            .background {
                Capsule(style: .continuous)
                    .fill(tint.opacity(EquinoxDesign.StateOpacity.badgeTint))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(tint.opacity(EquinoxDesign.StateOpacity.badgeBorder), lineWidth: 0.5)
                    }
            }
    }
}

struct EquinoxChip: View {
    let text: String
    var dotColor: Color? = nil
    var symbol: String? = nil
    var foreground: Color = .secondary
    var background: Color = EquinoxDesign.ColorToken.interactionSubtle
    var border: Color = EquinoxDesign.ColorToken.hairlineBorder
    var usesCapsule = false

    var body: some View {
        HStack(spacing: EquinoxDesign.ChipMetrics.spacing) {
            if let dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(
                        width: EquinoxDesign.ChipMetrics.detailDotSize,
                        height: EquinoxDesign.ChipMetrics.detailDotSize
                    )
            }
            if let symbol {
                Image(systemName: symbol)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, EquinoxDesign.ChipMetrics.detailHorizontalPadding)
        .padding(.vertical, EquinoxDesign.ChipMetrics.detailVerticalPadding)
        .background {
            if usesCapsule {
                Capsule(style: .continuous)
                    .fill(background)
            } else {
                RoundedRectangle(cornerRadius: EquinoxDesign.chipRadius, style: .continuous)
                    .fill(background)
                    .overlay {
                        RoundedRectangle(cornerRadius: EquinoxDesign.chipRadius, style: .continuous)
                            .strokeBorder(border, lineWidth: 0.5)
                    }
            }
        }
    }
}

// MARK: - Event detail card

struct EventDetailCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
            .fill(EquinoxDesign.ColorToken.surfaceSecondary.opacity(EquinoxDesign.StateOpacity.cardBackground))
            .overlay {
                RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                    .strokeBorder(EquinoxDesign.ColorToken.hairlineBorder, lineWidth: 1)
            }
    }
}

// MARK: - Banner

enum EquinoxBannerStyle {
    case error
    case warning
    case info
}

enum EquinoxBannerPresentation {
    case filled
    case card
}

struct EquinoxBanner: View {
    let message: String
    var style: EquinoxBannerStyle = .error
    var presentation: EquinoxBannerPresentation = .card
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: EquinoxDesign.spacingSM) {
            Image(systemName: iconName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(foregroundColor)
            Text(message)
                .font(.footnote)
                .foregroundStyle(foregroundColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(EquinoxButtonStyle(variant: style == .error ? .prominent : .bordered, size: .small))
            }
        }
        .padding(.horizontal, EquinoxDesign.spacingMD)
        .padding(.vertical, EquinoxDesign.spacingSM)
        .background {
            if presentation == .filled {
                RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                    .fill(filledBackgroundColor)
            }
        }
        .modifier(CardPresentationModifier(presentation: presentation))
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch style {
        case .error: "exclamationmark.triangle.fill"
        case .warning: "info.circle.fill"
        case .info: "info.circle"
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .error: EquinoxDesign.ColorToken.semanticRed
        case .warning: EquinoxDesign.ColorToken.semanticOrange
        case .info: .secondary
        }
    }

    private var filledBackgroundColor: Color {
        switch style {
        case .error: EquinoxDesign.ColorToken.semanticRed.opacity(EquinoxDesign.StateOpacity.badgeTint)
        case .warning: EquinoxDesign.ColorToken.semanticOrange.opacity(EquinoxDesign.StateOpacity.badgeTint)
        case .info: Color.secondary.opacity(EquinoxDesign.StateOpacity.badgeTint)
        }
    }
}

private struct CardPresentationModifier: ViewModifier {
    let presentation: EquinoxBannerPresentation

    func body(content: Content) -> some View {
        if presentation == .card {
            content.equinoxCard(style: .subtle, cornerRadius: EquinoxDesign.radiusSM)
        } else {
            content
        }
    }
}

// MARK: - Join button

struct EquinoxJoinButton: View {
    let url: URL
    var variant: Variant = .full
    var metrics: SizeMetrics? = nil
    let action: () -> Void

    enum Variant {
        case full
        case compact
    }

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            switch variant {
            case .full:
                fullLabel
            case .compact:
                compactLabel
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isHovered)
        .accessibilityLabel(String(localized: "Join Meeting", comment: ""))
        .accessibilityHint(JoinURLPresentation.meetingDisplayName(for: url))
    }

    private var fullLabel: some View {
        HStack(spacing: EquinoxDesign.spacingMD) {
            Image(systemName: JoinURLPresentation.meetingSystemImage(for: url))
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: EquinoxDesign.ControlWidth.joinIcon, height: EquinoxDesign.ControlWidth.joinIcon)
                .background {
                    Circle()
                        .fill(EquinoxDesign.onAccentForeground.opacity(EquinoxDesign.StateOpacity.joinGlassOverlay))
                }

            VStack(alignment: .leading, spacing: EquinoxDesign.spacingMicro) {
                Text(String(localized: "Join Meeting", comment: ""))
                    .font(.headline)
                Text(JoinURLPresentation.meetingDisplayName(for: url))
                    .font(.caption)
                    .opacity(EquinoxDesign.StateOpacity.joinSubtitle)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.bold))
                .opacity(EquinoxDesign.StateOpacity.joinSubtitle)
        }
        .foregroundStyle(EquinoxDesign.onAccentForeground)
        .padding(.horizontal, EquinoxDesign.spacingMD)
        .padding(.vertical, EquinoxDesign.spacingMD)
        .background { joinBackground }
        .scaleEffect(isHovered && !reduceMotion ? EquinoxDesign.joinHoverScale : 1)
    }

    private var compactLabel: some View {
        Image(systemName: JoinURLPresentation.meetingSystemImage(for: url))
            .font(.caption.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(EquinoxDesign.onAccentForeground)
            .frame(width: metrics?.toolbarButtonSize ?? EquinoxDesign.toolbarButtonSize,
                   height: metrics?.toolbarButtonSize ?? EquinoxDesign.toolbarButtonSize)
            .background { joinBackground }
            .scaleEffect(isHovered && !reduceMotion ? EquinoxDesign.joinHoverScale : 1)
    }

    private var joinBackground: some View {
        RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        EquinoxDesign.ColorToken.accent,
                        EquinoxDesign.ColorToken.accent.opacity(isHovered ? 0.82 : 0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(
                color: EquinoxDesign.ColorToken.accent.opacity(
                    isHovered ? EquinoxDesign.ShadowToken.joinHoverOpacity : EquinoxDesign.ShadowToken.joinRestOpacity
                ),
                radius: EquinoxDesign.ShadowToken.joinRadius,
                y: EquinoxDesign.ShadowToken.joinYOffset
            )
    }
}
