import CoreLocation
import Observation

// pure distance maths for a tracked ride, kept apart from CoreLocation callbacks so it is testable
struct TrackAccumulator {
    static let maxAccuracy: CLLocationAccuracy = 50
    static let minStep: CLLocationDistance = 10
    static let maxSpeed: CLLocationSpeed = 70
    static let placeRadius: CLLocationDistance = 300

    private(set) var meters = 0
    private(set) var start: CLLocation?
    private(set) var end: CLLocation?
    private var last: CLLocation?
    private var total: CLLocationDistance = 0

    mutating func add(_ loc: CLLocation) {
        guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= Self.maxAccuracy else { return }
        guard let prev = last else {
            start = loc; end = loc; last = loc
            return
        }
        let step = loc.distance(from: prev)
        // jitter while parked is smaller than the fix accuracy
        guard step >= max(Self.minStep, loc.horizontalAccuracy) else { return }
        let dt = loc.timestamp.timeIntervalSince(prev.timestamp)
        guard dt > 0, step / dt <= Self.maxSpeed else { return }
        total += step
        meters = Int(total.rounded())
        last = loc
        end = loc
    }

    static func nearestPlace(to loc: CLLocation, in places: [Place]) -> Place? {
        places
            .map { ($0, loc.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lng))) }
            .filter { $0.1 <= placeRadius }
            .min { $0.1 < $1.1 }?
            .0
    }
}

// drives CoreLocation for one ride; keeps running with the screen locked via the location background mode
@MainActor
@Observable
final class RideTracker: NSObject, CLLocationManagerDelegate {
    enum Status: Equatable { case idle, waitingForPermission, denied, tracking, finished }

    private(set) var status: Status = .idle
    private(set) var startedAt: Date?
    private(set) var acc = TrackAccumulator()
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        manager.pausesLocationUpdatesAutomatically = false
    }

    var meters: Int { acc.meters }

    func start() {
        acc = TrackAccumulator()
        startedAt = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            status = .waitingForPermission
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            status = .denied
        default:
            begin()
        }
    }

    func finish() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        status = .finished
    }

    func reset() {
        manager.stopUpdatingLocation()
        acc = TrackAccumulator()
        startedAt = nil
        status = .idle
    }

    private func begin() {
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        startedAt = .now
        status = .tracking
        manager.startUpdatingLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        Task { @MainActor in
            guard self.status == .waitingForPermission else { return }
            switch auth {
            case .authorizedWhenInUse, .authorizedAlways: self.begin()
            case .denied, .restricted: self.status = .denied
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard self.status == .tracking else { return }
            for loc in locations { self.acc.add(loc) }
        }
    }
}
