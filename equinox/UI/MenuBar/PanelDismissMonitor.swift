import AppKit

@MainActor
final class PanelDismissMonitor {
    private var outsideClickMonitor: Any?
    private var outsideClickLocalMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?
    private var onResignActive: (@MainActor () -> Void)?
    private var isModalSheetPresented: (@MainActor () -> Bool)?
    private var isEquinoxWindow: (@MainActor (NSWindow) -> Bool)?
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
        onOutsideClick: @escaping @MainActor () -> Void
    ) {
        self.isModalSheetPresented = isModalSheetPresented
        self.isEquinoxWindow = isEquinoxWindow
        self.onOutsideClick = onOutsideClick

        if isPinned || !isPanelVisible {
            stopOutsideClickMonitor()
        } else {
            startOutsideClickMonitor()
        }
    }

    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor in
                self?.onOutsideClick?()
            }
        }
        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self else { return event }
            MainActor.assumeIsolated {
                if self.isModalSheetPresented?() == true { return }
                if let window = event.window, self.isEquinoxWindow?(window) == true {
                    return
                }
                self.onOutsideClick?()
            }
            return event
        }
    }

    private func stopOutsideClickMonitor() {
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
