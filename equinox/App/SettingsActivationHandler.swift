import AppKit
import SwiftUI

/// Presents the Settings window for the menu bar app.
///
/// A SwiftUI `Settings` scene cannot be opened programmatically from a menu bar
/// (`LSUIElement`) app on macOS 26: `NSApp.sendAction(Selector("showSettingsWindow:"))`
/// was removed and the `openSettings` environment action does nothing without a
/// foreground SwiftUI render tree. `SettingsView` is therefore hosted in a dedicated
/// AppKit window, which is reliable across macOS versions and lets us control focus and
/// the `.regular`/`.accessory` activation policy explicitly.
@MainActor
enum SettingsActivationHandler {
    private static let windowIdentifier = "equinoxSettingsWindow"
    private static var closeObserver: SettingsWindowCloseObserver?

    static func install() {
        guard closeObserver == nil else { return }
        let observer = SettingsWindowCloseObserver(windowIdentifier: windowIdentifier)
        NotificationCenter.default.addObserver(
            observer,
            selector: #selector(SettingsWindowCloseObserver.windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        closeObserver = observer
    }

    static func openSettings(appState: AppState, initialTab: SettingsTab = .general) {
        appState.panel.settingsInitialTab = initialTab
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let existing = NSApp.windows.first(where: { $0.identifier?.rawValue == windowIdentifier }) {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let root = SettingsView(initialTab: initialTab)
            .environment(\.appState, appState)
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        window.identifier = NSUserInterfaceItemIdentifier(windowIdentifier)
        window.title = String(localized: "Preferences", comment: "Settings window title")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: SettingsDesign.windowMinWidth, height: SettingsDesign.windowMinHeight))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}

@MainActor
private final class SettingsWindowCloseObserver: NSObject {
    private let windowIdentifier: String

    init(windowIdentifier: String) {
        self.windowIdentifier = windowIdentifier
    }

    @objc func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.identifier?.rawValue == windowIdentifier else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}
