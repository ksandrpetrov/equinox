import AppKit
import SwiftUI

struct EventDetailView: View {
    @Bindable var appState: AppState
    let event: DayEvent
    let metrics: SizeMetrics
    @Environment(\.dismiss) private var dismiss
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
        ModalSheetScaffold(
            title: String(localized: "Event Details", comment: "Event detail sheet title"),
            metrics: metrics,
            destructiveTitle: event.allowsDeletion
                ? String(localized: "Delete", comment: "")
                : nil,
            isDestructiveInProgress: isDeleting,
            minHeight: nil,
            onCancel: { dismiss() },
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
            .frame(maxHeight: EventDetailLayout.maxScrollableHeight)
        }
        .background {
            EventDetailParentClickDismissMonitor(
                isDismissEnabled: !isDeleteConfirmationPresented && !isDeleting,
                onDismiss: { dismiss() }
            )
            .allowsHitTesting(false)
        }
        .sheet(isPresented: $isDeleteConfirmationPresented) {
            ModalConfirmDialog(
                title: EventDeletionConfirmation.title(isRecurring: event.isRecurring),
                message: event.title,
                confirmTitle: String(localized: "Delete", comment: ""),
                onConfirm: {
                    isDeleteConfirmationPresented = false
                    deleteEvent()
                },
                onCancel: {
                    isDeleteConfirmationPresented = false
                }
            )
            .equinoxSheetPresentation()
        }
    }

    private var hasActionSection: Bool {
        event.joinURL != nil || eventLinkURL != nil
    }

    private func openURL(_ url: URL, fallback: URL? = nil) {
        actionError = URLOpener.open(url, fallback: fallback)
            ? nil : String(localized: "Could not open the link.", comment: "URL open error")
    }

    private var metadataRows: [EventDetailMetadataRowModel] {
        var rows: [EventDetailMetadataRowModel] = [
            EventDetailMetadataRowModel(
                symbol: "clock",
                title: String(localized: "When", comment: "Event detail metadata label"),
                value: whenString,
                tint: .secondary
            )
        ]

        if let location = event.location, !location.isEmpty {
            rows.append(
                EventDetailMetadataRowModel(
                    symbol: "mappin.and.ellipse",
                    title: String(localized: "Location", comment: "Event detail metadata label"),
                    value: location,
                    tint: .secondary
                )
            )
        }

        if let status = event.participationStatus {
            rows.append(
                EventDetailMetadataRowModel(
                    symbol: "person.crop.circle.badge.clock",
                    title: String(localized: "Attendance", comment: "Event detail metadata label"),
                    value: status.detailStatusLabel,
                    tint: status.chipForeground
                )
            )
        }

        return rows
    }

    private var whenString: String {
        if event.isEventAllDay {
            let formatter = EquinoxFormatters.formatter(key: "date.medium") { $0.dateStyle = .medium }
            let inclusiveEnd = appState.calendar.date(byAdding: .day, value: -1, to: event.endDate) ?? event.endDate
            let dates = appState.calendar.isDate(event.startDate, inSameDayAs: inclusiveEnd)
                ? formatter.string(from: event.startDate)
                : "\(formatter.string(from: event.startDate)) – \(formatter.string(from: inclusiveEnd))"
            return "\(String(localized: "All-day", comment: "")) · \(dates)"
        }
        return EquinoxFormatters.mediumDateTime(from: event.startDate, to: event.endDate)
    }

    private func deleteEvent() {
        guard !isDeleting else { return }
        actionError = nil
        guard let id = event.eventIdentifier else {
            actionError = String(localized: "Could not delete event", comment: "Delete event failure")
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
                dismiss()
            }
        }
    }
}

private struct EventDetailParentClickDismissMonitor: NSViewRepresentable {
    let isDismissEnabled: Bool
    let onDismiss: @MainActor () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isDismissEnabled: isDismissEnabled, onDismiss: onDismiss)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isDismissEnabled = isDismissEnabled
        context.coordinator.onDismiss = onDismiss
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    @MainActor
    final class Coordinator {
        var isDismissEnabled: Bool
        var onDismiss: @MainActor () -> Void

        private weak var sheetContentView: NSView?
        private var eventMonitor: Any?
        private var isDismissPending = false

        init(isDismissEnabled: Bool, onDismiss: @escaping @MainActor () -> Void) {
            self.isDismissEnabled = isDismissEnabled
            self.onDismiss = onDismiss
        }

        func install(for view: NSView) {
            sheetContentView = view
            guard eventMonitor == nil else { return }

            eventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                guard let self else { return event }
                let shouldConsume = MainActor.assumeIsolated {
                    guard self.isDismissEnabled,
                          !self.isDismissPending,
                          let sheetWindow = self.sheetContentView?.window,
                          let sheetParent = sheetWindow.sheetParent,
                          event.window === sheetParent,
                          sheetWindow.attachedSheet == nil else {
                        return false
                    }

                    self.isDismissPending = true
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.isDismissEnabled, self.sheetContentView?.window != nil else { return }
                        self.onDismiss()
                    }
                    return true
                }
                return shouldConsume ? nil : event
            }
        }

        func teardown() {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
                self.eventMonitor = nil
            }
            sheetContentView = nil
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
                    Text(String(localized: "Open Link", comment: "Event URL action"))
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
        .accessibilityLabel(String(localized: "Open Link", comment: "Event URL action"))
        .accessibilityHint(url.absoluteString)
    }
}

private enum EventDetailLayout {
    static var maxScrollableHeight: CGFloat {
        let fallbackHeight: CGFloat = 720
        let visibleHeight = NSScreen.main?.visibleFrame.height ?? fallbackHeight
        return max(360, min(fallbackHeight, visibleHeight - 96))
    }
}
