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
enum SettingsActivationHandler {
    private static let windowIdentifier = "equinoxSettingsWindow"
    private static var closeObserver: NSObjectProtocol?

    static func install() {
        guard closeObserver == nil else { return }
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow,
                  window.identifier?.rawValue == windowIdentifier else { return }
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @MainActor
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
        window.setContentSize(NSSize(width: 720, height: 560))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}
