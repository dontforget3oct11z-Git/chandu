import CoreMotion
import Foundation

/// Today's step count from the iPhone's motion coprocessor, updated live while you walk.
final class PedometerService: ObservableObject {
    @Published private(set) var stepsToday: Int = 0

    private let pedometer = CMPedometer()
    private var dayStart = Calendar.current.startOfDay(for: Date())

    func start() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometer.stopUpdates()
        let start = Calendar.current.startOfDay(for: Date())
        dayStart = start
        // Reports the total since midnight first, then a new total every few seconds while walking.
        pedometer.startUpdates(from: start) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            let steps = data.numberOfSteps.intValue
            DispatchQueue.main.async {
                if Calendar.current.startOfDay(for: Date()) != self.dayStart {
                    self.stepsToday = 0
                    self.start()   // a new day began: count from the new midnight
                    return
                }
                self.stepsToday = steps
            }
        }
    }

    func stop() {
        pedometer.stopUpdates()
    }
}
