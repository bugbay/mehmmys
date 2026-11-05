import SwiftUI
import MapKit

struct RouteMapCard: View {
    let from: Place?
    let to: Place?
    let unit: DistanceUnit
    @Binding var meters: Int?

    @State private var route: MKRoute?
    @State private var loading = false
    @State private var estimated = false
    @State private var camera: MapCameraPosition = .automatic

    private var same: Bool { from?.id == to?.id }
    private var key: String { "\(from?.id ?? "-")>\(to?.id ?? "-")" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            map
            VStack(alignment: .leading, spacing: 0) {
                RouteLine()
                HStack {
                    Text(from?.name ?? "—")
                    Spacer()
                    Text(to?.name ?? "—")
                }
                .font(Typo.body(12, .bold))
                .lineLimit(1)
                .padding(.top, 7)
                Divider().overlay(Palette.locked).padding(.vertical, 12)
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(milesText).font(Typo.display(34)).monospacedDigit()
                    Text(Distance.unitLabel(unit) == "mi" ? "miles" : "km").font(Typo.body(14, .bold))
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(statusColor).frame(width: 7, height: 7)
                        Text(statusText).font(Typo.body(10, .bold)).foregroundStyle(Palette.muted)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
        }
        .brutal(Palette.paper, radius: 18, shadow: 4)
        .task(id: key) { await compute() }
    }

    private var map: some View {
        Map(position: $camera, interactionModes: []) {
            if let from {
                Marker(from.name, coordinate: CLLocationCoordinate2D(latitude: from.lat, longitude: from.lng)).tint(Palette.green)
            }
            if let to, !same {
                Marker(to.name, coordinate: CLLocationCoordinate2D(latitude: to.lat, longitude: to.lng)).tint(Palette.coral)
            }
            if let route {
                MapPolyline(route).stroke(Palette.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 150)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16, style: .continuous))
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 2) }
        .padding([.horizontal, .top], Metrics.border)
        .accessibilityLabel("Route map")
    }

    private var milesText: String {
        if same { return "—" }
        if loading { return "· · ·" }
        guard let meters else { return "—" }
        return Distance.number(meters, unit: unit)
    }

    private var statusText: String {
        if same { return "pick two places" }
        if loading { return "measuring route…" }
        return estimated ? "estimated" : "via Apple Maps"
    }

    private var statusColor: Color {
        if same { return Palette.faint }
        if loading { return Palette.yellow }
        return estimated ? Palette.faint : Palette.green
    }

    private func compute() async {
        route = nil
        guard let from, let to, !same else { meters = nil; return }
        loading = true
        defer { loading = false }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: from.lat, longitude: from.lng)))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: to.lat, longitude: to.lng)))
        request.transportType = .automobile
        // apple maps can stall in the simulator; fall back to an estimate after 6s
        let found: MKRoute? = await withTaskGroup(of: MKRoute?.self) { group in
            group.addTask { try? await MKDirections(request: request).calculate().routes.first }
            group.addTask {
                try? await Task.sleep(for: .seconds(6))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        if Task.isCancelled { return }
        if let r = found {
            route = r
            meters = Int(r.distance.rounded())
            estimated = false
        } else {
            meters = Distance.estimateRoadMeters(from: from, to: to)
            estimated = true
        }
        if let route {
            let r = route.polyline.boundingMapRect
            camera = .rect(r.insetBy(dx: -r.size.width * 0.35, dy: -r.size.height * 0.35))
        } else {
            camera = .automatic
        }
    }
}
