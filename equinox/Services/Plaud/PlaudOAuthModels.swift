import Foundation

struct PlaudOAuthTokenSet: Codable, Sendable, Equatable {
    var access_token: String
    var refresh_token: String?
    var token_type: String?
    var expires_at: Double?
    var version: Int?
    var savedAt: String?

    var expiresAtDate: Date? {
        guard let expires_at else { return nil }
        return Date(timeIntervalSince1970: expires_at / 1000)
    }

    var isExpired: Bool {
        guard let expires_at else { return false }
        return Date().timeIntervalSince1970 * 1000 > expires_at - 60_000
    }

    var hasRefreshToken: Bool {
        guard let refresh_token else { return false }
        return !refresh_token.isEmpty
    }
}

enum PlaudOAuthError: LocalizedError {
    case callbackPortInUse
    case callbackListenFailed(String)
    case authenticationDenied(String?)
    case authenticationTimeout
    case tokenExchangeFailed(String)
    case tokenRefreshFailed(String)
    case credentialsMissing
    case alreadySignedIn

    var errorDescription: String? {
        switch self {
        case .callbackPortInUse:
            return String(
                localized: "OAuth callback port 8199 is already in use. Stop the other OAuth client and try again.",
                comment: "Plaud OAuth port error"
            )
        case .callbackListenFailed(let detail):
            return String(
                localized: "Could not start OAuth callback server: \(detail)",
                comment: "Plaud OAuth listen error"
            )
        case .authenticationDenied(let reason):
            if let reason, !reason.isEmpty {
                return String(
                    localized: "Plaud sign-in was denied: \(reason)",
                    comment: "Plaud OAuth denied"
                )
            }
            return String(localized: "Plaud sign-in was denied.", comment: "Plaud OAuth denied")
        case .authenticationTimeout:
            return String(
                localized: "Plaud sign-in timed out after 2 minutes.",
                comment: "Plaud OAuth timeout"
            )
        case .tokenExchangeFailed(let detail):
            return String(
                localized: "Plaud token exchange failed: \(detail)",
                comment: "Plaud OAuth exchange error"
            )
        case .tokenRefreshFailed(let detail):
            return String(
                localized: "Plaud token refresh failed: \(detail)",
                comment: "Plaud OAuth refresh error"
            )
        case .credentialsMissing:
            return String(
                localized: "Plaud live credentials not found.",
                comment: "Plaud OAuth missing credentials"
            )
        case .alreadySignedIn:
            return String(
                localized: "Already signed in to Plaud. Disconnect first to switch accounts.",
                comment: "Plaud OAuth already signed in"
            )
        }
    }
}
