import SwiftUI
import MapKit

struct AddPlaceSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var label = ""
    @State private var results: [MKMapItem] = []
    @State private var chosen: MKMapItem?
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.74, longitude: -74.28),
        span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)))
    @State private var pin: CLLocationCoordinate2D?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    BrutalField(placeholder: "Search an address or place", text: $query)
                        .onSubmit { Task { await search() } }
                        .submitLabel(.search)
                    if !results.isEmpty && chosen == nil {
                        VStack(spacing: 0) {
                            ForEach(results, id: \.self) { item in
                                Button { choose(item) } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "Place").font(Typo.body(14, .bold))
                                        Text(item.placemark.title ?? "").font(Typo.body(11)).foregroundStyle(Palette.muted).lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 13).padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                        .brutal(Palette.paper, radius: 12)
                    }
                    MapReader { proxy in
                        Map(position: $camera) {
                            if let pin { Marker(label.isEmpty ? "New place" : label, coordinate: pin).tint(Palette.coral) }
                        }
                        .onTapGesture { point in
                            if let c = proxy.convert(point, from: .local) { pin = c }
                        }
                    }
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.ink, lineWidth: Metrics.border))
                    Text("Search, or tap the map to drop a pin.").font(Typo.body(11)).foregroundStyle(Palette.muted)
                    FieldLabel(text: "NAME IT")
                    BrutalField(placeholder: "Home, Work, Gym…", text: $label)
                    Button("📍 Save place") {
                        if let pin, state.addPlace(name: label, lat: pin.latitude, lng: pin.longitude) != nil { dismiss() }
                    }
                    .buttonStyle(BrutalButtonStyle(fill: Palette.green, enabled: pin != nil && !label.trimmingCharacters(in: .whitespaces).isEmpty))
                    .disabled(pin == nil || label.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.top, 6)
                }
                .padding(Metrics.gutter)
            }
            .background(Palette.cream)
            .navigationTitle("Add a place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func search() async {
        chosen = nil
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: pin ?? CLLocationCoordinate2D(latitude: 40.74, longitude: -74.28), span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
        results = (try? await MKLocalSearch(request: request).start().mapItems.prefix(5).map { $0 }) ?? []
    }

    private func choose(_ item: MKMapItem) {
        chosen = item
        pin = item.placemark.coordinate
        if label.isEmpty { label = String((item.name ?? "").prefix(22)) }
        camera = .region(MKCoordinateRegion(center: item.placemark.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
    }
}
