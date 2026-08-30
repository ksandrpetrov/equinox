import SwiftUI

struct SizeMetrics {
    let fontSize: CGFloat
    let calendarTitleFontSize: CGFloat
    let cellSize: CGFloat
    let cellRadius: CGFloat
    let cellDotWidth: CGFloat
    let agendaTimeColumnWidth: CGFloat
    let agendaTimelineColumnWidth: CGFloat
    let agendaEventTitleFontSize: CGFloat
    let agendaEventMetaFontSize: CGFloat
    let agendaTimeFontSize: CGFloat
    let agendaRowMinHeight: CGFloat
    let panelWidth: CGFloat
    let sheetWidth: CGFloat
    let toolbarButtonSize: CGFloat
    let weekColumnWidth: CGFloat

    static func metrics(for preference: SizePreference) -> SizeMetrics {
        switch preference {
        case .small:
            return SizeMetrics(fontSize: 11, calendarTitleFontSize: 13, cellSize: 30,
                               cellRadius: EquinoxDesign.cellRadius, cellDotWidth: 4,
                               agendaTimeColumnWidth: 54, agendaTimelineColumnWidth: 16,
                               agendaEventTitleFontSize: 12, agendaEventMetaFontSize: 10,
                               agendaTimeFontSize: 10, agendaRowMinHeight: 28,
                               panelWidth: 340, sheetWidth: 340, toolbarButtonSize: 28,
                               weekColumnWidth: 24)
        case .medium:
            return SizeMetrics(fontSize: 13, calendarTitleFontSize: 15, cellSize: 36,
                               cellRadius: EquinoxDesign.cellRadius, cellDotWidth: 4,
                               agendaTimeColumnWidth: 60, agendaTimelineColumnWidth: 18,
                               agendaEventTitleFontSize: 13, agendaEventMetaFontSize: 11,
                               agendaTimeFontSize: 11, agendaRowMinHeight: 30,
                               panelWidth: 380, sheetWidth: 380, toolbarButtonSize: 30,
                               weekColumnWidth: 24)
        case .large:
            return SizeMetrics(fontSize: 15, calendarTitleFontSize: 17, cellSize: 40,
                               cellRadius: EquinoxDesign.cellRadius, cellDotWidth: 4.5,
                               agendaTimeColumnWidth: 68, agendaTimelineColumnWidth: 20,
                               agendaEventTitleFontSize: 14, agendaEventMetaFontSize: 12,
                               agendaTimeFontSize: 12, agendaRowMinHeight: 32,
                               panelWidth: 420, sheetWidth: 420, toolbarButtonSize: 32,
                               weekColumnWidth: 24)
        }
    }
}

enum SizePreference: Int, CaseIterable {
    case small = 0
    case medium = 1
    case large = 2
}
