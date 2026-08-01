import SwiftUI

struct SizeMetrics {
    let fontSize: CGFloat
    let calendarTitleFontSize: CGFloat
    let cellSize: CGFloat
    let cellRadius: CGFloat
    let cellDotWidth: CGFloat
    let agendaEventLeadingMargin: CGFloat
    let panelWidth: CGFloat
    let sheetWidth: CGFloat
    let toolbarButtonSize: CGFloat
    let weekColumnWidth: CGFloat
    let loadingIndicatorHeight: CGFloat

    /// Leading inset for agenda event content, aligned to the event stripe edge.
    var agendaContentLeadingInset: CGFloat {
        agendaEventLeadingMargin - EquinoxDesign.EventStripe.width
    }

    static func metrics(for preference: SizePreference) -> SizeMetrics {
        switch preference {
        case .small:
            return SizeMetrics(fontSize: 11, calendarTitleFontSize: 13, cellSize: 30,
                               cellRadius: EquinoxDesign.cellRadius, cellDotWidth: 4,
                               agendaEventLeadingMargin: 8,
                               panelWidth: 340, sheetWidth: 340, toolbarButtonSize: 28,
                               weekColumnWidth: 24, loadingIndicatorHeight: 14)
        case .medium:
            return SizeMetrics(fontSize: 13, calendarTitleFontSize: 15, cellSize: 36,
                               cellRadius: EquinoxDesign.cellRadius, cellDotWidth: 4,
                               agendaEventLeadingMargin: 10,
                               panelWidth: 380, sheetWidth: 380, toolbarButtonSize: 30,
                               weekColumnWidth: 24, loadingIndicatorHeight: 14)
        case .large:
            return SizeMetrics(fontSize: 15, calendarTitleFontSize: 17, cellSize: 40,
                               cellRadius: EquinoxDesign.cellRadius, cellDotWidth: 4.5,
                               agendaEventLeadingMargin: 12,
                               panelWidth: 420, sheetWidth: 420, toolbarButtonSize: 32,
                               weekColumnWidth: 24, loadingIndicatorHeight: 14)
        }
    }
}

enum SizePreference: Int, CaseIterable {
    case small = 0
    case medium = 1
    case large = 2
}
