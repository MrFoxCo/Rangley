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
            searchHeader
            
            // Content
            VStack(spacing: 20) {
                // Search Field
                searchField
                
                // Suggestions List
                if !vm.suggestions.isEmpty {
                    suggestionsList
                }
                
                // Selected Location Map
                if let item = selectedItem, !isDisappearing {
                    selectedLocationSection(item)
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(AppPalette.bgGradient)
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .onDisappear {
            isDisappearing = true
        }
    }
    
    // MARK: - Search Header
    private var searchHeader: some View {
        HStack(spacing: 16) {
            // Close button
            Button(action: {
                isDisappearing = true
                onCancel()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppPalette.Brand.neonPink.opacity(0.1))
                    )
            }
            .disabled(isDisappearing)
            
            // Title
            Text("Enter Address")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
                .frame(maxWidth: .infinity)
            
            // Use button
            Button(action: {
                guard let item = selectedItem else { return }
                isDisappearing = true
                onPick(makeLocationInfo(from: item, radius: radiusMeters))
            }) {
                Text("Use")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selectedItem != nil ? AppPalette.Brand.neonPink : AppPalette.Text.tertiary)
                    .frame(width: 32, height: 32)
            }
            .disabled(selectedItem == nil || isDisappearing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Search Field
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "location")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
            
            TextField("Search address or place", text: $vm.query)
                .font(.system(size: 16))
                .foregroundStyle(Color.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(isDisappearing)
            
            if !vm.query.isEmpty {
                Button(action: { vm.query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
                }
                .disabled(isDisappearing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Suggestions List
    private var suggestionsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(vm.suggestions, id: \.self) { suggestion in
                    suggestionRow(suggestion)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 200)
    }
    
    private func suggestionRow(_ suggestion: MKLocalSearchCompletion) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(suggestion.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppPalette.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !suggestion.subtitle.isEmpty {
                Text(suggestion.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isDisappearing {
                Task { await select(suggestion) }
            }
        }
    }
    
    // MARK: - Selected Location Section
    private func selectedLocationSection(_ item: MKMapItem) -> some View {
        VStack(spacing: 16) {
            // Map
            Map {
                Annotation("Selected", coordinate: item.placemark.coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(AppPalette.Brand.neonPink)
                        .font(.title2)
                }
                MapCircle(center: item.placemark.coordinate, radius: radiusMeters)
                    .stroke(AppPalette.Brand.neonPink.opacity(0.35), lineWidth: 2)
                    .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.08))
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
            )
            .allowsHitTesting(!isDisappearing)
            
            // Radius Control
            radiusControl
        }
    }
    
    // MARK: - Radius Control
    private var radiusControl: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Search Radius")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.Text.secondary)
                Spacer()
                Text("\(Int(radiusMeters))m")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                    .monospacedDigit()
            }
            
            Slider(value: $radiusMeters, in: 50...20000, step: 50)
                .tint(AppPalette.Brand.neonPink)
                .disabled(isDisappearing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
                )
        )
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
