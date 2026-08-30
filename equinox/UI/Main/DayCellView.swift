import SwiftUI

struct DayCellView: View {
    let date: CalendarDate
    let isToday: Bool
    let isSelected: Bool
    var isKeyboardFocused = false
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

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @State private var selectionTrigger = false

    private var todayMarkerSize: CGFloat {
        min(metrics.cellSize - 3, metrics.cellSize * 0.9)
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
        values.append(EquinoxFormatters.eventCount(eventCount))
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

                if isSelected && !isToday {
                    RoundedRectangle(cornerRadius: metrics.cellRadius, style: .continuous)
                        .fill(EquinoxDesign.ColorToken.accentSoft)
                        .overlay {
                            RoundedRectangle(cornerRadius: metrics.cellRadius, style: .continuous)
                                .strokeBorder(
                                    isKeyboardFocused
                                        ? EquinoxDesign.ColorToken.focusRing
                                        : EquinoxDesign.ColorToken.accentRing,
                                    lineWidth: isKeyboardFocused
                                        ? EquinoxDesign.focusStrokeWidth
                                        : EquinoxDesign.selectionStrokeWidth
                                )
                        }
                        .padding(.horizontal, 1)
                } else if isHovered && !isSelected {
                    RoundedRectangle(cornerRadius: metrics.cellRadius, style: .continuous)
                        .fill(EquinoxDesign.ColorToken.interactionHover)
                        .padding(.horizontal, 1)
                }

                if isToday {
                    Circle()
                        .fill(
                            isSelected
                                ? EquinoxDesign.ColorToken.present
                                    .opacity(EquinoxDesign.StateOpacity.selectionTint)
                                : Color.clear
                        )
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    isSelected && isKeyboardFocused
                                        ? EquinoxDesign.ColorToken.focusRing
                                        : EquinoxDesign.ColorToken.present,
                                    lineWidth: isSelected
                                        ? EquinoxDesign.focusStrokeWidth
                                        : EquinoxDesign.todayOrbitStrokeWidth
                                )
                        }
                        .frame(width: todayMarkerSize, height: todayMarkerSize)
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
        .focusable(false)
        .disabled(!date.isValid)
        .sensoryFeedback(.selection, trigger: selectionTrigger)
        .onHover { isHovered = $0 }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            if date.isValid { onDoubleClick() }
        })
        .contextMenu {
            Button {
                if date.isValid { onDoubleClick() }
            } label: {
                Label(String(localized: "New Event", comment: "Day cell context action"), systemImage: "plus")
            }
            .disabled(!date.isValid)
        }
        .help(accessibilityDateLabel)
        .accessibilityLabel(accessibilityDateLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(
            String(localized: "Use the New Event action to create an event.", comment: "Day cell hint")
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: Text(String(localized: "New Event", comment: "Day cell accessibility action"))) {
            if date.isValid { onDoubleClick() }
        }
    }

    private var textColor: Color {
        if isToday { return EquinoxDesign.ColorToken.present }
        if isSelected { return EquinoxDesign.ColorToken.action }
        if isInCurrentMonth { return .primary }
        return .secondary
    }

    @ViewBuilder
    private var dotRow: some View {
        if let dotColors {
            Group {
                if differentiateWithoutColor, eventCount > 0 {
                    Text("\(eventCount)")
                        .font(EquinoxDesign.microFont())
                        .foregroundStyle(textColor)
                } else {
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
                }
            }
            .frame(height: EquinoxDesign.eventMarkerRowHeight)
            .accessibilityHidden(true)
        }
    }
}
