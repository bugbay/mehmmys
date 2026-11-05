import SwiftUI

struct MeView: View {
    @Environment(AppState.self) private var state
    @State private var addingPlace = false
    @State private var confirmDelete = false
    @State private var joinCode = ""
    @State private var joining = false

    var body: some View {
        @Bindable var state = state
        Screen {
            profileCard
            statsGrid.padding(.top, 16)
            alertsCard.padding(.top, 16)
            crewsSection.padding(.top, 22)
            if state.isOwner {
                membersSection.padding(.top, 22)
                placesSection.padding(.top, 22)
            }
            settings(unit: $state.me.unit).padding(.top, 22)
        }
        .sheet(isPresented: $addingPlace) { AddPlaceSheet() }
        .alert("Join a crew", isPresented: $joining) {
            TextField("Invite code", text: $joinCode).textInputAutocapitalization(.characters)
            Button("Join") { state.show(Toast(emoji: "🤝", title: "Joined!", subtitle: "Preview only — joining goes live with the backend")) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account and my crew", role: .destructive) { state.onboarded = false }
        } message: {
            Text("This removes your profile, your crew and everyone's Mehmmys in it. It can't be undone.")
        }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            Avatar(emoji: state.me.emoji, color: Palette.cream, size: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text(state.me.name).font(Typo.display(22))
                Text(state.isOwner ? "That's you — the one who needs the rides 😄" : "You drive for \(state.crew.owner?.name ?? "this crew") 🚗")
                    .font(Typo.body(12)).foregroundStyle(Palette.navy)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .brutal(Palette.sky, radius: 20, shadow: 5)
    }

    private var statsGrid: some View {
        let c = state.crew
        let stats: [(String, String, String, Color)] = state.isOwner ? [
            ("🚗", "\(c.drivers.reduce(0) { $0 + $1.rides })", "Rides taken", Palette.mint),
            ("⭐", "\(c.drivers.reduce(0) { $0 + $1.mehmmys })", "Mehmmys owed", Palette.yellow),
            ("📍", Distance.format(c.drivers.reduce(0) { $0 + $1.meters }, unit: state.me.unit), "Driven for you", Palette.sky),
            (c.drivers.max { $0.rides < $1.rides }?.emoji ?? "🙂", c.drivers.max { $0.rides < $1.rides }?.name ?? "—", "Top driver", Palette.rose),
        ] : [
            ("🚗", "\(state.myMember?.rides ?? 0)", "Rides given", Palette.mint),
            ("⭐", "\(state.myMember?.mehmmys ?? 0)", "Mehmmys banked", Palette.yellow),
            ("📍", Distance.format(state.myMember?.meters ?? 0, unit: state.me.unit), "Driven", Palette.sky),
            ("🏆", "#\((c.drivers.sorted { $0.mehmmys > $1.mehmmys }.firstIndex { $0.id == state.me.id } ?? 0) + 1)", "On the board", Palette.rose),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(stats, id: \.2) { s in
                VStack(alignment: .leading, spacing: 0) {
                    IconTile(icon: s.0, fill: s.3, size: 34)
                    Text(s.1).font(Typo.display(22)).lineLimit(1).minimumScaleFactor(0.6).padding(.top, 10)
                    Text(s.2).font(Typo.body(11, .bold)).foregroundStyle(Palette.muted).padding(.top, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .brutal(Palette.paper, radius: 15, shadow: 3)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var alertsCard: some View {
        HStack(spacing: 11) {
            Text("🔔").font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text("Ride alerts are on").font(Typo.body(13, .bold))
                Text(state.isOwner ? "You'll hear when someone claims your ride or redeems." : "You'll get pinged the moment a ride is requested.")
                    .font(Typo.body(11)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            Text("✓").font(.system(size: 14, weight: .heavy)).frame(width: 26, height: 26)
                .background(Circle().fill(Palette.green)).overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .brutal(Palette.paper, radius: 15, shadow: 3)
    }

    private var crewsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow(text: "Your crews · \(state.crews.count)")
                Spacer()
                Button("Join with code") { joinCode = ""; joining = true }.buttonStyle(PillButtonStyle(fill: Palette.paper))
            }
            ForEach(state.crews) { c in
                let mine = c.ownerID == state.me.id
                let current = c.id == state.currentCrewID
                Button { state.currentCrewID = c.id } label: {
                    HStack(spacing: 11) {
                        Avatar(emoji: c.owner?.emoji ?? "🙂", color: c.owner?.color ?? Palette.sky, size: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.name).font(Typo.body(14, .bold))
                            Text(mine ? "You're the rider · \(c.drivers.count) drivers" : "You drive · \(c.members.first { $0.id == state.me.id }?.mehmmys ?? 0) Mehmmys banked")
                                .font(Typo.body(11)).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        if current { Text("✓").font(.system(size: 14, weight: .heavy)) }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .brutal(current ? Palette.cream : Palette.paper, radius: 13)
                }
                .buttonStyle(.plain)
            }
            if let owned = state.ownedCrew {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("INVITE CODE").font(Typo.body(10, .heavy)).tracking(0.4)
                        Text(owned.inviteCode).font(Typo.display(26)).tracking(3)
                    }
                    Spacer()
                    ShareLink(item: URL(string: "https://mehmmys.app/join/\(owned.inviteCode)")!,
                              message: Text("Drive me around and earn Mehmmys 🚗 Join my crew:")) {
                        Text("Share")
                    }
                    .buttonStyle(PillButtonStyle(fill: Palette.green))
                }
                .padding(14)
                .brutal(Palette.yellow, radius: 15, shadow: 3)
            }
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: "Drivers · \(state.crew.drivers.count)")
            ForEach(state.crew.drivers) { m in
                HStack(spacing: 11) {
                    Avatar(emoji: m.emoji, color: m.color, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(m.name).font(Typo.body(14, .bold))
                        Text("\(m.mehmmys) \(plural(m.mehmmys)) · \(m.rides) \(m.rides == 1 ? "ride" : "rides")").font(Typo.body(11)).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Menu {
                        Button("Remove from crew", role: .destructive) { state.removeMember(id: m.id) }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 14, weight: .heavy)).foregroundStyle(Palette.ink)
                            .frame(width: 30, height: 30)
                    }
                    .accessibilityLabel("Options for \(m.name)")
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .brutal(Palette.paper, radius: 13)
            }
            let banked = state.crew.drivers.reduce(0) { $0 + $1.mehmmys }
            HStack(spacing: 11) {
                Text("💛").font(.system(size: 24))
                Text("\(banked) \(plural(banked)) banked across the crew, waiting to be spent.").font(Typo.body(13, .bold))
            }
            .padding(14)
            .brutal(Palette.yellow, radius: 15, shadow: 3)
            .padding(.top, 6)
        }
    }

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Saved places · \(state.crew.places.count)")
            FlowLayout(spacing: 8) {
                ForEach(state.crew.places) { p in
                    Menu {
                        Button("Remove \(p.name)", role: .destructive) { state.removePlace(id: p.id) }
                    } label: {
                        Chip(label: "📍 \(p.name)", selected: true, color: Palette.paper)
                    }
                }
                Button { addingPlace = true } label: { DashedChip(label: "＋ place") }.buttonStyle(.plain)
            }
        }
    }

    private func settings(unit: Binding<DistanceUnit>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Settings")
            VStack(spacing: 0) {
                HStack {
                    Text("Distance").font(Typo.body(14, .bold))
                    Spacer()
                    Picker("Distance", selection: unit) {
                        ForEach(DistanceUnit.allCases) { Text($0.label).tag($0) }
                    }
                    .tint(Palette.subtle)
                }
                .padding(.horizontal, 13).padding(.vertical, 6)
                Divider().overlay(Palette.locked)
                if !state.isOwner {
                    Button(role: .destructive) { state.leaveCurrentCrew() } label: {
                        Text("Leave \(state.crew.name)").font(Typo.body(14, .bold)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 13).padding(.vertical, 13)
                    Divider().overlay(Palette.locked)
                }
                Button { state.onboarded = false } label: {
                    Text("Sign out").font(Typo.body(14, .bold)).foregroundStyle(Palette.ink).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 13).padding(.vertical, 13)
                Divider().overlay(Palette.locked)
                Button(role: .destructive) { confirmDelete = true } label: {
                    Text("Delete account").font(Typo.body(14, .bold)).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 13).padding(.vertical, 13)
            }
            .brutal(Palette.paper, radius: 15, shadow: 3)
            Text("Mehmmy 1.0 · preview build").font(Typo.body(10)).foregroundStyle(Palette.faint).frame(maxWidth: .infinity).padding(.top, 8)
        }
    }
}
