import SwiftUI

extension EventParticipationStatus {
    var chipForeground: Color {
        switch self {
        case .unknown, .pending: .primary.opacity(0.85)
        case .accepted: .green
        case .tentative: .orange
        case .declined: .red
        }
    }

    var chipBackground: Color {
        chipForeground.opacity(0.14)
    }
}
