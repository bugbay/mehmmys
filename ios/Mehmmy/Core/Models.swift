import SwiftUI

enum Role: String { case owner, coowner, driver }

struct Member: Identifiable, Hashable {
    let id: String
    var name: String
    var emoji: String
    var color: Color
    var role: Role
    var mehmmys: Int = 0
    var meters: Int = 0
    var rides: Int = 0
    // imported from the old web board, not yet merged into a real account
    var legacy = false
}

struct Place: Identifiable, Hashable {
    let id: String
    var name: String
    var lat: Double
    var lng: Double
}

struct RewardTier: Identifiable, Hashable {
    let id: String
    var cost: Int
    var icon: String
    var title: String
    var subtitle: String

    static let defaults: [RewardTier] = [
        RewardTier(id: "t3", cost: 3, icon: "☕", title: "Coffee or bakery treat", subtitle: "Latte, pastry or cookie"),
        RewardTier(id: "t5", cost: 5, icon: "💳", title: "$15 gift card", subtitle: "Your pick of spot"),
        RewardTier(id: "t7", cost: 7, icon: "🍻", title: "Happy hour or $25 card", subtitle: "First round covered"),
        RewardTier(id: "t10", cost: 10, icon: "🎁", title: "$50 gift card", subtitle: "The big one"),
    ]
}

enum RequestWhen: String, CaseIterable, Identifiable {
    case now, morning, afternoon, tonight
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct RideRequest: Identifiable, Hashable {
    let id: String
    var fromName: String
    var toName: String
    var when: RequestWhen
    var date: Date
    var claimedBy: String?
    var byID: String = ""
}

enum ActivityKind: Hashable {
    case ride(driver: String, from: String, to: String, meters: Int)
    case request(from: String, to: String, when: RequestWhen)
    case claim(driver: String, from: String, to: String)
    case redeem(driver: String, title: String, cost: Int)
}

struct ActivityItem: Identifiable, Hashable {
    let id: String
    var kind: ActivityKind
    var date: Date
}

struct Crew: Identifiable {
    let id: String
    var name: String
    var ownerID: String
    var coOwnerIDs: [String] = []
    // founder's choice: false keeps routes, distances and places to owners only
    var detailsVisible = false
    var inviteCode: String
    var members: [Member]
    var places: [Place]
    var tiers: [RewardTier]
    var requests: [RideRequest]
    var activity: [ActivityItem]

    // everyone who can earn mehmmys; co-owners still drive
    var drivers: [Member] { members.filter { $0.role != .owner } }

    func isManager(_ id: String) -> Bool { ownerID == id || coOwnerIDs.contains(id) }
    var legacyStubs: [Member] { members.filter(\.legacy) }
}

// which slice of a crew's ride details the signed-in user is allowed to load
enum DetailScope: Equatable {
    case all, mine

    static func `for`(isManager: Bool, detailsVisible: Bool) -> DetailScope {
        isManager || detailsVisible ? .all : .mine
    }
}

extension Crew {

    static let empty = Crew(id: "", name: "", ownerID: "", inviteCode: "", members: [], places: [], tiers: [], requests: [], activity: [])
    var owner: Member? { members.first { $0.role == .owner } }
}

struct UserProfile {
    var id: String
    var name: String
    var emoji: String
    var color: Color
    var unit: DistanceUnit = .auto
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var emoji: String
    var title: String
    var subtitle: String
}

enum Tab: String, CaseIterable, Identifiable {
    case ride, board, rewards, activity, me
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .ride: "🚗"
        case .board: "🏆"
        case .rewards: "🎁"
        case .activity: "🧾"
        case .me: "🙂"
        }
    }
    var label: String { rawValue.capitalized }
}
