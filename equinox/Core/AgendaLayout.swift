import Foundation

enum AgendaLayout {
    static let minHeight: CGFloat = 120
    static let defaultHeightRatio: Double = 0.35
    static let maximumHeightRatio: Double = 0.65

    static func agendaHeight(maxHeight: CGFloat, heightRatio: Double) -> CGFloat {
        guard maxHeight.isFinite, maxHeight > 0 else { return 0 }

        let ratio = heightRatio.isFinite ? heightRatio : defaultHeightRatio
        let clampedRatio = min(max(ratio, defaultHeightRatio), maximumHeightRatio)
        let ratioProgress = (clampedRatio - defaultHeightRatio)
            / (maximumHeightRatio - defaultHeightRatio)
        let availableMinimum = min(minHeight, maxHeight)
        let standardHeight = availableMinimum + (maxHeight - availableMinimum) * 0.4

        return standardHeight + (maxHeight - standardHeight) * CGFloat(ratioProgress)
    }
}
