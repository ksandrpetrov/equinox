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

/// Keep the shared variants while delegating interaction, focus and rendering to macOS.
struct EquinoxButtonStyle: PrimitiveButtonStyle {
    var variant: EquinoxButtonVariant = .bordered
    var size: EquinoxButtonSize = .regular

    func makeBody(configuration: Configuration) -> some View {
        styledButton(configuration)
            .controlSize(size == .small ? .small : .regular)
    }

    @ViewBuilder
    private func styledButton(_ configuration: Configuration) -> some View {
        switch variant {
        case .prominent:
            Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                .buttonStyle(.borderedProminent)
        case .bordered:
            Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                .buttonStyle(.bordered)
        case .plain:
            Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                .buttonStyle(.borderless)
        case .destructive:
            Button(role: .destructive, action: configuration.trigger) { configuration.label }
                .buttonStyle(.bordered)
        }
    }
}

// MARK: - Card modifier

enum EquinoxCardStyle {
    case secondary
    case subtle
    case raised
    case row
    case timeline
    case activeTimeline
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
                        borderColor,
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
        case .row:
            isHovered ? EquinoxDesign.ColorToken.interactionHover : EquinoxDesign.ColorToken.interactionSubtle
        case .timeline:
            isHovered ? EquinoxDesign.ColorToken.interactionHover : .clear
        case .activeTimeline:
            EquinoxDesign.ColorToken.present.opacity(EquinoxDesign.StateOpacity.currentEventBackground)
        }
    }

    private var borderColor: Color {
        if style == .row {
            return isHovered ? EquinoxDesign.ColorToken.separator : EquinoxDesign.ColorToken.hairlineBorder
        }
        if style == .timeline || style == .activeTimeline {
            return .clear
        }
        return isHovered ? EquinoxDesign.ColorToken.interactionHover : EquinoxDesign.ColorToken.hairlineBorder
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
            .lineLimit(1)
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
            .fill(EquinoxDesign.ColorToken.surfaceSecondary)
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
                .accessibilityHidden(true)
            Text(message)
                .font(.footnote)
                .foregroundStyle(foregroundColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(EquinoxButtonStyle(variant: .bordered, size: .small))
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
    var isProminent = true
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
        .help(helpText)
        .accessibilityLabel(String(localized: "Join Meeting", comment: ""))
        .accessibilityHint(JoinURLPresentation.meetingDisplayName(for: url))
    }

    private var fullLabel: some View {
        HStack(spacing: EquinoxDesign.spacingMD) {
            Image(systemName: JoinURLPresentation.meetingSystemImage(for: url))
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: EquinoxDesign.ControlWidth.joinIcon, height: EquinoxDesign.ControlWidth.joinIcon)

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
    }

    private var compactLabel: some View {
        Image(systemName: JoinURLPresentation.meetingSystemImage(for: url))
            .font(.caption.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isProminent ? EquinoxDesign.onAccentForeground : Color.primary)
            .frame(width: metrics?.toolbarButtonSize ?? EquinoxDesign.toolbarButtonSize,
                   height: metrics?.toolbarButtonSize ?? EquinoxDesign.toolbarButtonSize)
            .background { joinBackground }
    }

    private var joinBackground: some View {
        RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
            .fill(joinBackgroundColor)
    }

    private var joinBackgroundColor: Color {
        if variant == .compact, !isProminent {
            return isHovered
                ? EquinoxDesign.ColorToken.interactionHover
                : EquinoxDesign.ColorToken.interactionRest
        }
        return isHovered
            ? EquinoxDesign.ColorToken.accentStrong
            : EquinoxDesign.ColorToken.accent
    }

    private var helpText: String {
        "\(String(localized: "Join Meeting", comment: "")) — \(JoinURLPresentation.meetingDisplayName(for: url))"
    }
}
