import KeyboardShortcuts
import AppKit
import Carbon.HIToolbox
import XCTest
@testable import EquinoxKit

@MainActor
final class PanelPresentationStateTests: XCTestCase {
    func testReopeningPanelPreservesMonthDayAndAgendaPosition() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let state = context.appState
        state.goToNextMonth()
        let selectedDate = state.events.selectedDate
        let monthDate = state.events.monthDate
        let scrollToken = state.events.agendaScrollToken

        state.panel.isPanelVisible = false
        state.panel.isPanelVisible = true
        state.panelDidOpen()

        XCTAssertEqual(state.events.selectedDate, selectedDate)
        XCTAssertEqual(state.events.monthDate, monthDate)
        XCTAssertEqual(state.events.agendaScrollToken, scrollToken)
        state.goToToday()
        XCTAssertEqual(state.events.selectedDate, state.events.todayDate)
    }

    func testStatusItemClickWithoutWindowLeavesDismissalToButtonToggle() {
        let monitor = PanelDismissMonitor()
        defer { monitor.teardown() }
        var isPanelVisible = true
        var outsideClicks = 0
        var statusFrame = NSRect(x: 800, y: 900, width: 40, height: 24)
        monitor.updateMonitoring(
            isPinned: false,
            isPanelVisible: true,
            isModalSheetPresented: { false },
            isEquinoxWindow: { _ in false },
            statusItemFrame: { statusFrame },
            onOutsideClick: {
                outsideClicks += 1
                isPanelVisible = false
            }
        )

        monitor.handleMouseDown(window: nil, screenLocation: NSPoint(x: statusFrame.midX, y: statusFrame.midY))
        XCTAssertTrue(monitor.isStatusItemClickInProgress)
        monitor.handleMouseUp()
        XCTAssertFalse(monitor.isStatusItemClickInProgress)
        isPanelVisible.toggle()

        XCTAssertFalse(isPanelVisible, "Outside-click dismissal must not hide the panel before its button toggles it")
        XCTAssertEqual(outsideClicks, 0)

        // The status item can move to another display while the monitor is installed.
        statusFrame.origin = NSPoint(x: -600, y: 1200)
        monitor.handleMouseDown(window: nil, screenLocation: NSPoint(x: statusFrame.midX, y: statusFrame.midY))
        isPanelVisible.toggle()

        XCTAssertTrue(isPanelVisible)
        XCTAssertEqual(outsideClicks, 0)
        monitor.handleMouseDown(window: nil, screenLocation: NSPoint(x: 820, y: 912))
        XCTAssertFalse(isPanelVisible)
        XCTAssertEqual(outsideClicks, 1, "The old status item position is an outside click after moving")
    }

    func testDismissMonitorPreservesPanelAndModalInteractions() {
        let monitor = PanelDismissMonitor()
        defer { monitor.teardown() }
        let panel = NSPanel(contentRect: .zero, styleMask: [.nonactivatingPanel], backing: .buffered, defer: false)
        let otherWindow = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        var isModalPresented = false
        var outsideClicks = 0
        monitor.updateMonitoring(
            isPinned: false,
            isPanelVisible: true,
            isModalSheetPresented: { isModalPresented },
            isEquinoxWindow: { $0 === panel },
            statusItemFrame: { nil },
            onOutsideClick: { outsideClicks += 1 }
        )

        monitor.handleMouseDown(window: panel, screenLocation: .zero)
        XCTAssertEqual(outsideClicks, 0)
        monitor.handleMouseDown(window: otherWindow, screenLocation: .zero)
        monitor.handleMouseDown(window: nil, screenLocation: .zero)
        XCTAssertEqual(outsideClicks, 2, "Local and global outside clicks both dismiss the panel")

        isModalPresented = true
        monitor.handleMouseDown(window: otherWindow, screenLocation: .zero)
        monitor.handleMouseDown(window: nil, screenLocation: .zero)
        XCTAssertEqual(outsideClicks, 2, "Outside clicks must preserve an open event sheet")

        monitor.teardown()
        isModalPresented = false
        monitor.handleMouseDown(window: nil, screenLocation: .zero)
        XCTAssertEqual(outsideClicks, 2)
    }

    func testStatusItemHitAreaIncludesTopScreenEdgeAndCorners() {
        let frame = NSRect(x: 800, y: 900, width: 40, height: 24)
        for point in [
            NSPoint(x: frame.midX, y: frame.maxY),
            NSPoint(x: frame.minX, y: frame.maxY),
            NSPoint(x: frame.maxX, y: frame.maxY),
            NSPoint(x: frame.midX, y: frame.minY)
        ] {
            XCTAssertTrue(PanelDismissMonitor.containsStatusItemPoint(point, frame: frame))
        }
        XCTAssertFalse(PanelDismissMonitor.containsStatusItemPoint(NSPoint(x: frame.minX - 1, y: frame.maxY), frame: frame))
        XCTAssertFalse(PanelDismissMonitor.containsStatusItemPoint(NSPoint(x: frame.midX, y: frame.minY - 1), frame: frame))
        XCTAssertFalse(PanelDismissMonitor.containsStatusItemPoint(.zero, frame: nil))
    }

    func testSystemTimeNotificationsFromBackgroundThreadReachCalendarRefresh() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let center = NotificationCenter()
        let workspaceCenter = NotificationCenter()
        let controller = StatusItemController(appState: context.appState)
        controller.setupSystemChangeObservers(notificationCenter: center, workspaceNotificationCenter: workspaceCenter)
        defer { controller.stopObservingSystemChanges() }
        for name in [
            Notification.Name.NSCalendarDayChanged,
            .NSSystemClockDidChange,
            .NSSystemTimeZoneDidChange
        ] {
            let refreshed = expectation(description: "Calendar time context invalidated for \(name.rawValue)")
            context.store.onTimeInvalidation = { refreshed.fulfill() }
            await postFromBackground(name, center: center)
            await fulfillment(of: [refreshed], timeout: 2)
        }
        let wakeRefreshed = expectation(description: "Calendar time context invalidated after wake")
        context.store.onTimeInvalidation = { wakeRefreshed.fulfill() }
        await postFromBackground(NSWorkspace.didWakeNotification, center: workspaceCenter)
        await fulfillment(of: [wakeRefreshed], timeout: 2)
        XCTAssertEqual(context.store.timeInvalidationCount, 4)
        XCTAssertEqual(context.store.accessRequestCount, 1, "Access is prepared once through the stub, not once per notification")
    }

    func testLocaleNotificationFromBackgroundThreadRefreshesCachedFormatters() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let center = NotificationCenter()
        let controller = StatusItemController(appState: context.appState)
        controller.setupSystemChangeObservers(notificationCenter: center, workspaceNotificationCenter: NotificationCenter())
        defer { controller.stopObservingSystemChanges() }
        let oldFormatter = EquinoxFormatters.formatter(key: "test.locale-observer") { $0.dateFormat = "HH" }
        let refreshed = expectation(description: "Presentation refreshed after locale change")
        context.appState.events.onMeetingIndicatorChanged = { refreshed.fulfill() }

        await postFromBackground(NSLocale.currentLocaleDidChangeNotification, center: center)
        await fulfillment(of: [refreshed], timeout: 2)

        let newFormatter = EquinoxFormatters.formatter(key: "test.locale-observer") { $0.dateFormat = "hh" }
        XCTAssertFalse(oldFormatter === newFormatter)
        XCTAssertEqual(newFormatter.dateFormat, "hh")
        XCTAssertEqual(context.store.accessRequestCount, 0)
        XCTAssertEqual(context.store.timeInvalidationCount, 0)
    }

    private func postFromBackground(_ name: Notification.Name, center: NotificationCenter) async {
        let posted = expectation(description: "Posted \(name.rawValue) from a background queue")
        DispatchQueue.global(qos: .userInitiated).async {
            XCTAssertFalse(Thread.isMainThread)
            center.post(name: name, object: nil)
            posted.fulfill()
        }
        await fulfillment(of: [posted], timeout: 5)
    }

    func testDeepLinkBeforeApplicationInitializationIsDeferred() throws {
        let delegate = AppDelegate()
        delegate.application(NSApplication.shared, open: [try XCTUnwrap(URL(string: "equinox://date/2026-06-14"))])
        XCTAssertNil(delegate.appState)
    }

    func testModalSheetPresentedWhenNewEventSheetOpen() {
        let panel = PanelPresentationState()
        panel.isNewEventSheetPresented = true
        XCTAssertTrue(panel.isModalSheetPresented)
    }

    func testModalSheetPresentedWhenEventDetailOpen() {
        let panel = PanelPresentationState()
        panel.isEventDetailPresented = true
        XCTAssertTrue(panel.isModalSheetPresented)
    }

    func testModalSheetNotPresentedByDefault() {
        let panel = PanelPresentationState()
        XCTAssertFalse(panel.isModalSheetPresented)
    }

    func testEscapeDismissesOnlyVisiblePanelWithoutModalSheet() {
        XCTAssertTrue(PanelWindowController.shouldHandleCancelOperation(
            isVisible: true,
            isModalSheetPresented: false
        ))
        XCTAssertFalse(PanelWindowController.shouldHandleCancelOperation(
            isVisible: false,
            isModalSheetPresented: false
        ))
        XCTAssertFalse(PanelWindowController.shouldHandleCancelOperation(
            isVisible: true,
            isModalSheetPresented: true
        ))
    }

    func testKeyablePanelRoutesCancelOperationToDismissHandler() {
        let window = KeyablePanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        var didRequestDismissal = false
        window.onCancelOperation = {
            didRequestDismissal = true
            return true
        }

        window.cancelOperation(nil)

        XCTAssertTrue(didRequestDismissal)
    }

    func testStatusItemButtonHasLocalizedAccessibilityMetadata() {
        let button = NSButton()

        StatusItemController.configureAccessibility(for: button)

        XCTAssertEqual(
            button.accessibilityLabel(),
            String(localized: "Equinox calendar", bundle: .equinox, comment: "Menu bar status item accessibility label")
        )
        let expectedHelp = String(
            localized: "Show or hide the Equinox panel from anywhere",
            bundle: .equinox, comment: "Menu bar status item accessibility help and tooltip"
        )
        XCTAssertEqual(button.accessibilityHelp(), expectedHelp)
        XCTAssertEqual(button.toolTip, expectedHelp)
    }
}
