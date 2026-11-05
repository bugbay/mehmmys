import XCTest
@testable import Mehmmy

final class AppStateTests: XCTestCase {
    private var state: AppState!

    override func setUp() {
        state = AppState.sample()
        state.currentCrewID = AppState.sampleOwnedCrewID
    }

    private var home: Place { state.crew.places[0] }
    private var work: Place { state.crew.places[1] }

    func testLogRideCreditsTheDriver() {
        let leo = state.crew.drivers.first { $0.name == "Leo" }!
        XCTAssertTrue(state.logRide(driverID: leo.id, from: home, to: work, meters: 8530))
        let after = state.crew.members.first { $0.id == leo.id }!
        XCTAssertEqual(after.mehmmys, leo.mehmmys + 1)
        XCTAssertEqual(after.meters, leo.meters + 8530)
        XCTAssertEqual(after.rides, leo.rides + 1)
        XCTAssertEqual(state.crew.activity.first?.kind, .ride(driver: "Leo", from: home.name, to: work.name, meters: 8530))
        XCTAssertEqual(state.toast?.title, "+1 Mehmmy!")
    }

    func testLogRideRejectsOwnerSamePlaceAndZeroMeters() {
        let leo = state.crew.drivers[0]
        XCTAssertFalse(state.logRide(driverID: state.me.id, from: home, to: work, meters: 100))
        XCTAssertFalse(state.logRide(driverID: leo.id, from: home, to: home, meters: 100))
        XCTAssertFalse(state.logRide(driverID: leo.id, from: home, to: work, meters: 0))
    }

    func testDriverCannotLogRides() {
        state.currentCrewID = AppState.sampleDriverCrewID
        let driver = state.crew.drivers.first { $0.id != state.me.id }!
        XCTAssertFalse(state.logRide(driverID: driver.id, from: home, to: work, meters: 100))
    }

    func testSendRequestRecordsActivity() {
        XCTAssertTrue(state.sendRequest(from: home, to: work, when: .tonight))
        XCTAssertEqual(state.crew.requests.first?.when, .tonight)
        XCTAssertEqual(state.crew.activity.first?.kind, .request(from: home.name, to: work.name, when: .tonight))
    }

    func testDriverClaimsAnOpenRequestOnce() {
        state.currentCrewID = AppState.sampleDriverCrewID
        let open = state.crew.requests.first { $0.claimedBy == nil }!
        XCTAssertTrue(state.claim(requestID: open.id))
        XCTAssertEqual(state.crew.requests.first { $0.id == open.id }?.claimedBy, state.me.id)
        XCTAssertFalse(state.claim(requestID: open.id))
    }

    func testDriverRedeemsWithinBalanceOnly() {
        state.currentCrewID = AppState.sampleDriverCrewID
        let before = state.myMember!.mehmmys
        let coffee = state.crew.tiers.first { $0.cost == 3 }!
        let big = state.crew.tiers.first { $0.cost == 10 }!
        XCTAssertTrue(before >= 3 && before < 10)
        XCTAssertTrue(state.redeem(tier: coffee))
        XCTAssertEqual(state.myMember!.mehmmys, before - 3)
        XCTAssertFalse(state.redeem(tier: big))
    }

    func testOwnerCannotRedeem() {
        XCTAssertFalse(state.redeem(tier: state.crew.tiers[0]))
    }

    func testAddPlaceTrimsAndAppends() {
        let p = state.addPlace(name: "  Gym  ", lat: 40.7, lng: -74.2)
        XCTAssertEqual(p?.name, "Gym")
        XCTAssertEqual(state.crew.places.last?.id, p?.id)
        XCTAssertNil(state.addPlace(name: "   ", lat: 0, lng: 0))
    }
}

final class DistanceTests: XCTestCase {
    func testFormatsBothUnits() {
        XCTAssertEqual(Distance.format(8530, unit: .mi), "5.3 mi")
        XCTAssertEqual(Distance.format(8530, unit: .km), "8.5 km")
    }

    func testAutoFollowsLocale() {
        XCTAssertEqual(Distance.format(8530, unit: .auto, locale: Locale(identifier: "en_US")), "5.3 mi")
        XCTAssertEqual(Distance.format(8530, unit: .auto, locale: Locale(identifier: "tr_TR")), "8.5 km")
    }
}
