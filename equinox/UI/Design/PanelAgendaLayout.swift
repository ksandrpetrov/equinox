import Foundation

enum PanelAgendaLayout {
    static let agendaMaxHeightFallback: CGFloat = 220
    static let screenVisibleHeightFraction: CGFloat = 0.85

    static func maxHeight(
        metrics: SizeMetrics,
        calendarRowCount: Int,
        screenVisibleHeight: CGFloat
    ) -> CGFloat {
        let maxPanel = screenVisibleHeight * screenVisibleHeightFraction
        let commandBarHeight = metrics.commandBarHeight + EquinoxDesign.spacingSM
        let weekdayHeaderRowHeight = metrics.fontSize + EquinoxDesign.spacingXS
        let gridHeight = weekdayHeaderRowHeight + CGFloat(calendarRowCount) * (metrics.cellSize + EquinoxDesign.spacingXS)
        let splitHeight = metrics.toolbarButtonSize
        let padding = EquinoxDesign.panelPadding * 2
        let fixed = commandBarHeight + gridHeight + splitHeight + padding + EquinoxDesign.spacingLG
        let availableHeight = max(0, maxPanel - fixed)
        guard availableHeight >= AgendaLayout.minHeight else { return 0 }
        return min(EquinoxDesign.panelAgendaMaxHeight, availableHeight)
    }
}
