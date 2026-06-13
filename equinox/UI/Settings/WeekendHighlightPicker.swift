import SwiftUI

struct WeekendHighlightPicker: View {
    @Bindable private var prefs = PreferencesStore.shared

    private var dowLabels: [String] {
        let formatter = DateFormatter()
        formatter.locale = appLocale
        let symbols = formatter.shortWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return symbols
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { col in
                let dow = weekdayForColumn(startDOW: prefs.weekStartWeekday, col: col)
                let isOn = (prefs.highlightedWeekdays & (1 << dow)) != 0
                Button {
                    if isOn {
                        prefs.highlightedWeekdays = prefs.highlightedWeekdays & ~(1 << dow)
                    } else {
                        prefs.highlightedWeekdays = prefs.highlightedWeekdays | (1 << dow)
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
