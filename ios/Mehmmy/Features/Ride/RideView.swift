import SwiftUI

struct RideView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        if state.isManager {
            OwnerRideView()
        } else {
            DriverRequestsView()
        }
    }
}

private enum RideMode: String { case request, log, track, drive }

struct OwnerRideView: View {
    @Environment(AppState.self) private var state
    @State private var mode: RideMode = Launch.has("-log") ? .log : (Launch.has("-track") ? .track : .request)
    @State private var fromID: String?
    @State private var toID: String?
    @State private var when: RequestWhen = .now
    @State private var driverID: String? = Launch.has("-log") ? "leo" : nil
    @State private var meters: Int?
    @State private var addingPlace = false

    private var places: [Place] { state.crew.places }
    private var from: Place? { places.first { $0.id == fromID } ?? places.first }
    private var to: Place? { places.first { $0.id == toID } ?? places.dropFirst().first ?? places.first }
    private var same: Bool { from?.id == to?.id }

    var body: some View {
        Screen {
            if state.isOwner && (state.crew.drivers.isEmpty || places.count < 2) {
                SetupChecklist { addingPlace = true }.padding(.bottom, 18)
            }
            CrewSwitcher().padding(.bottom, 12)
            modeToggle
            switch mode {
            case .request: requestBody
            case .log: logBody
            case .track: TrackRideView(addingPlace: $addingPlace)
            case .drive: DriverRequestsList().padding(.top, 18)
            }
        }
        .sheet(isPresented: $addingPlace) { AddPlaceSheet() }
    }

    private var modeToggle: some View {
        HStack(spacing: 5) {
            segment("🔔 Request", .request)
            segment("📡 Track", .track)
            segment("✅ Log", .log)
            if !state.isOwner { segment("🚗 Drive", .drive) }
        }
        .padding(4)
        .brutal(Palette.paper, radius: 14, shadow: 3)
    }

    private func segment(_ title: String, _ value: RideMode) -> some View {
        let on = mode == value
        return Button {
            withAnimation(.snappy) { mode = value }
        } label: {
            Text(title)
                .font(Typo.display(14))
                .foregroundStyle(on ? Palette.cream : Palette.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(on ? Palette.ink : .clear))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: request

    private var requestBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenTitle(title: "Need a ride?", subtitle: "Ping the whole crew — first to claim it drives you. 🔔")
                .padding(.top, 18)
            routePickers.padding(.top, 16)
            FieldLabel(text: "WHEN").padding(.top, 14).padding(.bottom, 7)
            HStack(spacing: 8) {
                ForEach(RequestWhen.allCases) { w in
                    Button { when = w } label: { Chip(label: w.label, selected: when == w, color: Palette.yellow) }
                        .buttonStyle(.plain)
                }
            }
            VStack(spacing: 9) {
                RouteLine()
                HStack {
                    Text(from?.name ?? "—")
                    Spacer()
                    Text(to?.name ?? "—")
                }
                .font(Typo.body(13, .heavy))
            }
            .padding(16)
            .brutal(Palette.paper, radius: 18, shadow: 4)
            .padding(.top, 18)

            let n = state.rideCandidates.count
            let can = !same && n > 0
            Button {
                if let from, let to { state.sendRequest(from: from, to: to, when: when) }
            } label: {
                Text(same ? "Pick two different places" : (n == 0 ? "Add a friend first" : "🔔 Send to the crew · \(when.label)"))
            }
            .buttonStyle(BrutalButtonStyle(fill: Palette.coral, enabled: can))
            .disabled(!can)
            .padding(.top, 18)
            Text("\(n) \(n == 1 ? "driver" : "drivers") get a notification")
                .font(Typo.body(11))
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 9)
        }
    }

    // MARK: log

    private var logBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenTitle(title: "Log a ride", subtitle: "Caught a lift? Tag your driver — they bank a Mehmmy for it.")
                .padding(.top, 18)
            Eyebrow(text: "1 · Who drove?").padding(.top, 20).padding(.bottom, 10)
            DriverPicker(selection: $driverID)

            Eyebrow(text: "2 · Which route?").padding(.top, 18).padding(.bottom, 10)
            routePickers
            RouteMapCard(from: from, to: to, unit: state.me.unit, meters: $meters).padding(.top, 18)

            let driver = state.rideCandidates.first { $0.id == driverID }
            let can = driver != nil && !same && meters != nil
            Button {
                if let driver, let from, let to, let meters,
                   state.logRide(driverID: driver.id, from: from, to: to, meters: meters) {
                    driverID = nil
                }
            } label: {
                Text(driver == nil ? "Pick a driver first" : (same ? "Pick two different places" : (meters == nil ? "Measuring route…" : "Log ride · +1 for \(driver!.name)")))
            }
            .buttonStyle(BrutalButtonStyle(fill: Palette.green, enabled: can))
            .disabled(!can)
            .padding(.top, 18)
        }
    }

    private var routePickers: some View {
        VStack(alignment: .leading, spacing: 0) {
            FieldLabel(text: "FROM").padding(.bottom, 7)
            placeChips(selected: from?.id, color: Palette.green) { fromID = $0 }
            FieldLabel(text: "TO").padding(.top, 12).padding(.bottom, 7)
            placeChips(selected: to?.id, color: Palette.coral) { toID = $0 }
        }
    }

    private func placeChips(selected: String?, color: Color, pick: @escaping (String) -> Void) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(places) { p in
                Button { pick(p.id) } label: { Chip(label: p.name, selected: selected == p.id, color: color) }
                    .buttonStyle(.plain)
            }
            Button { addingPlace = true } label: { DashedChip(label: "＋ place") }
                .buttonStyle(.plain)
        }
    }
}

struct DriverRequestsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Screen {
            CrewSwitcher().padding(.bottom, 12)
            ScreenTitle(title: "Ride requests", subtitle: "\(state.crew.owner?.name ?? "Your friend") pings the crew here. First to claim it drives.")
            DriverRequestsList()
        }
    }
}

// open requests from others to claim, then the claimed history
struct DriverRequestsList: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let open = state.crew.requests.filter { $0.claimedBy == nil }
        let claimed = state.crew.requests.filter { $0.claimedBy != nil }
        VStack(alignment: .leading, spacing: 0) {
            if open.isEmpty {
                VStack(spacing: 8) {
                    Text("🛋️").font(.system(size: 40))
                    Text("No one needs a lift right now").font(Typo.display(17))
                    Text("You'll get a notification the moment they do.").font(Typo.body(12)).foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .brutal(Palette.paper, radius: 18, shadow: 3)
                .padding(.top, 18)
            }
            ForEach(open) { r in
                let who = state.crew.members.first { $0.id == r.byID } ?? state.crew.owner
                let mine = r.byID == state.me.id
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 11) {
                        Avatar(emoji: who?.emoji ?? "🙂", color: who?.color ?? Palette.sky, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mine ? "You asked for a ride" : "\(who?.name ?? "A friend") needs a ride").font(Typo.body(15, .bold))
                            Text(r.date, format: .relative(presentation: .named)).font(Typo.body(11)).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Text(r.when.label).font(Typo.display(13)).padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(Palette.yellow)).overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2))
                    }
                    RouteLine()
                    HStack { Text(r.fromName); Spacer(); Text(r.toName) }.font(Typo.body(13, .heavy))
                    if mine {
                        Text("Waiting for someone to claim it…").font(Typo.body(12, .bold)).foregroundStyle(Palette.muted)
                    } else {
                        Button { state.claim(requestID: r.id) } label: { Text("I've got you 🚗") }
                            .buttonStyle(BrutalButtonStyle(fill: Palette.green, shadow: 3))
                    }
                }
                .padding(16)
                .brutal(Palette.paper, radius: 18, shadow: 4)
                .padding(.top, 18)
            }
            if !claimed.isEmpty {
                Eyebrow(text: "Claimed").padding(.top, 24).padding(.bottom, 10)
                ForEach(claimed) { r in
                    let who = state.crew.members.first { $0.id == r.claimedBy }
                    HStack(spacing: 11) {
                        Avatar(emoji: who?.emoji ?? "🙂", color: who?.color ?? Palette.mint, size: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(who?.id == state.me.id ? "You" : (who?.name ?? "Someone")) got it").font(Typo.body(14, .bold))
                            Text("\(r.fromName) → \(r.toName) · \(r.when.label)").font(Typo.body(11)).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .brutal(Palette.paper, radius: 13)
                    .padding(.bottom, 9)
                }
            }
        }
    }
}

// wraps children onto new lines like css flex-wrap
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map { $0.width }.max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var items: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        var y: CGFloat = 0
        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            let needed = row.items.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width, !row.items.isEmpty {
                y += row.height + spacing
                rows.append(Row(items: [i], y: y, width: size.width, height: size.height))
                continue
            }
            row.items.append(i)
            row.width = needed
            row.height = max(row.height, size.height)
            row.y = y
            rows[rows.count - 1] = row
        }
        return rows
    }
}

// launch flags used by the screenshot script
enum Launch {
    static func has(_ flag: String) -> Bool { ProcessInfo.processInfo.arguments.contains(flag) }
}
