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
    
    //MKLocalSearchCompleter updates live as the query changes
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
    
    //User types "Starb..." → shows list of Starbucks locations
    func selectCompletion(_ completion: MKLocalSearchCompletion) async -> MKMapItem?
    {
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
    var onPick  : (LocationInfo) -> Void
    var onCancel: () -> Void

    @StateObject private var vm = AddressSearchVM()
    @State private var selectedItem: MKMapItem?
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search Field
            searchSection
            
            // Content
            if let item = selectedItem {
                selectedLocationView(item)
            } else if !vm.suggestions.isEmpty {
                suggestionsView
            } else if vm.query.isEmpty {
                emptyStateView
            } else {
                loadingView
            }
            
            Spacer(minLength: 20)
            
            // Action Button
            actionButton
        }
        .padding(.horizontal, 24)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSearchFieldFocused = true
            }
        }
    }
    
    // MARK: - Search Section
    private var searchSection: some View
    {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search for a location")
                .font(.system(size: 16))
                .foregroundColor(AppPalette.Text.secondary)
            
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppPalette.Brand.neonPink.opacity(0.7))
                
                TextField("", text: $vm.query, prompt: Text("Enter address or place name").foregroundColor(AppPalette.Text.tertiary))
                    .font(.system(size: 16))
                    .foregroundColor(AppPalette.Text.primary)
                    .focused($isSearchFieldFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onSubmit {
                        if let first = vm.suggestions.first {
                            Task { await selectSuggestion(first) }
                        }
                    }
                
                if !vm.query.isEmpty {
                    Button(action: {
                        vm.query = ""
                        selectedItem = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppPalette.Text.tertiary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppPalette.Surface.fieldFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSearchFieldFocused ? AppPalette.Surface.focusStroke : AppPalette.Surface.fieldStroke,
                                lineWidth: isSearchFieldFocused ? 2 : 1
                            )
                    )
            )
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View
    {
        VStack(spacing: 16) {
            Image(systemName: "location.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(AppPalette.Brand.neonPink.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Start typing to search")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppPalette.Text.primary)
                
                Text("Enter an address, business name, or landmark")
                    .font(.system(size: 14))
                    .foregroundColor(AppPalette.Text.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Loading View
    private var loadingView: some View
    {
        VStack(spacing: 16) {
            ProgressView()
                .tint(AppPalette.Brand.neonPink)
            
            Text("Searching...")
                .font(.system(size: 16))
                .foregroundColor(AppPalette.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Suggestions View
    private var suggestionsView: some View
    {
        VStack(alignment: .leading, spacing: 16) {
            Text("Suggestions")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppPalette.Text.primary)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.suggestions, id: \.self) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 300)
        }
    }
    
    private func suggestionRow(_ suggestion: MKLocalSearchCompletion) -> some View
    {
        Button(action: {
            Task { await selectSuggestion(suggestion) }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppPalette.Brand.neonPink)
                
                VStack(alignment: .leading, spacing: 2) {
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
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppPalette.Text.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppPalette.Surface.fieldFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Selected Location View
    private func selectedLocationView(_ item: MKMapItem) -> some View
    {
        VStack(alignment: .leading, spacing: 16) {
            Text("Selected Location")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppPalette.Text.primary)
            
            // Location details card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppPalette.Brand.neonPink)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name ?? "Selected Location")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppPalette.Text.primary)
                        
                        if let address = formatAddress(item.placemark) {
                            Text(address)
                                .font(.system(size: 14))
                                .foregroundColor(AppPalette.Text.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppPalette.Brand.neonPink.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // Map preview
                Map {
                    Annotation("Selected", coordinate: item.placemark.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(AppPalette.Brand.neonPink)
                            .font(.title2)
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                )
                .allowsHitTesting(false)
            }
        }
    }
    
    // MARK: - Action Button
    private var actionButton: some View
    {
        Button(action: {
            guard let item = selectedItem else { return }
            onPick(makeLocationInfo(from: item))
        }) {
            Text("Use This Location")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedItem != nil ? AppPalette.Brand.neonPink : AppPalette.Brand.neonPink.opacity(0.5))
                )
        }
        .disabled(selectedItem == nil)
        .padding(.bottom, 24)
    }
    
    // MARK: - Helper Methods
    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) async
    {
        isSearching = true
        if let item = await vm.selectCompletion(suggestion) {
            selectedItem = item
            vm.query = item.name ?? suggestion.title
            isSearchFieldFocused = false
        }
        isSearching = false
    }
    
    private func formatAddress(_ placemark: MKPlacemark) -> String?
    {
        var components: [String] = []
        
        if let number = placemark.subThoroughfare,
           let street = placemark.thoroughfare {
            components.append("\(number) \(street)")
        } else if let street = placemark.thoroughfare {
            components.append(street)
        }
        
        if let city = placemark.locality {
            components.append(city)
        }
        
        if let state = placemark.administrativeArea {
            components.append(state)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    private func makeLocationInfo(from item: MKMapItem) -> LocationInfo
    {
        let p = item.placemark
        let c = p.coordinate
        
        // Use a reasonable default radius based on placemark type
        let defaultRadius: Double = {
            if p.thoroughfare != nil {
                return 500.0  // Street address - smaller radius
            } else if p.locality != nil {
                return 1000.0 // City/locality - medium radius
            } else {
                return 2000.0 // Larger area - bigger radius
            }
        }()
        
        return LocationInfo(
            Coordinate           : .init(c.latitude, c.longitude),
            RegionCoordinate     : .init(c.latitude, c.longitude),
            RegionRadius         : defaultRadius,
            Name                 : p.name,
            ThoroughFare         : p.thoroughfare,
            SubThoroughFare      : p.subThoroughfare,
            Locality             : p.locality,
            SubLocality          : p.subLocality,
            AdministrativeArea   : p.administrativeArea,
            SubAdministrativeArea: p.subAdministrativeArea,
            PostalCode           : p.postalCode,
            Country              : p.country,
            IsoCountryCode       : p.isoCountryCode,
            TimeZone             : nil,
            InlandWater          : nil,
            Ocean                : nil
        )
    }
}
