import Foundation

enum AgendaLayout {
    static let minHeight: CGFloat = 120
    static let minimumHeightRatio: Double = 0.15
    static let defaultHeightRatio: Double = 0.35
    static let maximumHeightRatio: Double = 0.65

    static func agendaHeight(maxHeight: CGFloat, heightRatio: Double) -> CGFloat {
        guard maxHeight.isFinite, maxHeight > 0 else { return 0 }

        let ratio = heightRatio.isFinite ? heightRatio : defaultHeightRatio
        let clampedRatio = min(max(ratio, minimumHeightRatio), maximumHeightRatio)
        let ratioProgress = (clampedRatio - minimumHeightRatio)
            / (maximumHeightRatio - minimumHeightRatio)
        let availableMinimum = min(minHeight, maxHeight)

        return availableMinimum + (maxHeight - availableMinimum) * CGFloat(ratioProgress)
    }
}
