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
            Text(sectionContext(isToday: isToday, isTomorrow: isTomorrow, nsDate: nsDate))
                .font(EquinoxDesign.agendaSectionSubtitleFont(size: metrics.fontSize))
                .foregroundStyle(.tertiary)
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
        .accessibilityAddTraits(.isHeader)
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

    private func sectionContext(isToday: Bool, isTomorrow: Bool, nsDate: Date) -> String {
        if isToday || isTomorrow {
            return EquinoxFormatters.agendaHeader(nsDate)
        }
        return EquinoxFormatters.shortWeekday(nsDate)
    }
}

enum AgendaTimelineEmphasis {
    case none
    case next
    case current
}

struct AgendaTimelineMarker: View {
    let calendarColor: Color
    let emphasis: AgendaTimelineEmphasis
    let connectsAbove: Bool
    let connectsBelow: Bool
    let width: CGFloat

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(connectsAbove ? EquinoxDesign.ColorToken.separator : .clear)
                    .frame(width: EquinoxDesign.agendaTimelineLineWidth)
                    .frame(maxHeight: .infinity)
                Color.clear
                    .frame(height: EquinoxDesign.agendaTimelineFocusNodeSize)
                Rectangle()
                    .fill(connectsBelow ? EquinoxDesign.ColorToken.separator : .clear)
                    .frame(width: EquinoxDesign.agendaTimelineLineWidth)
                    .frame(maxHeight: .infinity)
            }

            marker
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var marker: some View {
        switch emphasis {
        case .none:
            Circle()
                .fill(calendarColor)
                .frame(
                    width: EquinoxDesign.agendaTimelineNodeSize,
                    height: EquinoxDesign.agendaTimelineNodeSize
                )
        case .next, .current:
            Circle()
                .fill(EquinoxDesign.ColorToken.surfaceRaised)
                .frame(
                    width: EquinoxDesign.agendaTimelineFocusNodeSize,
                    height: EquinoxDesign.agendaTimelineFocusNodeSize
                )
                .overlay {
                    Circle()
                        .strokeBorder(emphasisColor, lineWidth: EquinoxDesign.focusStrokeWidth)
                    Circle()
                        .fill(calendarColor)
                        .frame(
                            width: EquinoxDesign.agendaTimelineNodeSize - 3,
                            height: EquinoxDesign.agendaTimelineNodeSize - 3
                        )
                }
        }
    }

    private var emphasisColor: Color {
        switch emphasis {
        case .none: calendarColor
        case .next: EquinoxDesign.ColorToken.action
        case .current: EquinoxDesign.ColorToken.present
        }
    }
}

struct AgendaEventCard: View {
    let event: DayEvent
    let metrics: SizeMetrics
    let showLocation: Bool
    let now: Date
    var isFirstInSection = false
    var isLastInSection = false
    var isFocusedEvent = false
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
        showLocation && !(event.location?.isEmpty ?? true)
    }

    var body: some View {
        HStack(alignment: showsSecondaryDetails ? .top : .center, spacing: 0) {
            Button {
                onTap?()
            } label: {
                HStack(alignment: showsSecondaryDetails ? .top : .center, spacing: 0) {
                    timeColumn

                    AgendaTimelineMarker(
                        calendarColor: calendarColor,
                        emphasis: timelineEmphasis,
                        connectsAbove: !isFirstInSection,
                        connectsBelow: !isLastInSection,
                        width: metrics.agendaTimelineColumnWidth
                    )

                    Group {
                        if showsSecondaryDetails {
                            expandedEventContent
                        } else {
                            compactEventContent
                        }
                    }
                    .padding(.leading, EquinoxDesign.spacingXS)
                    .padding(.trailing, EquinoxDesign.spacingSM)
                }
                .padding(.vertical, showsSecondaryDetails ? EquinoxDesign.spacingXS : EquinoxDesign.spacingMicro + 1)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(eventAccessibilityLabel)
            .accessibilityHint(String(localized: "Show event details.", comment: "Agenda event hint"))

            if let url = event.joinURL {
                EquinoxJoinButton(
                    url: url,
                    variant: .compact,
                    metrics: metrics,
                    isProminent: isJoinUrgent
                ) {
                    URLOpener.open(url)
                }
                .padding(.trailing, EquinoxDesign.spacingSM)
                .padding(.top, showsSecondaryDetails ? EquinoxDesign.spacingXS : 2)
            }
        }
        .equinoxCard(style: isHappeningNow ? .activeTimeline : .timeline, isHovered: isHovered)
        .opacity(isDeclined ? EquinoxDesign.StateOpacity.declinedEvent : 1)
        .padding(.horizontal, EquinoxDesign.spacingXS)
        .help(eventHelp)
        .onHover { isHovered = $0 }
        .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isHovered)
    }

    @ViewBuilder
    private var timeColumn: some View {
        if event.isEventAllDay {
            Text(String(localized: "All-day", comment: ""))
                .font(EquinoxDesign.monoTimeFont(size: metrics.agendaTimeFontSize))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: metrics.agendaTimeColumnWidth, alignment: .trailing)
        } else {
            VStack(alignment: .trailing, spacing: EquinoxDesign.spacingMicro) {
                Text(EquinoxFormatters.shortTime(event.startDate))
                    .foregroundStyle(.secondary)
                Text(EquinoxFormatters.shortTime(event.endDate))
                    .foregroundStyle(.tertiary)
            }
            .font(EquinoxDesign.monoTimeFont(size: metrics.agendaTimeFontSize))
            .lineLimit(1)
            .frame(width: metrics.agendaTimeColumnWidth, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var compactEventContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: EquinoxDesign.spacingSM) {
            Text(event.title)
                .font(
                    EquinoxDesign.agendaEventTitleFont(
                        size: metrics.agendaEventTitleFontSize,
                        isExpanded: false
                    )
                )
                .lineLimit(1)
                .layoutPriority(1)
                .opacity(isDeclined ? EquinoxDesign.StateOpacity.declinedTitle : 1)
            Spacer(minLength: EquinoxDesign.spacingXS)
            relativeTimeLabel
        }
    }

    @ViewBuilder
    private var expandedEventContent: some View {
        VStack(alignment: .leading, spacing: EquinoxDesign.spacingMicro) {
            HStack(alignment: .firstTextBaseline, spacing: EquinoxDesign.spacingSM) {
                Text(event.title)
                    .font(
                        EquinoxDesign.agendaEventTitleFont(
                            size: metrics.agendaEventTitleFontSize,
                            isExpanded: true
                        )
                    )
                    .lineLimit(1)
                    .layoutPriority(1)
                    .opacity(isDeclined ? EquinoxDesign.StateOpacity.declinedTitle : 1)
                Spacer(minLength: EquinoxDesign.spacingXS)
                relativeTimeLabel
            }

            if showLocation || !event.calendarTitle.isEmpty {
                HStack(spacing: EquinoxDesign.spacingXS) {
                    if showLocation, let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(EquinoxDesign.agendaEventMetaFont(size: metrics.agendaEventMetaFontSize))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !event.calendarTitle.isEmpty {
                        if showLocation, let location = event.location, !location.isEmpty {
                            Text("·")
                                .foregroundStyle(.tertiary)
                        }
                        Text(event.calendarTitle)
                            .font(EquinoxDesign.agendaEventMetaFont(size: metrics.agendaEventMetaFontSize))
                            .foregroundStyle(.secondary)
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
        if let relativeTimeString {
            parts.append(relativeTimeString)
        }
        return parts.joined(separator: ", ")
    }

    private var eventHelp: String {
        var parts = [event.title, timeRangeString]
        if !event.calendarTitle.isEmpty {
            parts.append(event.calendarTitle)
        }
        return parts.joined(separator: " · ")
    }

    private var timeRangeString: String {
        if event.isEventAllDay { return String(localized: "All-day", comment: "") }
        return EquinoxFormatters.timeRange(from: event.startDate, to: event.endDate)
    }

    private var relativeTimeString: String? {
        switch temporalState {
        case .ongoing:
            return EquinoxFormatters.relativeTimeDuringEvent()
        case .upcoming where Calendar.autoupdatingCurrent.isDate(event.startDate, inSameDayAs: now):
            return EquinoxFormatters.relativeTime(until: event.startDate, from: now)
        case .notApplicable, .past, .upcoming:
            return nil
        }
    }

    private var isHappeningNow: Bool {
        temporalState == .ongoing
    }

    private var temporalState: AgendaEventTemporalState {
        AgendaFocus.temporalState(for: event, now: now)
    }

    private var timelineEmphasis: AgendaTimelineEmphasis {
        if isHappeningNow { return .current }
        if isFocusedEvent, temporalState == .upcoming { return .next }
        return .none
    }

    private var isJoinUrgent: Bool {
        MeetingIndicator.isJoinActionUrgent(event, now: now)
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
