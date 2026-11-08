import CoreLocation
import Foundation
import UIKit
import UserNotifications

/// Tells the player, even while the app is closed, when they walk into a town whose ごとうちチャーム
/// they don't have yet. The charm itself is still given by the game when the app is opened there.
///
/// Privacy: the position is only compared, on this iPhone, with the town shapes in jp-muni.json. It is
/// never sent anywhere and never stored. Only town codes are kept (the charms already owned, and the
/// towns already announced today), so the same town isn't announced twice.
final class MuniWatcher: NSObject, CLLocationManagerDelegate {
    static let shared = MuniWatcher()

    private let manager = CLLocationManager()
    private let defaults = UserDefaults.standard
    private var towns: [Town] = []
    private var arcs: [[Int32]] = []
    private var transform: [Double] = [1, 1, 0, 0]
    private var names: [String: String] = [:]   // code → charm name
    private var loading = false

    private struct Town {
        let code: String, pref: String, name: String
        let box: [Int32]
        let polys: [[[Int]]]
    }

    private var enabled: Bool { defaults.bool(forKey: "muniNotify") }
    private var owned: Set<String> { Set(defaults.stringArray(forKey: "muniOwned") ?? []) }

    private override init() {
        super.init()
        manager.delegate = self
    }

    /// Called at launch (also when iOS relaunches the app in the background for a location change).
    func resume() {
        if enabled { start() }
    }

    /// From the game: the towns already collected, and whether to announce new ones.
    func update(owned codes: [String], notify: Bool) {
        defaults.set(codes, forKey: "muniOwned")
        let was = enabled
        defaults.set(notify, forKey: "muniNotify")
        if notify && !was {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            manager.requestAlwaysAuthorization()
        }
        if notify { start() } else { manager.stopMonitoringSignificantLocationChanges() }
    }

    private func start() {
        loadTowns()
        // Low power: iOS reports a new position only after moving about 500 m or more.
        manager.startMonitoringSignificantLocationChanges()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if enabled && manager.authorizationStatus == .authorizedWhenInUse { manager.requestAlwaysAuthorization() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard enabled, let loc = locations.last, loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= 3000 else { return }
        let lon = loc.coordinate.longitude, lat = loc.coordinate.latitude
        loadTowns { [weak self] in
            guard let self, let town = self.find(lon: lon, lat: lat) else { return }
            DispatchQueue.main.async { self.announce(town) }
        }
    }

    private func announce(_ town: Town) {
        // The open game shows its own popup, so only announce while it is closed or in the background.
        guard UIApplication.shared.applicationState != .active, !owned.contains(town.code) else { return }
        let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        var told = defaults.dictionary(forKey: "muniTold") as? [String: Double] ?? [:]
        if told[town.code] == today { return }
        told = told.filter { $0.value == today }
        told[town.code] = today
        defaults.set(told, forKey: "muniTold")

        let content = UNMutableNotificationContent()
        content.title = "📍 \(town.name)に はいったよ！"
        let charm = names[town.code].map { "「\($0)」" } ?? ""
        content.body = "まだ もっていない ごとうちチャーム\(charm)が もらえるよ。チャンドゥを ひらいてね！"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "muni-\(town.code)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Town shapes (the same files the game uses, kept in Caches once downloaded)

    private func loadTowns(then done: (() -> Void)? = nil) {
        if !towns.isEmpty { done?(); return }
        if loading { return }
        loading = true
        DispatchQueue.global(qos: .utility).async {
            let base = GameWebView.pageURL
            if let data = Self.file("jp-muni.json", from: base) { self.parse(data) }
            if let data = Self.file("jp-muni-items.json", from: base),
               let items = try? JSONSerialization.jsonObject(with: data) as? [String: [Any]] {
                self.names = items.compactMapValues { $0.first as? String }
            }
            self.loading = false
            if !self.towns.isEmpty { done?() }
        }
    }

    /// A cached copy if there is one, otherwise downloaded (and cached).
    private static func file(_ name: String, from base: URL) -> Data? {
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
        if let data = try? Data(contentsOf: cache) { return data }
        guard let data = try? Data(contentsOf: base.appendingPathComponent(name)) else { return nil }
        try? data.write(to: cache, options: .atomic)
        return data
    }

    private func parse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let t = json["t"] as? [Double], let rawArcs = json["arcs"] as? [[[Int]]], let m = json["m"] as? [[Any]] else { return }
        // arcs are stored as steps; turn them into absolute points (x0, y0, x1, y1, …)
        arcs = rawArcs.map { arc in
            var x: Int32 = 0, y: Int32 = 0, out: [Int32] = []
            out.reserveCapacity(arc.count * 2)
            for p in arc where p.count == 2 { x += Int32(p[0]); y += Int32(p[1]); out.append(x); out.append(y) }
            return out
        }
        transform = t
        towns = m.compactMap { row in
            guard row.count >= 5, let code = row[0] as? String, let pref = row[1] as? String, let name = row[2] as? String,
                  let box = row[3] as? [Int], let polys = row[4] as? [[[Int]]] else { return nil }
            return Town(code: code, pref: pref, name: name, box: box.map { Int32($0) }, polys: polys)
        }
    }

    private func find(lon: Double, lat: Double) -> Town? {
        let x = (lon - transform[2]) / transform[0], y = (lat - transform[3]) / transform[1]
        for town in towns {
            let b = town.box
            if x < Double(b[0]) || x > Double(b[2]) || y < Double(b[1]) || y > Double(b[3]) { continue }
            for poly in town.polys where !poly.isEmpty {
                if inRing(poly[0], x, y) && !poly.dropFirst().contains(where: { inRing($0, x, y) }) { return town }
            }
        }
        return nil
    }

    private func inRing(_ ring: [Int], _ x: Double, _ y: Double) -> Bool {
        var inside = false
        for ai in ring {
            let index = ai >= 0 ? ai : ~ai
            guard index < arcs.count else { continue }
            let a = arcs[index], n = a.count / 2
            if n < 2 { continue }
            for k in 0..<(n - 1) {
                let i = ai >= 0 ? k : n - 1 - k, j = ai >= 0 ? k + 1 : n - 2 - k
                let xi = Double(a[i * 2]), yi = Double(a[i * 2 + 1]), xj = Double(a[j * 2]), yj = Double(a[j * 2 + 1])
                if (yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi { inside.toggle() }
            }
        }
        return inside
    }
}
