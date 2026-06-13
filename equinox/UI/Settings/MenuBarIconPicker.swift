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
            ForEach(0..<3, id: \.self) { index in
                iconButton(for: index)
            }
        }
    }

    private func iconButton(for index: Int) -> some View {
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
                            selection == index ? Color.accentColor : Color.primary.opacity(0.08),
                            lineWidth: selection == index ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(styleNames[index])
        .accessibilityAddTraits(selection == index ? .isSelected : [])
    }
}
