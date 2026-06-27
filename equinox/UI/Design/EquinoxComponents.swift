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
            .opacity(isEnabled ? 1 : 0.5)
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
            return .white
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
            shape.fill(EquinoxDesign.ColorToken.semanticRed.opacity(fillOpacity(isPressed: isPressed)))
        case .bordered, .plain:
            shape.fill(Color.primary.opacity(fillOpacity(isPressed: isPressed)))
        }
    }

    @ViewBuilder
    private func borderOverlay(isPressed: Bool) -> some View {
        if variant == .bordered || variant == .destructive {
            RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                .strokeBorder(
                    variant == .destructive
                        ? EquinoxDesign.ColorToken.semanticRed.opacity(0.35)
                        : EquinoxDesign.ColorToken.hairlineBorder,
                    lineWidth: 1
                )
        }
    }

    private func fillOpacity(isPressed: Bool) -> Double {
        if isPressed { return 0.10 }
        if isHovered { return 0.08 }
        return variant == .plain ? 0 : 0.06
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
                        Color.primary.opacity(isHovered ? 0.08 : 0.06),
                        lineWidth: 1
                    )
            }
    }

    private var fillColor: Color {
        switch style {
        case .secondary:
            EquinoxDesign.ColorToken.surfaceSecondary.opacity(0.5)
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
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(tint.opacity(0.25), lineWidth: 0.5)
                    }
            }
    }
}

struct EquinoxChip: View {
    let text: String
    var dotColor: Color? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background {
            RoundedRectangle(cornerRadius: EquinoxDesign.chipRadius, style: .continuous)
                .fill(EquinoxDesign.ColorToken.interactionSubtle)
                .overlay {
                    RoundedRectangle(cornerRadius: EquinoxDesign.chipRadius, style: .continuous)
                        .strokeBorder(EquinoxDesign.ColorToken.hairlineBorder, lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Banner

enum EquinoxBannerStyle {
    case error
    case warning
    case info
}

struct EquinoxBanner: View {
    let message: String
    var style: EquinoxBannerStyle = .error
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
        .equinoxCard(style: .subtle, cornerRadius: EquinoxDesign.radiusSM)
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
        .background { joinBackground }
        .scaleEffect(isHovered && !reduceMotion ? EquinoxDesign.joinHoverScale : 1)
    }

    private var compactLabel: some View {
        Image(systemName: JoinURLPresentation.meetingSystemImage(for: url))
            .font(.system(size: 12, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white)
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
            .shadow(color: EquinoxDesign.ColorToken.accent.opacity(isHovered ? 0.35 : 0.22), radius: 8, y: 3)
    }
}
