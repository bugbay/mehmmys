import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct MehmmyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var state: AppState

    init() {
        let sample = Launch.has("-sample")
        if sample {
            _state = State(initialValue: Launch.has("-fresh") ? AppState.freshSample() : AppState.sample(onboarded: !Launch.has("-onboarding")))
        } else {
            FirebaseApp.configure()
            let state = AppState(me: UserProfile(id: "", name: "", emoji: "🙋", color: Palette.sky), crews: [], currentCrewID: "", phase: .loading)
            _state = State(initialValue: state)
            Backend.state = state
            Backend.shared = FirebaseBackend(state: state)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .onAppear { applyLaunchArguments() }
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
        }
    }

    // screenshot automation: -sample -tab <name> -driver
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let tab = Tab(rawValue: args[i + 1]) {
            state.tab = tab
        }
        if args.contains("-driver") { state.currentCrewID = AppState.sampleDriverCrewID }
    }
}
