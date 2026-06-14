import Foundation

struct PlaudSetup: Equatable, Sendable {
    var isEnabled: Bool
    var syncIndexPath: String?
    var hasSyncIndexBookmark: Bool
    var exporterDataPath: String?
    var defaultSyncIndexPath: String?
    var recordCount: Int
    var indexModifiedAt: Date?
    var cachePositiveCount: Int
    var cacheNegativeCount: Int
    var cacheManualCount: Int
    var lastError: String?
    var hasKeychainOAuth: Bool
    var keychainOAuthExpiresAt: Date?
    var keychainOAuthHasRefresh: Bool
    var hasExporterOAuth: Bool

    var isIndexReady: Bool {
        hasSyncIndexBookmark || (syncIndexPath.map { FileManager.default.fileExists(atPath: $0) } ?? false)
    }

    var isReady: Bool { isEnabled && isIndexReady }
}

enum PlaudConfigurator {
    static let defaultExporterRelative = "plaud-server-exporter/server/.data"

    static func buildSetup(
        enabled: Bool? = nil,
        syncIndexPath: String? = nil,
        bookmarkData: Data? = nil,
        exporterDataPath: String? = nil,
        snapshot: PlaudCatalogSnapshot? = nil,
        cacheStats: (positive: Int, negative: Int, manual: Int)? = nil,
        lastError: String? = nil
    ) -> PlaudSetup {
        let prefs = PreferencesStore.shared
        let resolvedPath = syncIndexPath ?? prefs.plaudSyncIndexPath
        let resolvedExporter = exporterDataPath ?? prefs.plaudExporterDataPath
        let bookmark = bookmarkData ?? prefs.plaudSyncIndexBookmark

        let defaultPath = resolveDefaultSyncIndexPath()
        let exporterOAuthPath = resolvedExporter.map {
            URL(fileURLWithPath: $0).appendingPathComponent("oauth-tokens.json").path
        }
        let hasExporterOAuth = exporterOAuthPath.map { FileManager.default.fileExists(atPath: $0) } ?? false

        let stats = cacheStats ?? PlaudMatchCache().stats()
        let keychainTokens = PlaudOAuthClient.loadTokens()

        return PlaudSetup(
            isEnabled: enabled ?? prefs.isPlaudEnabled,
            syncIndexPath: resolvedPath,
            hasSyncIndexBookmark: bookmark != nil,
            exporterDataPath: resolvedExporter,
            defaultSyncIndexPath: defaultPath,
            recordCount: snapshot?.recordCount ?? 0,
            indexModifiedAt: snapshot?.indexModifiedAt,
            cachePositiveCount: stats.positive,
            cacheNegativeCount: stats.negative,
            cacheManualCount: stats.manual,
            lastError: lastError,
            hasKeychainOAuth: keychainTokens != nil,
            keychainOAuthExpiresAt: keychainTokens?.expiresAtDate,
            keychainOAuthHasRefresh: keychainTokens?.hasRefreshToken ?? false,
            hasExporterOAuth: hasExporterOAuth
        )
    }

    static func resolveDefaultSyncIndexPath() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Developer/\(defaultExporterRelative)/sync-index.json"),
            home.appendingPathComponent("Developer/plaud-server-exporter/server/.data/sync-index.json"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }?.path
    }

    static func resolveExporterDataPath() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Developer/\(defaultExporterRelative)"),
            home.appendingPathComponent("Developer/plaud-server-exporter/server/.data"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }?.path
    }
}
