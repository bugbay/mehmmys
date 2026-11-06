import SwiftUI

// horizontal avatar row of everyone the current manager can credit, plus an invite tile
struct DriverPicker: View {
    @Environment(AppState.self) private var state
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 13) {
                ForEach(state.rideCandidates) { d in
                    let sel = selection == d.id
                    Button { selection = d.id } label: {
                        VStack(spacing: 5) {
                            Avatar(emoji: d.emoji, color: d.color, size: 54, selected: sel)
                                .opacity(sel ? 1 : 0.85)
                            Text(d.name)
                                .font(Typo.body(12, sel ? .heavy : .semibold))
                                .foregroundStyle(sel ? Palette.ink : Palette.subtle)
                                .lineLimit(1)
                        }
                        .frame(width: 60)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(d.name)
                    .accessibilityAddTraits(sel ? .isSelected : [])
                }
                ShareLink(item: URL(string: "https://mehmmys.app/join/\(state.crew.inviteCode)")!) {
                    VStack(spacing: 5) {
                        Text("＋").font(.system(size: 26))
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(Palette.cream))
                            .overlay(Circle().strokeBorder(Palette.ink, style: StrokeStyle(lineWidth: 2.5, dash: [5, 3])))
                        Text("Invite").font(Typo.body(12)).foregroundStyle(Palette.subtle)
                    }
                    .frame(width: 60)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }
}
