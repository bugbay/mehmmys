import XCTest
@testable import Mehmmy

@MainActor
final class LegacyLinkTests: XCTestCase {
    func testLegacyStubsMapWithFlag() {
        let m = Member.from(id: "legacy-1", data: ["legacy": true, "role": "driver", "displayName": "Shannon", "mehmmys": 8])
        XCTAssertEqual(m?.legacy, true)
        XCTAssertEqual(m?.mehmmys, 8)
    }

    func testStubsShowOnBoardButCannotBeCredited() {
        let state = AppState.sample()
        state.currentCrewID = AppState.sampleOwnedCrewID
        let i = state.crews.firstIndex { $0.id == AppState.sampleOwnedCrewID }!
        state.crews[i].members.append(Member(id: "legacy-1", name: "Old Leo", emoji: "🐶", color: .blue, role: .driver, mehmmys: 4, legacy: true))
        XCTAssertTrue(state.crew.drivers.contains { $0.id == "legacy-1" })
        XCTAssertFalse(state.rideCandidates.contains { $0.id == "legacy-1" })
        XCTAssertEqual(state.crew.legacyStubs.map(\.id), ["legacy-1"])
    }

    func testFounderMergesStubIntoRealMember() {
        let state = AppState.sample()
        state.currentCrewID = AppState.sampleOwnedCrewID
        let i = state.crews.firstIndex { $0.id == AppState.sampleOwnedCrewID }!
        state.crews[i].members.append(Member(id: "legacy-1", name: "Old Leo", emoji: "🐶", color: .blue, role: .driver, mehmmys: 4, meters: 1000, rides: 4, legacy: true))
        let leo = state.crew.members.first { $0.id == "leo" }!
        XCTAssertTrue(state.linkLegacy(stubID: "legacy-1", memberID: "leo"))
        let after = state.crew.members.first { $0.id == "leo" }!
        XCTAssertEqual(after.mehmmys, leo.mehmmys + 4)
        XCTAssertEqual(after.rides, leo.rides + 4)
        XCTAssertNil(state.crew.members.first { $0.id == "legacy-1" })
        XCTAssertFalse(state.linkLegacy(stubID: "leo", memberID: "amanda"))
    }
}
