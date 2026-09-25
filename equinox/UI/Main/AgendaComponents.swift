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
        let context = sectionContext(isToday: isToday, isTomorrow: isTomorrow, nsDate: nsDate)

        HStack(spacing: EquinoxDesign.spacingSM) {
            HStack(alignment: .firstTextBaseline, spacing: EquinoxDesign.spacingSM) {
                Text(agendaSectionTitle(isToday: isToday, isTomorrow: isTomorrow, nsDate: nsDate))
                    .font(EquinoxDesign.agendaSectionTitleFont(size: metrics.fontSize))
                    .foregroundStyle(isSelected ? EquinoxDesign.ColorToken.action : .primary)
                if !context.isEmpty {
                    Text(context)
                        .font(EquinoxDesign.agendaSectionSubtitleFont(size: metrics.fontSize))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if eventCount > 0 {
                Text("\(eventCount)")
                    .font(EquinoxDesign.agendaEventCountFont())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(EquinoxFormatters.eventCount(eventCount))
            }
        }
        .padding(.horizontal, EquinoxDesign.spacingSM)
        .padding(.vertical, EquinoxDesign.spacingSM)
        .background {
            // Pinned headers must obscure the rows scrolling underneath them.
            EquinoxSurface(style: .solid, cornerRadius: EquinoxDesign.radiusSM, showsBorder: false)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EquinoxDesign.ColorToken.separator)
                .frame(height: EquinoxDesign.hairlineWidth)
                .padding(.horizontal, EquinoxDesign.spacingSM)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private func agendaSectionTitle(isToday: Bool, isTomorrow: Bool, nsDate: Date) -> String {
        if isToday { return String(localized: "Today", bundle: .equinox, comment: "") }
        if isTomorrow { return String(localized: "Tomorrow", bundle: .equinox, comment: "Agenda section header") }
        return EquinoxFormatters.agendaHeader(nsDate)
    }

    private func sectionContext(isToday: Bool, isTomorrow: Bool, nsDate: Date) -> String {
        if isToday || isTomorrow {
            return EquinoxFormatters.agendaHeader(nsDate)
        }
        return ""
    }
}

struct AgendaHorizonControl: View {
    @Binding var heightRatio: Double
    let metrics: SizeMetrics
    let onHide: () -> Void

    var body: some View {
        HStack(spacing: EquinoxDesign.spacingSM) {
            horizonLine

            Menu {
                presetButton(
                    String(localized: "Standard height", bundle: .equinox, comment: "Standard agenda height"),
                    ratio: AgendaLayout.defaultHeightRatio
                )
                presetButton(
                    String(localized: "Expanded height", bundle: .equinox, comment: "Expanded agenda height"),
                    ratio: AgendaLayout.maximumHeightRatio
                )
                Divider()
                Button(String(localized: "Hide agenda", bundle: .equinox, comment: "Agenda horizon action")) {
                    onHide()
                }
            } label: {
                HStack(spacing: EquinoxDesign.spacingXS) {
                    Text(String(localized: "Agenda", bundle: .equinox, comment: "Agenda section label"))
                        .font(.caption2.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, EquinoxDesign.spacingSM)
                .frame(minHeight: metrics.toolbarButtonSize)
                .contentShape(Rectangle())
            }
            .menuIndicator(.hidden)
            .buttonStyle(PanelButtonStyle())
            .help(String(localized: "Adjust agenda height", bundle: .equinox, comment: "Agenda horizon help"))
            .accessibilityLabel(String(localized: "Adjust agenda height", bundle: .equinox, comment: "Agenda horizon accessibility"))

            horizonLine
        }
        .frame(height: metrics.toolbarButtonSize)
    }

    private var horizonLine: some View {
        Rectangle()
            .fill(EquinoxDesign.ColorToken.separator)
            .frame(maxWidth: .infinity)
            .frame(height: EquinoxDesign.monthBoundaryWidth)
            .accessibilityHidden(true)
    }

    private func presetButton(_ title: String, ratio: Double) -> some View {
        Button {
            heightRatio = ratio
        } label: {
            if abs(heightRatio - ratio) < 0.001 {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
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
    let width: CGFloat

    var body: some View {
        EventStripeView(
            color: calendarColor,
            width: emphasis == .none ? EquinoxDesign.EventStripe.width : EquinoxDesign.EventStripe.widthHero
        )
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}

struct AgendaEventCard: View {
    let event: DayEvent
    let metrics: SizeMetrics
    let showLocation: Bool
    let now: Date
    var isFocusedEvent = false
    var onTap: (() -> Void)? = nil

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @State private var showsOpenError = false

    private var calendarColor: Color {
        event.swiftUIColor
    }

    private var isDeclined: Bool {
        event.participationStatus == .declined
    }

    private var showsSecondaryDetails: Bool {
        (showLocation && !(event.location?.isEmpty ?? true))
            || (differentiateWithoutColor && !event.calendarTitle.isEmpty)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Button {
                onTap?()
            } label: {
                HStack(alignment: .center, spacing: 0) {
                    timeColumn

                    AgendaTimelineMarker(
                        calendarColor: calendarColor,
                        emphasis: timelineEmphasis,
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
                .frame(
                    maxWidth: .infinity,
                    minHeight: metrics.agendaRowMinHeight,
                    alignment: .leading
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(eventAccessibilityLabel)
            .accessibilityHint(String(localized: "Show event details.", bundle: .equinox, comment: "Agenda event hint"))

            if let url = event.joinURL {
                EquinoxJoinButton(
                    url: url,
                    variant: .compact,
                    metrics: metrics,
                    isProminent: isJoinUrgent
                ) {
                    let fallback = JoinURLDetection.detectJoinURL(
                        location: event.location, url: event.url?.absoluteString, notes: event.notes
                    )
                    showsOpenError = !URLOpener.open(url, fallback: fallback)
                }
                .padding(.trailing, EquinoxDesign.spacingSM)
            }
        }
        .equinoxCard(style: isHappeningNow ? .activeTimeline : .timeline, isHovered: isHovered)
        .opacity(isDeclined ? EquinoxDesign.StateOpacity.declinedEvent : 1)
        .padding(.horizontal, EquinoxDesign.spacingXS)
        .help(eventHelp)
        .onHover { isHovered = $0 }
        .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isHovered)
        .alert(String(localized: "Could not open the link.", bundle: .equinox, comment: "URL open error"), isPresented: $showsOpenError) {
            Button(String(localized: "OK", bundle: .equinox, comment: "Dismiss alert"), role: .cancel) {}
        }
    }

    @ViewBuilder
    private var timeColumn: some View {
        if event.displaysAsAllDay {
            Text(String(localized: "All-day", bundle: .equinox, comment: ""))
                .font(EquinoxDesign.monoTimeFont(size: metrics.agendaTimeFontSize))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: metrics.agendaTimeColumnWidth, alignment: .center)
        } else {
            VStack(alignment: .center, spacing: EquinoxDesign.spacingMicro) {
                Text(EquinoxFormatters.shortTime(event.slotStartDate))
                    .foregroundStyle(.primary)
                Text(EquinoxFormatters.shortTime(event.slotEndDate))
                    .foregroundStyle(.secondary)
            }
            .font(EquinoxDesign.monoTimeFont(size: metrics.agendaTimeFontSize))
            .lineLimit(1)
            .frame(width: metrics.agendaTimeColumnWidth, alignment: .center)
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
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
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
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
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
        if event.displaysAsAllDay { return String(localized: "All-day", bundle: .equinox, comment: "") }
        return EquinoxFormatters.timeRange(from: event.slotStartDate, to: event.slotEndDate)
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
