import AppKit
import SwiftUI

@MainActor
final class PanelWindowController {
    private let appState: AppState
    private var panel: NSPanel?
    private var hostingController: NSHostingController<MainPanelView>?
    private weak var currentStatusItem: NSStatusItem?
    private var layoutUpdateWorkItem: DispatchWorkItem?
    var onDismissRequested: (() -> Void)?

    init(appState: AppState) {
        self.appState = appState
        appState.layout.onPanelSizeInvalidated = { [weak self] in
            self?.scheduleLayoutUpdate()
        }
    }

    var window: NSPanel? { panel }

    var isVisible: Bool { panel?.isVisible == true }

    static func shouldHandleCancelOperation(
        isVisible: Bool,
        isModalSheetPresented: Bool
    ) -> Bool {
        isVisible && !isModalSheetPresented
    }

    func show(statusItem: NSStatusItem, isPinned: Bool) {
        currentStatusItem = statusItem
        if panel == nil {
            panel = makePanel()
        }
        guard let panel else { return }

        configurePanelMode(panel, isPinned: isPinned)
        assignHostingController(to: panel)
        updatePanelAgendaMaxHeight(statusItem: statusItem)

        let needsPositioning = !panel.isVisible
        if needsPositioning {
            applyGeometry(statusItem: statusItem, resize: false, reposition: true)
        } else {
            applyGeometry(statusItem: statusItem, resize: true, reposition: false)
        }
        if !isPinned {
            NSApp.activate()
        }
        panel.makeKeyAndOrderFront(nil)
        appState.panel.isPanelVisible = true

        if needsPositioning {
            appState.panelDidOpen()
            DispatchQueue.main.async { [weak self, weak statusItem] in
                guard let self, let statusItem, self.isVisible else { return }
                self.applyGeometry(statusItem: statusItem, resize: true, reposition: true)
            }
        }
    }

    func hide() {
        layoutUpdateWorkItem?.cancel()
        panel?.orderOut(nil)
        appState.panel.isPanelVisible = false
    }

    func handleSizePreferenceChanged(statusItem: NSStatusItem) {
        currentStatusItem = statusItem
        updatePanelAgendaMaxHeight(statusItem: statusItem)
        applyGeometry(
            statusItem: statusItem,
            resize: true,
            reposition: appState.panel.isPanelVisible && !appState.isPinned
        )
    }

    func repositionUnderStatusItem(_ statusItem: NSStatusItem) {
        currentStatusItem = statusItem
        guard let panel, panel.isVisible else { return }
        updatePanelAgendaMaxHeight(statusItem: statusItem)
        applyGeometry(statusItem: statusItem, resize: true, reposition: !appState.isPinned)
    }

    func retainFocusAfterModalDismiss(isPinned: Bool) {
        guard !isPinned, isVisible else { return }
        NSApp.activate()
        panel?.makeKeyAndOrderFront(nil)
    }

    func applyPinState(isPinned: Bool, statusItem: NSStatusItem) {
        currentStatusItem = statusItem
        guard let panel, panel.isVisible else { return }
        configurePanelMode(panel, isPinned: isPinned)
        applyGeometry(statusItem: statusItem, reposition: !isPinned)
    }

    func isEquinoxCalendarWindow(_ window: NSWindow, statusItem: NSStatusItem) -> Bool {
        if let statusWindow = statusItem.button?.window, window === statusWindow {
            return true
        }
        guard let panel else { return false }
        if window === panel { return true }
        if panel.attachedSheet === window { return true }
        var candidate: NSWindow? = window
        while let current = candidate {
            if current === panel { return true }
            candidate = current.parent ?? current.sheetParent
        }
        return false
    }

    private var sizeMetrics: SizeMetrics {
        SizeMetrics.metrics(
            for: SizePreference(rawValue: appState.preferences.sizePreference) ?? .medium
        )
    }

    private func makePanel() -> NSPanel {
        let width = sizeMetrics.panelWidth
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: EquinoxDesign.panelDefaultHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .mainMenu
        panel.collectionBehavior = [.moveToActiveSpace]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.onCancelOperation = { [weak self] in
            self?.handleCancelOperation() ?? false
        }
        return panel
    }

    private func handleCancelOperation() -> Bool {
        let isModalSheetPresented = appState.panel.isModalSheetPresented
            || panel?.attachedSheet != nil
        guard Self.shouldHandleCancelOperation(
            isVisible: isVisible,
            isModalSheetPresented: isModalSheetPresented
        ), let onDismissRequested else {
            return false
        }
        onDismissRequested()
        return true
    }

    private func configurePanelMode(_ panel: NSPanel, isPinned: Bool) {
        panel.level = isPinned ? .floating : .mainMenu
        panel.isMovableByWindowBackground = isPinned
    }

    private func assignHostingController(to panel: NSPanel) {
        let hostingController = ensureHostingController()
        if panel.contentViewController !== hostingController {
            panel.contentViewController = hostingController
        }
    }

    private func ensureHostingController() -> NSHostingController<MainPanelView> {
        if let hostingController {
            return hostingController
        }
        let hc = NSHostingController(rootView: MainPanelView(appState: appState))
        hc.sizingOptions = [.intrinsicContentSize]
        // Native material and sheet dimming layers must share the panel's contour.
        hc.view.wantsLayer = true
        hc.view.layer?.cornerRadius = EquinoxDesign.panelCornerRadius
        hc.view.layer?.cornerCurve = .continuous
        hc.view.layer?.masksToBounds = true
        hostingController = hc
        return hc
    }

    private func applyGeometry(
        statusItem: NSStatusItem,
        resize: Bool = false,
        reposition: Bool = false
    ) {
        guard let panel else { return }
        var frame = panel.frame
        if resize {
            let topEdge = frame.maxY
            let rightEdge = frame.maxX
            frame.size = panelContentSize()
            frame.origin.x = rightEdge - frame.width
            frame.origin.y = topEdge - frame.height
        }
        if reposition {
            positionPanelFrame(&frame, statusItem: statusItem)
        }
        // Resolve screen constraints before animation, so there is no second jump.
        clampPanelFrame(&frame, statusItem: statusItem)
        let animate = panel.isVisible && panel.frame.width != frame.width
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.setFrame(frame, display: panel.isVisible, animate: animate)
    }

    private func scheduleLayoutUpdate() {
        layoutUpdateWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  let statusItem = self.currentStatusItem,
                  let panel = self.panel,
                  panel.isVisible else { return }
            self.updateLayout(screenVisibleHeight: self.screenForStatusItem(statusItem)?.visibleFrame.height) {
                self.applyGeometry(
                    statusItem: statusItem,
                    resize: true,
                    reposition: !self.appState.isPinned
                )
            }
        }
        layoutUpdateWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    func updateLayout(screenVisibleHeight: CGFloat?, applyGeometry: () -> Void) {
        appState.layout.panelAgendaMaxHeight = agendaMaxHeight(screenVisibleHeight: screenVisibleHeight)
        applyGeometry()
    }

    private func panelContentSize() -> NSSize {
        let width = sizeMetrics.panelWidth + eventDrawerWidth
        guard let view = hostingController?.view else {
            return NSSize(width: width, height: EquinoxDesign.panelDefaultHeight)
        }
        view.layoutSubtreeIfNeeded()
        let height = ceil(view.fittingSize.height)
        return NSSize(
            width: width,
            height: height > 0 ? height : EquinoxDesign.panelDefaultHeight
        )
    }

    private func positionPanelFrame(_ panelFrame: inout NSRect, statusItem: NSStatusItem) {
        guard let button = statusItem.button, let window = button.window else { return }
        let statusFrame = window.convertToScreen(button.frame)
        let calendarWidth = sizeMetrics.panelWidth
        panelFrame.size.width = calendarWidth + eventDrawerWidth
        panelFrame.origin = NSPoint(
            x: statusFrame.midX - calendarWidth / 2 - eventDrawerWidth,
            y: statusFrame.minY - panelFrame.height - EquinoxDesign.panelPopoverOffset
        )
    }

    private var eventDrawerWidth: CGFloat {
        appState.panel.isModalSheetPresented ? sizeMetrics.sheetWidth : 0
    }

    private func clampPanelFrame(_ frame: inout NSRect, statusItem: NSStatusItem) {
        guard let screen = screenForStatusItem(statusItem) else { return }
        let visible = screen.visibleFrame
        let margin = EquinoxDesign.panelScreenMargin
        frame.origin.x = min(max(frame.origin.x, visible.minX + margin), visible.maxX - frame.width - margin)
        frame.origin.y = min(max(frame.origin.y, visible.minY + margin), visible.maxY - frame.height - margin)
    }

    private func screenForStatusItem(_ statusItem: NSStatusItem) -> NSScreen? {
        guard let button = statusItem.button, let window = button.window else { return NSScreen.main }
        var testPoint = window.convertToScreen(button.frame).origin
        testPoint.y -= 100
        for screen in NSScreen.screens where screen.frame.contains(testPoint) {
            return screen
        }
        return NSScreen.main
    }

    private func updatePanelAgendaMaxHeight(statusItem: NSStatusItem) {
        appState.layout.panelAgendaMaxHeight = agendaMaxHeight(screenVisibleHeight: screenForStatusItem(statusItem)?.visibleFrame.height)
    }

    private func agendaMaxHeight(screenVisibleHeight: CGFloat?) -> CGFloat {
        guard let screenVisibleHeight else {
            return PanelAgendaLayout.agendaMaxHeightFallback
        }
        return PanelAgendaLayout.maxHeight(
            metrics: sizeMetrics,
            calendarRowCount: appState.preferences.calendarRowCount,
            screenVisibleHeight: screenVisibleHeight
        )
    }
}
