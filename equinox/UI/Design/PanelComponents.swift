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
                        .overlay { shape.fill(EquinoxDesign.ColorToken.interactionRest) }
                        .glassEffect(.regular, in: shape)
                }
            }
            .overlay {
                shape.strokeBorder(EquinoxDesign.ColorToken.hairlineBorder, lineWidth: 0.5)
            }
            .shadow(
                color: .black.opacity(
                    effectiveStyle == .glass
                        ? EquinoxDesign.ShadowToken.panelGlassOpacity
                        : EquinoxDesign.ShadowToken.panelSolidOpacity
                ),
                radius: EquinoxDesign.ShadowToken.panelRadius,
                y: EquinoxDesign.ShadowToken.panelYOffset
            )
        }
        .clipShape(shape)
    }

}

struct PanelButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    var isProminent: Bool = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : EquinoxDesign.StateOpacity.disabled)
            .background(
                RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay {
                if isSelected && !isProminent {
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
        if isProminent {
            return isPressed || isHovered
                ? EquinoxDesign.ColorToken.actionStrong
                : EquinoxDesign.ColorToken.action
        }
        if isSelected {
            return EquinoxDesign.ColorToken.accentSoft
        }
        if isPressed { return EquinoxDesign.ColorToken.interactionPress }
        if isHovered { return EquinoxDesign.ColorToken.interactionHover }
        return .clear
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
    var isProminent: Bool = false
    var buttonSize: CGFloat = EquinoxDesign.toolbarButtonSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            panelIconLabel(
                symbol: symbol,
                isSelected: isSelected,
                isProminent: isProminent,
                buttonSize: buttonSize
            )
        }
        .buttonStyle(PanelButtonStyle(isSelected: isSelected, isProminent: isProminent))
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

struct PanelDateButton: View {
    let day: Int
    var help: String = ""
    var accessibilityLabel: String = ""
    var isSelected = false
    var buttonSize: CGFloat = EquinoxDesign.toolbarButtonSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: EquinoxDesign.chipRadius, style: .continuous)
                    .strokeBorder(
                        EquinoxDesign.ColorToken.present,
                        lineWidth: 1
                    )
                    .frame(width: buttonSize * 0.62, height: buttonSize * 0.62)
                Text("\(day)")
                    .font(.system(size: buttonSize * 0.3, weight: .bold, design: .rounded))
                    .foregroundStyle(EquinoxDesign.ColorToken.present)
                    .contentTransition(.numericText())
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(PanelButtonStyle(isSelected: isSelected))
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
    isProminent: Bool = false,
    buttonSize: CGFloat
) -> some View {
    Image(systemName: symbol)
        .font(EquinoxDesign.panelIconFont(isSelected: isSelected))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(
            isProminent
                ? EquinoxDesign.onAccentForeground
                : (isSelected ? EquinoxDesign.ColorToken.action : Color.primary)
        )
        .frame(width: buttonSize, height: buttonSize)
        .contentShape(Rectangle())
}

struct PanelButtonGroup<Content: View>: View {
    var spacing: CGFloat = EquinoxDesign.spacingXS
    var showsBackground = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: spacing) {
            content()
        }
        .background {
            if showsBackground {
                RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                    .fill(EquinoxDesign.ColorToken.interactionSubtle)
                    .overlay {
                        RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                            .strokeBorder(EquinoxDesign.ColorToken.hairlineBorder, lineWidth: 0.5)
                    }
            }
        }
    }
}
