import SwiftUI
import Observation

// in-memory app state with sample data; firebase repositories replace this in phase 2
@MainActor
@Observable
final class AppState {
    static let sampleOwnedCrewID = "crew-mehmed"
    static let sampleDriverCrewID = "crew-bugrahan"

    var me: UserProfile
    var crews: [Crew]
    var currentCrewID: String
    var tab: Tab = .ride
    var toast: Toast?
    var phase: AppPhase
    var suggestedName = ""
    var busy = false
    weak var remote: RemoteActions?

    init(me: UserProfile, crews: [Crew], currentCrewID: String, phase: AppPhase = .ready) {
        self.me = me
        self.crews = crews
        self.currentCrewID = currentCrewID
        self.phase = phase
    }

    var isSample: Bool { remote == nil }

    // MARK: derived

    private var crewIndex: Int { crews.firstIndex { $0.id == currentCrewID } ?? 0 }
    var crew: Crew { crews.isEmpty ? Crew.empty : crews[crewIndex] }
    var isOwner: Bool { crew.ownerID == me.id }
    var myMember: Member? { crew.members.first { $0.id == me.id } }
    var ownedCrew: Crew? { crews.first { $0.ownerID == me.id } }

    func unitLabel() -> String { Distance.unitLabel(me.unit) }

    // MARK: owner actions

    @discardableResult
    func logRide(driverID: String, from: Place, to: Place, meters: Int) -> Bool {
        guard isOwner, from.id != to.id, meters > 0,
              let i = crew.members.firstIndex(where: { $0.id == driverID && $0.role == .driver }) else { return false }
        if let remote {
            let driver = crew.members[i]
            remote.logRide(crewID: crew.id, driverID: driverID, from: from, to: to, meters: meters)
            remote.requestPushPermission()
            show(Toast(emoji: driver.emoji, title: "+1 Mehmmy!", subtitle: "\(driver.name) banked one · \(Distance.format(meters, unit: me.unit)) \(from.name) → \(to.name)"))
            return true
        }
        var c = crew
        c.members[i].mehmmys += 1
        c.members[i].meters += meters
        c.members[i].rides += 1
        let driver = c.members[i]
        c.activity.insert(ActivityItem(id: UUID().uuidString, kind: .ride(driver: driver.name, from: from.name, to: to.name, meters: meters), date: .now), at: 0)
        crews[crewIndex] = c
        show(Toast(emoji: driver.emoji, title: "+1 Mehmmy!", subtitle: "\(driver.name) banked one · \(Distance.format(meters, unit: me.unit)) \(from.name) → \(to.name)"))
        return true
    }

    @discardableResult
    func sendRequest(from: Place, to: Place, when: RequestWhen) -> Bool {
        guard isOwner, from.id != to.id, !crew.drivers.isEmpty else { return false }
        if let remote {
            remote.sendRequest(crewID: crew.id, from: from, to: to, when: when)
            remote.requestPushPermission()
            show(Toast(emoji: "🔔", title: "Request sent!", subtitle: "Crew pinged · \(from.name) → \(to.name) · \(when.label)"))
            return true
        }
        var c = crew
        c.requests.insert(RideRequest(id: UUID().uuidString, fromName: from.name, toName: to.name, when: when, date: .now), at: 0)
        c.activity.insert(ActivityItem(id: UUID().uuidString, kind: .request(from: from.name, to: to.name, when: when), date: .now), at: 0)
        crews[crewIndex] = c
        show(Toast(emoji: "🔔", title: "Request sent!", subtitle: "Crew pinged · \(from.name) → \(to.name) · \(when.label)"))
        return true
    }

    @discardableResult
    func addPlace(name: String, lat: Double, lng: Double) -> Place? {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard isOwner, !trimmed.isEmpty else { return nil }
        let place = Place(id: UUID().uuidString, name: trimmed, lat: lat, lng: lng)
        if let remote {
            remote.addPlace(crewID: crew.id, place: place)
        } else {
            crews[crewIndex].places.append(place)
        }
        show(Toast(emoji: "📍", title: "\(trimmed) saved", subtitle: "Real distances now mapped"))
        return place
    }

    func removePlace(id: String) {
        guard isOwner else { return }
        if let remote { remote.removePlace(crewID: crew.id, placeID: id); return }
        crews[crewIndex].places.removeAll { $0.id == id }
    }

    func removeMember(id: String) {
        guard isOwner, id != me.id else { return }
        if let remote { remote.removeMember(crewID: crew.id, memberID: id); return }
        crews[crewIndex].members.removeAll { $0.id == id }
    }

    func updateTiers(_ tiers: [RewardTier]) {
        guard isOwner else { return }
        let sorted = tiers.sorted { $0.cost < $1.cost }
        if let remote { remote.updateTiers(crewID: crew.id, tiers: sorted); return }
        crews[crewIndex].tiers = sorted
    }

    // MARK: driver actions

    @discardableResult
    func claim(requestID: String) -> Bool {
        guard !isOwner, let i = crew.requests.firstIndex(where: { $0.id == requestID }),
              crew.requests[i].claimedBy == nil else { return false }
        if let remote {
            remote.claim(crewID: crew.id, requestID: requestID)
            show(Toast(emoji: "🚗", title: "You've got it!", subtitle: "\(crew.owner?.name ?? "Your friend") knows you're coming"))
            return true
        }
        var c = crew
        c.requests[i].claimedBy = me.id
        let r = c.requests[i]
        c.activity.insert(ActivityItem(id: UUID().uuidString, kind: .claim(driver: me.name, from: r.fromName, to: r.toName), date: .now), at: 0)
        crews[crewIndex] = c
        show(Toast(emoji: "🚗", title: "You've got it!", subtitle: "\(c.owner?.name ?? "Your friend") knows you're coming"))
        return true
    }

    @discardableResult
    func redeem(tier: RewardTier) -> Bool {
        guard !isOwner, let i = crew.members.firstIndex(where: { $0.id == me.id }),
              crew.members[i].mehmmys >= tier.cost else { return false }
        if let remote {
            remote.redeem(crewID: crew.id, tier: tier)
            show(Toast(emoji: "🎉", title: "Redeemed!", subtitle: "\(tier.title) (−\(tier.cost)) · \(crew.owner?.name ?? "Your friend") was notified"))
            return true
        }
        var c = crew
        c.members[i].mehmmys -= tier.cost
        c.activity.insert(ActivityItem(id: UUID().uuidString, kind: .redeem(driver: me.name, title: tier.title, cost: tier.cost), date: .now), at: 0)
        crews[crewIndex] = c
        show(Toast(emoji: "🎉", title: "Redeemed!", subtitle: "\(tier.title) (−\(tier.cost)) · \(c.owner?.name ?? "Your friend") was notified"))
        return true
    }

    func leaveCurrentCrew() {
        guard !isOwner, !crews.isEmpty else { return }
        if let remote { remote.leaveCrew(crewID: crew.id); return }
        crews.remove(at: crewIndex)
        currentCrewID = crews.first?.id ?? ""
    }

    func show(_ toast: Toast) {
        self.toast = toast
        let id = toast.id
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            if self?.toast?.id == id { self?.toast = nil }
        }
    }
}

// MARK: sample data

extension AppState {
    static func sample(onboarded: Bool = true) -> AppState {
        let state = makeSample()
        state.phase = onboarded ? .ready : .signedOut
        return state
    }

    // a brand-new rider who just created a crew: no places, no drivers, default rewards
    static func freshSample() -> AppState {
        let me = UserProfile(id: "me", name: "Ozzy", emoji: "🦊", color: Palette.sky)
        let crew = Crew(
            id: sampleOwnedCrewID, name: "Ozzy's crew", ownerID: me.id, inviteCode: "OZY4KQ",
            members: [Member(id: me.id, name: me.name, emoji: me.emoji, color: me.color, role: .owner)],
            places: [], tiers: RewardTier.defaults, requests: [], activity: []
        )
        return AppState(me: me, crews: [crew], currentCrewID: crew.id)
    }

    private static func makeSample() -> AppState {
        let me = UserProfile(id: "me", name: "Mehmed", emoji: "🙋", color: Palette.sky)
        let ago = { (h: Double) in Date.now.addingTimeInterval(-h * 3600) }

        let home = Place(id: "home", name: "Home", lat: 40.7270, lng: -74.3174)
        let work = Place(id: "work", name: "Work", lat: 40.7818, lng: -74.2691)
        let ewr = Place(id: "ewr", name: "EWR", lat: 40.6895, lng: -74.1745)
        let gym = Place(id: "gym", name: "Gym", lat: 40.7420, lng: -74.3000)

        let owned = Crew(
            id: sampleOwnedCrewID,
            name: "Mehmed's crew",
            ownerID: me.id,
            inviteCode: "MHM23K",
            members: [
                Member(id: me.id, name: me.name, emoji: me.emoji, color: me.color, role: .owner),
                Member(id: "amanda", name: "Amanda", emoji: "🐢", color: Color(hex: 0xFDBA74), role: .driver, mehmmys: 2, meters: 17200, rides: 2),
                Member(id: "shannon", name: "Shannon", emoji: "🦄", color: Color(hex: 0xC4B5FD), role: .driver, mehmmys: 6, meters: 52400, rides: 7),
                Member(id: "leighann", name: "LeighAnn", emoji: "🐯", color: Color(hex: 0xF9A8D4), role: .driver, mehmmys: 1, meters: 8851, rides: 1),
                Member(id: "leo", name: "Leo", emoji: "🐶", color: Color(hex: 0x7DD3FC), role: .driver, mehmmys: 4, meters: 34120, rides: 4),
                Member(id: "deanna", name: "Deanna", emoji: "🦋", color: Color(hex: 0xFCD34D), role: .driver, mehmmys: 0, meters: 0, rides: 0),
                Member(id: "manan", name: "Manan", emoji: "🐳", color: Color(hex: 0x86EFAC), role: .driver, mehmmys: 3, meters: 25600, rides: 3),
            ],
            places: [home, work, ewr, gym],
            tiers: RewardTier.defaults,
            requests: [],
            activity: [
                ActivityItem(id: "a1", kind: .ride(driver: "Manan", from: "Home", to: "Work", meters: 8530), date: ago(2)),
                ActivityItem(id: "a2", kind: .redeem(driver: "Shannon", title: "Coffee or bakery treat", cost: 3), date: ago(20)),
                ActivityItem(id: "a3", kind: .request(from: "Work", to: "Home", when: .tonight), date: ago(26)),
                ActivityItem(id: "a4", kind: .claim(driver: "Leo", from: "Work", to: "Home"), date: ago(25.8)),
                ActivityItem(id: "a5", kind: .ride(driver: "Shannon", from: "Work", to: "Home", meters: 8851), date: ago(49)),
            ]
        )

        let driving = Crew(
            id: sampleDriverCrewID,
            name: "Buğrahan's crew",
            ownerID: "bugrahan",
            inviteCode: "BGR7QX",
            members: [
                Member(id: "bugrahan", name: "Buğrahan", emoji: "🦊", color: Color(hex: 0xFCA5A5), role: .owner),
                Member(id: me.id, name: me.name, emoji: me.emoji, color: me.color, role: .driver, mehmmys: 5, meters: 41800, rides: 5),
                Member(id: "toprak", name: "Toprak", emoji: "🐼", color: Color(hex: 0xA7F3D0), role: .driver, mehmmys: 2, meters: 12100, rides: 2),
            ],
            places: [home, work, ewr],
            tiers: RewardTier.defaults,
            requests: [
                RideRequest(id: "q1", fromName: "Millburn", toName: "EWR", when: .morning, date: ago(0.3)),
                RideRequest(id: "q2", fromName: "Work", toName: "Home", when: .tonight, date: ago(30), claimedBy: "toprak"),
            ],
            activity: [
                ActivityItem(id: "b1", kind: .request(from: "Millburn", to: "EWR", when: .morning), date: ago(0.3)),
                ActivityItem(id: "b2", kind: .ride(driver: "Mehmed", from: "Home", to: "Work", meters: 8530), date: ago(28)),
            ]
        )

        return AppState(me: me, crews: [owned, driving], currentCrewID: owned.id)
    }
}
