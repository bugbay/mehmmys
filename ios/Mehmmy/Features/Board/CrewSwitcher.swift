import SwiftUI

struct CrewSwitcher: View {
    @Environment(AppState.self) private var state

    var body: some View {
        if state.crews.count > 1 {
            Menu {
                ForEach(state.crews) { c in
                    Button {
                        state.currentCrewID = c.id
                    } label: {
                        Label(c.name, systemImage: c.id == state.currentCrewID ? "checkmark" : (c.ownerID == state.me.id ? "person.crop.circle" : "car"))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(state.crew.name).font(Typo.display(13)).lineLimit(1)
                    Text(state.isOwner ? "YOURS" : "DRIVER")
                        .font(Typo.body(9, .heavy))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(state.isOwner ? Palette.yellow : Palette.sky))
                        .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 1.5))
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .heavy))
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .brutal(Palette.paper, radius: 20)
            }
            .accessibilityLabel("Switch crew, current \(state.crew.name)")
        }
    }
}
