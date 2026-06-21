import SwiftUI

struct AgendaSectionHeader: View {
    let date: CalendarDate
    let calendar: Calendar
    var backgroundStyle: BackgroundStyle = .glass

    var body: some View {
        let nsDate = date.date(in: calendar)
        let isToday = calendar.isDateInToday(nsDate)
        let isTomorrow = calendar.isDateInTomorrow(nsDate)

        HStack(spacing: EquinoxDesign.spacingSM - 2) {
            Text(agendaSectionTitle(isToday: isToday, isTomorrow: isTomorrow, nsDate: nsDate))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isToday ? EquinoxDesign.ColorToken.todayAccent : .secondary)
            if !isToday && !isTomorrow {
                Text(EquinoxFormatters.shortWeekday(nsDate))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, EquinoxDesign.spacingSM)
        .padding(.vertical, EquinoxDesign.spacingSM - 3)
        .background { agendaHeaderBackground }
        .padding(.horizontal, EquinoxDesign.spacingXS)
        .padding(.top, EquinoxDesign.spacingXS)
    }

    @ViewBuilder
    private var agendaHeaderBackground: some View {
        let shape = RoundedRectangle(cornerRadius: EquinoxDesign.radiusSM, style: .continuous)
        if backgroundStyle == .solid {
            shape.fill(EquinoxDesign.ColorToken.surfaceSecondary)
        } else {
            shape
                .fill(.regularMaterial)
                .overlay { shape.fill(Color.primary.opacity(0.04)) }
                .glassEffect(.regular, in: shape)
        }
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
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(calendarColor)
                    .frame(width: 3)
                    .padding(.vertical, showsSecondaryDetails ? EquinoxDesign.spacingXS : 2)

                Group {
                    if showsSecondaryDetails {
                        expandedEventContent
                    } else {
                        compactEventContent
                    }
                }
                .padding(.leading, metrics.agendaEventLeadingMargin - 3)
                .padding(.trailing, trailingPadding)
                .padding(.vertical, showsSecondaryDetails ? EquinoxDesign.spacingXS : 2)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap?()
                }

                if let url = event.joinURL {
                    JoinMeetingButton(url: url, metrics: metrics) {
                        URLOpener.open(url)
                    }
                    .padding(.trailing, plaudMatch == nil ? EquinoxDesign.spacingSM : 0)
                    .padding(.top, showsSecondaryDetails ? EquinoxDesign.spacingXS : 2)
                }

                if let match = plaudMatch {
                    Button {
                        URLOpener.open(match.webURL)
                    } label: {
                        Image(systemName: "waveform")
                            .font(.system(size: 12))
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: metrics.toolbarButtonSize, height: metrics.toolbarButtonSize)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(String(localized: "Open in Plaud", comment: "Plaud agenda button help"))
                    .accessibilityLabel(String(localized: "Open in Plaud", comment: ""))
                    .padding(.trailing, EquinoxDesign.spacingSM)
                    .padding(.top, showsSecondaryDetails ? EquinoxDesign.spacingXS : 2)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                .fill(calendarColor.opacity(isHovered ? 0.08 : 0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(isHovered ? 0.08 : 0), lineWidth: 1)
        }
        .opacity(isDeclined ? 0.72 : 1)
        .padding(.horizontal, EquinoxDesign.spacingXS)
        .onHover { isHovered = $0 }
        .animation(EquinoxDesign.hoverAnimation, value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(eventAccessibilityLabel)
        .accessibilityHint(String(localized: "Tap to show details.", comment: "Agenda event hint"))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var compactEventContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: EquinoxDesign.spacingSM) {
            Text(timeRangeString)
                .font(EquinoxDesign.monoTimeFont(size: 11))
                .foregroundStyle(.secondary)
            Text(event.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .opacity(isDeclined ? 0.55 : 1)
            Spacer(minLength: EquinoxDesign.spacingXS)
            if event.showsRSVPControls,
               event.participationStatus?.needsResponse == true {
                EventRSVPRespondBadge()
            }
            if let relative = relativeTimeString {
                Text(relative)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(EquinoxDesign.ColorToken.todayAccent)
            }
        }
    }

    @ViewBuilder
    private var expandedEventContent: some View {
        VStack(alignment: .leading, spacing: EquinoxDesign.spacingXS) {
            HStack(alignment: .firstTextBaseline) {
                Text(timeRangeString)
                    .font(EquinoxDesign.monoTimeFont(size: 11))
                    .foregroundStyle(.secondary)
                Spacer(minLength: EquinoxDesign.spacingXS)
                if event.showsRSVPControls,
                   event.participationStatus?.needsResponse == true {
                    EventRSVPRespondBadge()
                }
                if let relative = relativeTimeString {
                    Text(relative)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(EquinoxDesign.ColorToken.todayAccent)
                }
            }

            Text(event.title)
                .font(.body.weight(.medium))
                .lineLimit(2)
                .opacity(isDeclined ? 0.55 : 1)

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
