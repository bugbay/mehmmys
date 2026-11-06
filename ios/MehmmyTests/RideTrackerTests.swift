import XCTest
import CoreLocation
@testable import Mehmmy

final class RideTrackerTests: XCTestCase {
    private func loc(_ lat: Double, _ lng: Double, acc: Double = 10, t: TimeInterval = 0) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), altitude: 0,
                   horizontalAccuracy: acc, verticalAccuracy: 5, timestamp: Date(timeIntervalSince1970: 1_800_000_000 + t))
    }

    func testSumsDistanceAlongTheTrack() {
        var acc = TrackAccumulator()
        // ~111 m per 0.001 deg latitude
        for i in 0...10 { acc.add(loc(40.0 + Double(i) * 0.001, -74.0, t: Double(i) * 10)) }
        XCTAssertEqual(Double(acc.meters), 1112, accuracy: 15)
        XCTAssertEqual(acc.start?.coordinate.latitude, 40.0)
        XCTAssertEqual(acc.end?.coordinate.latitude ?? 0, 40.01, accuracy: 0.0001)
    }

    func testIgnoresInaccurateFixes() {
        var acc = TrackAccumulator()
        acc.add(loc(40.0, -74.0))
        acc.add(loc(40.05, -74.0, acc: 500, t: 5))
        acc.add(loc(40.001, -74.0, t: 10))
        XCTAssertEqual(Double(acc.meters), 111, accuracy: 5)
    }

    func testIgnoresJitterWhileStandingStill() {
        var acc = TrackAccumulator()
        acc.add(loc(40.0, -74.0))
        for i in 1...20 { acc.add(loc(40.0 + (i.isMultiple(of: 2) ? 0.00002 : -0.00002), -74.0, t: Double(i))) }
        XCTAssertLessThan(acc.meters, 10)
    }

    func testIgnoresImpossibleJumps() {
        var acc = TrackAccumulator()
        acc.add(loc(40.0, -74.0))
        acc.add(loc(41.0, -74.0, t: 1))
        XCTAssertEqual(acc.meters, 0)
    }

    func testNearestPlaceWithinRadius() {
        let places = [Place(id: "h", name: "Home", lat: 40.0, lng: -74.0), Place(id: "w", name: "Work", lat: 40.1, lng: -74.0)]
        XCTAssertEqual(TrackAccumulator.nearestPlace(to: loc(40.0005, -74.0), in: places)?.id, "h")
        XCTAssertNil(TrackAccumulator.nearestPlace(to: loc(40.05, -74.0), in: places))
    }
}
