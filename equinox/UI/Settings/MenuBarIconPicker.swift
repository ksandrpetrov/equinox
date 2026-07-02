import SwiftUI

struct MenuBarIconPicker: View {
    @Bindable var prefs: PreferencesStore
    @Environment(\.colorScheme) private var colorScheme

    private var selection: Int { prefs.menuBarIconType }

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
            prefs.menuBarIconType = index
        } label: {
            styleThumbnail(for: style)
                .frame(maxWidth: .infinity)
                .padding(.vertical, EquinoxDesign.spacingLG)
                .background {
                    RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                        .fill(selection == index ? EquinoxDesign.ColorToken.interactionRest : EquinoxDesign.ColorToken.pickerUnselected)
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

    @ViewBuilder
    private func styleThumbnail(for style: MenuBarIconStyle) -> some View {
        if let icon = MenuBarIconRenderer.previewImage(
            text: previewText,
            iconStyle: style,
            showMeetingIndicator: false,
            colorScheme: colorScheme
        ) {
            Image(nsImage: icon)
                .frame(height: EquinoxDesign.ControlWidth.menuBarPickerPreviewHeight)
        } else {
            Color.clear
                .frame(height: EquinoxDesign.ControlWidth.menuBarPickerPreviewHeight)
        }
    }

    private var previewText: String {
        MenuBarIconRenderer.iconText(
            prefs: prefs,
            calendar: Calendar.current,
            today: CalendarDate(year: 2026, monthIndex: 5, day: 13)
        )
    }
}
