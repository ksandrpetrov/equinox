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
    private var iconDateFormatter = DateFormatter()

    init(appState: AppState) {
        self.appState = appState
        self.panelController = PanelWindowController(appState: appState)
        super.init()
        iconDateFormatter.locale = appLocale
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
        NotificationCenter.default.addObserver(
            forName: kEquinoxSizePreferenceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSizePreferenceChanged() }
        }
        NotificationCenter.default.addObserver(
            forName: kEquinoxMenuBarAppearanceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateMenuBarIcon() }
        }
        createStatusItem()
        setupPeriodicRefresh()
        setupShortcut()
        setupDismissMonitoring()
        restorePinnedPanelIfNeeded()
    }

    func teardown() {
        dismissMonitor.teardown()
        refreshScheduler?.stop()
        statusItemMoveWorkItem?.cancel()
        UserDefaults.standard.set(appState.isPinned && isPanelActuallyVisible, forKey: kPinnedPanelVisible)
        KeyboardShortcuts.disable(.togglePanel)
    }

    private func restorePinnedPanelIfNeeded() {
        guard appState.isPinned,
              UserDefaults.standard.bool(forKey: kPinnedPanelVisible) else { return }
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

    @objc private func statusItemClicked() {
        togglePanel()
    }

    private var isPanelActuallyVisible: Bool {
        panelController.isVisible
    }

    private func syncPanelVisibleState() {
        appState.panel.isPanelVisible = isPanelActuallyVisible
    }

    func applyPinState() {
        syncPanelVisibleState()
        if !appState.isPinned, isPanelActuallyVisible {
            NSApp.activate()
            panelController.window?.makeKeyAndOrderFront(nil)
        }
        updateDismissMonitoring()
    }

    private func togglePanel() {
        syncPanelVisibleState()
        if appState.panel.isPanelVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel(resetToToday: Bool = true) {
        if resetToToday {
            appState.events.goToToday()
        }
        panelController.show(statusItem: statusItem, isPinned: appState.isPinned)
        updateDismissMonitoring()
    }

    private func showPanelIfHidden(resetToToday: Bool = true) {
        syncPanelVisibleState()
        if !appState.panel.isPanelVisible { showPanel(resetToToday: resetToToday) }
    }

    private func hidePanel() {
        panelController.hide()
        updateDismissMonitoring()
    }

    @objc private func statusItemMoved() {
        statusItemMoveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.syncPanelVisibleState()
            self.panelController.repositionUnderStatusItem(self.statusItem)
        }
        statusItemMoveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }

    func refreshPanelIfVisible() {
        panelController.refreshIfVisible(statusItem: statusItem)
    }

    private func handleSizePreferenceChanged() {
        panelController.handleSizePreferenceChanged(statusItem: statusItem)
    }

    func updateMenuBarIcon() {
        let prefs = appState.preferences
        guard let button = statusItem.button else { return }

        if prefs.isIconHidden {
            if prefs.showMeetingIndicator && appState.events.shouldShowMeetingIndicator {
                button.image = NSImage(named: "meetSolid")
                button.image?.isTemplate = true
                button.imagePosition = .imageLeading
            } else {
                button.image = nil
                button.imagePosition = .noImage
            }
        } else {
            let text = MenuBarIconRenderer.iconText(prefs: prefs, calendar: appState.calendar, today: appState.events.todayDate)
            let scale = button.window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            button.image = MenuBarIconRenderer.iconImage(text: text, prefs: prefs, shouldShowMeetingIndicator: appState.events.shouldShowMeetingIndicator, scale: scale)
            button.imagePosition = prefs.clockFormat != nil ? .imageLeading : .imageOnly
        }

        if let format = prefs.clockFormat, !format.isEmpty {
            iconDateFormatter.dateFormat = format
            var title = iconDateFormatter.string(from: Date())
            if !prefs.isIconHidden { title = " " + title }
            button.title = title
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        } else {
            button.title = ""
        }
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
        let today = CalendarDate.today(calendar: appState.calendar)
        if today != appState.events.todayDate {
            appState.events.todayDate = today
        }
        appState.events.updateMeetingIndicator()
        updateMenuBarIcon()
    }

    private func setupShortcut() {
        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            Task { @MainActor in self?.statusItemClicked() }
        }
    }

    func handleDateURL(_ date: Date) {
        let calDate = CalendarDate(date: date, calendar: appState.calendar)
        appState.events.selectDate(calDate)
        showPanelIfHidden(resetToToday: false)
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
            isModalSheetPresented: { [weak self] in self?.appState.panel.isModalSheetPresented ?? false },
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
        syncPanelVisibleState()
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
        syncPanelVisibleState()
        guard isPanelActuallyVisible else { return }
        hidePanel()
    }
}
