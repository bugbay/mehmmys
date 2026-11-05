import SwiftUI

struct BoardView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let ranked = state.crew.drivers.sorted { ($0.mehmmys, $0.meters) > ($1.mehmmys, $1.meters) }
        Screen {
            VStack(alignment: .leading, spacing: 12) {
                CrewSwitcher()
                ScreenTitle(title: "Leaderboard", subtitle: "The whole crew, ranked by Mehmmys banked.")
            }
            if let top = ranked.first {
                HStack(spacing: 13) {
                    Avatar(emoji: top.emoji, color: top.color, size: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(top.name).font(Typo.display(20))
                        Text("\(top.mehmmys) \(plural(top.mehmmys)) banked · \(Distance.format(top.meters, unit: state.me.unit))")
                            .font(Typo.body(12, .bold)).foregroundStyle(Palette.forest)
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(top.mehmmys)").font(Typo.display(30)).monospacedDigit()
                        Text("MEHMMYS").font(Typo.body(9, .heavy)).tracking(0.4)
                    }
                }
                .padding(16)
                .brutal(Palette.green, radius: 18, shadow: 5)
                .overlay(alignment: .topTrailing) {
                    Text("TOP DRIVER 👑")
                        .font(Typo.body(11, .bold))
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .brutal(Palette.yellow, radius: 9, shadow: 0)
                        .rotationEffect(.degrees(4))
                        .offset(x: -16, y: -13)
                }
                .padding(.top, 22)
                .accessibilityElement(children: .combine)
            }
            VStack(spacing: 10) {
                ForEach(Array(ranked.dropFirst().enumerated()), id: \.element.id) { i, m in
                    HStack(spacing: 12) {
                        Text("\(i + 2)").font(Typo.display(16)).frame(width: 20)
                        Avatar(emoji: m.emoji, color: m.color, size: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(m.id == state.me.id ? "\(m.name) (you)" : m.name).font(Typo.body(15, .bold))
                            Text("\(m.rides) \(m.rides == 1 ? "ride" : "rides") · \(Distance.format(m.meters, unit: state.me.unit))")
                                .font(Typo.body(11)).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(m.mehmmys)").font(Typo.display(19)).monospacedDigit()
                            Text(plural(m.mehmmys)).font(Typo.body(10, .bold)).foregroundStyle(Palette.muted)
                        }
                    }
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .brutal()
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 14)
            if ranked.isEmpty {
                EmptyCard(icon: "🏁", title: "No drivers yet", subtitle: "Once friends join your crew and drive you around, they'll race up this board.") {
                    InviteButton()
                }
                .padding(.top, 20)
            }
        }
    }
}

func plural(_ n: Int) -> String { n == 1 ? "Mehmmy" : "Mehmmys" }
