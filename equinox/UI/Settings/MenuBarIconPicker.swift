import SwiftUI

struct MenuBarIconPicker: View {
    @Binding var selection: Int

    private let styleNames = [
        String(localized: "Minimal", comment: "Menu bar icon style"),
        String(localized: "Classic", comment: "Menu bar icon style"),
        String(localized: "Compact", comment: "Menu bar icon style"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: EquinoxDesign.spacingMD),
        GridItem(.flexible(), spacing: EquinoxDesign.spacingMD),
        GridItem(.flexible(), spacing: EquinoxDesign.spacingMD),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: EquinoxDesign.spacingMD) {
            ForEach(MenuBarIconStyle.allCases, id: \.rawValue) { style in
                iconButton(for: style)
            }
        }
    }

    @ViewBuilder
    private func iconButton(for style: MenuBarIconStyle) -> some View {
        let index = style.rawValue
        Button {
            selection = index
        } label: {
            Image("menubaricon\(index)")
                .resizable()
                .scaledToFit()
                .frame(height: 20)
                .frame(maxWidth: .infinity)
                .padding(.vertical, EquinoxDesign.spacingLG)
                .background {
                    RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                        .fill(Color.primary.opacity(selection == index ? 0.06 : 0.03))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                        .strokeBorder(
                            selection == index ? EquinoxDesign.ColorToken.accentRing : EquinoxDesign.ColorToken.hairlineBorder,
                            lineWidth: selection == index ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(styleNames[index])
        .accessibilityAddTraits(selection == index ? .isSelected : [])
    }
}
