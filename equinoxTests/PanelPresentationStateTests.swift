import KeyboardShortcuts
import AppKit
import XCTest
@testable import equinox

@MainActor
final class PanelPresentationStateTests: XCTestCase {
    func testSystemTimeNotificationsFromBackgroundThreadDoNotCrash() async {
        // The test host runs the app's real StatusItemController observers.
        // Foundation can deliver the midnight notification on a background queue.
        for name in [
            Notification.Name.NSCalendarDayChanged,
            .NSSystemClockDidChange,
            .NSSystemTimeZoneDidChange
        ] {
            await postFromBackground(name, center: .default)
        }
        await postFromBackground(NSWorkspace.didWakeNotification, center: NSWorkspace.shared.notificationCenter)
    }

    func testLocaleNotificationFromBackgroundThreadDoesNotCrash() async {
        await postFromBackground(NSLocale.currentLocaleDidChangeNotification, center: .default)
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
            String(localized: "Equinox calendar", comment: "Menu bar status item accessibility label")
        )
        let expectedHelp = String(
            localized: "Show or hide the Equinox panel from anywhere",
            comment: "Menu bar status item accessibility help and tooltip"
        )
        XCTAssertEqual(button.accessibilityHelp(), expectedHelp)
        XCTAssertEqual(button.toolTip, expectedHelp)
    }
}

@MainActor
final class ShortcutCaptureLifecycleTests: XCTestCase {
    func testLeavingRecorderWindowRestoresGlobalShortcuts() {
        let originalEnabled = KeyboardShortcuts.isEnabled
        defer { KeyboardShortcuts.isEnabled = originalEnabled }
        KeyboardShortcuts.isEnabled = true
        let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        let button = ShortcutCaptureButton(frame: .zero)
        window.contentView = button
        XCTAssertTrue(button.becomeFirstResponder())
        XCTAssertTrue(button.isRecording)
        XCTAssertFalse(KeyboardShortcuts.isEnabled)
        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
        XCTAssertFalse(button.isRecording)
        XCTAssertTrue(KeyboardShortcuts.isEnabled)
        window.contentView = nil
    }
}
