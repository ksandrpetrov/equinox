import SwiftUI

struct DayHoverPreview: View {
    let date: CalendarDate
    let events: [DayEvent]
    let calendar: Calendar

    var body: some View {
        ModalPopoverCard {
            VStack(alignment: .leading, spacing: EquinoxDesign.spacingSM) {
                Text(headerString)
                    .font(.subheadline.weight(.semibold))

                if events.isEmpty {
                    Text(String(localized: "No events", comment: "Agenda empty day"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(events.prefix(3).enumerated()), id: \.offset) { _, event in
                        HStack(spacing: EquinoxDesign.spacingSM) {
                            Circle()
                                .fill(event.swiftUIColor)
                                .frame(width: 6, height: 6)
                            Text(event.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                    if events.count > 3 {
                        Text("+\(events.count - 3)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var headerString: String {
        EquinoxFormatters.dayMonth(date.date(in: calendar))
    }
}

struct DayCellHoverPreviewModifier: ViewModifier {
    let date: CalendarDate
    let events: [DayEvent]
    let calendar: Calendar
    let isEnabled: Bool

    @State private var isHovered = false
    @State private var showPreview = false
    @State private var hoverTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovered = hovering
                hoverTask?.cancel()
                if hovering && isEnabled {
                    hoverTask = Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        guard !Task.isCancelled, isHovered else { return }
                        showPreview = true
                    }
                } else {
                    showPreview = false
                }
            }
            .popover(isPresented: $showPreview, arrowEdge: .bottom) {
                DayHoverPreview(date: date, events: events, calendar: calendar)
                    .presentationBackground(.clear)
            }
    }
}

extension View {
    func dayHoverPreview(date: CalendarDate, events: [DayEvent], calendar: Calendar, isEnabled: Bool) -> some View {
        modifier(DayCellHoverPreviewModifier(date: date, events: events, calendar: calendar, isEnabled: isEnabled))
    }
}
