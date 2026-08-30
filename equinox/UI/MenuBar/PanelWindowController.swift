import AppKit
import SwiftUI

@MainActor
final class PanelWindowController {
    private let appState: AppState
    private var panel: NSPanel?
    private var hostingController: NSHostingController<MainPanelView>?
    private weak var currentStatusItem: NSStatusItem?
    private var layoutUpdateWorkItem: DispatchWorkItem?

    init(appState: AppState) {
        self.appState = appState
        appState.layout.onPanelSizeInvalidated = { [weak self] in
            self?.scheduleLayoutUpdate()
        }
    }

    var window: NSPanel? { panel }

    var isVisible: Bool { panel?.isVisible == true }

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
        if appState.isPinned, let panel, panel.isVisible {
            var frame = panel.frame
            clampPanelFrame(&frame, statusItem: statusItem)
            panel.setFrame(frame, display: true)
        }
    }

    func repositionUnderStatusItem(_ statusItem: NSStatusItem) {
        currentStatusItem = statusItem
        guard let panel, panel.isVisible else { return }
        updatePanelAgendaMaxHeight(statusItem: statusItem)
        resizePanel(panel)
        if appState.isPinned {
            var frame = panel.frame
            clampPanelFrame(&frame, statusItem: statusItem)
            panel.setFrame(frame, display: true)
        } else {
            positionPanel(panel, statusItem: statusItem)
        }
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
        if isPinned {
            var frame = panel.frame
            clampPanelFrame(&frame, statusItem: statusItem)
            panel.setFrame(frame, display: true)
        } else {
            positionPanel(panel, statusItem: statusItem)
        }
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
        return panel
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
        hostingController = hc
        return hc
    }

    private func applyGeometry(
        statusItem: NSStatusItem,
        resize: Bool = false,
        reposition: Bool = false
    ) {
        guard let panel else { return }
        if resize {
            resizePanel(panel)
        }
        if reposition {
            positionPanel(panel, statusItem: statusItem)
        }
    }

    private func resizePanel(_ panel: NSPanel) {
        var frame = panel.frame
        let topEdge = frame.maxY
        frame.size = panelContentSize()
        frame.origin.y = topEdge - frame.height
        panel.setFrame(frame, display: panel.isVisible)
    }

    private func scheduleLayoutUpdate() {
        layoutUpdateWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  let statusItem = self.currentStatusItem,
                  let panel = self.panel,
                  panel.isVisible else { return }
            self.applyGeometry(
                statusItem: statusItem,
                resize: true,
                reposition: !self.appState.isPinned
            )
            if self.appState.isPinned {
                var frame = panel.frame
                self.clampPanelFrame(&frame, statusItem: statusItem)
                panel.setFrame(frame, display: true)
            }
        }
        layoutUpdateWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func panelContentSize() -> NSSize {
        let width = sizeMetrics.panelWidth
        guard let view = hostingController?.view else {
            return NSSize(width: width, height: EquinoxDesign.panelDefaultHeight)
        }
        view.frame.size.width = width
        view.layoutSubtreeIfNeeded()
        let height = ceil(view.fittingSize.height)
        return NSSize(
            width: width,
            height: height > 0 ? height : EquinoxDesign.panelDefaultHeight
        )
    }

    private func positionPanel(_ panel: NSPanel, statusItem: NSStatusItem) {
        guard let button = statusItem.button, let window = button.window else { return }
        let frame = window.convertToScreen(button.frame)
        let panelWidth = sizeMetrics.panelWidth
        let origin = NSPoint(x: frame.midX - panelWidth / 2, y: frame.minY - panel.frame.height - EquinoxDesign.panelPopoverOffset)
        var panelFrame = panel.frame
        panelFrame.size.width = panelWidth
        panelFrame.origin = origin
        clampPanelFrame(&panelFrame, statusItem: statusItem)
        panel.setFrame(panelFrame, display: panel.isVisible)
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
        appState.layout.panelAgendaMaxHeight = agendaMaxHeight(statusItem: statusItem)
    }

    private func agendaMaxHeight(statusItem: NSStatusItem) -> CGFloat {
        guard let screen = screenForStatusItem(statusItem) else {
            return PanelAgendaLayout.agendaMaxHeightFallback
        }
        return PanelAgendaLayout.maxHeight(
            metrics: sizeMetrics,
            calendarRowCount: appState.preferences.calendarRowCount,
            screenVisibleHeight: screen.visibleFrame.height
        )
    }
}
