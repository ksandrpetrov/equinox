import SwiftUI

extension EventParticipationStatus {
    var chipForeground: Color {
        switch self {
        case .unknown, .pending: .primary.opacity(0.85)
        case .accepted: EquinoxDesign.ColorToken.semanticGreen
        case .tentative: EquinoxDesign.ColorToken.semanticOrange
        case .declined: EquinoxDesign.ColorToken.semanticRed
        }
    }

    var chipBackground: Color {
        chipForeground.opacity(0.14)
    }
}
