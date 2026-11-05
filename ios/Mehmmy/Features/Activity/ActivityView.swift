import SwiftUI

struct ActivityView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Screen {
            VStack(alignment: .leading, spacing: 12) {
                CrewSwitcher()
                ScreenTitle(title: "Activity", subtitle: "Every ride, request and reward in the crew.")
            }
            if state.crew.activity.isEmpty {
                EmptyCard(icon: "🧾", title: "Nothing here yet", subtitle: "Rides, requests and rewards will show up here as they happen.")
                    .padding(.top, 16)
            }
            VStack(spacing: 10) {
                ForEach(state.crew.activity) { item in
                    ActivityRow(row: describe(item.kind), date: item.date)
                }
            }
            .padding(.top, 16)
        }
    }

    private struct Row {
        var icon: String
        var tint: Color
        var title: String
        var subtitle: String
        var meta: String
        var metaColor: Color
    }

    private func describe(_ kind: ActivityKind) -> Row {
        let owner = state.crew.owner?.name ?? "Your friend"
        let you = { (name: String) in name == state.me.name ? "You" : name }
        switch kind {
        case let .ride(driver, from, to, meters):
            let title = state.isOwner ? "\(driver) drove you" : "\(you(driver)) drove \(owner)"
            return Row(icon: "🚗", tint: Palette.mint, title: title, subtitle: "\(from) → \(to) · \(Distance.format(meters, unit: state.me.unit))", meta: "+1", metaColor: Palette.deepGreen)
        case let .request(from, to, when):
            let title = state.isOwner ? "You asked for a ride" : "\(owner) needs a ride"
            return Row(icon: "🔔", tint: Palette.peach, title: title, subtitle: "\(from) → \(to)", meta: when.label, metaColor: Palette.burnt)
        case let .claim(driver, from, to):
            return Row(icon: "🤝", tint: Palette.sky, title: "\(you(driver)) got it", subtitle: "\(from) → \(to)", meta: "", metaColor: Palette.ink)
        case let .redeem(driver, title, cost):
            return Row(icon: "🎁", tint: Palette.rose, title: "\(you(driver)) cashed in", subtitle: title, meta: "−\(cost)", metaColor: Palette.burnt)
        }
    }

    private struct ActivityRow: View {
        let row: Row
        let date: Date

        var body: some View {
            HStack(spacing: 12) {
                IconTile(icon: row.icon, fill: row.tint, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title).font(Typo.body(14, .bold))
                    Text(row.subtitle).font(Typo.body(11)).foregroundStyle(Palette.muted).lineLimit(1)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 2) {
                    if !row.meta.isEmpty {
                        Text(row.meta).font(Typo.display(14)).foregroundStyle(row.metaColor)
                    }
                    Text(date, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
                        .font(Typo.body(10)).foregroundStyle(Palette.faint)
                }
            }
            .padding(.horizontal, 13).padding(.vertical, 11)
            .brutal()
            .accessibilityElement(children: .combine)
        }
    }
}
