import Foundation

struct PlaudLiveSession: Sendable {
    let apiBase: URL
    let accessToken: String
}

enum PlaudLiveClientError: LocalizedError {
    case credentialsMissing
    case authFailed
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .credentialsMissing:
            return String(localized: "Plaud live credentials not found.", comment: "Plaud live client error")
        case .authFailed:
            return String(localized: "Plaud live session expired or invalid.", comment: "Plaud live client error")
        case .unexpectedResponse:
            return String(localized: "Plaud API returned an unexpected response.", comment: "Plaud live client error")
        }
    }
}

actor PlaudLiveClient {
    private static let apiBase = URL(string: "https://platform.plaud.ai/developer/api")!

    func fetchRecordings() async throws -> [PlaudRecording] {
        let session = try await resolveSession()
        return try await listAllRecordings(session: session)
    }

    func resolveSession() async throws -> PlaudLiveSession {
        guard let accessToken = try await PlaudOAuthClient.validAccessToken() else {
            throw PlaudLiveClientError.credentialsMissing
        }
        return PlaudLiveSession(apiBase: Self.apiBase, accessToken: accessToken)
    }

    private func listAllRecordings(session: PlaudLiveSession) async throws -> [PlaudRecording] {
        var page = 1
        let pageSize = 50
        var byID: [String: PlaudRecording] = [:]

        while page <= 100 {
            let payload = try await fetchFilesPage(session: session, page: page, pageSize: pageSize)
            guard let items = payload["data"] as? [[String: Any]] else {
                throw PlaudLiveClientError.unexpectedResponse
            }
            if items.isEmpty { break }

            for raw in items {
                guard let recording = parseLiveRecord(raw) else { continue }
                byID[recording.fileID] = recording
            }

            if items.count < pageSize { break }
            page += 1
        }

        return Array(byID.values)
    }

    private func fetchFilesPage(
        session: PlaudLiveSession,
        page: Int,
        pageSize: Int
    ) async throws -> [String: Any] {
        var components = URLComponents(
            url: session.apiBase.appendingPathComponent("open/third-party/files/"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(max(10, pageSize))),
        ]
        guard let url = components.url else { throw PlaudLiveClientError.unexpectedResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        PlaudOAuthPKCE.applyBrowserHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PlaudLiveClientError.unexpectedResponse
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw PlaudLiveClientError.authFailed
        }
        guard http.statusCode == 200 else {
            throw PlaudLiveClientError.unexpectedResponse
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlaudLiveClientError.unexpectedResponse
        }
        return json
    }

    private func parseLiveRecord(_ raw: [String: Any]) -> PlaudRecording? {
        let idKeys = ["id", "file_id", "fileId", "recording_id", "recordingId"]
        var fileID: String?
        for key in idKeys {
            if let value = raw[key] as? String {
                let normalized = value.lowercased().replacingOccurrences(of: "-", with: "")
                if normalized.count == 32, normalized.allSatisfy(\.isHexDigit) {
                    fileID = normalized
                    break
                }
            }
        }
        guard let fileID else { return nil }

        let titleKeys = ["title", "name", "file_name", "fileName"]
        var title = fileID
        for key in titleKeys {
            if let value = raw[key] as? String, !value.isEmpty {
                title = value
                break
            }
        }

        let createdKeys = ["created_at", "createdAt", "create_time", "createTime", "start_time", "startTime"]
        var createdValue: Any?
        for key in createdKeys {
            if let value = raw[key] {
                createdValue = value
                break
            }
        }
        guard let recordedAt = PlaudTimestamp.parseCreatedAt(createdValue) else { return nil }

        return PlaudRecording(
            fileID: fileID,
            title: title,
            recordedAt: recordedAt
        )
    }
}
