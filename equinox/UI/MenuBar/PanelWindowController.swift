import AppKit
import SwiftUI

@MainActor
final class PanelWindowController {
    private let appState: AppState
    private var panel: NSPanel?
    private var hostingController: NSHostingController<MainPanelView>?

    init(appState: AppState) {
        self.appState = appState
    }

    var window: NSPanel? { panel }

    var isVisible: Bool { panel?.isVisible == true }

    func show(statusItem: NSStatusItem, isPinned: Bool) {
        if panel == nil {
            panel = makePanel()
        }
        guard let panel else { return }

        assignHostingController(to: panel)
        updatePanelAgendaMaxHeight(statusItem: statusItem)

        let needsPositioning = !panel.isVisible
        if !isPinned {
            NSApp.activate()
        }
        panel.makeKeyAndOrderFront(nil)
        appState.panel.isPanelVisible = true

        if needsPositioning {
            scheduleGeometryUpdate(statusItem: statusItem, resize: true, reposition: true)
        }
    }

    func hide() {
        panel?.orderOut(nil)
        detachHostingControllerFromContainers()
        appState.panel.isPanelVisible = false
    }

    func refreshIfVisible(statusItem: NSStatusItem) {
        guard appState.panel.isPanelVisible else { return }
        updatePanelAgendaMaxHeight(statusItem: statusItem)
        scheduleGeometryUpdate(statusItem: statusItem, resize: true, reposition: true)
    }

    func handleSizePreferenceChanged(statusItem: NSStatusItem) {
        updatePanelAgendaMaxHeight(statusItem: statusItem)
        scheduleGeometryUpdate(statusItem: statusItem, resize: true, reposition: appState.panel.isPanelVisible)
    }

    func repositionUnderStatusItem(_ statusItem: NSStatusItem) {
        guard let panel, panel.isVisible else { return }
        positionPanel(panel, statusItem: statusItem)
    }

    func retainFocusAfterModalDismiss(isPinned: Bool) {
        guard !isPinned, isVisible else { return }
        NSApp.activate()
        panel?.makeKeyAndOrderFront(nil)
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

    private func assignHostingController(to panel: NSPanel) {
        detachHostingControllerFromContainers()
        panel.contentViewController = ensureHostingController()
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

    private func detachHostingControllerFromContainers() {
        if panel?.contentViewController === hostingController {
            panel?.contentViewController = nil
        }
    }

    private func scheduleGeometryUpdate(
        statusItem: NSStatusItem,
        resize: Bool = false,
        reposition: Bool = false,
        preferredFrame: NSRect? = nil
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.panel else { return }
            if resize {
                self.resizePanel(panel)
            }
            if reposition, panel.isVisible {
                self.positionPanel(panel, statusItem: statusItem, preferredFrame: preferredFrame)
            }
        }
    }

    private func resizePanel(_ panel: NSPanel) {
        var frame = panel.frame
        frame.size.width = sizeMetrics.panelWidth
        panel.setFrame(frame, display: true)
    }

    private func positionPanel(_ panel: NSPanel, statusItem: NSStatusItem, preferredFrame: NSRect? = nil) {
        if let preferredFrame {
            var frame = panel.frame
            frame.origin = preferredFrame.origin
            frame.size.height = preferredFrame.height
            clampPanelFrame(&frame, statusItem: statusItem)
            panel.setFrame(frame, display: true)
            return
        }

        guard let button = statusItem.button, let window = button.window else { return }
        let frame = window.convertToScreen(button.frame)
        let panelWidth = sizeMetrics.panelWidth
        let origin = NSPoint(x: frame.midX - panelWidth / 2, y: frame.minY - panel.frame.height - EquinoxDesign.panelPopoverOffset)
        var panelFrame = panel.frame
        panelFrame.size.width = panelWidth
        panelFrame.origin = origin
        clampPanelFrame(&panelFrame, statusItem: statusItem)
        panel.setFrameOrigin(panelFrame.origin)
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
        guard let screen = screenForStatusItem(statusItem) else { return 220 }
        let maxPanel = screen.visibleFrame.height * 0.85
        let prefs = appState.preferences
        let metrics = sizeMetrics
        let commandBarHeight: CGFloat = EquinoxDesign.commandBarHeight + 8
        let dowRow: CGFloat = 20
        let gridHeight = dowRow + CGFloat(prefs.calendarRowCount) * (metrics.cellSize + 4)
        let splitHeight: CGFloat = 10
        let padding = EquinoxDesign.panelPadding * 2
        let fixed = commandBarHeight + gridHeight + splitHeight + padding + 16
        return max(120, min(400, maxPanel - fixed))
    }
}
