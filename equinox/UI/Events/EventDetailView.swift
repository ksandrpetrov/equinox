import SwiftUI

struct EventDetailView: View {
    @Bindable var appState: AppState
    let event: DayEvent
    let metrics: SizeMetrics
    @State private var isDeleting = false
    @State private var isDeleteConfirmationPresented = false
    @State private var actionError: String?

    private var sourceJoinURL: URL? {
        JoinURLPresentation.sourceJoinURL(
            location: event.location,
            eventURL: event.url,
            notes: event.notes,
            fallback: event.joinURL
        )
    }

    private var eventLinkURL: URL? {
        JoinURLPresentation.supplementalEventURL(
            eventURL: event.url,
            sourceJoinURL: sourceJoinURL
        )
    }

    private var displayNotes: String? {
        JoinURLPresentation.notesForDisplay(notes: event.notes, excludingJoinURL: sourceJoinURL)
    }

    var body: some View {
        EventDrawerScaffold(
            title: String(localized: "Event Details", bundle: .equinox, comment: "Event detail sheet title"),
            metrics: metrics,
            destructiveTitle: event.allowsDeletion
                ? String(localized: "Delete", bundle: .equinox, comment: "")
                : nil,
            isDestructiveInProgress: isDeleting,
            onCancel: { appState.dismissEventDrawer() },
            onDestructive: event.allowsDeletion ? { isDeleteConfirmationPresented = true } : nil
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: EquinoxDesign.spacingLG) {
                    if let actionError {
                        ModalErrorBanner(message: actionError)
                    }

                    EventDetailHeroHeader(event: event)

                    EventDetailMetadataCard(rows: Array(metadataRows.prefix(1)))

                    if hasActionSection {
                        VStack(spacing: EquinoxDesign.spacingSM) {
                            if let url = event.joinURL {
                                EventDetailJoinButton(url: url, action: { openURL(url, fallback: sourceJoinURL) })
                            }
                            if let url = eventLinkURL {
                                EventDetailLinkButton(url: url, action: { openURL(url) })
                            }
                        }
                    }

                    if metadataRows.count > 1 {
                        EventDetailMetadataCard(rows: Array(metadataRows.dropFirst()))
                    }
                    if let displayNotes {
                        EventDetailNotesCard(notes: displayNotes)
                    }
                }
                .padding(ModalDesign.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $isDeleteConfirmationPresented) {
            ModalConfirmDialog(
                title: EventDeletionConfirmation.title(isRecurring: event.isRecurring),
                message: event.title,
                confirmTitle: String(localized: "Delete", bundle: .equinox, comment: ""),
                onConfirm: {
                    isDeleteConfirmationPresented = false
                    deleteEvent()
                },
                onCancel: {
                    isDeleteConfirmationPresented = false
                }
            )
            .equinoxSheetPresentation(style: BackgroundStyle(rawValue: appState.preferences.backgroundStyle) ?? .glass)
        }
    }

    private var hasActionSection: Bool {
        event.joinURL != nil || eventLinkURL != nil
    }

    private func openURL(_ url: URL, fallback: URL? = nil) {
        actionError = URLOpener.open(url, fallback: fallback)
            ? nil : String(localized: "Could not open the link.", bundle: .equinox, comment: "URL open error")
    }

    private var metadataRows: [EventDetailMetadataRowModel] {
        var rows: [EventDetailMetadataRowModel] = [
            EventDetailMetadataRowModel(
                symbol: "clock",
                title: String(localized: "When", bundle: .equinox, comment: "Event detail metadata label"),
                value: whenString,
                tint: .secondary
            )
        ]

        if let location = event.location, !location.isEmpty {
            rows.append(
                EventDetailMetadataRowModel(
                    symbol: "mappin.and.ellipse",
                    title: String(localized: "Location", bundle: .equinox, comment: "Event detail metadata label"),
                    value: location,
                    tint: .secondary
                )
            )
        }

        return rows
    }

    private var whenString: String {
        if event.isEventAllDay {
            let formatter = EquinoxFormatters.formatter(key: "date.medium") { $0.dateStyle = .medium }
            let inclusiveEnd = inclusiveAllDayEnd(start: event.startDate, end: event.endDate, calendar: appState.calendar)
            let dates = appState.calendar.isDate(event.startDate, inSameDayAs: inclusiveEnd)
                ? formatter.string(from: event.startDate)
                : "\(formatter.string(from: event.startDate)) – \(formatter.string(from: inclusiveEnd))"
            return "\(String(localized: "All-day", bundle: .equinox, comment: "")) · \(dates)"
        }
        return EquinoxFormatters.mediumDateTime(from: event.startDate, to: event.endDate)
    }

    private func deleteEvent() {
        guard !isDeleting else { return }
        actionError = nil
        guard let id = event.eventIdentifier else {
            actionError = String(localized: "Could not delete event", bundle: .equinox, comment: "Delete event failure")
            return
        }
        isDeleting = true
        Task {
            if let error = await appState.deleteEvent(
                identifier: id,
                occurrenceStartDate: event.startDate
            ) {
                actionError = error
                isDeleting = false
            } else {
                isDeleting = false
                appState.dismissEventDrawer()
            }
        }
    }
}

private struct EventDetailLinkButton: View {
    let url: URL
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: EquinoxDesign.spacingMD) {
                Image(systemName: "link")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(EquinoxDesign.ColorToken.accent)
                    .frame(
                        width: EquinoxDesign.ControlWidth.joinIcon,
                        height: EquinoxDesign.ControlWidth.joinIcon
                    )

                VStack(alignment: .leading, spacing: EquinoxDesign.spacingMicro) {
                    Text(String(localized: "Open Link", bundle: .equinox, comment: "Event URL action"))
                        .font(.headline)
                    Text(url.host() ?? url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, EquinoxDesign.spacingMD)
            .padding(.vertical, EquinoxDesign.spacingSM)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .equinoxCard(style: .row, isHovered: isHovered)
        .onHover { isHovered = $0 }
        .animation(
            EquinoxDesign.animation(EquinoxDesign.hoverAnimation, reduceMotion: reduceMotion),
            value: isHovered
        )
        .accessibilityLabel(String(localized: "Open Link", bundle: .equinox, comment: "Event URL action"))
        .accessibilityHint(url.absoluteString)
    }
}
