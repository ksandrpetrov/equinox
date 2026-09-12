import AppKit
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState!
    private var statusItemController: StatusItemController?
    private var pendingOpenURLs: [URL]?

    public func applicationWillFinishLaunching(_ notification: Notification) {
        PreferencesStore.shared.applyTheme()
        SettingsActivationHandler.install()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        appState = AppState()
        statusItemController = StatusItemController(appState: appState)
        statusItemController?.setup()
        Task { [appState] in
            guard let appState else { return }
            await appState.waitForInitialization()
            appState.requestCalendarAccessIfNeeded()
        }
        if let pendingOpenURLs {
            self.pendingOpenURLs = nil
            application(NSApp, open: pendingOpenURLs)
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        statusItemController?.teardown()
    }

    public func applicationDidBecomeActive(_ notification: Notification) {
        guard let appState else { return }
        Task { @MainActor in
            let previouslyAuthorized = appState.events.calendarAccessStatus.isAuthorized
            await appState.refreshCalendarAccessStatus()
            if !previouslyAuthorized, appState.events.calendarAccessStatus.isAuthorized {
                appState.events.retryFetchEvents()
            }
        }
    }

    public func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first,
              url.scheme?.lowercased() == "equinox",
              url.host == "date",
              url.pathComponents.count == 2 else { return }
        guard appState != nil else {
            pendingOpenURLs = urls
            return
        }
        let dateString = url.pathComponents[1]
        if dateString == "now" {
            appState.navigateToDate(Date())
        } else {
            _ = appState.navigateToDeepLinkDateString(dateString)
        }
    }

}
