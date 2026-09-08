import SwiftUI

struct AppearancePreview: View {
    @Bindable var prefs: PreferencesStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var previewMetrics: SizeMetrics {
        let preference = SizePreference(rawValue: prefs.sizePreference) ?? .medium
        return SizeMetrics.metrics(for: preference)
    }

    private var previewCalendar: Calendar {
        Calendar.equinoxGregorian()
    }

    private var previewMonth: CalendarDate {
        CalendarDate(year: 2026, monthIndex: 5, day: 1)
    }

    private var previewEventColor: Color {
        EquinoxDesign.ColorToken.accent
    }

    private var previewBackgroundStyle: BackgroundStyle {
        BackgroundStyle(rawValue: prefs.backgroundStyle) ?? .glass
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
                        .padding(.horizontal, MenuBarDesign.previewCapsuleHorizontalPadding)
                        .padding(.vertical, MenuBarDesign.previewCapsuleVerticalPadding)
                        .background(EquinoxDesign.ColorToken.interactionSubtle, in: Capsule())
                }

                HStack(spacing: EquinoxDesign.spacingSM) {
                    previewDayCell(day: 12, isToday: false, isSelected: false, inMonth: false)
                    previewDayCell(day: 13, isToday: true, isSelected: false, inMonth: true)
                    previewDayCell(day: 14, isToday: false, isSelected: true, inMonth: true, eventCount: 5)
                    previewDayCell(day: 15, isToday: false, isSelected: false, inMonth: true)
                }

                previewEventRow
            }
            .padding(.horizontal, EquinoxDesign.spacingMD)
            .padding(.vertical, EquinoxDesign.spacingMD)
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelBackground(
                style: previewBackgroundStyle,
                reduceTransparency: reduceTransparency
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var previewEventRow: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .trailing, spacing: EquinoxDesign.spacingMicro) {
                Text(verbatim: "09:00")
                    .foregroundStyle(.secondary)
                Text(verbatim: "10:00")
                    .foregroundStyle(.tertiary)
            }
            .font(EquinoxDesign.monoTimeFont(size: previewMetrics.agendaTimeFontSize))
            .frame(width: previewMetrics.agendaTimeColumnWidth, alignment: .trailing)

            AgendaTimelineMarker(
                calendarColor: previewEventColor,
                emphasis: .current,
                width: previewMetrics.agendaTimelineColumnWidth
            )

            HStack(alignment: .firstTextBaseline, spacing: EquinoxDesign.spacingSM) {
                Text(String(localized: "Team standup", comment: "Appearance preview sample event"))
                    .font(
                        EquinoxDesign.agendaEventTitleFont(
                            size: previewMetrics.agendaEventTitleFontSize,
                            isExpanded: false
                        )
                    )
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: EquinoxDesign.spacingXS)
                EquinoxBadge(
                    text: String(localized: "Now", comment: "Event happening now"),
                    tint: EquinoxDesign.ColorToken.present
                )
            }
            .padding(.leading, EquinoxDesign.spacingXS)
            .padding(.trailing, EquinoxDesign.spacingSM)

            Spacer(minLength: 0)
        }
        .padding(.vertical, EquinoxDesign.spacingMicro + 1)
        .equinoxCard(style: .activeTimeline)
        .padding(.horizontal, EquinoxDesign.spacingXS)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func previewDayCell(
        day: Int,
        isToday: Bool,
        isSelected: Bool,
        inMonth: Bool,
        eventCount: Int = 1
    ) -> some View {
        DayCellView(
            date: CalendarDate(year: previewMonth.year, monthIndex: previewMonth.monthIndex, day: day),
            isToday: isToday,
            isSelected: isSelected,
            isInCurrentMonth: inMonth,
            isHighlighted: false,
            isMonthBoundaryStart: false,
            isMonthBoundaryEnd: false,
            eventCount: eventCount,
            dotColors: prefs.showEventDots ? [EquinoxDesign.ColorToken.accent] : nil,
            metrics: previewMetrics,
            calendar: previewCalendar,
            onSelect: {},
            onDoubleClick: {}
        )
    }
}
