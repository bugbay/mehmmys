import XCTest
import SwiftUI
@testable import Mehmmy

@MainActor
final class CoOwnerTests: XCTestCase {
    private var state: AppState!

    // me is a co-owner in buğrahan's crew
    override func setUp() {
        state = AppState.sample()
        state.currentCrewID = AppState.sampleDriverCrewID
        let i = state.crews.firstIndex { $0.id == AppState.sampleDriverCrewID }!
        state.crews[i].coOwnerIDs = [state.me.id]
        let m = state.crews[i].members.firstIndex { $0.id == state.me.id }!
        state.crews[i].members[m].role = .coowner
    }

    private var home: Place { state.crew.places[0] }
    private var work: Place { state.crew.places[1] }

    func testCoOwnerIsManagerButNotFounder() {
        XCTAssertTrue(state.isManager)
        XCTAssertFalse(state.isOwner)
    }

    func testCoOwnerCanLogRideForAnyoneButThemselves() {
        XCTAssertTrue(state.logRide(driverID: "toprak", from: home, to: work, meters: 1000))
        XCTAssertTrue(state.logRide(driverID: "bugrahan", from: home, to: work, meters: 1000))
        XCTAssertFalse(state.logRide(driverID: state.me.id, from: home, to: work, meters: 1000))
        XCTAssertEqual(state.rideCandidates.map(\.id).sorted(), ["bugrahan", "toprak"])
    }

    func testCoOwnerCanSendRequestAndStillRedeem() {
        XCTAssertTrue(state.sendRequest(from: home, to: work, when: .now))
        XCTAssertEqual(state.crew.requests.first?.byID, state.me.id)
        let coffee = state.crew.tiers.first { $0.cost == 3 }!
        XCTAssertTrue(state.redeem(tier: coffee))
    }

    func testNobodyClaimsTheirOwnRequest() {
        XCTAssertTrue(state.sendRequest(from: home, to: work, when: .now))
        let mine = state.crew.requests.first!
        XCTAssertFalse(state.claim(requestID: mine.id))
        let founders = state.crew.requests.first { $0.byID == "bugrahan" && $0.claimedBy == nil }!
        XCTAssertTrue(state.claim(requestID: founders.id))
    }

    func testCoOwnersStillShowOnTheBoard() {
        XCTAssertTrue(state.crew.drivers.contains { $0.id == state.me.id })
        XCTAssertFalse(state.crew.drivers.contains { $0.id == "bugrahan" })
    }

    func testOnlyFounderSetsCoOwners() {
        XCTAssertFalse(state.setCoOwner(memberID: "toprak", on: true))
        state.currentCrewID = AppState.sampleOwnedCrewID
        XCTAssertTrue(state.setCoOwner(memberID: "leo", on: true))
        XCTAssertEqual(state.crew.coOwnerIDs, ["leo"])
        XCTAssertEqual(state.crew.members.first { $0.id == "leo" }?.role, .coowner)
        XCTAssertTrue(state.setCoOwner(memberID: "leo", on: false))
        XCTAssertEqual(state.crew.coOwnerIDs, [])
        XCTAssertFalse(state.setCoOwner(memberID: state.me.id, on: true))
    }

    func testCoOwnerCanLeave() {
        state.leaveCurrentCrew()
        XCTAssertFalse(state.crews.contains { $0.id == AppState.sampleDriverCrewID })
    }

    func testMappingReadsCoOwnerRoleAndRequester() {
        XCTAssertEqual(Member.from(id: "u", data: ["role": "coowner", "displayName": "Oz"])?.role, .coowner)
        let r = RideRequest.from(id: "q", data: ["byUid": "u1", "fromName": "A", "toName": "B", "when": "now"], date: .now)
        XCTAssertEqual(r?.byID, "u1")
    }
}
