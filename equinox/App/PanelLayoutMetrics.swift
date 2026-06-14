import Foundation

@Observable
@MainActor
final class PanelLayoutMetrics {
    /// Upper bound for agenda height; updated by `StatusItemController` when the panel is shown.
    var panelAgendaMaxHeight: CGFloat = EquinoxDesign.panelAgendaMaxHeight
}
