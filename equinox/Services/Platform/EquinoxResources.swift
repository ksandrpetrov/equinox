import Foundation

private final class EquinoxResourceAnchor {}

extension Bundle {
    /// The framework owns localized strings and assets in both the app and XCTest.
    static let equinox = Bundle(for: EquinoxResourceAnchor.self)
}

/// Public documentation URLs shared by Settings and the submission checklist.
enum EquinoxDocumentation {
    static let privacyPolicy = URL(string: "https://github.com/ksandrpetrov/equinox/blob/main/PRIVACY.md")!
    static let support = URL(string: "https://github.com/ksandrpetrov/equinox/blob/main/SUPPORT.md")!
}
