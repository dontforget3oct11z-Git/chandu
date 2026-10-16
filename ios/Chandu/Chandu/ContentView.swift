import SwiftUI

struct ContentView: View {
    @StateObject private var pedometer = PedometerService()
    @StateObject private var health = HealthService()
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshToken = 0

    var body: some View {
        GameWebView(steps: pedometer.stepsToday, day: pedometer.day, health: health.json, refreshToken: refreshToken)
            .background(Color(red: 0.953, green: 0.914, blue: 0.863))
            .ignoresSafeArea(edges: .bottom)
            .onAppear { pedometer.start(); health.refresh() }
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active:
                    pedometer.start()      // catch up on steps walked while the app was closed
                    health.refresh()       // and on the ヘルスケア numbers for the きろく screen
                    refreshToken += 1      // and pick up any game update
                case .background:
                    pedometer.stop()
                default:
                    break
                }
            }
    }
}
