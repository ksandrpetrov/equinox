import Foundation

@MainActor
final class EventFetchCoordinator {
    private let calendarStore: CalendarStore
    private let loadingIndicator = LoadingIndicatorController()
    private var fetchGeneration = 0

    var onPresentationUpdate: ((_ shouldShowLoadingIndicator: Bool, _ isFetchingEvents: Bool) -> Void)?
    var onSyncComplete: (() async -> Void)?

    init(calendarStore: CalendarStore) {
        self.calendarStore = calendarStore
        loadingIndicator.onUpdate = { [weak self] shouldShow, isFetching in
            self?.onPresentationUpdate?(shouldShow, isFetching)
        }
    }

    func scheduleFetch(
        range: (first: CalendarDate, last: CalendarDate),
        refetch: Bool = false
    ) {
        fetchGeneration &+= 1
        let generation = fetchGeneration
        Task {
            await performFetch(generation: generation) {
                if refetch {
                    await calendarStore.refetchAll(first: range.first, last: range.last)
                } else {
                    await calendarStore.fetchEvents(first: range.first, last: range.last)
                }
            }
        }
    }

    func performFetch(generation: Int, operation: () async -> Void) async {
        loadingIndicator.beginFetch()
        defer {
            loadingIndicator.endFetch()
        }
        await operation()
        guard generation == fetchGeneration else { return }
        await onSyncComplete?()
    }
}
