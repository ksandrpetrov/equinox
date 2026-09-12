import Foundation

@Observable
@MainActor
final class PanelLayoutMetrics {
    /// Upper bound for agenda height; refreshed by `PanelWindowController` before resizing.
    var panelAgendaMaxHeight: CGFloat = EquinoxDesign.panelAgendaMaxHeight {
        didSet {
            guard panelAgendaMaxHeight != oldValue else { return }
            onPanelSizeInvalidated?()
        }
    }
    var onPanelSizeInvalidated: (() -> Void)?

    func invalidatePanelSize() {
        onPanelSizeInvalidated?()
    }
}
