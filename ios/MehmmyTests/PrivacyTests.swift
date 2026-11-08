import XCTest
@testable import Mehmmy

@MainActor
final class PrivacyTests: XCTestCase {
    private var state: AppState!

    override func setUp() {
        state = AppState.sample()
    }

    func testFounderAndCoOwnersSeeDetailsDriversDoNotByDefault() {
        state.currentCrewID = AppState.sampleOwnedCrewID
        XCTAssertTrue(state.seesDetails)
        state.currentCrewID = AppState.sampleDriverCrewID
        XCTAssertFalse(state.crew.detailsVisible)
        XCTAssertFalse(state.seesDetails)
        let i = state.crews.firstIndex { $0.id == AppState.sampleDriverCrewID }!
        state.crews[i].coOwnerIDs = [state.me.id]
        XCTAssertTrue(state.seesDetails)
    }

    func testDriversSeeTheirOwnDistanceButNotOthers() {
        state.currentCrewID = AppState.sampleDriverCrewID
        let me = state.crew.members.first { $0.id == state.me.id }!
        let toprak = state.crew.members.first { $0.id == "toprak" }!
        XCTAssertNotNil(state.distanceText(for: me))
        XCTAssertNil(state.distanceText(for: toprak))
        let i = state.crews.firstIndex { $0.id == AppState.sampleDriverCrewID }!
        state.crews[i].detailsVisible = true
        XCTAssertNotNil(state.distanceText(for: toprak))
    }

    func testOnlyTheFounderChangesVisibility() {
        state.currentCrewID = AppState.sampleDriverCrewID
        XCTAssertFalse(state.setDetailsVisible(true))
        state.currentCrewID = AppState.sampleOwnedCrewID
        XCTAssertTrue(state.setDetailsVisible(true))
        XCTAssertTrue(state.crew.detailsVisible)
    }

    func testListenerScopeFollowsRoleAndSetting() {
        XCTAssertEqual(DetailScope.for(isManager: true, detailsVisible: false), .all)
        XCTAssertEqual(DetailScope.for(isManager: false, detailsVisible: true), .all)
        XCTAssertEqual(DetailScope.for(isManager: false, detailsVisible: false), .mine)
    }
}
