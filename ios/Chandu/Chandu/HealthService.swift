import Foundation
import HealthKit

/// Reads the ヘルスケア numbers the game's きろく screen shows, one entry per day, and hands them to the page
/// as JSON: [{"day":"2026-10-16","steps":6200,"km":4.3,"flights":7,"kcal":312,"exMin":24,"standH":9,
/// "hr":82,"restHr":61,"sleepMin":412,"speed":4.6,"stride":68,"kg":62.4}]. Only numbers the iPhone has are sent.
/// Everything is read only; the app never writes to ヘルスケア.
final class HealthService: ObservableObject {
    /// The latest JSON for the page; changes whenever a new read finishes.
    @Published private(set) var json: String = ""

    private let store = HKHealthStore()
    private var asked = false
    private var firstRead = true

    private struct Sum { let id: HKQuantityTypeIdentifier; let key: String; let unit: HKUnit; let scale: Double }
    private struct Avg { let id: HKQuantityTypeIdentifier; let key: String; let unit: HKUnit; let scale: Double }

    private let sums: [Sum] = [
        Sum(id: .stepCount, key: "steps", unit: .count(), scale: 1),
        Sum(id: .distanceWalkingRunning, key: "km", unit: .meterUnit(with: .kilo), scale: 1),
        Sum(id: .flightsClimbed, key: "flights", unit: .count(), scale: 1),
        Sum(id: .activeEnergyBurned, key: "kcal", unit: .kilocalorie(), scale: 1),
        Sum(id: .appleExerciseTime, key: "exMin", unit: .minute(), scale: 1),
        Sum(id: .appleStandTime, key: "standH", unit: .minute(), scale: 1.0 / 60),
    ]
    private let avgs: [Avg] = [
        Avg(id: .heartRate, key: "hr", unit: HKUnit.count().unitDivided(by: .minute()), scale: 1),
        Avg(id: .restingHeartRate, key: "restHr", unit: HKUnit.count().unitDivided(by: .minute()), scale: 1),
        Avg(id: .walkingSpeed, key: "speed", unit: HKUnit.meterUnit(with: .kilo).unitDivided(by: .hour()), scale: 1),
        Avg(id: .walkingStepLength, key: "stride", unit: .meterUnit(with: .centi), scale: 1),
        Avg(id: .bodyMass, key: "kg", unit: .gramUnit(with: .kilo), scale: 1),
    ]

    private var readTypes: Set<HKObjectType> {
        var s = Set<HKObjectType>()
        for x in sums { if let t = HKObjectType.quantityType(forIdentifier: x.id) { s.insert(t) } }
        for x in avgs { if let t = HKObjectType.quantityType(forIdentifier: x.id) { s.insert(t) } }
        if let t = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { s.insert(t) }
        return s
    }

    /// Asks for permission the first time, then reads the last year once and the last two weeks after that.
    func refresh() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        if !asked {
            asked = true
            store.requestAuthorization(toShare: nil, read: readTypes) { [weak self] _, _ in
                DispatchQueue.main.async { self?.read() }
            }
        } else {
            read()
        }
    }

    private func read() {
        let cal = Calendar.current
        let end = Date()
        let today = cal.startOfDay(for: end)
        let start = cal.date(byAdding: .day, value: firstRead ? -365 : -14, to: today)!
        firstRead = false
        var days: [String: [String: Double]] = [:]
        let lock = NSLock()
        let group = DispatchGroup()
        func put(_ date: Date, _ key: String, _ value: Double) {
            lock.lock(); days[PedometerService.dayKey(date), default: [:]][key] = value; lock.unlock()
        }
        func collect(_ id: HKQuantityTypeIdentifier, _ options: HKStatisticsOptions, _ value: @escaping (HKStatistics) -> Double?, _ key: String) {
            guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return }
            group.enter()
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end),
                                                options: options, anchorDate: today, intervalComponents: DateComponents(day: 1))
            q.initialResultsHandler = { _, results, _ in
                results?.enumerateStatistics(from: start, to: end) { stats, _ in
                    if let v = value(stats) { put(stats.startDate, key, v) }
                }
                group.leave()
            }
            store.execute(q)
        }
        for x in sums {
            collect(x.id, .cumulativeSum, { $0.sumQuantity().map { $0.doubleValue(for: x.unit) * x.scale } }, x.key)
        }
        for x in avgs {
            collect(x.id, .discreteAverage, { $0.averageQuantity().map { $0.doubleValue(for: x.unit) * x.scale } }, x.key)
        }
        // Sleep: minutes asleep in the night that ends on each day (6 p.m. the day before to 6 p.m.)
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            group.enter()
            let from = cal.date(byAdding: .hour, value: -6, to: start)!
            let q = HKSampleQuery(sampleType: sleep, predicate: HKQuery.predicateForSamples(withStart: from, end: end),
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                var mins: [String: Double] = [:]
                for case let s as HKCategorySample in samples ?? [] {
                    guard s.value != HKCategoryValueSleepAnalysis.inBed.rawValue,
                          s.value != HKCategoryValueSleepAnalysis.awake.rawValue else { continue }
                    let day = PedometerService.dayKey(s.endDate.addingTimeInterval(6 * 3600))
                    mins[day, default: 0] += s.endDate.timeIntervalSince(s.startDate) / 60
                }
                lock.lock(); for (d, m) in mins { days[d, default: [:]]["sleepMin"] = m }; lock.unlock()
                group.leave()
            }
            store.execute(q)
        }
        group.notify(queue: .main) { [weak self] in
            let list: [[String: Any]] = days.map { day, values in
                var e: [String: Any] = ["day": day]
                for (k, v) in values { e[k] = (v * 100).rounded() / 100 }
                return e
            }
            guard !list.isEmpty, let data = try? JSONSerialization.data(withJSONObject: list),
                  let text = String(data: data, encoding: .utf8) else { return }
            self?.json = text
        }
    }
}
