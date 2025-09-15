//
//  AddressSearchPickerView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/14/25.
//

import SwiftUI
import MapKit
import CoreLocation

final class AddressSearchVM: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" { didSet { completer.queryFragment = query } }
    @Published var suggestions: [MKLocalSearchCompletion] = []
    let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }
}

struct AddressSearchPicker: View {
    var initialRadiusMeters: Double = 2000
    var onPick: (LocationInfo) -> Void
    var onCancel: () -> Void

    @StateObject private var vm = AddressSearchVM()
    @State private var selectedItem: MKMapItem?
    @State private var radiusMeters: Double

    init(initialRadiusMeters: Double = 2000,
         onPick: @escaping (LocationInfo) -> Void,
         onCancel: @escaping () -> Void) {
        self.initialRadiusMeters = max(50, initialRadiusMeters)
        self.onPick = onPick
        self.onCancel = onCancel
        _radiusMeters = State(initialValue: max(50, initialRadiusMeters))
    }

    var body: some View {
        VStack {
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Text("Enter Address").font(.headline)
                Spacer()
                Button("Use") {
                    guard let item = selectedItem else { return }
                    onPick(makeLocationInfo(from: item, radius: radiusMeters))
                }
                .bold()
                .disabled(selectedItem == nil)
            }
            .padding()

            TextField("Search address or place", text: $vm.query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List(vm.suggestions, id: \.self) { s in
                VStack(alignment: .leading) {
                    Text(s.title).font(.body)
                    if !s.subtitle.isEmpty {
                        Text(s.subtitle).font(.footnote).foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { Task { await select(s) } }
            }
            .listStyle(.plain)

            if let item = selectedItem {
                Map {
                    Annotation("Selected", coordinate: item.placemark.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                    }
                    MapCircle(center: item.placemark.coordinate, radius: radiusMeters)
                        .stroke(.secondary.opacity(0.3), lineWidth: 2)
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                HStack {
                    Text("Radius:")
                    Slider(value: $radiusMeters, in: 50...20000, step: 50)
                    Text("\(Int(radiusMeters)) m").monospacedDigit()
                }
                .padding()
            }

            Spacer(minLength: 0)
        }
        .presentationDetents([.large])
    }

    private func select(_ s: MKLocalSearchCompletion) async {
        let request = MKLocalSearch.Request(completion: s)
        let search = MKLocalSearch(request: request)
        if let response = try? await search.start(), let first = response.mapItems.first {
            selectedItem = first
        }
    }

    private func makeLocationInfo(from item: MKMapItem, radius: Double) -> LocationInfo {
        let p = item.placemark
        let c = p.coordinate
        return LocationInfo(
            Coordinate: .init(c.latitude, c.longitude),
            RegionCoordinate: .init(c.latitude, c.longitude),
            RegionRadius: radius,                 // meters
            Name: p.name,
            ThoroughFare: p.thoroughfare,
            SubThoroughFare: p.subThoroughfare,
            Locality: p.locality,
            SubLocality: p.subLocality,
            AdministrativeArea: p.administrativeArea,
            SubAdministrativeArea: p.subAdministrativeArea,
            PostalCode: p.postalCode,
            Country: p.country,
            IsoCountryCode: p.isoCountryCode,
            TimeZone: nil,                        // MKMapItem doesn't expose timeZone
            InlandWater: nil,
            Ocean: nil
        )
    }
}
