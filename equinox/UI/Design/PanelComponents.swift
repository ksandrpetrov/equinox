import SwiftUI

extension View {
    func panelBackground(style: BackgroundStyle, reduceTransparency: Bool = false) -> some View {
        let effectiveStyle: BackgroundStyle = (style == .glass && reduceTransparency) ? .solid : style
        let shape = RoundedRectangle(cornerRadius: EquinoxDesign.panelCornerRadius, style: .continuous)
        return background {
            Group {
                if effectiveStyle == .solid {
                    shape.fill(EquinoxDesign.ColorToken.surfacePrimary)
                } else {
                    shape
                        .fill(.regularMaterial)
                        .overlay { shape.fill(Color.primary.opacity(0.06)) }
                        .glassEffect(.regular, in: shape)
                }
            }
            .overlay {
                shape.strokeBorder(EquinoxDesign.ColorToken.hairlineBorder, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(effectiveStyle == .glass ? 0.12 : 0.06), radius: 12, y: 4)
        }
        .clipShape(shape)
    }

    func panelCommandBarBackground(style: BackgroundStyle, reduceTransparency: Bool = false) -> some View {
        let effectiveStyle: BackgroundStyle = (style == .glass && reduceTransparency) ? .solid : style
        let shape = Capsule(style: .continuous)
        return background {
            Group {
                if effectiveStyle == .solid {
                    shape.fill(EquinoxDesign.ColorToken.surfaceSecondary)
                } else {
                    shape.glassEffect(.regular, in: shape)
                }
            }
        }
    }
}

struct PanelButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.5)
            .background(
                RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                        .strokeBorder(EquinoxDesign.ColorToken.accentRing, lineWidth: 1)
                }
            }
            .scaleEffect(pressScale(isPressed: configuration.isPressed))
            .onHover { isHovered = $0 }
            .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: configuration.isPressed)
            .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isSelected)
            .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isHovered)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isSelected {
            return EquinoxDesign.ColorToken.accentSoft
        }
        if isPressed { return EquinoxDesign.ColorToken.interactionPress }
        if isHovered { return EquinoxDesign.ColorToken.interactionHover }
        return EquinoxDesign.ColorToken.interactionRest
    }

    private func pressScale(isPressed: Bool) -> CGFloat {
        guard isEnabled, isPressed, !reduceMotion else { return 1 }
        return EquinoxDesign.pressScale
    }
}

struct PanelIconButton: View {
    let symbol: String
    var help: String = ""
    var accessibilityLabel: String = ""
    var isSelected: Bool = false
    var buttonSize: CGFloat = EquinoxDesign.toolbarButtonSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            panelIconLabel(symbol: symbol, isSelected: isSelected, buttonSize: buttonSize)
        }
        .buttonStyle(PanelButtonStyle(isSelected: isSelected))
        .help(help)
        .panelAccessibilityLabel(
            accessibilityLabel.isEmpty ? help : accessibilityLabel,
            hint: help
        )
    }
}

struct PanelIconMenuButton<MenuContent: View>: View {
    let symbol: String
    var help: String = ""
    var accessibilityLabel: String = ""
    var buttonSize: CGFloat = EquinoxDesign.toolbarButtonSize
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            panelIconLabel(symbol: symbol, buttonSize: buttonSize)
        }
        .menuIndicator(.hidden)
        .buttonStyle(PanelButtonStyle())
        .help(help)
        .panelAccessibilityLabel(
            accessibilityLabel.isEmpty ? help : accessibilityLabel,
            hint: help
        )
    }
}

private func panelIconLabel(
    symbol: String,
    isSelected: Bool = false,
    buttonSize: CGFloat
) -> some View {
    Image(systemName: symbol)
        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(isSelected ? EquinoxDesign.ColorToken.accent : Color.primary)
        .frame(width: buttonSize, height: buttonSize)
        .contentShape(Rectangle())
}

struct PanelButtonGroup<Content: View>: View {
    var spacing: CGFloat = EquinoxDesign.spacingXS
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: spacing) {
            content()
        }
    }
}
