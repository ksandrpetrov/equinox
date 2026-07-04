import SwiftUI

struct AgendaSectionHeader: View {
    let date: CalendarDate
    let calendar: Calendar
    let metrics: SizeMetrics
    var backgroundStyle: BackgroundStyle = .glass

    var body: some View {
        let nsDate = date.date(in: calendar)
        let isToday = calendar.isDateInToday(nsDate)
        let isTomorrow = calendar.isDateInTomorrow(nsDate)

        HStack(spacing: EquinoxDesign.agendaHeaderTitleSpacing) {
            Text(agendaSectionTitle(isToday: isToday, isTomorrow: isTomorrow, nsDate: nsDate))
                .font(.system(size: metrics.fontSize + 1, weight: .semibold))
                .foregroundStyle(isToday ? EquinoxDesign.ColorToken.accent : .secondary)
            if !isToday && !isTomorrow {
                Text(EquinoxFormatters.shortWeekday(nsDate))
                    .font(.system(size: metrics.fontSize - 1, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, EquinoxDesign.spacingSM)
        .padding(.vertical, EquinoxDesign.agendaHeaderVerticalPadding)
        .equinoxGlassSurface(
            RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous),
            style: backgroundStyle
        )
        .padding(.horizontal, EquinoxDesign.spacingXS)
        .padding(.top, EquinoxDesign.spacingXS)
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
    var plaudMatch: PlaudEventMatch? = nil
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
        VStack(alignment: .leading, spacing: EquinoxDesign.spacingXS) {
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
                .padding(.trailing, trailingPadding)
                .padding(.vertical, showsSecondaryDetails ? EquinoxDesign.spacingXS : EquinoxDesign.spacingMicro)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap?()
                }

                if let url = event.joinURL {
                    EquinoxJoinButton(url: url, variant: .compact, metrics: metrics) {
                        URLOpener.open(url)
                    }
                    .padding(.trailing, plaudMatch == nil ? EquinoxDesign.spacingSM : EquinoxDesign.spacingXS)
                    .padding(.top, showsSecondaryDetails ? EquinoxDesign.spacingXS : 2)
                }

                if let match = plaudMatch {
                    PanelIconButton(
                        symbol: "waveform",
                        help: String(localized: "Open in Plaud", comment: "Plaud agenda button help"),
                        accessibilityLabel: String(localized: "Open in Plaud", comment: ""),
                        buttonSize: metrics.toolbarButtonSize
                    ) {
                        URLOpener.open(match.webURL)
                    }
                    .padding(.trailing, EquinoxDesign.spacingSM)
                    .padding(.top, showsSecondaryDetails ? EquinoxDesign.spacingXS : 2)
                }
            }
        }
        .equinoxCard(style: .subtle, isHovered: isHovered)
        .opacity(isDeclined ? EquinoxDesign.StateOpacity.declinedEvent : 1)
        .padding(.horizontal, EquinoxDesign.spacingXS)
        .onHover { isHovered = $0 }
        .animation(EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion), value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(eventAccessibilityLabel)
        .accessibilityHint(String(localized: "Tap to show details.", comment: "Agenda event hint"))
        .accessibilityAddTraits(.isButton)
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
            if event.showsRSVPControls,
               event.participationStatus?.needsResponse == true {
                EventRSVPRespondBadge()
            }
            if let relative = relativeTimeString {
                Text(relative)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(EquinoxDesign.ColorToken.accent)
            }
        }
    }

    @ViewBuilder
    private var expandedEventContent: some View {
        VStack(alignment: .leading, spacing: EquinoxDesign.spacingXS) {
            HStack(alignment: .firstTextBaseline) {
                Text(timeRangeString)
                    .font(EquinoxDesign.monoTimeFont(size: max(10, metrics.fontSize - 2)))
                    .foregroundStyle(.secondary)
                Spacer(minLength: EquinoxDesign.spacingXS)
                if event.showsRSVPControls,
                   event.participationStatus?.needsResponse == true {
                    EventRSVPRespondBadge()
                }
                if let relative = relativeTimeString {
                    Text(relative)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(EquinoxDesign.ColorToken.accent)
                }
            }

            Text(event.title)
                .font(.body.weight(.medium))
                .lineLimit(2)
                .opacity(isDeclined ? EquinoxDesign.StateOpacity.declinedTitle : 1)

            if showLocation || !event.calendarTitle.isEmpty {
                HStack(spacing: EquinoxDesign.spacingXS) {
                    if showLocation, let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    if !event.calendarTitle.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(event.calendarTitle)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var trailingPadding: CGFloat {
        if event.joinURL != nil || plaudMatch != nil {
            return EquinoxDesign.spacingSM
        }
        return EquinoxDesign.panelPadding
    }

    private var eventAccessibilityLabel: String {
        var parts = [event.title, timeRangeString]
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
        let now = Date()
        guard Calendar.autoupdatingCurrent.isDateInToday(event.startDate) else { return nil }
        if event.startDate <= now && event.endDate > now {
            return EquinoxFormatters.relativeTimeDuringEvent(from: now)
        }
        if event.startDate > now {
            return EquinoxFormatters.relativeTime(until: event.startDate, from: now)
        }
        return nil
    }
}
