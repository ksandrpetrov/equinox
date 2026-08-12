import Foundation

struct PlaudSetup: Equatable, Sendable {
    var isEnabled: Bool
    var recordCount: Int
    var lastRefreshAt: Date?
    var cachePositiveCount: Int
    var cacheManualCount: Int
    var lastError: String?
    var hasKeychainOAuth: Bool
    var keychainOAuthExpiresAt: Date?
    var keychainOAuthHasRefresh: Bool
}

enum PlaudConfigurator {
    static func buildSetup(
        enabled: Bool,
        recordCount: Int = 0,
        lastRefreshAt: Date? = nil,
        cacheStats: (positive: Int, manual: Int)? = nil,
        lastError: String? = nil
    ) -> PlaudSetup {
        let stats = cacheStats ?? (positive: 0, manual: 0)
        let keychainTokens = PlaudOAuthClient.loadTokens()

        return PlaudSetup(
            isEnabled: enabled,
            recordCount: recordCount,
            lastRefreshAt: lastRefreshAt,
            cachePositiveCount: stats.positive,
            cacheManualCount: stats.manual,
            lastError: lastError,
            hasKeychainOAuth: keychainTokens != nil,
            keychainOAuthExpiresAt: keychainTokens?.expiresAtDate,
            keychainOAuthHasRefresh: keychainTokens?.hasRefreshToken ?? false
        )
    }

    @MainActor
    static func buildSetupFromPreferences(
        recordCount: Int = 0,
        lastRefreshAt: Date? = nil,
        cacheStats: (positive: Int, manual: Int)? = nil,
        lastError: String? = nil
    ) -> PlaudSetup {
        buildSetup(
            enabled: PreferencesStore.shared.isPlaudEnabled,
            recordCount: recordCount,
            lastRefreshAt: lastRefreshAt,
            cacheStats: cacheStats,
            lastError: lastError
        )
    }
}
