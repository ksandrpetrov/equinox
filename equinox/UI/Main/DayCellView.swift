import SwiftUI

struct DayCellView: View {
    let date: CalendarDate
    let isToday: Bool
    let isSelected: Bool
    let isInCurrentMonth: Bool
    let isHighlighted: Bool
    let isMonthBoundaryStart: Bool
    let isMonthBoundaryEnd: Bool
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
        if isToday && isSelected {
            return String(localized: "Today, selected", comment: "Day cell accessibility")
        }
        if isToday {
            return String(localized: "Today", comment: "")
        }
        if isSelected {
            return String(localized: "Selected", comment: "Day cell accessibility")
        }
        return ""
    }

    var body: some View {
        Button(action: {
            selectionTrigger.toggle()
            onSelect()
        }) {
            ZStack {
                if isHighlighted && !isToday && !isSelected {
                    RoundedRectangle(cornerRadius: metrics.cellRadius, style: .continuous)
                        .fill(EquinoxDesign.ColorToken.highlightedDOWBackground)
                        .padding(.horizontal, 1)
                }

                if isToday {
                    Circle()
                        .fill(EquinoxDesign.ColorToken.todayAccent)
                        .frame(width: circleSize, height: circleSize)
                } else if isSelected {
                    Circle()
                        .fill(EquinoxDesign.ColorToken.todayAccent.opacity(0.15))
                        .frame(width: circleSize, height: circleSize)
                    Circle()
                        .strokeBorder(EquinoxDesign.ColorToken.todayAccent, lineWidth: 1.5)
                        .frame(width: circleSize, height: circleSize)
                } else if isHovered {
                    Circle()
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: circleSize, height: circleSize)
                }

                VStack(spacing: 2) {
                    Text("\(date.day)")
                        .font(.system(size: metrics.fontSize, weight: .medium, design: .rounded))
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
                        .frame(width: 1)
                }
            }
            .overlay(alignment: .trailing) {
                if isMonthBoundaryEnd {
                    Rectangle()
                        .fill(EquinoxDesign.ColorToken.monthBoundary)
                        .frame(width: 1)
                }
            }
            .contentShape(Rectangle())
            .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isHovered)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selectionTrigger)
        .onHover { isHovered = $0 }
        .simultaneousGesture(TapGesture(count: 2).onEnded { onDoubleClick() })
        .accessibilityLabel(accessibilityDateLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(String(localized: "Double-click to create an event", comment: "Day cell hint"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var textColor: Color {
        if isToday { return .white }
        if isInCurrentMonth { return .primary }
        return .secondary
    }

    @ViewBuilder
    private var dotRow: some View {
        if let dotColors {
            HStack(spacing: -metrics.cellDotWidth * 0.25) {
                ForEach(Array(dotColors.prefix(3).enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: metrics.cellDotWidth + 0.5, height: metrics.cellDotWidth + 0.5)
                }
                if dotColors.count > 3 {
                    Text("+\(dotColors.count - 3)")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: metrics.cellDotWidth + 2)
            .accessibilityLabel(
                String(format: String(localized: "%lld events", comment: "Day cell event count"), dotColors.count)
            )
        }
    }
}
