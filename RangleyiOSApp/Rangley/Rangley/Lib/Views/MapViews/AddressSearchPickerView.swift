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
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    isDisappearing = true
                    onCancel()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppPalette.Text.secondary)
                
                Spacer()
                
                Text("Enter Address")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppPalette.Text.primary)
                
                Spacer()
                
                Button("Use") {
                    guard let item = selectedItem else { return }
                    isDisappearing = true
                    onPick(makeLocationInfo(from: item, radius: radiusMeters))
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(selectedItem != nil ? AppPalette.Brand.neonPink : AppPalette.Text.tertiary)
                .disabled(selectedItem == nil || isDisappearing)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(AppPalette.Brand.russianViolet)

            // Search Field
            VStack(spacing: 16) {
                TextField("", text: $vm.query, prompt: Text("Search address or place").foregroundColor(AppPalette.Text.tertiary))
                    .font(.system(size: 16))
                    .foregroundColor(AppPalette.Text.primary)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppPalette.Brand.nearBlack.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppPalette.Brand.violetMid, lineWidth: 1)
                            )
                    )
                    .disabled(isDisappearing)
                
                // Suggestions List
                if !vm.suggestions.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.suggestions, id: \.self) { suggestion in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(suggestion.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(AppPalette.Text.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.system(size: 13))
                                            .foregroundColor(AppPalette.Text.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppPalette.Brand.russianViolet.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(AppPalette.Brand.violetMid.opacity(0.5), lineWidth: 0.5)
                                        )
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !isDisappearing {
                                        Task { await select(suggestion) }
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                
                // Selected Location Map
                if let item = selectedItem, !isDisappearing {
                    VStack(spacing: 16) {
                        Map {
                            Annotation("Selected", coordinate: item.placemark.coordinate) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(AppPalette.Brand.neonPink)
                                    .font(.title2)
                            }
                            MapCircle(center: item.placemark.coordinate, radius: radiusMeters)
                                .stroke(AppPalette.Brand.neonPink.opacity(0.4), lineWidth: 2)
                                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.1))
                        }
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppPalette.Brand.violetMid, lineWidth: 1)
                        )
                        .allowsHitTesting(!isDisappearing)

                        // Radius Slider
                        VStack(spacing: 8) {
                            HStack {
                                Text("Radius:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppPalette.Text.secondary)
                                Spacer()
                                Text("\(Int(radiusMeters)) meters")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppPalette.Brand.neonPink)
                                    .monospacedDigit()
                            }
                            
                            Slider(value: $radiusMeters, in: 50...20000, step: 50)
                                .tint(AppPalette.Brand.neonPink)
                                .disabled(isDisappearing)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppPalette.Brand.russianViolet.opacity(0.4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppPalette.Brand.violetMid.opacity(0.6), lineWidth: 1)
                                )
                        )
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    AppPalette.Brand.russianViolet,
                    AppPalette.Brand.nearBlack.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .preferredColorScheme(.dark)
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
            RegionRadius: radius,
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
            TimeZone: nil,
            InlandWater: nil,
            Ocean: nil
        )
    }
}
