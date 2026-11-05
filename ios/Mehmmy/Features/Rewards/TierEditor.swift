import SwiftUI

struct TierEditor: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var tiers: [RewardTier] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($tiers) { $t in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                TextField("", text: $t.icon).font(.system(size: 22)).frame(width: 44, height: 44)
                                    .multilineTextAlignment(.center)
                                    .background(RoundedRectangle(cornerRadius: 11).fill(Palette.cream))
                                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Palette.ink, lineWidth: 2))
                                BrutalField(placeholder: "Reward", text: $t.title)
                            }
                            BrutalField(placeholder: "Details", text: $t.subtitle)
                            Stepper(value: $t.cost, in: 1...50) {
                                Text("Costs \(t.cost) \(plural(t.cost))").font(Typo.body(14, .bold))
                            }
                        }
                        .padding(13)
                        .brutal(Palette.paper, radius: 15, shadow: 3)
                    }
                    Button("＋ Add a reward") {
                        tiers.append(RewardTier(id: UUID().uuidString, cost: (tiers.map(\.cost).max() ?? 0) + 2, icon: "🎁", title: "", subtitle: ""))
                    }
                    .buttonStyle(BrutalButtonStyle(fill: Palette.yellow, shadow: 3))
                    .disabled(tiers.count >= 10)
                }
                .padding(Metrics.gutter)
            }
            .background(Palette.cream)
            .navigationTitle("Reward tiers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        state.updateTiers(tiers.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty })
                        dismiss()
                    }
                    .fontWeight(.heavy)
                }
            }
        }
        .onAppear { tiers = state.crew.tiers }
    }
}
