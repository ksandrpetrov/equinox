import SwiftUI

extension EventParticipationStatus {
    var chipForeground: Color {
        switch self {
        case .unknown, .pending: .primary.opacity(EquinoxDesign.StateOpacity.chipForegroundSubtle)
        case .accepted: EquinoxDesign.ColorToken.semanticGreen
        case .tentative: EquinoxDesign.ColorToken.semanticOrange
        case .declined: EquinoxDesign.ColorToken.semanticRed
        case .delegated: EquinoxDesign.ColorToken.semanticBlue
        case .completed: EquinoxDesign.ColorToken.semanticGreen
        case .inProcess: EquinoxDesign.ColorToken.semanticOrange
        }
    }

    var chipBackground: Color {
        chipForeground.opacity(EquinoxDesign.StateOpacity.chipBackground)
    }
}
