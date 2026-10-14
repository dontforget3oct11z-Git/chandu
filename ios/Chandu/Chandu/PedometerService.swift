import CoreMotion
import Foundation

/// Today's step count from the iPhone's motion coprocessor, updated live while you walk.
final class PedometerService: ObservableObject {
    @Published private(set) var stepsToday: Int = 0
    /// The day `stepsToday` belongs to, written like the game's own day key ("2026-10-14").
    @Published private(set) var day: String = PedometerService.dayKey(Date())

    private let pedometer = CMPedometer()
    private var dayStart = Calendar.current.startOfDay(for: Date())
    private var timer: Timer?

    static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    func start() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometer.stopUpdates()
        let start = Calendar.current.startOfDay(for: Date())
        if start != dayStart { stepsToday = 0 }   // never carry yesterday's total into a new day
        dayStart = start
        day = PedometerService.dayKey(start)
        // Today's total right away (live updates only arrive once you walk), then every minute in case
        // live updates are slow, which also notices midnight while the app stays open.
        query(from: start)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            if Calendar.current.startOfDay(for: Date()) != self.dayStart { self.start() } else { self.query(from: self.dayStart) }
        }
        pedometer.startUpdates(from: start) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            let steps = data.numberOfSteps.intValue
            DispatchQueue.main.async {
                if Calendar.current.startOfDay(for: Date()) != self.dayStart {
                    self.start()   // a new day began: count from the new midnight
                    return
                }
                if start == self.dayStart { self.stepsToday = steps }
            }
        }
    }

    private func query(from start: Date) {
        pedometer.queryPedometerData(from: start, to: Date()) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            let steps = data.numberOfSteps.intValue
            DispatchQueue.main.async {
                if start == self.dayStart && steps > self.stepsToday { self.stepsToday = steps }
            }
        }
    }

    func stop() {
        pedometer.stopUpdates()
        timer?.invalidate()
        timer = nil
    }
}
