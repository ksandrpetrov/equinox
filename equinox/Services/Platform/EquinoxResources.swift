import Foundation

private final class EquinoxResourceAnchor {}

extension Bundle {
    /// The framework owns localized strings and assets in both the app and XCTest.
    static let equinox = Bundle(for: EquinoxResourceAnchor.self)
}
