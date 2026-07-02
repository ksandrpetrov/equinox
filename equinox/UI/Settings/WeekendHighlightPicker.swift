import SwiftUI

struct WeekendHighlightPicker: View {
    @Bindable var preferences: PreferencesStore

    private var dowLabels: [String] {
        let formatter = DateFormatter()
        formatter.locale = appLocale
        let symbols = formatter.shortWeekdaySymbols ?? ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]
        return symbols
    }

    var body: some View {
        HStack(spacing: EquinoxDesign.spacingSM - 2) {
            ForEach(0..<7, id: \.self) { col in
                let dow = weekdayForColumn(startDOW: preferences.weekStartWeekday, col: col)
                let isOn = (preferences.highlightedWeekdays & (1 << dow)) != 0
                Button {
                    if isOn {
                        preferences.highlightedWeekdays = preferences.highlightedWeekdays & ~(1 << dow)
                    } else {
                        preferences.highlightedWeekdays = preferences.highlightedWeekdays | (1 << dow)
                    }
                } label: {
                    Text(String(dowLabels[dow].prefix(2)))
                        .font(.caption.weight(.semibold))
                        .frame(width: EquinoxDesign.ControlWidth.weekdayCell, height: EquinoxDesign.ControlWidth.weekdayCellHeight)
                        .background {
                            RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                                .fill(isOn ? EquinoxDesign.ColorToken.weekendTint.opacity(EquinoxDesign.StateOpacity.weekendHighlight) : EquinoxDesign.ColorToken.interactionSubtle)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
                                .strokeBorder(isOn ? EquinoxDesign.ColorToken.accentRing : EquinoxDesign.ColorToken.hairlineBorder, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dowLabels[dow])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, EquinoxDesign.spacingSM)
    }
}
