import SwiftUI

@main
struct EquinoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The real Settings window is presented by `SettingsActivationHandler` as an
        // AppKit window, because the SwiftUI `Settings` scene cannot be opened
        // programmatically from a menu bar (`LSUIElement`) app on macOS 26. This scene
        // only satisfies the `App` scene requirement; its automatic "Settings…" command
        // is removed so it can never open a stray, empty window.
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) { }
            }
    }
}
