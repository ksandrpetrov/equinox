import Foundation

@Observable
@MainActor
final class PlaudCoordinator {
    private let plaudService = PlaudService()
    private var plaudLinks: [String: PlaudEventMatch] = [:]
    private var plaudRefreshTask: Task<Void, Never>?
    private var plaudHistoryTask: Task<Void, Never>?
    private var didMatchPlaudHistory = false

    private let preferences: PreferencesStore
    private let calendar: Calendar
    private let matchableEvents: (Date, Date) async -> [DayEvent]
    private let eventsByDate: () -> [CalendarDate: [DayEvent]]
    private let calendarAccessStatus: () -> CalendarAccessStatus
    private let isPlaudEnabled: () -> Bool

    var setup = PlaudConfigurator.buildSetup()

    init(
        preferences: PreferencesStore,
        calendar: Calendar,
        matchableEvents: @escaping (Date, Date) async -> [DayEvent],
        eventsByDate: @escaping () -> [CalendarDate: [DayEvent]],
        calendarAccessStatus: @escaping () -> CalendarAccessStatus,
        isPlaudEnabled: @escaping () -> Bool
    ) {
        self.preferences = preferences
        self.calendar = calendar
        self.matchableEvents = matchableEvents
        self.eventsByDate = eventsByDate
        self.calendarAccessStatus = calendarAccessStatus
        self.isPlaudEnabled = isPlaudEnabled
    }

    func link(for event: DayEvent) -> PlaudEventMatch? {
        guard isPlaudEnabled() else { return nil }
        guard let eventID = event.eventIdentifier else { return nil }
        let key = PlaudEventMatching.matchKey(eventIdentifier: eventID, startDate: event.startDate)
        return plaudLinks[key]
    }

    func refreshMatchesIfNeeded(force: Bool = false) {
        guard isPlaudEnabled() else {
            plaudLinks = [:]
            setup = PlaudConfigurator.buildSetup(enabled: false, cacheStats: nil)
            didMatchPlaudHistory = false
            return
        }

        plaudRefreshTask?.cancel()
        let pastEvents = eventsByDate().values.flatMap { $0 }.filter { $0.endDate < Date() }
        plaudRefreshTask = Task { @MainActor in
            let cached = await plaudService.allCachedLinks(isPlaudEnabled: isPlaudEnabled())
            guard !Task.isCancelled else { return }
            plaudLinks = cached

            let fresh = await plaudService.refreshMatches(for: pastEvents, isPlaudEnabled: isPlaudEnabled())
            guard !Task.isCancelled else { return }
            plaudLinks.merge(fresh) { _, new in new }
            setup = await plaudService.setupStatus()
        }
    }

    func refreshSetup() async {
        setup = await plaudService.setupStatus()
    }

    func refreshSetupForSettings() async {
        setup = await plaudService.setupStatus()
    }

    func signIn() async throws {
        try await PlaudOAuthClient.signIn()
        setup = await plaudService.setupStatus()
    }

    func signOut() async {
        await PlaudOAuthClient.signOut()
        setup = PlaudConfigurator.buildSetup(cacheStats: nil)
    }

    func forceRefresh() async {
        _ = await plaudService.refreshIfNeeded(force: true, isPlaudEnabled: isPlaudEnabled())
        plaudLinks = await plaudService.allCachedLinks(isPlaudEnabled: isPlaudEnabled())
        let historyEvents = await historyEvents()
        let fresh = await plaudService.refreshMatches(for: historyEvents, isPlaudEnabled: isPlaudEnabled())
        plaudLinks.merge(fresh) { _, new in new }
        setup = await plaudService.setupStatus()
        didMatchPlaudHistory = true
    }

    func matchHistoryIfNeeded() {
        guard isPlaudEnabled(), calendarAccessStatus() == .authorized else { return }
        guard !didMatchPlaudHistory else { return }
        didMatchPlaudHistory = true

        plaudHistoryTask?.cancel()
        plaudHistoryTask = Task { @MainActor in
            let historyEvents = await historyEvents()
            let fresh = await plaudService.refreshMatches(for: historyEvents, isPlaudEnabled: isPlaudEnabled())
            guard !Task.isCancelled else { return }
            plaudLinks.merge(fresh) { _, new in new }
            setup = await plaudService.setupStatus()
        }
    }

    func saveManualLink(for event: DayEvent, url: URL) async -> String? {
        do {
            let match = try await plaudService.saveManualLink(for: event, url: url)
            guard let eventID = event.eventIdentifier else { return nil }
            let key = PlaudEventMatching.matchKey(eventIdentifier: eventID, startDate: event.startDate)
            plaudLinks[key] = match
            setup = await plaudService.setupStatus()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func historyEvents() async -> [DayEvent] {
        guard let earliest = await plaudService.recordingsStartDate() else { return [] }
        let start = calendar.startOfDay(for: earliest)
        let now = Date()
        guard start < now else { return [] }
        return await matchableEvents(start, now)
    }
}
