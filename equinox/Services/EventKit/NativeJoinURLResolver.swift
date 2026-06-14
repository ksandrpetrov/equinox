import AppKit
import Foundation

typealias NativeAppInstalledChecker = @Sendable (URL) async -> Bool

enum NativeJoinURLResolver {
    /// Main-thread checker safe to call from `CalendarStore` actor isolation.
    static let defaultInstalledChecker: NativeAppInstalledChecker = { url in
        await MainActor.run {
            guard let scheme = NativeJoinURL.nativeScheme(for: url),
                  let schemeURL = URL(string: scheme) else { return false }
            return NSWorkspace.shared.urlForApplication(toOpen: schemeURL) != nil
        }
    }

    static func resolveNativeJoinURL(
        from webURL: URL,
        isAppInstalled: NativeAppInstalledChecker = defaultInstalledChecker
    ) async -> URL? {
        guard await isAppInstalled(webURL),
              let native = NativeJoinURL.nativeURLString(from: webURL) else {
            return nil
        }
        return URL(string: native)
    }
}
