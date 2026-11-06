import SwiftUI
import CoreLocation

// gps mode: start when you get in, finish when you get out, the real distance is logged
struct TrackRideView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openURL) private var openURL
    @Binding var addingPlace: Bool
    @State private var driverID: String?
    @State private var fromName = ""
    @State private var toName = ""
    @State private var fromPlace: Place?
    @State private var toPlace: Place?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenTitle(title: "Track a ride", subtitle: "Tap start when you get in. GPS measures the real distance — lock your phone, it keeps going. 📡")
                .padding(.top, 18)
            Eyebrow(text: "Who's driving?").padding(.top, 20).padding(.bottom, 10)
            DriverPicker(selection: $driverID)
            switch tracker.status {
            case .idle: idle
            case .waitingForPermission: note("📍", "Allow location", "Choose “Allow While Using App” so Mehmmy can measure the ride.")
            case .denied: denied
            case .tracking: live
            case .finished: summary
            }
        }
    }

    // lives on app state so a ride survives switching tabs
    private var tracker: RideTracker { state.tracker }

    private var driver: Member? { state.rideCandidates.first { $0.id == driverID } }

    private var idle: some View {
        Button { tracker.start() } label: { Text("▶️ Start tracking") }
            .buttonStyle(BrutalButtonStyle(fill: Palette.green))
            .padding(.top, 22)
            .accessibilityHint("Starts measuring the ride with GPS")
    }

    private var denied: some View {
        VStack(alignment: .leading, spacing: 12) {
            note("🚫", "Location is off for Mehmmy", "Turn it on in Settings to track rides, or use Log to pick saved places.")
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(PillButtonStyle(fill: Palette.yellow))
        }
    }

    private var live: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ON THE ROAD").font(Typo.body(10, .heavy)).tracking(0.5)
                Text(Distance.format(tracker.meters, unit: state.me.unit))
                    .font(Typo.display(44)).monospacedDigit().contentTransition(.numericText())
                    .accessibilityLabel("Distance so far \(Distance.format(tracker.meters, unit: state.me.unit))")
                if let started = tracker.startedAt {
                    TimelineView(.periodic(from: started, by: 1)) { ctx in
                        Text(Duration.seconds(ctx.date.timeIntervalSince(started)).formatted(.time(pattern: .minuteSecond)))
                            .font(Typo.body(14, .bold)).monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .brutal(Palette.mint, radius: 20, shadow: 5)
            Button {
                tracker.finish()
                Task { await resolveEnds() }
            } label: { Text("■ Finish ride") }
                .buttonStyle(BrutalButtonStyle(fill: Palette.coral))
        }
        .padding(.top, 20)
        .animation(.snappy, value: tracker.meters)
    }

    private var summary: some View {
        let can = driver != nil && tracker.meters > 0
        return VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 9) {
                RouteLine()
                HStack { Text(fromName.isEmpty ? "…" : fromName); Spacer(); Text(toName.isEmpty ? "…" : toName) }
                    .font(Typo.body(13, .heavy))
                Text(Distance.format(tracker.meters, unit: state.me.unit)).font(Typo.display(28)).monospacedDigit()
            }
            .padding(16)
            .brutal(Palette.paper, radius: 18, shadow: 4)
            if tracker.meters == 0 {
                Text("No distance recorded — the ride was too short or GPS was weak.").font(Typo.body(12, .bold)).foregroundStyle(Palette.burnt)
            }
            Button { log() } label: {
                Text(driver == nil ? "Pick who drove" : "Log ride · +1 for \(driver!.name)")
            }
            .buttonStyle(BrutalButtonStyle(fill: Palette.green, enabled: can))
            .disabled(!can)
            Button("Discard") { tracker.reset() }
                .buttonStyle(PillButtonStyle(fill: Palette.paper))
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 20)
    }

    private func note(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text(icon).font(.system(size: 24))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Typo.body(14, .bold))
                Text(body).font(Typo.body(12)).foregroundStyle(Palette.subtle)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .brutal(Palette.paper, radius: 15, shadow: 3)
        .padding(.top, 20)
    }

    // saved place within 300 m, otherwise the street name, otherwise a generic label
    private func resolveEnds() async {
        let places = state.crew.places
        fromPlace = tracker.acc.start.flatMap { TrackAccumulator.nearestPlace(to: $0, in: places) }
        toPlace = tracker.acc.end.flatMap { TrackAccumulator.nearestPlace(to: $0, in: places) }
        fromName = fromPlace?.name ?? "Pickup"
        toName = toPlace?.name ?? "Drop-off"
        if fromPlace == nil, let start = tracker.acc.start, let name = await streetName(start) { fromName = name }
        if toPlace == nil, let end = tracker.acc.end, let name = await streetName(end) { toName = name }
    }

    private func streetName(_ loc: CLLocation) async -> String? {
        let mark = try? await CLGeocoder().reverseGeocodeLocation(loc).first
        return (mark?.name ?? mark?.thoroughfare).map { String($0.prefix(40)) }
    }

    private func log() {
        guard let driver else { return }
        let from = fromPlace ?? Place(id: "gps-start", name: fromName, lat: tracker.acc.start?.coordinate.latitude ?? 0, lng: tracker.acc.start?.coordinate.longitude ?? 0)
        let to = toPlace ?? Place(id: "gps-end", name: toName, lat: tracker.acc.end?.coordinate.latitude ?? 0, lng: tracker.acc.end?.coordinate.longitude ?? 0)
        if state.logRide(driverID: driver.id, from: from, to: to, meters: tracker.meters, tracked: true) {
            tracker.reset()
            driverID = nil
        }
    }
}
