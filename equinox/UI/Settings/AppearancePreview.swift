import SwiftUI

struct AppearancePreview: View {
    @Bindable var prefs: PreferencesStore
    @Environment(\.colorScheme) private var colorScheme

    private var previewMetrics: SizeMetrics {
        SizeMetrics.metrics(for: .small)
    }

    private var previewCalendar: Calendar {
        Calendar.current
    }

    private var previewMonth: CalendarDate {
        CalendarDate(year: 2026, monthIndex: 5, day: 1)
    }

    private var previewEventColor: Color {
        Color.accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsDesign.sectionHeaderBottomPadding) {
            Text(String(localized: "Preview", comment: "Appearance preview section title"))
                .font(EquinoxDesign.sectionHeaderFont())

            VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                if let icon = MenuBarIconRenderer.previewImage(
                    text: MenuBarIconRenderer.iconText(
                        prefs: prefs,
                        calendar: previewCalendar,
                        today: CalendarDate(year: 2026, monthIndex: 5, day: 13)
                    ),
                    prefs: prefs,
                    colorScheme: colorScheme
                ) {
                    Image(nsImage: icon)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary.opacity(0.4), in: Capsule())
                }

                HStack(spacing: EquinoxDesign.spacingSM) {
                    previewDayCell(day: 12, isToday: false, isSelected: false, inMonth: false)
                    previewDayCell(day: 13, isToday: true, isSelected: false, inMonth: true)
                    previewDayCell(day: 14, isToday: false, isSelected: true, inMonth: true)
                    previewDayCell(day: 15, isToday: false, isSelected: false, inMonth: true)
                }

                previewEventRow
            }
            .padding(.horizontal, EquinoxDesign.spacingMD)
            .padding(.vertical, EquinoxDesign.spacingXS)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: SettingsDesign.sectionCornerRadius, style: .continuous)
                    .fill(.quaternary.opacity(0.35))
            }
        }
    }

    private var previewEventRow: some View {
        HStack(alignment: .center, spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(previewEventColor)
                .frame(width: 3, height: 12)

            HStack(alignment: .firstTextBaseline, spacing: EquinoxDesign.spacingSM) {
                Text("09:00 – 10:00")
                    .font(EquinoxDesign.monoTimeFont(size: 11))
                    .foregroundStyle(.secondary)
                Text(String(localized: "Team standup", comment: "Appearance preview sample event"))
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.leading, previewMetrics.agendaEventLeadingMargin - 3)
            .padding(.trailing, EquinoxDesign.spacingSM)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                .fill(previewEventColor.opacity(0.04))
        )
        .padding(.horizontal, EquinoxDesign.spacingXS)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func previewDayCell(day: Int, isToday: Bool, isSelected: Bool, inMonth: Bool) -> some View {
        DayCellView(
            date: CalendarDate(year: previewMonth.year, monthIndex: previewMonth.monthIndex, day: day),
            isToday: isToday,
            isSelected: isSelected,
            isInCurrentMonth: inMonth,
            isHighlighted: false,
            isMonthBoundaryStart: false,
            isMonthBoundaryEnd: false,
            dotColors: prefs.showEventDots ? [Color.accentColor] : nil,
            hoverEvents: [],
            showHoverPreview: false,
            metrics: previewMetrics,
            calendar: previewCalendar,
            onSelect: {},
            onDoubleClick: {}
        )
    }
}
