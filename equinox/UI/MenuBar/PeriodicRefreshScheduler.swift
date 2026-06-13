import Foundation

@MainActor
final class PeriodicRefreshScheduler {
    private var timer: Timer?
    private let onTick: () -> Void

    init(onTick: @escaping () -> Void) {
        self.onTick = onTick
    }

    func start() {
        guard timer == nil else { return }
        scheduleNextTick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleNextTick() {
        timer?.invalidate()
        let interval = secondsUntilNextMinuteBoundary()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.onTick()
                self.scheduleNextTick()
            }
        }
    }

    private func secondsUntilNextMinuteBoundary() -> TimeInterval {
        let now = Date()
        let calendar = Calendar.current
        guard let nextMinute = calendar.date(byAdding: .minute, value: 1, to: now),
              let startOfNextMinute = calendar.date(
                from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextMinute)
              ) else {
            return 30
        }
        return max(1, startOfNextMinute.timeIntervalSince(now))
    }
}
