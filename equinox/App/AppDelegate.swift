import AppKit
import KeyboardShortcuts
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState!
    private var statusItemController: StatusItemController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        registerDefaults()
        PreferencesStore.shared.applyTheme()
        SettingsActivationHandler.install()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        createApplicationSupportFolder()

        appState = AppState()
        KeyboardShortcutMigration.migrateIfNeeded()
        statusItemController = StatusItemController(appState: appState)
        statusItemController?.setup()
        appState.events.requestCalendarAccessIfNeeded()
        McpConfigurator.ensureBundledBridgeInstalled()
        McpConfigurator.ensureCursorConfigIfEnabled()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemController?.teardown()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first, url.host == "date", url.pathComponents.count >= 2 else { return }
        let dateString = url.pathComponents[1]
        if dateString == "now" {
            statusItemController?.handleDateURL(Date())
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateString) {
                statusItemController?.handleDateURL(date)
            }
        }
    }

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: PreferencesStore.registeredDefaultValues())
    }

    private func createApplicationSupportFolder() {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let bundleID = Bundle.main.bundleIdentifier else { return }
        let appSupport = url.appendingPathComponent(bundleID, isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
    }
}
