import SwiftUI

@main
struct MehmmyApp: App {
    @State private var state = AppState.sample(onboarded: !ProcessInfo.processInfo.arguments.contains("-onboarding"))

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .onAppear { applyLaunchArguments() }
        }
    }

    // screenshot automation: -tab <name> -crew driver
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let tab = Tab(rawValue: args[i + 1]) {
            state.tab = tab
        }
        if args.contains("-driver") { state.currentCrewID = AppState.sampleDriverCrewID }
    }
}
