import AppKit
import KeyboardShortcuts
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let appState: AppState
    private var statusItem: NSStatusItem!
    private let panelController: PanelWindowController
    private let dismissMonitor = PanelDismissMonitor()
    private var refreshScheduler: PeriodicRefreshScheduler?

    private var statusItemMoveWorkItem: DispatchWorkItem?
    private var shortcutEventsTask: Task<Void, Never>?
    private var notificationObservers: [NSObjectProtocol] = []
    private var systemNotificationCenter: NotificationCenter?
    private var workspaceNotificationCenter: NotificationCenter?
    private var iconDateFormatter = DateFormatter()

    init(appState: AppState) {
        self.appState = appState
        self.panelController = PanelWindowController(appState: appState)
        super.init()
        panelController.onDismissRequested = { [weak self] in
            self?.hidePanel()
        }
        resetIconDateFormatter()
    }

    func setup() {
        appState.panel.onPinStateChanged = { [weak self] in
            self?.applyPinState()
        }
        appState.panel.onModalSheetDismissed = { [weak self] in
            self?.retainPanelFocusAfterModalDismiss()
        }
        appState.events.onMeetingIndicatorChanged = { [weak self] in
            self?.updateMenuBarIcon()
        }
        appState.onRequestPresentPanel = { [weak self] resetToToday in
            self?.showPanelIfHidden(resetToToday: resetToToday)
        }
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: kEquinoxSizePreferenceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSizePreferenceChanged() }
        })
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: kEquinoxMenuBarAppearanceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateMenuBarIcon() }
        })
        setupSystemChangeObservers()
        createStatusItem()
        setupPeriodicRefresh()
        setupShortcut()
        setupDismissMonitoring()
        restorePinnedPanelIfNeeded()
    }

    func teardown() {
        shortcutEventsTask?.cancel()
        shortcutEventsTask = nil
        dismissMonitor.teardown()
        refreshScheduler?.stop()
        statusItemMoveWorkItem?.cancel()
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers = []
        NotificationCenter.default.removeObserver(self)
        stopObservingSystemChanges()
        appState.preferences.isPinnedPanelVisible = appState.isPinned && isPanelActuallyVisible
        KeyboardShortcuts.disable(.togglePanel)
    }

    private func restorePinnedPanelIfNeeded() {
        guard appState.isPinned,
              appState.preferences.isPinnedPanelVisible else { return }
        DispatchQueue.main.async { [weak self] in
            self?.showPanel()
        }
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "equinoxStatusItem"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseDown])
        if let button = statusItem.button {
            Self.configureAccessibility(for: button)
        }

        if let cell = statusItem.button?.cell as? NSButtonCell {
            cell.highlightsBy = []
        }

        updateMenuBarIcon()

        NotificationCenter.default.addObserver(
            self, selector: #selector(statusItemMoved),
            name: NSWindow.didMoveNotification,
            object: statusItem.button?.window
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(statusItemMoved),
            name: NSWindow.didResizeNotification,
            object: statusItem.button?.window
        )
    }

    static func configureAccessibility(for button: NSButton) {
        let help = String(
            localized: "Show or hide the Equinox panel from anywhere",
            bundle: .equinox, comment: "Menu bar status item accessibility help and tooltip"
        )
        button.setAccessibilityLabel(
            String(localized: "Equinox calendar", bundle: .equinox, comment: "Menu bar status item accessibility label")
        )
        button.setAccessibilityHelp(help)
        button.toolTip = help
    }

    @objc private func statusItemClicked() {
        togglePanel()
    }

    private var isPanelActuallyVisible: Bool {
        panelController.isVisible
    }

    private var isPanelModalPresented: Bool {
        appState.panel.isModalSheetPresented || panelController.window?.attachedSheet != nil
    }

    func applyPinState() {
        panelController.applyPinState(isPinned: appState.isPinned, statusItem: statusItem)
        if !appState.isPinned, isPanelActuallyVisible {
            NSApp.activate()
            panelController.window?.makeKeyAndOrderFront(nil)
        }
        updateDismissMonitoring()
    }

    private func togglePanel() {
        if isPanelActuallyVisible {
            guard !isPanelModalPresented else {
                panelController.window?.makeKeyAndOrderFront(nil)
                return
            }
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel(resetToToday: Bool = true) {
        if resetToToday {
            appState.goToToday()
        }
        panelController.show(statusItem: statusItem, isPinned: appState.isPinned)
        updateDismissMonitoring()
    }

    private func showPanelIfHidden(resetToToday: Bool = true) {
        if !isPanelActuallyVisible { showPanel(resetToToday: resetToToday) }
    }

    private func hidePanel() {
        panelController.hide()
        updateDismissMonitoring()
    }

    @objc private func statusItemMoved() {
        statusItemMoveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.panelController.repositionUnderStatusItem(self.statusItem)
        }
        statusItemMoveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }

    private func handleSizePreferenceChanged() {
        panelController.handleSizePreferenceChanged(statusItem: statusItem)
    }

    func setupSystemChangeObservers(
        notificationCenter: NotificationCenter = .default,
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter
    ) {
        guard systemNotificationCenter == nil else { return }
        self.systemNotificationCenter = notificationCenter
        self.workspaceNotificationCenter = workspaceNotificationCenter
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(significantTimeChanged),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(significantTimeChanged),
            name: Notification.Name.NSSystemClockDidChange,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(significantTimeChanged),
            name: Notification.Name.NSSystemTimeZoneDidChange,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(significantTimeChanged),
            name: Notification.Name.NSCalendarDayChanged,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(localeChanged),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
    }

    func stopObservingSystemChanges() {
        for name in [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange,
                     .NSCalendarDayChanged, NSLocale.currentLocaleDidChangeNotification] {
            systemNotificationCenter?.removeObserver(self, name: name, object: nil)
        }
        workspaceNotificationCenter?.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
        systemNotificationCenter = nil
        workspaceNotificationCenter = nil
    }

    // System notifications, including the midnight rollover, can arrive off the main thread.
    @objc nonisolated private func significantTimeChanged() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.refreshScheduler?.stop()
            self.refreshScheduler?.start()
            self.appState.events.refreshAfterSignificantTimeChange()
        }
    }

    @objc nonisolated private func localeChanged() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            EquinoxFormatters.invalidateCache()
            self.resetIconDateFormatter()
            self.appState.events.refreshTodayAndMeetingIndicator()
        }
    }

    private func resetIconDateFormatter() {
        iconDateFormatter = DateFormatter()
        iconDateFormatter.locale = EquinoxFormatters.appLocale
        iconDateFormatter.timeZone = .autoupdatingCurrent
    }

    func updateMenuBarIcon() {
        let prefs = appState.preferences
        guard let button = statusItem.button else { return }
        let clockIsVisible = !(prefs.clockFormat?.isEmpty ?? true)
        let scale = button.window?.screen?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2

        if prefs.isIconHidden {
            if prefs.showMeetingIndicator && appState.events.shouldShowMeetingIndicator {
                button.image = MenuBarIconRenderer.meetingIndicatorImage(scale: scale)
                button.imagePosition = clockIsVisible ? .imageLeading : .imageOnly
            } else if !clockIsVisible {
                button.image = MenuBarIconRenderer.hiddenDateFallbackImage(scale: scale)
                button.imagePosition = .imageOnly
            } else {
                button.image = nil
                button.imagePosition = .noImage
            }
        } else {
            let text = MenuBarIconRenderer.iconText(prefs: prefs, calendar: appState.calendar, today: appState.events.todayDate)
            button.image = MenuBarIconRenderer.iconImage(text: text, prefs: prefs, shouldShowMeetingIndicator: appState.events.shouldShowMeetingIndicator, scale: scale)
            button.imagePosition = clockIsVisible ? .imageLeading : .imageOnly
        }

        if let format = prefs.clockFormat, clockIsVisible {
            iconDateFormatter.dateFormat = format
            var title = iconDateFormatter.string(from: Date())
            if !prefs.isIconHidden { title = " " + title }
            button.title = title
            button.font = NSFont.monospacedDigitSystemFont(ofSize: MenuBarDesign.clockFontSize, weight: .medium)
        } else {
            button.title = ""
        }

        let accessibleDate = EquinoxFormatters.formatter(key: "status-item.date.full") {
            $0.dateStyle = .full
        }.string(from: appState.events.todayDate.date(in: appState.calendar))
        button.setAccessibilityValue(accessibleDate)
    }

    private func setupPeriodicRefresh() {
        let scheduler = PeriodicRefreshScheduler { [weak self] in
            self?.handlePeriodicRefresh()
        }
        refreshScheduler = scheduler
        scheduler.start()
        handlePeriodicRefresh()
    }

    private func handlePeriodicRefresh() {
        appState.events.refreshTodayAndMeetingIndicator()
    }

    private func setupShortcut() {
        shortcutEventsTask = Task { [weak self] in
            for await event in KeyboardShortcuts.events(for: .togglePanel) where event == .keyUp {
                await MainActor.run { [weak self] in
                    self?.statusItemClicked()
                }
            }
        }
    }

    private func setupDismissMonitoring() {
        dismissMonitor.install { [weak self] in
            self?.handleAppResignActive()
        }
    }

    private func updateDismissMonitoring() {
        dismissMonitor.updateMonitoring(
            isPinned: appState.isPinned,
            isPanelVisible: isPanelActuallyVisible,
            isModalSheetPresented: { [weak self] in self?.isPanelModalPresented ?? false },
            isEquinoxWindow: { [weak self] window in
                guard let self else { return false }
                return self.panelController.isEquinoxCalendarWindow(window, statusItem: self.statusItem)
            },
            onOutsideClick: { [weak self] in
                self?.handleOutsideClick()
            }
        )
    }

    private func retainPanelFocusAfterModalDismiss() {
        panelController.retainFocusAfterModalDismiss(isPinned: appState.isPinned)
    }

    private func handleAppResignActive() {
        guard !appState.isPinned else { return }
        guard isPanelActuallyVisible else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !self.appState.isPinned, self.isPanelActuallyVisible else { return }
            if self.panelController.window?.attachedSheet != nil { return }
            if self.appState.panel.isModalSheetPresented { return }
            guard !NSApp.isActive else { return }
            self.hidePanel()
        }
    }

    private func handleOutsideClick() {
        guard !appState.isPinned else { return }
        guard isPanelActuallyVisible else { return }
        hidePanel()
    }
}
