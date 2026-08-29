import SwiftUI

struct DayCellView: View {
    let date: CalendarDate
    let isToday: Bool
    let isSelected: Bool
    let isInCurrentMonth: Bool
    let isHighlighted: Bool
    let isMonthBoundaryStart: Bool
    let isMonthBoundaryEnd: Bool
    let eventCount: Int
    let dotColors: [Color]?
    let metrics: SizeMetrics
    let calendar: Calendar
    let onSelect: () -> Void
    let onDoubleClick: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @State private var selectionTrigger = false

    private var circleSize: CGFloat {
        min(metrics.cellSize - 7, metrics.cellSize * 0.82)
    }

    private var accessibilityDateLabel: String {
        EquinoxFormatters.formatter(key: "daycell.a11y") { $0.dateStyle = .full }.string(
            from: date.date(in: calendar)
        )
    }

    private var accessibilityValue: String {
        var values: [String] = []
        if isToday && isSelected {
            values.append(String(localized: "Today, selected", comment: "Day cell accessibility"))
        } else if isToday {
            values.append(String(localized: "Today", comment: ""))
        } else if isSelected {
            values.append(String(localized: "Selected", comment: "Day cell accessibility"))
        }
        values.append(
            String(
                format: String(localized: "%lld events", comment: "Day cell event count"),
                Int64(eventCount)
            )
        )
        return values.joined(separator: ", ")
    }

    var body: some View {
        Button(action: {
            selectionTrigger.toggle()
            onSelect()
        }) {
            ZStack {
                if isHighlighted && !isToday && !isSelected {
                    RoundedRectangle(cornerRadius: metrics.cellRadius, style: .continuous)
                        .fill(
                            EquinoxDesign.ColorToken.weekendTint
                                .opacity(EquinoxDesign.StateOpacity.weekendHighlight)
                        )
                        .padding(.horizontal, 1)
                }

                if isSelected {
                    RoundedRectangle(cornerRadius: metrics.cellRadius, style: .continuous)
                        .fill(EquinoxDesign.ColorToken.accentSoft)
                        .overlay {
                            RoundedRectangle(cornerRadius: metrics.cellRadius, style: .continuous)
                                .strokeBorder(EquinoxDesign.ColorToken.accentRing, lineWidth: 1)
                        }
                        .padding(.horizontal, 1)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: metrics.cellRadius, style: .continuous)
                        .fill(EquinoxDesign.ColorToken.interactionHover)
                        .padding(.horizontal, 1)
                }

                if isToday {
                    Circle()
                        .fill(EquinoxDesign.ColorToken.present)
                        .frame(width: circleSize, height: circleSize)
                }

                VStack(spacing: EquinoxDesign.spacingMicro) {
                    Text("\(date.day)")
                        .font(EquinoxDesign.dayNumeralFont(size: metrics.fontSize))
                        .foregroundStyle(textColor)
                        .contentTransition(.numericText())
                    dotRow
                }
            }
            .frame(height: metrics.cellSize)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                if isMonthBoundaryStart {
                    Rectangle()
                        .fill(EquinoxDesign.ColorToken.monthBoundary)
                        .opacity(EquinoxDesign.StateOpacity.monthBoundary)
                        .frame(width: EquinoxDesign.monthBoundaryWidth)
                }
            }
            .overlay(alignment: .trailing) {
                if isMonthBoundaryEnd {
                    Rectangle()
                        .fill(EquinoxDesign.ColorToken.monthBoundary)
                        .opacity(EquinoxDesign.StateOpacity.monthBoundary)
                        .frame(width: EquinoxDesign.monthBoundaryWidth)
                }
            }
            .contentShape(Rectangle())
            .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isHovered)
            .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(!date.isValid)
        .sensoryFeedback(.selection, trigger: selectionTrigger)
        .onHover { isHovered = $0 }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            if date.isValid { onDoubleClick() }
        })
        .accessibilityLabel(accessibilityDateLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(String(localized: "Double-click to create an event", comment: "Day cell hint"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: Text(String(localized: "New Event", comment: "Day cell accessibility action"))) {
            if date.isValid { onDoubleClick() }
        }
    }

    private var textColor: Color {
        if isToday { return EquinoxDesign.onSolarForeground }
        if isSelected { return EquinoxDesign.ColorToken.action }
        if isInCurrentMonth { return .primary }
        return .secondary
    }

    @ViewBuilder
    private var dotRow: some View {
        if let dotColors {
            HStack(spacing: EquinoxDesign.spacingMicro) {
                HStack(spacing: -metrics.cellDotWidth * 0.25) {
                    ForEach(Array(dotColors.prefix(3).enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: metrics.cellDotWidth + 0.5, height: metrics.cellDotWidth + 0.5)
                    }
                }
                if eventCount > 3 {
                    Text("\(eventCount)")
                        .font(EquinoxDesign.microFont())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: metrics.cellDotWidth + 2)
            .accessibilityHidden(true)
        }
    }
}
