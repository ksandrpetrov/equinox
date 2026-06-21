import SwiftUI

struct SizeMetrics {
    let fontSize: CGFloat
    let calendarTitleFontSize: CGFloat
    let cellSize: CGFloat
    let cellRadius: CGFloat
    let cellDotWidth: CGFloat
    let agendaEventLeadingMargin: CGFloat
    let agendaDotWidth: CGFloat
    let panelWidth: CGFloat
    let sheetWidth: CGFloat
    let toolbarButtonSize: CGFloat
    let weekColumnWidth: CGFloat
    let loadingIndicatorHeight: CGFloat

    static func metrics(for preference: SizePreference) -> SizeMetrics {
        switch preference {
        case .small:
            return SizeMetrics(fontSize: 11, calendarTitleFontSize: 13, cellSize: 30,
                               cellRadius: 6, cellDotWidth: 4,
                               agendaEventLeadingMargin: 8, agendaDotWidth: 6,
                               panelWidth: 340, sheetWidth: 340, toolbarButtonSize: 26,
                               weekColumnWidth: 24, loadingIndicatorHeight: 14)
        case .medium:
            return SizeMetrics(fontSize: 13, calendarTitleFontSize: 15, cellSize: 36,
                               cellRadius: 7, cellDotWidth: 4,
                               agendaEventLeadingMargin: 10, agendaDotWidth: 7,
                               panelWidth: 380, sheetWidth: 380, toolbarButtonSize: 28,
                               weekColumnWidth: 24, loadingIndicatorHeight: 14)
        case .large:
            return SizeMetrics(fontSize: 15, calendarTitleFontSize: 17, cellSize: 40,
                               cellRadius: 8, cellDotWidth: 4.5,
                               agendaEventLeadingMargin: 12, agendaDotWidth: 8,
                               panelWidth: 420, sheetWidth: 420, toolbarButtonSize: 30,
                               weekColumnWidth: 24, loadingIndicatorHeight: 14)
        }
    }
}

enum SizePreference: Int, CaseIterable {
    case small = 0
    case medium = 1
    case large = 2
}
