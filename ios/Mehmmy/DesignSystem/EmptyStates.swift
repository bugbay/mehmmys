import SwiftUI

struct EmptyCard<Action: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: 8) {
            Text(icon).font(.system(size: 40))
            Text(title).font(Typo.display(18)).multilineTextAlignment(.center)
            Text(subtitle).font(Typo.body(12)).foregroundStyle(Palette.subtle).multilineTextAlignment(.center)
            action.padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .brutal(Palette.paper, radius: 18, shadow: 3)
    }
}

extension EmptyCard where Action == EmptyView {
    init(icon: String, title: String, subtitle: String) {
        self.init(icon: icon, title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct InviteButton: View {
    @Environment(AppState.self) private var state
    var label = "Share invite link"

    var body: some View {
        if let crew = state.ownedCrew, let url = URL(string: "https://mehmmys.app/join/\(crew.inviteCode)") {
            ShareLink(item: url, message: Text("Drive me around and earn Mehmmys 🚗 Join my crew with code \(crew.inviteCode):")) {
                Text("\(label) · \(crew.inviteCode)")
            }
            .buttonStyle(PillButtonStyle(fill: Palette.green))
        }
    }
}

// first-run checklist for a brand-new crew owner
struct SetupChecklist: View {
    @Environment(AppState.self) private var state
    var onAddPlace: () -> Void

    var body: some View {
        let places = state.crew.places.count
        let drivers = state.crew.drivers.count
        VStack(alignment: .leading, spacing: 12) {
            Text("Let's set up your crew").font(Typo.display(18))
            row(done: places >= 2, title: "Save two places", detail: places >= 2 ? "\(places) saved" : "Home, work, the gym… (\(places)/2)") {
                Button("＋ Add place", action: onAddPlace).buttonStyle(PillButtonStyle(fill: Palette.yellow))
            }
            row(done: drivers > 0, title: "Invite the friends who drive you", detail: drivers > 0 ? "\(drivers) joined" : "They join with your code") {
                InviteButton(label: "Invite")
            }
        }
        .padding(16)
        .brutal(Palette.peach, radius: 18, shadow: 4)
    }

    private func row<A: View>(done: Bool, title: String, detail: String, @ViewBuilder action: () -> A) -> some View {
        HStack(spacing: 10) {
            Text(done ? "✓" : "")
                .font(.system(size: 13, weight: .heavy))
                .frame(width: 24, height: 24)
                .background(Circle().fill(done ? Palette.green : Palette.paper))
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Typo.body(13, .bold)).strikethrough(done)
                Text(detail).font(Typo.body(11)).foregroundStyle(Palette.subtle)
            }
            Spacer(minLength: 4)
            if !done { action() }
        }
    }
}
