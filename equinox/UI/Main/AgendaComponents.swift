import SwiftUI

struct AgendaSectionHeader: View {
    let date: CalendarDate
    let calendar: Calendar
    let metrics: SizeMetrics
    let eventCount: Int
    let isSelected: Bool

    var body: some View {
        let nsDate = date.date(in: calendar)
        let isToday = calendar.isDateInToday(nsDate)
        let isTomorrow = calendar.isDateInTomorrow(nsDate)

        HStack(spacing: EquinoxDesign.agendaHeaderTitleSpacing) {
            Circle()
                .fill(dateMarkerColor(isToday: isToday))
                .frame(
                    width: EquinoxDesign.agendaDateMarkerSize,
                    height: EquinoxDesign.agendaDateMarkerSize
                )
                .accessibilityHidden(true)
            Text(agendaSectionTitle(isToday: isToday, isTomorrow: isTomorrow, nsDate: nsDate))
                .font(EquinoxDesign.agendaSectionTitleFont(size: metrics.fontSize))
                .foregroundStyle(isToday ? EquinoxDesign.ColorToken.present : .secondary)
            if !isToday && !isTomorrow {
                Text(EquinoxFormatters.shortWeekday(nsDate))
                    .font(EquinoxDesign.agendaSectionSubtitleFont(size: metrics.fontSize))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if eventCount > 0 {
                Text("\(eventCount)")
                    .font(EquinoxDesign.agendaEventCountFont())
                    .foregroundStyle(
                        isSelected
                            ? EquinoxDesign.ColorToken.action
                            : EquinoxDesign.ColorToken.weekdayDimmed
                    )
                    .frame(minWidth: EquinoxDesign.agendaEventCountMinWidth, alignment: .trailing)
                    .accessibilityLabel(
                        String(
                            format: String(localized: "%lld events", comment: "Agenda section event count"),
                            Int64(eventCount)
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, EquinoxDesign.spacingSM)
        .padding(.vertical, EquinoxDesign.agendaHeaderVerticalPadding)
        .background(EquinoxDesign.ColorToken.surfaceRaised)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EquinoxDesign.ColorToken.separator)
                .frame(height: 1)
        }
        .padding(.top, EquinoxDesign.spacingXS)
    }

    private func dateMarkerColor(isToday: Bool) -> Color {
        if isToday { return EquinoxDesign.ColorToken.present }
        if isSelected { return EquinoxDesign.ColorToken.action }
        return EquinoxDesign.ColorToken.separator
    }

    private func agendaSectionTitle(isToday: Bool, isTomorrow: Bool, nsDate: Date) -> String {
        if isToday { return String(localized: "Today", comment: "") }
        if isTomorrow { return String(localized: "Tomorrow", comment: "Agenda section header") }
        return EquinoxFormatters.agendaHeader(nsDate)
    }
}

struct AgendaEventCard: View {
    let event: DayEvent
    let metrics: SizeMetrics
    let showLocation: Bool
    let now: Date
    var onTap: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    private var calendarColor: Color {
        event.swiftUIColor
    }

    private var isDeclined: Bool {
        event.participationStatus == .declined
    }

    private var showsSecondaryDetails: Bool {
        (showLocation && !(event.location?.isEmpty ?? true))
            || !event.calendarTitle.isEmpty
    }

    var body: some View {
        HStack(alignment: showsSecondaryDetails ? .top : .center, spacing: 0) {
            Button {
                onTap?()
            } label: {
                HStack(alignment: showsSecondaryDetails ? .top : .center, spacing: 0) {
                    EventStripeView(
                        color: calendarColor,
                        verticalPadding: showsSecondaryDetails ? EquinoxDesign.spacingXS : EquinoxDesign.spacingMicro
                    )

                    Group {
                        if showsSecondaryDetails {
                            expandedEventContent
                        } else {
                            compactEventContent
                        }
                    }
                    .padding(.leading, metrics.agendaContentLeadingInset)
                    .padding(.trailing, EquinoxDesign.spacingSM)
                    .padding(.vertical, showsSecondaryDetails ? EquinoxDesign.spacingXS : EquinoxDesign.spacingMicro)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(eventAccessibilityLabel)
            .accessibilityHint(String(localized: "Show event details.", comment: "Agenda event hint"))

            if let url = event.joinURL {
                EquinoxJoinButton(url: url, variant: .compact, metrics: metrics) {
                    URLOpener.open(url)
                }
                .padding(.trailing, EquinoxDesign.spacingSM)
                .padding(.top, showsSecondaryDetails ? EquinoxDesign.spacingXS : 2)
            }
        }
        .equinoxCard(style: isHappeningNow ? .activeTimeline : .timeline, isHovered: isHovered)
        .opacity(isDeclined ? EquinoxDesign.StateOpacity.declinedEvent : 1)
        .padding(.horizontal, EquinoxDesign.spacingXS)
        .help(event.calendarTitle)
        .onHover { isHovered = $0 }
        .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isHovered)
    }

    @ViewBuilder
    private var compactEventContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: EquinoxDesign.spacingSM) {
            Text(timeRangeString)
                .font(EquinoxDesign.monoTimeFont(size: max(10, metrics.fontSize - 2)))
                .foregroundStyle(.secondary)
            Text(event.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .opacity(isDeclined ? EquinoxDesign.StateOpacity.declinedTitle : 1)
            Spacer(minLength: EquinoxDesign.spacingXS)
            relativeTimeLabel
        }
    }

    @ViewBuilder
    private var expandedEventContent: some View {
        VStack(alignment: .leading, spacing: EquinoxDesign.spacingMicro) {
            HStack(alignment: .firstTextBaseline, spacing: EquinoxDesign.spacingSM) {
                Text(timeRangeString)
                    .font(EquinoxDesign.monoTimeFont(size: max(10, metrics.fontSize - 2)))
                    .foregroundStyle(.secondary)
                Text(event.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .opacity(isDeclined ? EquinoxDesign.StateOpacity.declinedTitle : 1)
                Spacer(minLength: EquinoxDesign.spacingXS)
                relativeTimeLabel
            }

            if showLocation || !event.calendarTitle.isEmpty {
                HStack(spacing: EquinoxDesign.spacingXS) {
                    if showLocation, let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    if !event.calendarTitle.isEmpty {
                        if showLocation, let location = event.location, !location.isEmpty {
                            Text("·")
                                .foregroundStyle(.tertiary)
                        }
                        Text(event.calendarTitle)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var eventAccessibilityLabel: String {
        var parts = [event.title, timeRangeString]
        if !event.calendarTitle.isEmpty {
            parts.append(event.calendarTitle)
        }
        if showLocation, let location = event.location, !location.isEmpty {
            parts.append(location)
        }
        if let status = event.participationStatus {
            parts.append(status.detailStatusLabel)
        }
        return parts.joined(separator: ", ")
    }

    private var timeRangeString: String {
        if event.isEventAllDay { return String(localized: "All-day", comment: "") }
        return EquinoxFormatters.timeRange(from: event.startDate, to: event.endDate)
    }

    private var relativeTimeString: String? {
        guard !event.isEventAllDay else { return nil }
        if isHappeningNow {
            return EquinoxFormatters.relativeTimeDuringEvent()
        }
        if event.startDate > now,
           Calendar.autoupdatingCurrent.isDate(event.startDate, inSameDayAs: now) {
            return EquinoxFormatters.relativeTime(until: event.startDate, from: now)
        }
        return nil
    }

    private var isHappeningNow: Bool {
        event.startDate <= now && event.endDate > now
    }

    @ViewBuilder
    private var relativeTimeLabel: some View {
        if let relative = relativeTimeString {
            if isHappeningNow {
                EquinoxBadge(text: relative, tint: EquinoxDesign.ColorToken.present)
            } else {
                Text(relative)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(EquinoxDesign.ColorToken.action)
            }
        }
    }
}
