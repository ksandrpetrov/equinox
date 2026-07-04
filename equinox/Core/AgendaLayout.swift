import Foundation

enum AgendaLayout {
    static let minHeight: CGFloat = 120
    static let defaultHeightRatio: Double = 0.35

    static func agendaHeight(maxHeight: CGFloat, heightRatio: Double) -> CGFloat {
        max(minHeight, min(maxHeight, maxHeight * heightRatio / defaultHeightRatio))
    }
}
