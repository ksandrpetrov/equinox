import Foundation

@MainActor
final class PeriodicRefreshScheduler {
    typealias Schedule = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Timer
    private var timer: Timer?
    private let onTick: () -> Void
    private let schedule: Schedule
    private let now: () -> Date
    private let calendar: Calendar
    private var isRunning = false
    private var generation = 0

    init(
        schedule: @escaping Schedule = PeriodicRefreshScheduler.scheduleTimer,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent,
        onTick: @escaping () -> Void
    ) {
        self.schedule = schedule
        self.now = now
        self.calendar = calendar
        self.onTick = onTick
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        generation &+= 1
        scheduleNextTick()
    }

    func stop() {
        isRunning = false
        generation &+= 1
        timer?.invalidate()
        timer = nil
    }

    private func scheduleNextTick() {
        timer?.invalidate()
        let interval = secondsUntilNextMinuteBoundary()
        let generation = generation
        timer = schedule(interval) { [weak self] in
            guard let self, self.isRunning, self.generation == generation else { return }
            self.onTick()
            guard self.isRunning, self.generation == generation else { return }
            self.scheduleNextTick()
        }
    }

    private static func scheduleTimer(interval: TimeInterval, tick: @escaping @MainActor () -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: false) { _ in
            Task { @MainActor in tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private func secondsUntilNextMinuteBoundary() -> TimeInterval {
        let now = now()
        guard let startOfNextMinute = calendar.dateInterval(of: .minute, for: now)?.end else {
            return 30
        }
        return max(1, startOfNextMinute.timeIntervalSince(now))
    }
}
