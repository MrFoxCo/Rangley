//
//  MapLocationPicker.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/14/25.
//

import SwiftUI
import MapKit
import CoreLocation

// THIS IS ITHE BAD BOY THAT WE USE FOR PICKING LOCATIONS NOT VIA TAP .. also by tap if u want
struct MapLocationPicker: View
{
    let initial: LocationInfo
    let onPick: (LocationInfo) -> Void
    let onCancel: () -> Void

    @State private var region: MKCoordinateRegion
    @State private var center: CLLocationCoordinate2D
    @State private var radiusMeters: Double
    @State private var cameraPosition: MapCameraPosition
    @State private var lastPlacemark: CLPlacemark?
    @State private var addressLine: String = ""
    @State private var geocodingTask: Task<Void, Never>?
    @State private var isDisappearing = false

    init(initial: LocationInfo,
         onPick: @escaping (LocationInfo) -> Void,
         onCancel: @escaping () -> Void) {
        self.initial = initial
        self.onPick = onPick
        self.onCancel = onCancel

        let start = initial.Coordinate.cl
        _center = State(initialValue: start)
        _region = State(initialValue: MKCoordinateRegion(
            center: start,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
        _radiusMeters = State(initialValue: max(50, initial.RegionRadius)) // keep sane minimum
        _cameraPosition = State(initialValue: .region(_region.wrappedValue))
    }

    var body: some View {
        VStack {
            HStack {
                Button("Cancel") {
                    isDisappearing = true
                    geocodingTask?.cancel()
                    onCancel()
                }
                Spacer()
                Text("Pick Location").font(.headline)
                Spacer()
                Button("Use") {
                    isDisappearing = true
                    geocodingTask?.cancel()
                    onPick(makeLocationInfo(coord: center, placemark: lastPlacemark, radius: radiusMeters))
                }
                .bold()
                .disabled(isDisappearing)
            }
            .padding()

            if !isDisappearing {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        Annotation("Pin", coordinate: center) {
                            Image(systemName: "mappin.circle.fill")
                        }
                        MapCircle(center: center, radius: radiusMeters)
                            .foregroundStyle(.secondary.opacity(0.2))  // Opaque fill
                            .stroke(.secondary.opacity(0.3), lineWidth: 2)
                    }
                    .gesture(
                        SpatialTapGesture().onEnded { value in
                            guard !isDisappearing else { return }
                            let point = value.location
                            if let coord = proxy.convert(point, from: .local) {
                                center = coord
                                // keep the same zoom/span while moving the camera
                                region.center = coord
                                cameraPosition = .region(region)
                                Task { await reverseGeocode(coord) }
                            }
                        }
                    )
                    .onAppear {
                        Task { await reverseGeocode(center) }
                    }
                    .allowsHitTesting(!isDisappearing)
                }
                .frame(height: 360)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text(addressLine.isEmpty ? "Tap the map to place the pin" : addressLine)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Radius:")
                        Slider(value: $radiusMeters, in: 50...20000, step: 50)
                            .disabled(isDisappearing)
                        Text("\(Int(radiusMeters)) m").monospacedDigit()
                    }
                }
                .padding()
            }

            Spacer(minLength: 0)
        }
        .presentationDetents([.medium, .large])
        .onDisappear {
            isDisappearing = true
            geocodingTask?.cancel()
        }
    }

    // MARK: - Helpers
    @MainActor
    private func reverseGeocode(_ coord: CLLocationCoordinate2D) async {
        guard !isDisappearing else { return }
        
        geocodingTask?.cancel()
        geocodingTask = Task {
            do {
                let placemarks = try await CLGeocoder().reverseGeocodeLocation(
                    CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                )
                
                guard !Task.isCancelled, !isDisappearing else { return }
                
                lastPlacemark = placemarks.first
                addressLine = formattedAddress(from: lastPlacemark)
            } catch {
                guard !Task.isCancelled, !isDisappearing else { return }
                lastPlacemark = nil
                addressLine = ""
            }
        }
    }

    private func makeLocationInfo(coord: CLLocationCoordinate2D,
                                  placemark: CLPlacemark?,
                                  radius: Double) -> LocationInfo {
        let c = Coordinate(coord.latitude, coord.longitude)
        return LocationInfo(
            Coordinate: c,
            RegionCoordinate: c,              // geofence center at pin
            RegionRadius: radius,             // meters
            Name: placemark?.name,
            ThoroughFare: placemark?.thoroughfare,
            SubThoroughFare: placemark?.subThoroughfare,
            Locality: placemark?.locality,
            SubLocality: placemark?.subLocality,
            AdministrativeArea: placemark?.administrativeArea,
            SubAdministrativeArea: placemark?.subAdministrativeArea,
            PostalCode: placemark?.postalCode,
            Country: placemark?.country,
            IsoCountryCode: placemark?.isoCountryCode,
            TimeZone: placemark?.timeZone?.identifier,
            InlandWater: placemark?.inlandWater,
            Ocean: placemark?.ocean
        )
    }

    private func formattedAddress(from p: CLPlacemark?) -> String {
        guard let p else { return "" }
        return [p.name, p.locality, p.administrativeArea, p.postalCode, p.country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}
