import Foundation

@MainActor
final class LoadingIndicatorController {
    typealias Cancel = @MainActor () -> Void
    typealias Schedule = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Cancel

    private(set) var shouldShowLoadingIndicator = false
    private(set) var isFetchingEvents = false
    var onUpdate: ((_ shouldShowLoadingIndicator: Bool, _ isFetchingEvents: Bool) -> Void)?

    private var activeFetchCount = 0
    private var cancelPending: Cancel?
    private var generation = 0
    private var visibleSince: TimeInterval?
    private let now: () -> TimeInterval
    private let schedule: Schedule

    private let showDelay: TimeInterval = 0.15
    private let minVisibleDuration: TimeInterval = 0.2

    init(
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        schedule: @escaping Schedule = LoadingIndicatorController.scheduleTask
    ) {
        self.now = now
        self.schedule = schedule
    }

    func beginFetch() {
        activeFetchCount += 1
        // Overlapping requests share the original show deadline.
        guard activeFetchCount == 1 else { return }
        isFetchingEvents = true
        invalidatePendingAction()
        if !shouldShowLoadingIndicator {
            let generation = generation
            cancelPending = schedule(showDelay) { [weak self] in
                guard let self, self.generation == generation, self.isFetchingEvents else { return }
                self.shouldShowLoadingIndicator = true
                self.visibleSince = self.now()
                self.cancelPending = nil
                self.notifyUpdate()
            }
        }
        notifyUpdate()
    }

    func endFetch() {
        guard activeFetchCount > 0 else { return }
        activeFetchCount -= 1
        guard activeFetchCount == 0 else { return }
        isFetchingEvents = false
        invalidatePendingAction()
        guard shouldShowLoadingIndicator else {
            notifyUpdate()
            return
        }
        let remaining = max(0, minVisibleDuration - (now() - (visibleSince ?? now())))
        if remaining == 0 {
            hideIndicator()
        } else {
            let generation = generation
            cancelPending = schedule(remaining) { [weak self] in
                guard let self, self.generation == generation, !self.isFetchingEvents else { return }
                self.hideIndicator()
            }
            notifyUpdate()
        }
    }

    private func invalidatePendingAction() {
        generation &+= 1
        cancelPending?()
        cancelPending = nil
    }

    private func hideIndicator() {
        shouldShowLoadingIndicator = false
        visibleSince = nil
        cancelPending = nil
        notifyUpdate()
    }

    private static func scheduleTask(after delay: TimeInterval, action: @escaping @MainActor () -> Void) -> Cancel {
        let task = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard !Task.isCancelled else { return }
            action()
        }
        return { task.cancel() }
    }

    private func notifyUpdate() {
        onUpdate?(shouldShowLoadingIndicator, isFetchingEvents)
    }
}
