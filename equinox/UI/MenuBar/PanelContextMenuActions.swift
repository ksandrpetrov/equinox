import AppKit

@MainActor
final class PanelContextMenuTargetAdapter: NSObject {
    private let appState: AppState
    private let onCreateNewEvent: () -> Void
    private let onGoToToday: () -> Void
    private let onTogglePin: () -> Void
    private let onShowSettings: () -> Void

    init(
        appState: AppState,
        onCreateNewEvent: @escaping () -> Void,
        onGoToToday: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onShowSettings: @escaping () -> Void
    ) {
        self.appState = appState
        self.onCreateNewEvent = onCreateNewEvent
        self.onGoToToday = onGoToToday
        self.onTogglePin = onTogglePin
        self.onShowSettings = onShowSettings
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let newEvent = NSMenuItem(
            title: String(localized: "New Event", comment: ""),
            action: #selector(createNewEvent),
            keyEquivalent: "n"
        )
        newEvent.keyEquivalentModifierMask = .command
        newEvent.target = self
        menu.addItem(newEvent)

        let today = NSMenuItem(
            title: String(localized: "Go to Today", comment: "Shortcut cheat sheet"),
            action: #selector(goToToday),
            keyEquivalent: "t"
        )
        today.target = self
        menu.addItem(today)

        let pinTitle = appState.isPinned
            ? String(localized: "Unpin Equinox", comment: "Context menu unpin")
            : String(localized: "Pin Equinox", comment: "")
        let pin = NSMenuItem(title: pinTitle, action: #selector(togglePin), keyEquivalent: "p")
        pin.target = self
        menu.addItem(pin)

        menu.addItem(.separator())

        let settings = NSMenuItem(
            title: String(localized: "Preferences…", comment: ""),
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settings.keyEquivalentModifierMask = .command
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: String(localized: "Quit Equinox", comment: ""),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.keyEquivalentModifierMask = .command
        quit.target = NSApp
        menu.addItem(quit)

        let symbols = ["plus.circle", "calendar.circle", "pin", "gearshape", "power"]
        let descriptions = [
            String(localized: "Create new event", comment: "Context menu icon"),
            String(localized: "Go to today", comment: "Context menu icon"),
            String(localized: "Pin or unpin panel", comment: "Context menu icon"),
            String(localized: "Open preferences", comment: "Context menu icon"),
            String(localized: "Quit application", comment: "Context menu icon"),
        ]
        var index = 0
        for item in menu.items where !item.isSeparatorItem {
            if index < symbols.count {
                item.image = NSImage(systemSymbolName: symbols[index], accessibilityDescription: descriptions[index])
                index += 1
            }
        }
        return menu
    }

    @objc func createNewEvent() { onCreateNewEvent() }
    @objc func goToToday() { onGoToToday() }
    @objc func togglePin() { onTogglePin() }
    @objc func showSettings() { onShowSettings() }
}

enum PanelContextMenuActions {
    @MainActor
    static func makeMenu(adapter: PanelContextMenuTargetAdapter) -> NSMenu {
        adapter.makeMenu()
    }
}
