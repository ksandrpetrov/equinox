import KeyboardShortcuts
import AppKit
import Carbon.HIToolbox
import XCTest
@testable import EquinoxKit

@MainActor
final class ShortcutCaptureLifecycleTests: XCTestCase {
    func testClickRestartsCaptureAfterWindowResignedKeyWithTheSameFirstResponder() {
        let originalEnabled = KeyboardShortcuts.isEnabled
        defer { KeyboardShortcuts.isEnabled = originalEnabled }
        KeyboardShortcuts.isEnabled = true
        let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        let button = ShortcutCaptureButton(frame: .zero)
        window.contentView = button
        defer {
            window.makeFirstResponder(nil)
            window.contentView = nil
        }
        XCTAssertTrue(window.makeFirstResponder(button))
        XCTAssertTrue(button.isRecording)

        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
        XCTAssertTrue(window.firstResponder === button)
        XCTAssertFalse(button.isRecording)
        XCTAssertTrue(KeyboardShortcuts.isEnabled)

        button.performClick(nil)

        XCTAssertTrue(button.isRecording)
        XCTAssertFalse(KeyboardShortcuts.isEnabled)
    }

    func testTabAndShiftTabLeaveCaptureAndMoveFocus() throws {
        let originalEnabled = KeyboardShortcuts.isEnabled
        defer { KeyboardShortcuts.isEnabled = originalEnabled }
        for modifiers: NSEvent.ModifierFlags in [[], [.shift]] {
            KeyboardShortcuts.isEnabled = true
            let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
            let content = NSView()
            let previous = NSTextField()
            let capture = ShortcutCaptureButton(frame: .zero)
            let next = NSTextField()
            [previous, capture, next].forEach { content.addSubview($0) }
            window.contentView = content
            window.autorecalculatesKeyViewLoop = false
            previous.nextKeyView = capture
            capture.nextKeyView = next
            next.nextKeyView = previous
            XCTAssertTrue(window.makeFirstResponder(capture))
            XCTAssertTrue(capture.isRecording)
            var validations: [String] = []
            var commits = 0
            capture.onValidation = { if let message = $0 { validations.append(message) } }
            capture.onCommit = { _ in commits += 1 }
            let event = try XCTUnwrap(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                windowNumber: window.windowNumber, context: nil,
                characters: "\t", charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: UInt16(kVK_Tab)
            ))

            capture.handleKeyEvent(event)

            XCTAssertFalse(capture.isRecording)
            XCTAssertTrue(KeyboardShortcuts.isEnabled)
            let expected = modifiers.contains(.shift) ? previous : next
            XCTAssertNotNil(expected.currentEditor())
            XCTAssertTrue(window.firstResponder === expected.currentEditor(), "Tab must move to the appropriate text field")
            XCTAssertTrue(validations.isEmpty)
            XCTAssertEqual(commits, 0)
            window.makeFirstResponder(nil)
            window.contentView = nil
        }
    }

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
