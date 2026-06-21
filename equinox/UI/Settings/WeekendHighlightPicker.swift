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
        HStack(spacing: 6) {
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
                        .frame(width: 32, height: 28)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isOn ? EquinoxDesign.ColorToken.weekendTint.opacity(0.25) : Color.primary.opacity(0.04))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(isOn ? EquinoxDesign.ColorToken.todayAccent : Color.primary.opacity(0.1), lineWidth: 1)
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
