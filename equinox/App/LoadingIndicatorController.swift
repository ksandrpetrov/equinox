import Foundation

@MainActor
final class LoadingIndicatorController {
    private(set) var shouldShowLoadingIndicator = false
    private(set) var isFetchingEvents = false

    var onUpdate: ((_ shouldShowLoadingIndicator: Bool, _ isFetchingEvents: Bool) -> Void)?

    private var activeFetchCount = 0
    private var task: Task<Void, Never>?
    private var generation = 0
    private var visibleSince: Date?

    private let showDelayNanoseconds: UInt64 = 150_000_000
    private let minVisibleDuration: TimeInterval = 0.2

    func beginFetch() {
        activeFetchCount += 1
        isFetchingEvents = true
        generation &+= 1
        task?.cancel()

        guard !shouldShowLoadingIndicator else {
            notifyUpdate()
            return
        }

        let currentGeneration = generation
        task = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.showDelayNanoseconds ?? 150_000_000)
            guard !Task.isCancelled,
                  let self,
                  self.generation == currentGeneration,
                  self.isFetchingEvents else { return }
            self.shouldShowLoadingIndicator = true
            self.visibleSince = Date()
            self.notifyUpdate()
        }
        notifyUpdate()
    }

    func endFetch() {
        activeFetchCount = max(0, activeFetchCount - 1)
        guard activeFetchCount == 0 else { return }

        isFetchingEvents = false
        generation &+= 1
        task?.cancel()

        guard shouldShowLoadingIndicator else {
            notifyUpdate()
            return
        }

        let visibleDuration = Date().timeIntervalSince(visibleSince ?? Date())
        let remaining = max(0, minVisibleDuration - visibleDuration)
        let currentGeneration = generation

        task = Task { @MainActor [weak self] in
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            guard !Task.isCancelled,
                  let self,
                  self.generation == currentGeneration,
                  !self.isFetchingEvents else { return }
            self.shouldShowLoadingIndicator = false
            self.visibleSince = nil
            self.notifyUpdate()
        }
    }

    private func notifyUpdate() {
        onUpdate?(shouldShowLoadingIndicator, isFetchingEvents)
    }
}
