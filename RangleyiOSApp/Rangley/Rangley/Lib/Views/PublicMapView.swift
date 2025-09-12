//
//  ContentView.swift
//  Freebird
//
//  Created by Anthony Guzzardo on 7/1/25.
//
import CoreLocation
import MapKit
import SwiftUI
import Foundation
import SQLite3 // TODO: remove this when all the sqlite logic is gone
import Amplify
import UIKit



public struct PublicMapView: View
{
    // MARK: - Map Location
    
    // TODO: Place it at the Users location ... or their last location if unknown
    // PUBLIC MAP ALWAYS STARTS HERE
    @State private var cameraPosition : MapCameraPosition = .region( MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.9211, longitude: -87.6338), // Lincoln Park Zoo approx
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)))
    
    @State private var selectedAnchor: CGPoint?

    // MARK: - END Map Location
        
    // Keep this in PublicMapView so helpers can see it
    @State private var lastSpan = MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)

    // =========================================================
    // MARK: - Meet Creation FLow
    // =========================================================
    @State private var selectedLocation: LocationInfo?
    @State private var showLocationPopup = false
    // =========================================================
    // MARK: - END Meet Creation FLow
    // =========================================================

    // =========================================================
    // MARK: - Hamburger Menu
    // =========================================================
    
    @State private var showStart        = false
    @State private var signingOut       = false
    @State private var confirmSignOut   = false
    
    private func signOutAndGoStart() {
        Task {
            guard !signingOut else { return }
            signingOut = true; defer { signingOut = false }
            _ = await Amplify.Auth.signOut()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showStart = true
        }
    }

    // =========================================================
    // MARK: - END Hamburger Menu
    // =========================================================
    
    
    // =========================================================
    // MARK: - Body (your existing body stays below)
    // =========================================================
    public var body: some View
    {
        ZStack
        {
            GeometryReader
            { geo in
                MapReader
                { proxy in
                    Map(position: $cameraPosition) {}
                    // Map tap should only create when placing, and not if a sheet is already up
                    .gesture(
                        SpatialTapGesture().onEnded { value in
                            // Don’t queue another sheet if one is already up

                            
                            let position = value.location
                            if let coordinate = proxy.convert(position, from: .local) {
                                let geocoder = CLGeocoder()
                                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                                
                                // Log the tapped coordinates to console
                                print("--- Map Tapped ---")
                                print("Latitude: \(coordinate.latitude)")
                                print("Longitude: \(coordinate.longitude)")
                                print("Position: (\(coordinate.latitude), \(coordinate.longitude))")
                                
                                // Get detailed location information
                                Task {
                                    if let locationInfo = await createLocationInfoObject(geocoder, location)
                                    {
                                        // Location info is now available for use
                                        // The function already logs all the details to console
                                        await MainActor.run {
                                               selectedLocation = locationInfo
                                               showLocationPopup = true
                                           }
                                    }
                                }
                            }
                        }
                    )
                    
                    .ignoresSafeArea()

                    .tabItem {
                        Image(systemName: "map")
                        Text("Map")
                    }
                }
            }
            // ADD THIS: Pink location popup overlay
            // ADD THIS: Meet creation overlay with two-step flow
            MeetCreationOverlay(
                selectedLocation: $selectedLocation,
                showPopup: $showLocationPopup,
                onCreateMeet: { locationInfo, name, startTime, endTime, maxCapacity in
                    // Handle meet creation here
                    print("Creating meet:")
                    print("  Name: \(name)")
                    print("  Location: \(locationInfo.Name ?? "Unknown")")
                    print("  Start: \(startTime)")
                    print("  End: \(endTime)")
                    print("  Capacity: \(maxCapacity ?? 0) (0 = unlimited)")
                    print("  Category ID: 1 (default)")
                    
                    // TODO: Call your API to create the meet with these values
                    // let meet_category_id = 1  // Default as requested
                }
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .safeAreaInset(edge: .bottom)
        {
            HStack {
                Spacer()
                HamburgerMenu { signOutAndGoStart() }
                    .padding(.trailing, 16)
            }
            .padding(.bottom, 8)
        }
        .confirmationDialog("Sign out?", isPresented: $confirmSignOut) // TODO: fix not working
        {
            Button("Sign Out", role: .destructive) { signOutAndGoStart() }
            Button("Cancel", role: .cancel) { }
        }
        // Full-screen handoff to StartScreenView after sign-out
        .fullScreenCover(isPresented: $showStart)
        {
            StartScreenView(onAuthenticated: {      // ← add this
                showStart = false                   // dismiss after successful auth
            })
            .preferredColorScheme(.dark)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - END Body
    


    
    // THIS IS FIRST THING GENERATED NEED FOR MEET CREATION

    private func createLocationInfoObject(_ geocoder: CLGeocoder, _ location: CLLocation) async -> LocationInfo?
    {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            
            print("--- Reverse Geocoded Placemark ---")
            print("Name                : \(placemark.name ?? "nil")")
            print("Thoroughfare        : \(placemark.thoroughfare ?? "nil")")         // Street name
            print("SubThoroughfare     : \(placemark.subThoroughfare ?? "nil")")     // Street number
            print("SubLocality         : \(placemark.subLocality ?? "nil")")         // Neighborhood
            print("Locality            : \(placemark.locality ?? "nil")")            // City
            print("SubAdministrativeArea: \(placemark.subAdministrativeArea ?? "nil")") // County
            print("AdministrativeArea  : \(placemark.administrativeArea ?? "nil")")  // State / Province
            print("PostalCode          : \(placemark.postalCode ?? "nil")")
            print("Country             : \(placemark.country ?? "nil")")
            print("ISO Country Code    : \(placemark.isoCountryCode ?? "nil")")
            print("TimeZone            : \(placemark.timeZone?.identifier ?? "nil")")
            print("Region              : \(placemark.region?.identifier ?? "nil")")
            print("Location (lat,long) : \(placemark.location?.coordinate.latitude ?? 0), \(placemark.location?.coordinate.longitude ?? 0)")
            
            let locationInfo = LocationInfo(
                Coordinate: Coordinate(
                    location.coordinate.latitude,
                    location.coordinate.longitude
                ),
                RegionCoordinate: Coordinate(
                    placemark.location?.coordinate.latitude ?? 0.0, // Fixed typo: was "latutde"
                    placemark.location?.coordinate.longitude ?? 0.0 // Fixed: was using latitude instead of longitude
                ),
                RegionRadius: (placemark.region as? CLCircularRegion)?.radius,
                Name: placemark.name,
                ThoroughFare: placemark.thoroughfare,
                SubThoroughFare: placemark.subThoroughfare,
                Locality: placemark.locality,
                SubLocality: placemark.subLocality,
                AdministrativeArea: placemark.administrativeArea,
                SubAdministrativeArea: placemark.subAdministrativeArea,
                PostalCode: placemark.postalCode,
                Country: placemark.country,
                IsoCountryCode: placemark.isoCountryCode,
                TimeZone: placemark.timeZone?.identifier,
                InlandWater: placemark.inlandWater,
                Ocean: placemark.ocean
            )
            return locationInfo
        } catch {
            print("Reverse geocoding error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - END Utilities

}



#Preview {
    return PublicMapView()
}
