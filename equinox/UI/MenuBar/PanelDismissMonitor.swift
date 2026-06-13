import AppKit

@MainActor
final class PanelDismissMonitor {
    private var outsideClickMonitor: Any?
    private var outsideClickLocalMonitor: Any?
    private var resignActiveObserver: NSObjectProtocol?

    func install(onResignActive: @escaping () -> Void) {
        guard resignActiveObserver == nil else { return }
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in onResignActive() }
        }
    }

    func teardown() {
        stopOutsideClickMonitor()
        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
            self.resignActiveObserver = nil
        }
    }

    func updateMonitoring(
        isPinned: Bool,
        isPanelVisible: Bool,
        isModalSheetPresented: @escaping () -> Bool,
        isEquinoxWindow: @escaping (NSWindow) -> Bool,
        onOutsideClick: @escaping () -> Void
    ) {
        if isPinned || !isPanelVisible {
            stopOutsideClickMonitor()
        } else {
            startOutsideClickMonitor(
                isModalSheetPresented: isModalSheetPresented,
                isEquinoxWindow: isEquinoxWindow,
                onOutsideClick: onOutsideClick
            )
        }
    }

    private func startOutsideClickMonitor(
        isModalSheetPresented: @escaping () -> Bool,
        isEquinoxWindow: @escaping (NSWindow) -> Bool,
        onOutsideClick: @escaping () -> Void
    ) {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { _ in
            Task { @MainActor in onOutsideClick() }
        }
        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            if isModalSheetPresented() { return event }
            if let window = event.window, isEquinoxWindow(window) {
                return event
            }
            onOutsideClick()
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
