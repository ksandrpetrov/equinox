import KeyboardShortcuts
import AppKit
import Carbon.HIToolbox
import XCTest
@testable import EquinoxKit

@MainActor
final class PanelPresentationStateTests: XCTestCase {
    private var statusFrame = NSRect(x: 800, y: 900, width: 40, height: 24)
    private var isModalPresented = false

    func testPinActionsPersistStateAndNotifyOnlyChanges() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let state = context.appState
        var observedStates: [Bool] = []
        state.panel.onPinStateChanged = { observedStates.append(state.isPinned) }
        defer { state.panel.onPinStateChanged = nil }

        XCTAssertFalse(state.isPinned)
        state.setPinned(false)
        XCTAssertEqual(observedStates, [])
        state.togglePinnedState()
        XCTAssertTrue(state.isPinned)
        XCTAssertTrue(context.defaults.bool(forKey: kPanelPinned))
        state.togglePinnedState()
        XCTAssertFalse(state.isPinned)
        XCTAssertFalse(context.defaults.bool(forKey: kPanelPinned))
        XCTAssertEqual(observedStates, [true, false])

        state.setPinned(true)
        state.setPinned(true)
        XCTAssertTrue(state.isPinned)
        XCTAssertTrue(context.defaults.bool(forKey: kPanelPinned))
        XCTAssertEqual(observedStates, [true, false, true])
        state.setPinned(false)
        XCTAssertFalse(context.defaults.bool(forKey: kPanelPinned))
        XCTAssertEqual(observedStates, [true, false, true, false])
    }

    func testReopeningPanelPreservesMonthDayAndAgendaPosition() async throws {
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let state = context.appState
        let initialDate = state.events.selectedDate
        let initialMonth = CalendarDate(year: initialDate.year, monthIndex: initialDate.monthIndex, day: 1)
        state.goToNextMonth()
        // Finish the initial navigation fetch before closing and reopening.
        await state.events.resetCalendarSelection()
        let selectedDate = state.events.selectedDate
        let monthDate = state.events.monthDate
        let scrollToken = state.events.agendaScrollToken
        XCTAssertEqual(selectedDate, initialDate.addingMonthsPreservingDay(1))
        let previousRefetchCount = context.store.refetchedRanges.count
        let refreshed = expectation(description: "Reopened panel applied a fresh snapshot")
        state.events.onEventsSnapshotChanged = { refreshed.fulfill() }
        defer { state.events.onEventsSnapshotChanged = {} }

        state.panel.isPanelVisible = false
        state.panel.isPanelVisible = true
        state.panelDidOpen()
        await fulfillment(of: [refreshed], timeout: 2)

        XCTAssertEqual(context.store.refetchedRanges.count, previousRefetchCount + 1)
        XCTAssertEqual(state.events.selectedDate, selectedDate)
        XCTAssertEqual(state.events.monthDate, monthDate)
        XCTAssertEqual(state.events.agendaScrollToken, scrollToken)
        state.goToPreviousMonth()
        XCTAssertEqual(state.events.selectedDate, initialDate)
        XCTAssertEqual(state.events.monthDate, initialMonth)
        state.goToNextMonth()
        state.goToToday()
        XCTAssertEqual(state.events.selectedDate, state.events.todayDate)
    }

    func testStatusItemClickWithoutWindowLeavesDismissalToButtonToggle() {
        let monitor = PanelDismissMonitor()
        defer { monitor.teardown() }
        var isPanelVisible = true
        var outsideClicks = 0
        monitor.updateMonitoring(
            isPinned: false,
            isPanelVisible: true,
            isModalSheetPresented: { false },
            isEquinoxWindow: { _ in false },
            statusItemFrame: { self.statusFrame },
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

        for (isPinned, isVisible) in [(true, true), (false, false), (true, false)] {
            monitor.handleMouseDown(window: nil, screenLocation: NSPoint(x: statusFrame.midX, y: statusFrame.midY))
            XCTAssertTrue(monitor.isStatusItemClickInProgress)
            monitor.updateMonitoring(
                isPinned: isPinned, isPanelVisible: isVisible,
                isModalSheetPresented: { false }, isEquinoxWindow: { _ in false },
                statusItemFrame: { self.statusFrame }, onOutsideClick: { outsideClicks += 1 }
            )
            XCTAssertFalse(monitor.isStatusItemClickInProgress, "Disabling monitoring clears an unfinished status click")
        }
        monitor.handleMouseDown(window: nil, screenLocation: NSPoint(x: statusFrame.midX, y: statusFrame.midY))
        XCTAssertTrue(monitor.isStatusItemClickInProgress)
        monitor.teardown()
        XCTAssertFalse(monitor.isStatusItemClickInProgress)
    }

    func testDismissObserverInstallsOnceAndCanRestartAfterTeardown() async {
        let monitor = PanelDismissMonitor()
        defer { monitor.teardown() }
        var initialCalls = 0
        var restartedCalls = 0
        let initial = expectation(description: "Initial resign-active notification delivered")
        monitor.install {
            initialCalls += 1
            if initialCalls == 1 { initial.fulfill() }
        }
        monitor.install { XCTFail("Repeated installation must preserve the original subscription") }
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)
        await fulfillment(of: [initial], timeout: 2)
        XCTAssertEqual(initialCalls, 1)

        monitor.teardown()
        let restarted = expectation(description: "Subscription works after teardown and installation")
        monitor.install {
            restartedCalls += 1
            if restartedCalls == 1 { restarted.fulfill() }
        }
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: nil)
        await fulfillment(of: [restarted], timeout: 2)
        XCTAssertEqual(initialCalls, 1)
        XCTAssertEqual(restartedCalls, 1)
    }

    func testDismissMonitorPreservesPanelAndModalInteractions() {
        let monitor = PanelDismissMonitor()
        defer { monitor.teardown() }
        let panel = NSPanel(contentRect: .zero, styleMask: [.nonactivatingPanel], backing: .buffered, defer: false)
        let otherWindow = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        var outsideClicks = 0
        monitor.updateMonitoring(
            isPinned: false,
            isPanelVisible: true,
            isModalSheetPresented: { self.isModalPresented },
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
        var refreshCount = 0
        context.appState.events.onMeetingIndicatorChanged = {
            refreshCount += 1
            if refreshCount == 1 {
                refreshed.fulfill()
            } else {
                XCTFail("A locale change must update presentation only once")
            }
        }
        defer { context.appState.events.onMeetingIndicatorChanged = {} }

        await postFromBackground(NSLocale.currentLocaleDidChangeNotification, center: center)
        await fulfillment(of: [refreshed], timeout: 2)

        let newFormatter = EquinoxFormatters.formatter(key: "test.locale-observer") { $0.dateFormat = "hh" }
        XCTAssertEqual(refreshCount, 1)
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
            localized: "Click to show or hide Equinox. Right-click for Preferences and Quit.",
            bundle: .equinox, comment: "Menu bar status item accessibility help and tooltip"
        )
        XCTAssertEqual(button.accessibilityHelp(), expectedHelp)
        XCTAssertEqual(button.toolTip, expectedHelp)
    }

    func testStatusMenuOffersQuitWithoutOpeningTheCalendarPanel() async throws {
        // Menu validation needs an application even when this test runs first.
        _ = NSApplication.shared
        let context = try CalendarTestContext()
        defer { context.cleanUp() }
        await context.finishInitialization()
        let controller = StatusItemController(appState: context.appState)
        let menu = controller.makeStatusMenu()
        menu.update()

        let quit = try XCTUnwrap(menu.item(withTitle:
            String(localized: "Quit Equinox", bundle: .equinox, comment: "")))
        XCTAssertTrue(quit.isEnabled)
        XCTAssertEqual(quit.action, #selector(NSApplication.terminate(_:)))
        XCTAssertTrue(quit.target === NSApp)
        XCTAssertEqual(quit.keyEquivalent, "q")
        XCTAssertEqual(quit.keyEquivalentModifierMask, .command)
        XCTAssertFalse(context.appState.panel.isPanelVisible)

        let preferences = try XCTUnwrap(menu.item(withTitle:
            String(localized: "Preferences", bundle: .equinox, comment: "")))
        XCTAssertTrue(preferences.isEnabled)
        XCTAssertTrue(preferences.target === controller)
        XCTAssertTrue(controller.responds(to: try XCTUnwrap(preferences.action)))
        XCTAssertEqual(preferences.keyEquivalent, ",")
        XCTAssertEqual(preferences.keyEquivalentModifierMask, .command)
    }
}
