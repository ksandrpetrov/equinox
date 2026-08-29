import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState!
    private var statusItemController: StatusItemController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        PreferencesStore.shared.applyTheme()
        SettingsActivationHandler.install()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState = AppState()
        statusItemController = StatusItemController(appState: appState)
        statusItemController?.setup()
        appState.requestCalendarAccessIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemController?.teardown()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard let appState else { return }
        Task { @MainActor in
            let previouslyAuthorized = appState.events.calendarAccessStatus.isAuthorized
            await appState.refreshCalendarAccessStatus()
            if !previouslyAuthorized, appState.events.calendarAccessStatus.isAuthorized {
                appState.events.retryFetchEvents()
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first,
              url.scheme?.lowercased() == "equinox",
              url.host == "date",
              url.pathComponents.count == 2 else { return }
        let dateString = url.pathComponents[1]
        if dateString == "now" {
            appState.navigateToDate(Date())
        } else {
            _ = appState.navigateToDeepLinkDateString(dateString)
        }
    }

}
