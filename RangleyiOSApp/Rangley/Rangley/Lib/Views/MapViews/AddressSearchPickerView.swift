//
//  AddressSearchPickerView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/14/25.
//

import SwiftUI
import MapKit
import CoreLocation

final class AddressSearchVM: NSObject, ObservableObject, MKLocalSearchCompleterDelegate
{
    @Published var query = "" { didSet { completer.queryFragment = query } }
    @Published var suggestions: [MKLocalSearchCompletion] = []
    let completer = MKLocalSearchCompleter()
    private var searchTask: Task<MKMapItem?, Never>?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
    deinit {
        searchTask?.cancel()
        completer.cancel()
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }
    
    func selectCompletion(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        searchTask?.cancel()
        
        searchTask = Task {
            let request = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: request)
            if let response = try? await search.start(), let first = response.mapItems.first {
                return first
            }
            return nil
        }
        return await searchTask?.value
    }
}

struct AddressSearchPicker: View
{
    var initialRadiusMeters: Double = 2000
    var onPick: (LocationInfo) -> Void
    var onCancel: () -> Void

    @StateObject private var vm = AddressSearchVM()
    @State private var selectedItem: MKMapItem?
    @State private var radiusMeters: Double
    @State private var isDisappearing = false

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
                Button("Cancel") {
                    isDisappearing = true
                    onCancel()
                }
                Spacer()
                Text("Enter Address").font(.headline)
                Spacer()
                Button("Use") {
                    guard let item = selectedItem else { return }
                    isDisappearing = true
                    onPick(makeLocationInfo(from: item, radius: radiusMeters))
                }
                .bold()
                .disabled(selectedItem == nil || isDisappearing)
            }
            .padding()

            TextField("Search address or place", text: $vm.query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .disabled(isDisappearing)

            List(vm.suggestions, id: \.self) { s in
                VStack(alignment: .leading) {
                    Text(s.title).font(.body)
                    if !s.subtitle.isEmpty {
                        Text(s.subtitle).font(.footnote).foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isDisappearing {
                        Task { await select(s) }
                    }
                }
            }
            .listStyle(.plain)
            .disabled(isDisappearing)

            if let item = selectedItem, !isDisappearing {
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
                .allowsHitTesting(!isDisappearing)

                HStack {
                    Text("Radius:")
                    Slider(value: $radiusMeters, in: 50...20000, step: 50)
                        .disabled(isDisappearing)
                    Text("\(Int(radiusMeters)) m").monospacedDigit()
                }
                .padding()
            }

            Spacer(minLength: 0)
        }
        .presentationDetents([.large])
        .onDisappear {
            isDisappearing = true
        }
    }

    private func select(_ s: MKLocalSearchCompletion) async {
        guard !isDisappearing else { return }
        if let item = await vm.selectCompletion(s) {
            selectedItem = item
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
