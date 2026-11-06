import XCTest
import SwiftUI
@testable import Mehmmy

@MainActor
final class MappingTests: XCTestCase {
    func testHexColorRoundTrip() {
        XCTAssertEqual(Color(hexString: "#7DD3FC")?.hexString, "#7DD3FC")
        XCTAssertEqual(Color(hexString: "7dd3fc")?.hexString, "#7DD3FC")
        XCTAssertNil(Color(hexString: "red"))
    }

    func testMemberFromDocument() {
        let m = Member.from(id: "u1", data: [
            "uid": "u1", "role": "driver", "displayName": "Leo", "emoji": "🐶",
            "color": "#7DD3FC", "mehmmys": 4, "meters": 34120, "rides": 4,
        ])
        XCTAssertEqual(m?.name, "Leo")
        XCTAssertEqual(m?.role, .driver)
        XCTAssertEqual(m?.mehmmys, 4)
        XCTAssertEqual(m?.meters, 34120)
        XCTAssertEqual(Member.from(id: "x", data: ["legacy": true, "role": "driver", "displayName": "Old"])?.legacy, true)
    }

    func testActivityFromDocuments() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(ActivityItem.from(id: "a", data: ["type": "ride", "driverName": "Leo", "fromName": "Home", "toName": "Work", "meters": 8530], date: date)?.kind,
                       .ride(driver: "Leo", from: "Home", to: "Work", meters: 8530))
        XCTAssertEqual(ActivityItem.from(id: "b", data: ["type": "request", "fromName": "Home", "toName": "Work", "when": "tonight"], date: date)?.kind,
                       .request(from: "Home", to: "Work", when: .tonight))
        XCTAssertEqual(ActivityItem.from(id: "c", data: ["type": "claim", "driverName": "Leo", "fromName": "Work", "toName": "Home"], date: date)?.kind,
                       .claim(driver: "Leo", from: "Work", to: "Home"))
        XCTAssertEqual(ActivityItem.from(id: "d", data: ["type": "redeem", "actorName": "Leo", "title": "Coffee", "cost": 3], date: date)?.kind,
                       .redeem(driver: "Leo", title: "Coffee", cost: 3))
        XCTAssertNil(ActivityItem.from(id: "e", data: ["type": "mystery"], date: date))
    }

    func testTiersRoundTrip() {
        let raw: [[String: Any]] = RewardTier.defaults.map(\.document)
        XCTAssertEqual(raw.compactMap(RewardTier.from), RewardTier.defaults)
    }

    func testPhaseFollowsAuthProfileAndCrews() {
        XCTAssertEqual(AppPhase.derive(signedIn: false, hasProfile: false, crewCount: 0), .signedOut)
        XCTAssertEqual(AppPhase.derive(signedIn: true, hasProfile: false, crewCount: 0), .needsProfile)
        XCTAssertEqual(AppPhase.derive(signedIn: true, hasProfile: true, crewCount: 0), .needsCrew)
        XCTAssertEqual(AppPhase.derive(signedIn: true, hasProfile: true, crewCount: 2), .ready)
    }

    func testEmptyStateHasNoCrewWithoutCrashing() {
        let state = AppState(me: UserProfile(id: "u", name: "New", emoji: "🐸", color: .white), crews: [], currentCrewID: "")
        XCTAssertEqual(state.crew.members.count, 0)
        XCTAssertFalse(state.isOwner)
    }
}
