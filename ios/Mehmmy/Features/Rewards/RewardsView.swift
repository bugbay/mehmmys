import SwiftUI

struct RewardsView: View {
    @Environment(AppState.self) private var state
    @State private var walletID: String?
    @State private var editing = false

    var body: some View {
        Screen {
            VStack(alignment: .leading, spacing: 12) {
                CrewSwitcher()
                ScreenTitle(title: "Rewards", subtitle: state.isOwner ? "What your drivers can cash their Mehmmys in for. 🎟️" : "Cash in the Mehmmys you've banked. 🎟️")
            }
            if state.isOwner && state.crew.drivers.isEmpty {
                EmptyCard(icon: "🎟️", title: "Set your rewards", subtitle: "These are what your drivers can cash their Mehmmys in for. Edit them now, invite drivers next.") {
                    InviteButton()
                }
                .padding(.top, 10)
            } else if state.isOwner { ownerHeader } else if let me = state.myMember { wallet(for: me, title: "Your wallet") }
            tiers
        }
        .sheet(isPresented: $editing) { TierEditor() }
    }

    private var selected: Member? {
        state.crew.drivers.first { $0.id == walletID } ?? state.crew.drivers.max { $0.mehmmys < $1.mehmmys }
    }

    @ViewBuilder private var ownerHeader: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 11) {
                ForEach(state.crew.drivers) { d in
                    let sel = selected?.id == d.id
                    Button { walletID = d.id } label: {
                        VStack(spacing: 5) {
                            Avatar(emoji: d.emoji, color: d.color, size: 46, selected: sel, glow: Palette.coral)
                            Text(d.name).font(Typo.body(11, sel ? .heavy : .semibold)).foregroundStyle(sel ? Palette.ink : Palette.subtle).lineLimit(1)
                        }
                        .frame(width: 54)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(d.name)
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .padding(.top, 10)
        if let selected { wallet(for: selected, title: "\(selected.name)'s wallet") }
    }

    private func wallet(for m: Member, title: String) -> some View {
        let next = state.crew.tiers.first { m.mehmmys < $0.cost }
        let goal = max(state.crew.tiers.map(\.cost).max() ?? 10, 1)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(Typo.display(17))
                Spacer()
                Text("\(m.mehmmys) \(plural(m.mehmmys)) to spend").font(Typo.body(12, .bold))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8).fill(Palette.cream)
                    Rectangle().fill(Palette.green)
                        .frame(width: geo.size.width * min(Double(m.mehmmys) / Double(goal), 1))
                        .overlay(alignment: .trailing) { Rectangle().fill(Palette.ink).frame(width: m.mehmmys > 0 && m.mehmmys < goal ? 2.5 : 0) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.ink, lineWidth: Metrics.border))
            }
            .frame(height: 15)
            .padding(.top, 12)
            Text(next.map { "\($0.cost - m.mehmmys) more \(plural($0.cost - m.mehmmys)) → \($0.title)" } ?? "Every tier unlocked! 🏅")
                .font(Typo.body(11, .bold)).padding(.top, 8)
        }
        .padding(16)
        .brutal(Palette.coral, radius: 18, shadow: 5)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    private var tiers: some View {
        VStack(spacing: 11) {
            if state.isManager {
                HStack {
                    Eyebrow(text: "Reward tiers")
                    Spacer()
                    Button("Edit") { editing = true }.buttonStyle(PillButtonStyle(fill: Palette.yellow))
                }
                .padding(.top, 6)
            }
            ForEach(state.crew.tiers) { t in
                let bal = state.isOwner ? (selected?.mehmmys ?? 0) : (state.myMember?.mehmmys ?? 0)
                let ok = bal >= t.cost
                HStack(spacing: 12) {
                    IconTile(icon: t.icon)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.title).font(Typo.body(14, .bold))
                        Text(t.subtitle).font(Typo.body(11)).foregroundStyle(Palette.subtle)
                        Text(ok ? "READY · \(t.cost) MEHMMYS" : "\(t.cost - bal) MORE TO UNLOCK")
                            .font(Typo.body(10, .heavy)).tracking(0.3)
                            .foregroundStyle(ok ? Palette.deepGreen : Palette.muted)
                            .padding(.top, 1)
                    }
                    Spacer(minLength: 4)
                    if state.isOwner {
                        Text("\(t.cost)").font(Typo.display(20)).monospacedDigit()
                    } else {
                        Button(ok ? "Redeem" : "Locked") { state.redeem(tier: t) }
                            .buttonStyle(BrutalButtonStyle(fill: Palette.green, radius: 11, shadow: 2, enabled: ok))
                            .frame(width: 92)
                            .disabled(!ok)
                    }
                }
                .padding(.horizontal, 13).padding(.vertical, 12)
                .brutal(ok ? Palette.paper : Palette.locked, radius: 15, shadow: 3)
            }
        }
        .padding(.top, 16)
    }
}
