import SwiftUI
import UIKit

// firestore <-> model mapping, kept free of firebase types so it is unit-testable

enum AppPhase: Equatable {
    case loading, signedOut, needsProfile, needsCrew, ready

    static func derive(signedIn: Bool, hasProfile: Bool, crewCount: Int) -> AppPhase {
        if !signedIn { return .signedOut }
        if !hasProfile { return .needsProfile }
        return crewCount == 0 ? .needsCrew : .ready
    }
}

extension Color {
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(hex: v)
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let c = { (x: CGFloat) in Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }
}

private func int(_ v: Any?) -> Int? {
    if let i = v as? Int { return i }
    if let d = v as? Double { return Int(d) }
    if let n = v as? NSNumber { return n.intValue }
    return nil
}

extension Member {
    static func from(id: String, data: [String: Any]) -> Member? {
        guard data["legacy"] as? Bool != true,
              let name = data["displayName"] as? String,
              let role = Role(rawValue: data["role"] as? String ?? "") else { return nil }
        return Member(
            id: id,
            name: name,
            emoji: data["emoji"] as? String ?? "🙂",
            color: Color(hexString: data["color"] as? String ?? "") ?? Palette.sky,
            role: role,
            mehmmys: int(data["mehmmys"]) ?? 0,
            meters: int(data["meters"]) ?? 0,
            rides: int(data["rides"]) ?? 0
        )
    }
}

extension Place {
    static func from(id: String, data: [String: Any]) -> Place? {
        guard let name = data["name"] as? String,
              let lat = data["lat"] as? Double, let lng = data["lng"] as? Double else { return nil }
        return Place(id: id, name: name, lat: lat, lng: lng)
    }
}

extension RewardTier {
    static func from(_ data: [String: Any]) -> RewardTier? {
        guard let id = data["id"] as? String, let cost = int(data["cost"]), let title = data["title"] as? String else { return nil }
        return RewardTier(id: id, cost: cost, icon: data["icon"] as? String ?? "🎁", title: title, subtitle: data["subtitle"] as? String ?? "")
    }

    var document: [String: Any] {
        ["id": id, "cost": cost, "icon": icon, "title": title, "subtitle": subtitle]
    }
}

extension RideRequest {
    static func from(id: String, data: [String: Any], date: Date) -> RideRequest? {
        guard let from = data["fromName"] as? String, let to = data["toName"] as? String,
              let when = RequestWhen(rawValue: data["when"] as? String ?? "") else { return nil }
        return RideRequest(id: id, fromName: from, toName: to, when: when, date: date, claimedBy: data["claimedBy"] as? String, byID: data["byUid"] as? String ?? "")
    }
}

extension ActivityItem {
    static func from(id: String, data: [String: Any], date: Date) -> ActivityItem? {
        let from = data["fromName"] as? String ?? ""
        let to = data["toName"] as? String ?? ""
        let kind: ActivityKind
        switch data["type"] as? String {
        case "ride":
            kind = .ride(driver: data["driverName"] as? String ?? "", from: from, to: to, meters: int(data["meters"]) ?? 0)
        case "request":
            kind = .request(from: from, to: to, when: RequestWhen(rawValue: data["when"] as? String ?? "") ?? .now)
        case "claim":
            kind = .claim(driver: data["driverName"] as? String ?? (data["actorName"] as? String ?? ""), from: from, to: to)
        case "redeem":
            kind = .redeem(driver: data["actorName"] as? String ?? "", title: data["title"] as? String ?? "", cost: int(data["cost"]) ?? 0)
        default:
            return nil
        }
        return ActivityItem(id: id, kind: kind, date: date)
    }
}
