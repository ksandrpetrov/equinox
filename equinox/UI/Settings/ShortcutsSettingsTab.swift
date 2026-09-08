import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts
import SwiftUI

struct ShortcutsSettingsTab: View {
    var searchText: String = ""
    @State private var shortcutError: String?

    var body: some View {
        SettingsDetailScaffold(title: String(localized: "Shortcuts", comment: "Settings section: shortcuts")) {
            if showsGlobalShortcutSection {
                SettingsSection(
                    String(localized: "Global Shortcut", comment: "Settings shortcuts section"),
                    subtitle: String(localized: "Show or hide the Equinox panel from anywhere", comment: "Shortcut section subtitle")
                ) {
                    SettingsRow(title: String(localized: "Keyboard shortcut", comment: "")) {
                        EquinoxShortcutRecorder(validationMessage: $shortcutError)
                            .frame(width: EquinoxDesign.ControlWidth.shortcutRecorder, height: EquinoxDesign.ControlWidth.shortcutRecorderHeight)
                    }

                    if let shortcutError {
                        SettingsDivider()
                        SettingsFooter(text: shortcutError, style: .error)
                    }
                }
            }

            if showsPanelShortcutsSection {
                SettingsSection(String(localized: "Panel Shortcuts", comment: "Settings panel shortcuts section")) {
                    shortcutRow(String(localized: "New Event", comment: ""), "⌘N")
                    SettingsDivider()
                    shortcutRow(String(localized: "Pin Equinox", comment: ""), "P")
                    SettingsDivider()
                    shortcutRow(String(localized: "Preferences…", comment: ""), "⌘,")
                    SettingsDivider()
                    shortcutRow(String(localized: "Go to Today", comment: "Shortcut cheat sheet"), "T")
                }
            }

            if !searchText.isEmpty && !showsGlobalShortcutSection && !showsPanelShortcutsSection {
                settingsSearchEmptyState
            }
        }
    }

    private var showsGlobalShortcutSection: Bool {
        SettingsSearchFilter.matches(
            searchText: searchText,
            keywords: "Global Shortcut", "Keyboard shortcut", "Show or hide the Equinox panel from anywhere"
        )
    }

    private var showsPanelShortcutsSection: Bool {
        SettingsSearchFilter.matches(
            searchText: searchText,
            keywords: "Panel Shortcuts", "New Event", "Pin Equinox", "Preferences…", "Go to Today"
        )
    }

    private var settingsSearchEmptyState: some View {
        ContentUnavailableView(
            String(localized: "No Results", comment: "Settings search empty"),
            systemImage: "magnifyingglass",
            description: Text(String(localized: "Try a different search term.", comment: ""))
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, EquinoxDesign.spacingXL)
    }

    private func shortcutRow(_ title: String, _ shortcut: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(shortcut)
                .font(EquinoxDesign.monoTimeFont(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, EquinoxDesign.spacingSM)
                .padding(.vertical, EquinoxDesign.spacingXS)
                .background {
                    RoundedRectangle(cornerRadius: EquinoxDesign.chipRadius, style: .continuous)
                        .fill(EquinoxDesign.ColorToken.interactionSubtle)
                        .overlay {
                            RoundedRectangle(cornerRadius: EquinoxDesign.chipRadius, style: .continuous)
                                .strokeBorder(EquinoxDesign.ColorToken.hairlineBorder, lineWidth: 0.5)
                        }
                }
        }
        .padding(.vertical, SettingsDesign.rowVerticalPadding)
    }
}

private struct EquinoxShortcutRecorder: NSViewRepresentable {
    @Binding var validationMessage: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(validationMessage: $validationMessage)
    }

    func makeNSView(context: Context) -> ShortcutRecorderView {
        ShortcutRecorderView(name: .togglePanel) { message in
            context.coordinator.report(message)
        }
    }

    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) {
        context.coordinator.validationMessage = $validationMessage
        nsView.refreshDisplay()
    }

    @MainActor
    final class Coordinator {
        var validationMessage: Binding<String?>

        init(validationMessage: Binding<String?>) {
            self.validationMessage = validationMessage
        }

        func report(_ message: String?) {
            validationMessage.wrappedValue = message
        }
    }
}

@MainActor
private final class ShortcutRecorderView: NSView {
    private let name: KeyboardShortcuts.Name
    private let captureButton = ShortcutCaptureButton()
    private let clearButton = NSButton()
    private let reportValidation: (String?) -> Void

    init(name: KeyboardShortcuts.Name, reportValidation: @escaping (String?) -> Void) {
        self.name = name
        self.reportValidation = reportValidation
        super.init(frame: .zero)

        captureButton.bezelStyle = .rounded
        captureButton.setButtonType(.momentaryPushIn)
        captureButton.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        captureButton.toolTip = String(localized: "Click to record a shortcut", comment: "Shortcut recorder help")
        captureButton.setAccessibilityLabel(String(localized: "Keyboard shortcut", comment: ""))
        captureButton.onCommit = { [weak self] shortcut in
            self?.commit(shortcut)
        }
        captureButton.onValidation = reportValidation

        clearButton.isBordered = false
        clearButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
        clearButton.contentTintColor = .secondaryLabelColor
        clearButton.toolTip = String(localized: "Clear shortcut", comment: "Shortcut recorder clear button")
        clearButton.setAccessibilityLabel(String(localized: "Clear shortcut", comment: "Shortcut recorder clear button"))
        clearButton.target = self
        clearButton.action = #selector(clearShortcut)

        for view in [captureButton, clearButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            captureButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            captureButton.topAnchor.constraint(equalTo: topAnchor),
            captureButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            clearButton.leadingAnchor.constraint(equalTo: captureButton.trailingAnchor, constant: EquinoxDesign.spacingXS),
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: EquinoxDesign.toolbarButtonSize),
        ])
        refreshDisplay()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshDisplay() {
        let shortcut = KeyboardShortcuts.getShortcut(for: name)
        captureButton.currentShortcut = shortcut
        if !captureButton.isRecording {
            captureButton.title = shortcut?.description ?? String(localized: "Record Shortcut", comment: "Shortcut recorder empty state")
        }
        clearButton.isHidden = shortcut == nil
    }

    private func commit(_ shortcut: KeyboardShortcuts.Shortcut?) {
        KeyboardShortcuts.setShortcut(shortcut, for: name)
        reportValidation(nil)
        refreshDisplay()
    }

    @objc private func clearShortcut() {
        commit(nil)
    }
}

@MainActor
final class ShortcutCaptureButton: NSButton {
    var currentShortcut: KeyboardShortcuts.Shortcut?
    var onCommit: (KeyboardShortcuts.Shortcut?) -> Void = { _ in }
    var onValidation: (String?) -> Void = { _ in }

    private var eventMonitor: Any?
    private var resignKeyObserver: NSObjectProtocol?
    private var wasKeyboardShortcutsEnabled = true
    private(set) var isRecording = false

    private static let functionKeyCodes: Set<UInt16> = Set([
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ].compactMap { UInt16(exactly: $0) })

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        target = self
        action = #selector(beginRecording)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { stopCapture() }
        super.viewWillMove(toWindow: newWindow)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { startCaptureIfNeeded() }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { stopCapture() }
        return resigned
    }

    @objc private func beginRecording() {
        window?.makeFirstResponder(self)
    }

    private func startCaptureIfNeeded() {
        guard !isRecording else { return }
        isRecording = true
        wasKeyboardShortcutsEnabled = KeyboardShortcuts.isEnabled
        KeyboardShortcuts.isEnabled = false
        title = String(localized: "Press shortcut…", comment: "Shortcut recorder recording state")
        onValidation(nil)

        if let window {
            resignKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.stopCapture() }
            }
        }

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self, self.isRecording else { return event }
            if event.type == .keyDown {
                self.handleKeyEvent(event)
                return nil
            }

            let localPoint = self.convert(event.locationInWindow, from: nil)
            if !self.bounds.insetBy(dx: -3, dy: -3).contains(localPoint) {
                self.window?.makeFirstResponder(nil)
            }
            return event
        }
    }

    private func stopCapture() {
        guard isRecording else { return }
        isRecording = false
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
            self.resignKeyObserver = nil
        }
        KeyboardShortcuts.isEnabled = wasKeyboardShortcutsEnabled
        title = currentShortcut?.description ?? String(localized: "Record Shortcut", comment: "Shortcut recorder empty state")
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let hasPrimaryModifier = !modifiers.intersection([.command, .control, .option]).isEmpty

        if modifiers.isEmpty, event.keyCode == UInt16(kVK_Escape) {
            window?.makeFirstResponder(nil)
            return
        }
        if modifiers.isEmpty, event.keyCode == UInt16(kVK_Tab) {
            window?.selectNextKeyView(self)
            return
        }
        if modifiers.isEmpty,
           event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete) {
            onCommit(nil)
            currentShortcut = nil
            window?.makeFirstResponder(nil)
            return
        }

        guard hasPrimaryModifier || Self.functionKeyCodes.contains(event.keyCode),
              let shortcut = KeyboardShortcuts.Shortcut(event: event) else {
            reject(String(localized: "Use Command, Control, or Option with a key, or choose a function key.", comment: "Shortcut recorder validation"))
            return
        }
        guard !shortcut.isTakenBySystem else {
            reject(String(localized: "This shortcut is already used by macOS.", comment: "Shortcut recorder validation"))
            return
        }
        if shortcut != currentShortcut, let menuItem = matchingMenuItem(for: shortcut, in: NSApp.mainMenu) {
            reject(
                String(
                    format: String(localized: "This shortcut is already used by “%@”.", comment: "Shortcut recorder menu conflict"),
                    menuItem.title
                )
            )
            return
        }

        currentShortcut = shortcut
        onCommit(shortcut)
        window?.makeFirstResponder(nil)
    }

    private func reject(_ message: String) {
        NSSound.beep()
        onValidation(message)
    }

    private func matchingMenuItem(
        for shortcut: KeyboardShortcuts.Shortcut,
        in menu: NSMenu?
    ) -> NSMenuItem? {
        guard let menu, let keyEquivalent = shortcut.nsMenuItemKeyEquivalent else { return nil }
        let relevantModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        for item in menu.items {
            if item.keyEquivalent.lowercased() == keyEquivalent.lowercased(),
               item.keyEquivalentModifierMask.intersection(relevantModifiers) ==
                    shortcut.modifiers.intersection(relevantModifiers) {
                return item
            }
            if let match = matchingMenuItem(for: shortcut, in: item.submenu) {
                return match
            }
        }
        return nil
    }
}
