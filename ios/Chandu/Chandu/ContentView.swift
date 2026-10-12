import SwiftUI

struct ContentView: View {
    @StateObject private var pedometer = PedometerService()
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshToken = 0

    var body: some View {
        GameWebView(steps: pedometer.stepsToday, refreshToken: refreshToken)
            .background(Color(red: 0.953, green: 0.914, blue: 0.863))
            .ignoresSafeArea(edges: .bottom)
            .onAppear { pedometer.start() }
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active:
                    pedometer.start()      // catch up on steps walked while the app was closed
                    refreshToken += 1      // and pick up any game update
                case .background:
                    pedometer.stop()
                default:
                    break
                }
            }
    }
}
