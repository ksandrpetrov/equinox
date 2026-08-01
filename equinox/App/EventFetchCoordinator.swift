import Foundation

@MainActor
final class EventFetchCoordinator {
    typealias AccessOperation = @MainActor () async -> Bool
    typealias FetchOperation = @MainActor (CalendarDate, CalendarDate) async -> Bool

    private struct PendingFetch {
        var first: CalendarDate
        var last: CalendarDate
        var refetch: Bool
        var preparesCalendarAccess: Bool
        var completions: [CheckedContinuation<Bool, Never>] = []

        mutating func merge(
            range: (first: CalendarDate, last: CalendarDate),
            refetch: Bool,
            preparesCalendarAccess: Bool,
            completion: CheckedContinuation<Bool, Never>?
        ) {
            first = min(first, range.first)
            last = max(last, range.last)
            self.refetch = self.refetch || refetch
            self.preparesCalendarAccess = self.preparesCalendarAccess || preparesCalendarAccess
            if let completion {
                completions.append(completion)
            }
        }
    }

    private let requestCalendarAccess: AccessOperation
    private let fetchEvents: FetchOperation
    private let refetchEvents: FetchOperation
    private let loadingIndicator = LoadingIndicatorController()

    private var pendingFetch: PendingFetch?
    private var isDrainingQueue = false
    private var hasPreparedCalendarAccess = false

    var onPresentationUpdate: ((_ shouldShowLoadingIndicator: Bool, _ isFetchingEvents: Bool) -> Void)?
    var onSyncComplete: ((_ successfulFetch: Bool) async -> Void)?

    convenience init(calendarStore: CalendarStore) {
        self.init(
            requestCalendarAccess: {
                await calendarStore.requestCalendarAccessIfNeeded()
            },
            fetchEvents: { first, last in
                await calendarStore.fetchEvents(first: first, last: last)
            },
            refetchEvents: { first, last in
                await calendarStore.refetchAll(first: first, last: last)
            }
        )
    }

    init(
        requestCalendarAccess: @escaping AccessOperation,
        fetchEvents: @escaping FetchOperation,
        refetchEvents: @escaping FetchOperation
    ) {
        self.requestCalendarAccess = requestCalendarAccess
        self.fetchEvents = fetchEvents
        self.refetchEvents = refetchEvents
        loadingIndicator.onUpdate = { [weak self] shouldShow, isFetching in
            self?.onPresentationUpdate?(shouldShow, isFetching)
        }
    }

    func scheduleFetch(
        range: (first: CalendarDate, last: CalendarDate),
        refetch: Bool = false,
        preparesCalendarAccess: Bool = false
    ) {
        enqueue(
            range: range,
            refetch: refetch,
            preparesCalendarAccess: preparesCalendarAccess,
            completion: nil
        )
    }

    func fetch(
        range: (first: CalendarDate, last: CalendarDate),
        refetch: Bool = false,
        preparesCalendarAccess: Bool = false
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            enqueue(
                range: range,
                refetch: refetch,
                preparesCalendarAccess: preparesCalendarAccess,
                completion: continuation
            )
        }
    }

    private func enqueue(
        range: (first: CalendarDate, last: CalendarDate),
        refetch: Bool,
        preparesCalendarAccess: Bool,
        completion: CheckedContinuation<Bool, Never>?
    ) {
        guard range.first <= range.last else {
            completion?.resume(returning: false)
            return
        }

        if pendingFetch != nil {
            pendingFetch?.merge(
                range: range,
                refetch: refetch,
                preparesCalendarAccess: preparesCalendarAccess,
                completion: completion
            )
        } else {
            pendingFetch = PendingFetch(
                first: range.first,
                last: range.last,
                refetch: refetch,
                preparesCalendarAccess: preparesCalendarAccess,
                completions: completion.map { [$0] } ?? []
            )
        }

        guard !isDrainingQueue else { return }
        isDrainingQueue = true
        Task {
            await drainQueue()
        }
    }

    private func drainQueue() async {
        loadingIndicator.beginFetch()
        defer {
            loadingIndicator.endFetch()
            isDrainingQueue = false
        }

        while let request = takePendingFetch() {
            let shouldPrepareAccess = request.preparesCalendarAccess || !hasPreparedCalendarAccess
            let hasAccess: Bool
            if shouldPrepareAccess {
                hasAccess = await requestCalendarAccess()
                hasPreparedCalendarAccess = true
            } else {
                hasAccess = true
            }

            let successfulFetch: Bool
            if !hasAccess {
                successfulFetch = false
            } else if request.refetch {
                successfulFetch = await refetchEvents(request.first, request.last)
            } else {
                successfulFetch = await fetchEvents(request.first, request.last)
            }

            await onSyncComplete?(successfulFetch)
            request.completions.forEach { $0.resume(returning: successfulFetch) }
        }
    }

    private func takePendingFetch() -> PendingFetch? {
        defer { pendingFetch = nil }
        return pendingFetch
    }
}
