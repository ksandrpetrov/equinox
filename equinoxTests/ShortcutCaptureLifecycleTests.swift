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

    func testRemovingRecorderFromWindowRestoresPreviousGlobalShortcutState() {
        let originalEnabled = KeyboardShortcuts.isEnabled
        defer { KeyboardShortcuts.isEnabled = originalEnabled }
        for enabled in [false, true] {
            KeyboardShortcuts.isEnabled = enabled
            let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
            let button = ShortcutCaptureButton(frame: .zero)
            window.contentView = button
            XCTAssertTrue(window.makeFirstResponder(button))
            XCTAssertTrue(button.isRecording)
            XCTAssertFalse(KeyboardShortcuts.isEnabled)

            window.contentView = nil

            XCTAssertFalse(button.isRecording)
            XCTAssertEqual(KeyboardShortcuts.isEnabled, enabled)
        }
    }

    func testRecorderKeysCancelClearRejectAndCommitWithoutChangingSavedShortcuts() throws {
        let application = NSApplication.shared
        let originalEnabled = KeyboardShortcuts.isEnabled
        let originalMenu = application.mainMenu
        defer {
            KeyboardShortcuts.isEnabled = originalEnabled
            application.mainMenu = originalMenu
        }
        application.mainMenu = nil
        let initial = KeyboardShortcuts.Shortcut(.f11)
        let accepted = KeyboardShortcuts.Shortcut(.f12)
        // The pinned KeyboardShortcuts version explicitly allows bare F12 even
        // when macOS has assigned it, so this fixture does not depend on settings.
        XCTAssertFalse(accepted.isTakenBySystem)
        let cases: [(String, Int, NSEvent.ModifierFlags, Int, KeyboardShortcuts.Shortcut?, Bool)] = [
            ("escape", kVK_Escape, [], 0, initial, false),
            ("delete", kVK_Delete, [], 1, nil, false),
            ("forward delete", kVK_ForwardDelete, [], 1, nil, false),
            ("unmodified letter", kVK_ANSI_A, [], 0, initial, true),
            ("shift letter", kVK_ANSI_A, [.shift], 0, initial, true),
            ("return", kVK_Return, [], 0, initial, true),
            ("function key", kVK_F12, [.function], 1, accepted, false),
        ]
        for (name, keyCode, modifiers, commitCount, expectedShortcut, rejected) in cases {
            KeyboardShortcuts.isEnabled = true
            let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
            let button = ShortcutCaptureButton(frame: .zero)
            button.currentShortcut = initial
            window.contentView = button
            defer {
                window.makeFirstResponder(nil)
                window.contentView = nil
            }
            XCTAssertTrue(window.makeFirstResponder(button), name)
            var commits: [KeyboardShortcuts.Shortcut?] = []
            var validations: [String] = []
            button.onCommit = { commits.append($0) }
            button.onValidation = { if let message = $0 { validations.append(message) } }
            let event = try XCTUnwrap(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                windowNumber: window.windowNumber, context: nil,
                characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                keyCode: UInt16(keyCode)
            ))

            button.handleKeyEvent(event)

            XCTAssertEqual(commits, commitCount == 1 ? [expectedShortcut] : [], name)
            XCTAssertEqual(button.currentShortcut, expectedShortcut, name)
            XCTAssertEqual(validations.count, rejected ? 1 : 0, name)
            XCTAssertTrue(validations.allSatisfy { !$0.isEmpty }, name)
            XCTAssertEqual(button.isRecording, rejected, name)
            XCTAssertEqual(KeyboardShortcuts.isEnabled, !rejected, name)
        }
    }

    func testRecorderDetectsNestedMenuConflictsAndAllowsItsCurrentShortcut() throws {
        let application = NSApplication.shared
        let originalEnabled = KeyboardShortcuts.isEnabled
        let originalMenu = application.mainMenu
        defer {
            KeyboardShortcuts.isEnabled = originalEnabled
            application.mainMenu = originalMenu
        }
        let shortcut = KeyboardShortcuts.Shortcut(.f12)
        let cases: [(String, KeyboardShortcuts.Shortcut, KeyboardShortcuts.Shortcut?, Bool)] = [
            ("nested conflict", shortcut, nil, true),
            ("unchanged shortcut", shortcut, shortcut, false),
            ("different key", KeyboardShortcuts.Shortcut(.f11), nil, false),
            ("different modifiers", KeyboardShortcuts.Shortcut(.f12, modifiers: .shift), nil, false),
        ]
        for (name, menuShortcut, current, rejected) in cases {
            let menu = NSMenu()
            let parent = NSMenuItem(title: "Audit", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            let item = NSMenuItem(title: "Audit action", action: nil,
                                  keyEquivalent: try XCTUnwrap(menuShortcut.nsMenuItemKeyEquivalent))
            item.keyEquivalentModifierMask = menuShortcut.modifiers
            submenu.addItem(item)
            parent.submenu = submenu
            menu.addItem(parent)
            application.mainMenu = menu
            KeyboardShortcuts.isEnabled = true
            let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
            let button = ShortcutCaptureButton(frame: .zero)
            button.currentShortcut = current
            window.contentView = button
            defer {
                window.makeFirstResponder(nil)
                window.contentView = nil
            }
            XCTAssertTrue(window.makeFirstResponder(button), name)
            var commits: [KeyboardShortcuts.Shortcut?] = []
            var validations: [String] = []
            button.onCommit = { commits.append($0) }
            button.onValidation = { if let message = $0 { validations.append(message) } }
            let event = try XCTUnwrap(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil,
                characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(kVK_F12)
            ))

            button.handleKeyEvent(event)

            XCTAssertEqual(commits, rejected ? [] : [shortcut], name)
            XCTAssertEqual(button.currentShortcut, rejected ? current : shortcut, name)
            XCTAssertEqual(validations.count, rejected ? 1 : 0, name)
            XCTAssertTrue(validations.allSatisfy { $0.contains("Audit action") }, name)
            XCTAssertEqual(button.isRecording, rejected, name)
            XCTAssertEqual(KeyboardShortcuts.isEnabled, !rejected, name)
        }
    }
}
