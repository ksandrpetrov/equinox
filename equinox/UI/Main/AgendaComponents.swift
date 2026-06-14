import Pow
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
    var isExpanded: Bool = false
    var onToggleExpand: (() -> Void)? = nil
    var onRespond: ((EventParticipationStatus) async -> Void)? = nil

    @State private var isHovered = false
    @State private var isResponding = false
    @State private var joinHovered = false
    @State private var plaudHovered = false

    private var calendarColor: Color {
        event.swiftUIColor
    }

    private var isDeclined: Bool {
        event.participationStatus == .declined
    }

    private var showsSecondaryDetails: Bool {
        isExpanded
            || (showLocation && !(event.location?.isEmpty ?? true))
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
                    onToggleExpand?()
                }

                if let url = event.joinURL {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Image(systemName: "video.fill")
                            .font(.system(size: 12))
                            .symbolRenderingMode(.hierarchical)
                            .symbolEffect(.bounce, value: joinHovered)
                            .frame(width: metrics.toolbarButtonSize, height: metrics.toolbarButtonSize)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help(String(localized: "Join meeting", comment: ""))
                    .accessibilityLabel(String(localized: "Join meeting", comment: ""))
                    .padding(.trailing, plaudMatch == nil ? EquinoxDesign.spacingSM : 0)
                    .padding(.top, showsSecondaryDetails ? EquinoxDesign.spacingXS : 2)
                    .onHover { joinHovered = $0 }
                }

                if let match = plaudMatch {
                    Button {
                        NSWorkspace.shared.open(match.webURL)
                    } label: {
                        Image(systemName: "waveform")
                            .font(.system(size: 12))
                            .symbolRenderingMode(.hierarchical)
                            .symbolEffect(.bounce, value: plaudHovered)
                            .frame(width: metrics.toolbarButtonSize, height: metrics.toolbarButtonSize)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(String(localized: "Open in Plaud", comment: "Plaud agenda button help"))
                    .accessibilityLabel(String(localized: "Open in Plaud", comment: ""))
                    .padding(.trailing, EquinoxDesign.spacingSM)
                    .padding(.top, showsSecondaryDetails ? EquinoxDesign.spacingXS : 2)
                    .onHover { plaudHovered = $0 }
                }
            }

            if isExpanded, event.showsRSVPControls {
                EventRSVPBar(
                    status: event.participationStatus,
                    isCompact: true,
                    isResponding: isResponding
                ) { status in
                    guard let onRespond else { return }
                    isResponding = true
                    Task {
                        await onRespond(status)
                        isResponding = false
                    }
                }
                .padding(.horizontal, EquinoxDesign.spacingXS + 3)
                .padding(.bottom, EquinoxDesign.spacingXS)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                .fill(calendarColor.opacity(isHovered || isExpanded ? 0.08 : 0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: EquinoxDesign.cardRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(isHovered ? 0.08 : 0), lineWidth: 1)
        }
        .opacity(isDeclined ? 0.72 : 1)
        .padding(.horizontal, EquinoxDesign.spacingXS)
        .onHover { isHovered = $0 }
        .animation(EquinoxDesign.hoverAnimation, value: isHovered)
        .animation(EquinoxDesign.expandAnimation, value: isExpanded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(eventAccessibilityLabel)
        .accessibilityHint(String(localized: "Tap to expand. Tap again to show details.", comment: "Agenda event hint"))
        .accessibilityAddTraits(isExpanded ? .isSelected : [])
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
                   !isExpanded,
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
                .lineLimit(isExpanded ? nil : 2)
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

            if isExpanded, let notes = event.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                    .transition(.movingParts.blur.combined(with: .opacity))
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
            return String(localized: "Now", comment: "Event happening now")
        }
        if event.startDate > now {
            let minutes = Int(event.startDate.timeIntervalSince(now) / 60)
            if minutes < 60 {
                return String(format: String(localized: "in %lld min", comment: "Relative event time"), minutes)
            }
            let hours = minutes / 60
            return String(format: String(localized: "in %lld h", comment: "Relative event time hours"), hours)
        }
        return nil
    }
}
