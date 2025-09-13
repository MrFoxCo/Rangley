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
import Amplify
import UIKit
import AWSPluginsCore


@MainActor
public struct PublicMapView: View
{
    private struct RefreshShim: View {
        let onRefresh: () async -> Void
        var body: some View {
            ScrollView { Color.clear.frame(height: 1) }
                .refreshable { await onRefresh() }
                .allowsHitTesting(false)
        }
    }

    
    // =========================================================
    // MARK: - Managing Taps
    // =========================================================
    @State private var tapTask: Task<Void, Never>?
    private func handleMapTap(_ proxy: MapProxy, _ value: SpatialTapGesture.Value) {
        guard !showLocationPopup && !showMeetOverlay else { return }
        
        // cancel previous debounce
        tapTask?.cancel()
        tapTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            
            let position = value.location
            if let coordinate = proxy.convert(position, from: .local) {
                let geocoder = CLGeocoder()
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                if let locationInfo = await createLocationInfoObject(geocoder, location) {
                    await MainActor.run {
                        selectedLocation = locationInfo
                        showLocationPopup = true
                    }
                }
            }
        }
    }
    // =========================================================
    // MARK: - END Managing Taps
    // =========================================================
    @State private var geocodeCache: [String: LocationInfo] = [:]
    //    @State private var geocodeCache: [String: LocationInfo] = [:] {
    //        didSet {
    //            // Limit cache to 100 entries
    //            if geocodeCache.count > 100 {
    //                let keysToRemove = Array(geocodeCache.keys.prefix(20))
    //                keysToRemove.forEach { geocodeCache.removeValue(forKey: $0) }
    //            }
    //        }
    //    }
    
    // =========================================================
    // MARK: - USER LOCATION
    // =========================================================
    @StateObject private var lm = LocationManager()
    
    
    
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.9211, longitude: -87.6338),
        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04) // ~3 mile radius
    ))
    
    @State private var selectedAnchor: CGPoint?
    
    // MARK: - END Map Location
    
    // Keep this in PublicMapView so helpers can see it
    @State private var lastSpan = MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    // =========================================================
    // MARK: - END USER LOCATION
    // =========================================================
    
    // =========================================================
    // MARK: - Meet Creation FLow
    // =========================================================
    @State private var selectedLocation: LocationInfo?
    @State private var showLocationPopup = false
    
    // PublicMapView.swift
    private func submitMeet(
        locationInfo: LocationInfo,name: String,
        startTime: Date,endTime: Date) async throws
    {
        // Derive required fields (non-optionals)
        let lat  = locationInfo.Coordinate.latitude
        let lon  = locationInfo.Coordinate.longitude
        let rLat = locationInfo.RegionCoordinate.latitude
        let rLon = locationInfo.RegionCoordinate.longitude
        let rRad = (locationInfo.RegionRadius ?? 500.0).rounded()
        
        // Optional placeholders
        let description   = ""
        let changeReason  = "initial create"
        let meetCategoryId: Int16 = 1
        let maxCapacity  : Int32 = 8
        
        // (Optional) print sanity
        print("""
        Creating meet (print-test):
          Name            : \(name)
          Location Name   : \(locationInfo.Name ?? "Unknown")
          Start (UTC)     : \(startTime)
          End (UTC)       : \(endTime)
          lat/lon         : \(lat), \(lon)
          region lat/lon  : \(rLat), \(rLon)
          region radius   : \(Int(rRad)) m
          description     : \(description.isEmpty ? "(empty)" : description)
          change_reason   : \(changeReason)
          category_id     : \(meetCategoryId)
          max_capacity    : \(maxCapacity)
        """)
        
        // Build body
        let body = MeetInsertBody(
            latitude: lat,
            longitude: lon,
            region_latitude: rLat,
            region_longitude: rLon,
            region_radius: rRad,
            name: name,
            dttm_start_utc: startTime,
            dttm_end_utc: endTime,
            description: description,
            change_reason: changeReason,
            meet_category_id: meetCategoryId,
            max_capacity: maxCapacity
        )
        
        // Token + API
        let session = try await Amplify.Auth.fetchAuthSession()
        guard let provider = session as? AuthCognitoTokensProvider else {
            throw AuthAPIError.http(-1, "No Cognito token provider")
        }
        let tokens = try provider.getCognitoTokens().get()
        let idToken = tokens.idToken
        
        let res = try await AuthAPI.createMeet(baseURL: Env.apiBaseURL, token: idToken, body: body)
        print("✅ /s/meet OK → meet_id:\(res.meet_id) coord_id:\(res.meet_coordinate_id)")
    }
    
    // Add this after your @State variables and before submitMeet
    @State private var currentRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.9211, longitude: -87.6338),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )
    private func isInVisibleRegion(_ meet: ViewMeetsModel) -> Bool {
        let r = currentRegion
        let latMin = r.center.latitude  - r.span.latitudeDelta  / 2
        let latMax = r.center.latitude  + r.span.latitudeDelta  / 2
        let lonMin = r.center.longitude - r.span.longitudeDelta / 2
        let lonMax = r.center.longitude + r.span.longitudeDelta / 2

        return meet.latitude  >= latMin && meet.latitude  <= latMax &&
               meet.longitude >= lonMin && meet.longitude <= lonMax
    }


    private func checkBounds(meet: ViewMeetsModel, region: MKCoordinateRegion) -> Bool
    {
        let meetCoordinate = CLLocationCoordinate2D(latitude: meet.latitude, longitude: meet.longitude)
        
        let latMin = region.center.latitude - region.span.latitudeDelta / 2
        let latMax = region.center.latitude + region.span.latitudeDelta / 2
        let lonMin = region.center.longitude - region.span.longitudeDelta / 2
        let lonMax = region.center.longitude + region.span.longitudeDelta / 2
        
        return meetCoordinate.latitude >= latMin && meetCoordinate.latitude <= latMax &&
        meetCoordinate.longitude >= lonMin && meetCoordinate.longitude <= lonMax
    }
    
    // =========================================================
    // MARK: - END Meet Creation FLow
    // =========================================================
    
    // =========================================================
    // MARK: - Display MeetMarkers + MeetCard
    // =========================================================
    @State private var meets: [ViewMeetsModel] = []
    @State private var meetsError: String?
    @State private var isLoadingMeets = false
    
    // Bubble → Card morph
    @State private var selectedMeet: ViewMeetsModel?
    @State private var showMeetOverlay = false
    @Namespace private var meetNS
    
    // Loader
    private func fetchIdToken() async throws -> String {
        let session = try await Amplify.Auth.fetchAuthSession()
        guard let provider = session as? AuthCognitoTokensProvider else {
            throw AuthAPIError.http(-1, "No Cognito token provider")
        }
        return try provider.getCognitoTokens().get().idToken
    }
    
    private func loadMeets() async {
        guard !isLoadingMeets else { return }
        isLoadingMeets = true; defer { isLoadingMeets = false }
        do {
            let token: String = try await fetchIdToken()
            let rows: [ViewMeetsModel] = try await AuthAPI.viewMeets(baseURL: Env.apiBaseURL, token: token)
            meets = rows
            meetsError = nil
        } catch {
            meetsError = String(describing: error)
        }
    }
    // =========================================================
    // MARK: - END Display MeetMarkers + MeetCard
    // =========================================================
    
    // =========================================================
    // MARK: - Meets in Radius
    // =========================================================
    @State private var selectedRadius: Double = 2.0 // Default 2 mile radius
    @State private var userLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 41.9211, longitude: -87.6338) // Default to Lincoln Park
    // =========================================================
    // MARK: - END Meets in Radius
    // =========================================================
    
    // =========================================================
    // MARK: - Hamburger Menu
    // =========================================================
    @State private var showStart        = false
    @State private var signingOut       = false
    @State private var confirmSignOut   = false
    
    private func signOutAndGoStart()
    {
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
                    Map(position: $cameraPosition)
                    {
                        ForEach(meets.filter { isInVisibleRegion($0) }, id: \.meet_id)
                        { meet in
                            Annotation(
                                meet.name,
                                coordinate: CLLocationCoordinate2D(latitude: meet.latitude, longitude: meet.longitude),
                                anchor: .bottom // or .top, experiment with different anchors
                            ) {
                                MeetBubbleButton(meet: meet, ns: meetNS) {
                                    selectedMeet = meet
                                    showMeetOverlay = true
                                }
                            }
                        }
                    }
                    .onMapCameraChange(frequency: .onEnd) { ctx in
                        lastSpan = ctx.region.span
                        currentRegion = ctx.region
                    }
                    .onTapGesture { location in
                        Task {
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s - let button taps process first
                            guard !showLocationPopup && !showMeetOverlay else { return }
                            
                            // cancel previous debounce
                            tapTask?.cancel()
                            tapTask = Task {
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s - debounce delay
                                
                                if let coordinate = proxy.convert(location, from: .local) {
                                    let geocoder = CLGeocoder()
                                    let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                                    if let locationInfo = await createLocationInfoObject(geocoder, clLocation) {
                                        await MainActor.run {
                                            selectedLocation = locationInfo
                                            showLocationPopup = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .ignoresSafeArea()
                }
            }
            // Nearby Meets Badge - positioned in top-right
            VStack {
                HStack {
                    Spacer()
                    
                    NearbyMeetsBadgeView(
                        meets: meets,
                        userLocation: userLocation,
                        selectedRadius: $selectedRadius
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                Spacer()
            }
            .allowsHitTesting(!showMeetOverlay && !showLocationPopup)
            // ADD THIS: Pink location popup overlay
            MeetCreationOverlay(
                selectedLocation: $selectedLocation,
                showPopup: $showLocationPopup,
                onCreateMeet: { location, name, start, end in
                    Task {
                        do
                        {
                            try await submitMeet(locationInfo: location, name: name, startTime: start, endTime: end)
                        }
                        catch { print("createMeet error:", error) }
                    }
                }
            )
            // Meet viewer overlay (bubble → card morph)
            MeetCardOverlay(selectedMeet: $selectedMeet, isPresented: $showMeetOverlay, ns: meetNS)
                .allowsHitTesting(showMeetOverlay) // keep map taps working when hidden
            // Add this after MeetCardOverlay in your ZStack
            if isLoadingMeets {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading meets...")
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
            }
            
            
        }
        .onAppear { lm.requestWhenInUse() }

        .task(id: lm.userLocation) {
            if let c = lm.userLocation?.coordinate {
                userLocation = c
                cameraPosition = .region(.init(center: c, span: .init(latitudeDelta: 0.04, longitudeDelta: 0.04)))
            }
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
        // Load on appear
        .task { await loadMeets() }
        .overlay(RefreshShim(onRefresh: { await loadMeets() }))
    }
    
    // =========================================================
    // MARK: - END Body (your existing body stays below)
    // =========================================================
    
    
    // THIS IS FIRST THING GENERATED NEED FOR MEET CREATION
    
    private func createLocationInfoObject(_ geocoder: CLGeocoder, _ location: CLLocation) async -> LocationInfo?
    {
        let cacheKey = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        
        // Check cache first
        if let cached = geocodeCache[cacheKey] {
            print("Using cached location info")
            return cached
        }
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
            await MainActor.run {
                geocodeCache[cacheKey] = locationInfo
            }
            
            return locationInfo
        } catch {
            print("Reverse geocoding error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - END Utilities
}
//#Preview {
//    return PublicMapView()
//}
