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
            .shadow(color: .black.opacity(effectiveStyle == .glass ? 0.12 : 0.06), radius: 12, y: 4)
        }
        .clipShape(shape)
    }

    func panelCommandBarBackground() -> some View {
        background {
            Capsule(style: .continuous)
                .glassEffect(.regular, in: Capsule(style: .continuous))
        }
    }
}

struct PanelButtonStyle: ButtonStyle {
    var isSelected: Bool = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.5)
            .background(
                RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                    .fill(Color.primary.opacity(backgroundOpacity(isPressed: configuration.isPressed)))
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 1)
                }
            }
            .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: configuration.isPressed)
            .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isSelected)
    }

    private func backgroundOpacity(isPressed: Bool) -> Double {
        if isSelected { return isPressed ? 0.16 : 0.12 }
        return isPressed ? 0.1 : 0.06
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
            Image(systemName: symbol)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(PanelButtonStyle(isSelected: isSelected))
        .help(help)
        .panelAccessibilityLabel(
            accessibilityLabel.isEmpty ? help : accessibilityLabel,
            hint: help
        )
    }
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

struct PanelSplitDivider: View {
    @Binding var agendaHeightRatio: Double
    @State private var dragStartRatio: Double = 0.35

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
        }
        .frame(height: 10)
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
        }
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    let delta = -value.translation.height / 300
                    agendaHeightRatio = min(max(dragStartRatio + delta, 0.15), 0.65)
                }
                .onEnded { _ in
                    dragStartRatio = agendaHeightRatio
                }
        )
        .onAppear {
            dragStartRatio = agendaHeightRatio
        }
        .accessibilityLabel(String(localized: "Resize agenda", comment: "Split divider accessibility"))
        .accessibilityHint(String(localized: "Drag to change agenda height", comment: "Split divider hint"))
    }
}
