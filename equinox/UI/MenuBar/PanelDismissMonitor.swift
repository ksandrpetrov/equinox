import AppKit

@MainActor
final class PanelDismissMonitor {
    private(set) var isStatusItemClickInProgress = false
    private var outsideClickMonitor: Any?
    private var outsideClickLocalMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?
    private var onResignActive: (@MainActor () -> Void)?
    private var isModalSheetPresented: (@MainActor () -> Bool)?
    private var isEquinoxWindow: (@MainActor (NSWindow) -> Bool)?
    private var statusItemFrame: (@MainActor () -> NSRect?)?
    private var onOutsideClick: (@MainActor () -> Void)?

    func install(onResignActive: @escaping @MainActor () -> Void) {
        guard resignActiveObserver == nil else { return }
        self.onResignActive = onResignActive
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onResignActive?()
            }
        }
    }

    func teardown() {
        stopOutsideClickMonitor()
        onResignActive = nil
        isModalSheetPresented = nil
        isEquinoxWindow = nil
        statusItemFrame = nil
        onOutsideClick = nil
        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
            self.resignActiveObserver = nil
        }
    }

    func updateMonitoring(
        isPinned: Bool,
        isPanelVisible: Bool,
        isModalSheetPresented: @escaping @MainActor () -> Bool,
        isEquinoxWindow: @escaping @MainActor (NSWindow) -> Bool,
        statusItemFrame: @escaping @MainActor () -> NSRect?,
        onOutsideClick: @escaping @MainActor () -> Void
    ) {
        self.isModalSheetPresented = isModalSheetPresented
        self.isEquinoxWindow = isEquinoxWindow
        self.statusItemFrame = statusItemFrame
        self.onOutsideClick = onOutsideClick

        if isPinned || !isPanelVisible {
            stopOutsideClickMonitor()
        } else {
            startOutsideClickMonitor()
        }
    }

    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        let mouseEvents: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp]
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] event in
            MainActor.assumeIsolated {
                if event.type == .leftMouseUp {
                    self?.handleMouseUp()
                } else {
                    self?.handleMouseDown(window: nil, screenLocation: NSEvent.mouseLocation)
                }
            }
        }
        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents) { [weak self] event in
            guard let self else { return event }
            MainActor.assumeIsolated {
                if event.type == .leftMouseUp {
                    self.handleMouseUp()
                } else {
                    self.handleMouseDown(window: event.window, screenLocation: NSEvent.mouseLocation)
                }
            }
            return event
        }
    }

    func handleMouseDown(window: NSWindow?, screenLocation: NSPoint) {
        isStatusItemClickInProgress = Self.containsStatusItemPoint(screenLocation, frame: statusItemFrame?())
        guard isModalSheetPresented?() != true else { return }
        // Menu bar events can arrive without the status item's window. Let its
        // button toggle the panel instead of dismissing it before the action runs.
        if isStatusItemClickInProgress { return }
        if let window, isEquinoxWindow?(window) == true { return }
        onOutsideClick?()
    }

    func handleMouseUp() {
        isStatusItemClickInProgress = false
    }

    static func containsStatusItemPoint(_ point: NSPoint, frame: NSRect?) -> Bool {
        guard let frame else { return false }
        // The menu bar accepts clicks on the screen's top edge as well as in
        // the icon. NSRect.contains excludes that upper boundary.
        return point.x >= frame.minX && point.x <= frame.maxX
            && point.y >= frame.minY && point.y <= frame.maxY
    }

    private func stopOutsideClickMonitor() {
        isStatusItemClickInProgress = false
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        if let outsideClickLocalMonitor {
            NSEvent.removeMonitor(outsideClickLocalMonitor)
            self.outsideClickLocalMonitor = nil
        }
    }
}
