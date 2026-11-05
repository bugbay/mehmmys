import Foundation
import CoreLocation

enum DistanceUnit: String, CaseIterable, Identifiable {
    case auto, mi, km
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: "Auto"
        case .mi: "Miles"
        case .km: "Kilometres"
        }
    }

    func resolved(locale: Locale = .current) -> DistanceUnit {
        guard self == .auto else { return self }
        return locale.measurementSystem == .us ? .mi : .km
    }
}

enum Distance {
    static let metersPerMile = 1609.344

    static func value(_ meters: Int, unit: DistanceUnit, locale: Locale = .current) -> Double {
        unit.resolved(locale: locale) == .mi ? Double(meters) / metersPerMile : Double(meters) / 1000
    }

    static func number(_ meters: Int, unit: DistanceUnit, locale: Locale = .current) -> String {
        String(format: "%.1f", value(meters, unit: unit, locale: locale))
    }

    static func unitLabel(_ unit: DistanceUnit, locale: Locale = .current) -> String {
        unit.resolved(locale: locale) == .mi ? "mi" : "km"
    }

    static func format(_ meters: Int, unit: DistanceUnit, locale: Locale = .current) -> String {
        "\(number(meters, unit: unit, locale: locale)) \(unitLabel(unit, locale: locale))"
    }

    static func estimateRoadMeters(from a: Place, to b: Place) -> Int {
        let la = CLLocation(latitude: a.lat, longitude: a.lng)
        let lb = CLLocation(latitude: b.lat, longitude: b.lng)
        return Int((la.distance(from: lb) * 1.3).rounded())
    }
}
