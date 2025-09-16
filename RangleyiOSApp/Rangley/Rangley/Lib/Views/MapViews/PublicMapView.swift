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

// =========================================================
// =========================================================
// =========================================================
// MARK: - IGNORE THE BELOW TODOs FOR NOW
// TODO: - FIGURE OUT A WAY TO TRIGER UPDATES ON OTHER PHONES WHEN MEETS ARE CREATED OR UPDATED
// TODO: - Fix the rotating screen view -- probably should look to be vertical
// TODO: - Create UNDO for deletes and updates
// TODO: - Create UNDO for deletes and updates
// TODO: - Fix recenter compass top right
// TODO: - return to user tap
// TODO: - Remeber User when Login Option and for Create New Account
// MARK: - IGNORE THE ABOVE TODOs FOR NOW
// =========================================================
// =========================================================
// =========================================================
@MainActor
public struct PublicMapView: View
{
    //@EnvironmentObject private var session: SessionModel
    
    
    
    // =========================================================
    // MARK: - Managing Taps
    // =========================================================
    @State private var tapTask: Task<Void, Never>?
    private func handleMapTap(_ proxy: MapProxy, _ value: SpatialTapGesture.Value)
    {
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
    
    // =========================================================
    // MARK: - USER LOCATION
    // =========================================================
    @StateObject private var lm = LocationManager()
    
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.9211, longitude: -87.6338),
        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04) // ~3 mile radius
    ))
    
    @State private var selectedAnchor: CGPoint?
    
    // Keep this in PublicMapView so helpers can see it
    @State private var lastSpan = MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    
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
        let rRad = (locationInfo.RegionRadius).rounded()
        
        // Optional placeholders
        let description   = ""
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

        // or
        let res = try await AuthAPI.createMeet(baseURL: Env.apiBaseURL, token: idToken, body: body)
        print("inserted: \(res.num_inserted)")
    }
    
    // Add this after your @State variables and before submitMeet
    @State private var currentRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.9211, longitude: -87.6338),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )
    private func isInVisibleRegion(_ meet: ViewMeetsModel) -> Bool
    {
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
    
    private func seedFromUser() -> LocationInfo?
    {
        guard let c = lm.userLocation?.coordinate else { return nil }
        let coord = Coordinate(c.latitude, c.longitude)
        return LocationInfo(
            Coordinate: coord, RegionCoordinate: coord, RegionRadius: 600,
            Name: nil, ThoroughFare: nil, SubThoroughFare: nil,
            Locality: nil, SubLocality: nil, AdministrativeArea: nil,
            SubAdministrativeArea: nil, PostalCode: nil, Country: nil,
            IsoCountryCode: nil, TimeZone: nil, InlandWater: nil, Ocean: nil
        )
    }

    
    // =========================================================
    // MARK: - END Meet Creation FLow
    // =========================================================
    // =========================================================
    // MARK: - Meet Creation No Tap Flow
    // =========================================================
    @State private var showCreateForm = false

    private func seedForCreate() -> LocationInfo?
    {
        if let sel = selectedLocation { return sel }     // from tap, if any
        if let user = seedFromUser() { return user }     // your helper
        // fall back to current map center
        let c = currentRegion.center
        let coord = Coordinate(c.latitude, c.longitude)
        return LocationInfo(
            Coordinate: coord, RegionCoordinate: coord, RegionRadius: 600,
            Name: nil, ThoroughFare: nil, SubThoroughFare: nil, Locality: nil, SubLocality: nil,
            AdministrativeArea: nil, SubAdministrativeArea: nil, PostalCode: nil,
            Country: nil, IsoCountryCode: nil, TimeZone: nil, InlandWater: nil, Ocean: nil
        )
    }
    
    // =========================================================
    // MARK: - END Meet Creation No Tap Flow
    // =========================================================
    
    // =========================================================
    // MARK: - Edit Meet FLow
    // =========================================================
    
    @State private var showEditSheet = false
    // Add these state variables to PublicMapView
    @State private var isDeletingMeet = false
    @State private var deleteError: String?
    
    @MainActor
    private func deleteMeet(_ meet: ViewMeetsModel) async
    {
        guard !isDeletingMeet else { return }
        
        isDeletingMeet = true
        deleteError = nil
        
        do {
            let deleteBody = DeletedMeetInsertBody(meet_id_uuid: meet.id)
            let token = try await fetchIdToken()
            
            _ = try await AuthAPI.deleteMeet(
                baseURL: Env.apiBaseURL,
                token: token,
                body: deleteBody
            )
            
            await loadMeets()
            
            // Clean up UI state
            showMeetOverlay = false
            selectedMeet = nil
            deleteError = nil
            
        } catch {
            deleteError = error.localizedDescription
        }
        
        isDeletingMeet = false
    }
    
    // =========================================================
    // MARK: - END Edit Meet FLow
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
    private func fetchIdToken() async throws -> String
    {
        let session = try await Amplify.Auth.fetchAuthSession()
        guard let provider = session as? AuthCognitoTokensProvider else {
            throw AuthAPIError.http(-1, "No Cognito token provider")
        }
        return try provider.getCognitoTokens().get().idToken
    }
    
    private func loadMeets() async
    {
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
    // MARK: - Meets in Radius / NearbyMeetsBadge
    // =========================================================
    @State private var selectedRadius: Double = 2.0 // Default 2 mile radius
    
    // TODO: what is this used for??
    @State private var userLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 41.9211, longitude: -87.6338) // Default to Lincoln Park
    
    // Add these with your other @State variables
    @State private var isBadgeExpanded = false
    @State private var showBadgeRadiusSelector = false
    // =========================================================
    // MARK: - END Meets in Radius / NearbyMeetsBadge
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
                    { // MARK: WARNING THIS TAKES FOREVER TO COMPILE -- COMMENT OUT IF BUILD IS STALLING
                        ForEach(meets.filter { isInVisibleRegion($0) })
                        { meet in
                            Annotation(
                                meet.name,
                                coordinate: CLLocationCoordinate2D(latitude: meet.latitude, longitude: meet.longitude),
                                anchor: .center // Instead of .bottom
                            ) {
                                MeetBubbleButton(meet: meet, ns: meetNS) {
                                    selectedMeet = meet
                                    showMeetOverlay = true
                                }
                            }
                        }
                        UserAnnotation() // THIS IS HOW WE DISPLAY THE USER'S LOCATION
                    }
                    .onMapCameraChange(frequency: .onEnd) { ctx in
                        lastSpan = ctx.region.span
                        currentRegion = ctx.region
                    }
                    .onTapGesture { location in
                        Task {
                            try? await Task.sleep(nanoseconds: 200_000_000) // Increase delay to 0.2s
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
                    .simultaneousGesture(
                        // This allows both gestures to work
                        TapGesture().onEnded { _ in }
                    )
                }
            }
            // Nearby Meets Badge - positioned in top-right
            VStack
            {
                HStack {
                    Spacer()
                    
                    NearbyMeetsBadgeView(
                        meets: meets,
                        userLocation: userLocation,
                        selectedRadius: $selectedRadius,
                        onExpandedChange: { isExpanded in
                            isBadgeExpanded = isExpanded
                        },
                        onRadiusSelectorChange: { showSelector in
                            showBadgeRadiusSelector = showSelector
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                Spacer()
            }
            .allowsHitTesting(!showMeetOverlay && !showLocationPopup)
            // ADD THIS: Pink location popup overlay
            MeetCreationOverlayByTap(
                selectedLocation: $selectedLocation,
                showPopup: $showLocationPopup,
                onCreateMeet: { location, name, start, end in
                    Task {
                        do
                        {
                            try await submitMeet(locationInfo: location, name: name, startTime: start, endTime: end)
                            await loadMeets() // refresh screen when new meets?
                        }
                        catch { print("createMeet error:", error) }
                    }
                }
            )
            // Meet viewer overlay (bubble → card morph)
            MeetCardOverlay(
                selectedMeet: $selectedMeet,
                isPresented: $showMeetOverlay,
                ns: meetNS,
                onEdit: { meet in
                    selectedMeet = meet
                    showEditSheet = true
                },
                onDelete: { meet in
                    Task {
                        await deleteMeet(meet)
                    }
                }
            )
            .allowsHitTesting(showMeetOverlay)
            .sheet(isPresented: $showCreateForm) {
                MeetCreationFormView(
                    mode: .create(location: seedForCreate()),
                    onCreate: { body in
                        let token = try await fetchIdToken()
                        _ = try await AuthAPI.createMeet(baseURL: Env.apiBaseURL, token: token, body: body)
                        await loadMeets()                 // refresh after success
                    },
                    onClose: { showCreateForm = false },
                    onPickLocation: nil  // uses your existing picker bridge

                   // onPickLocation: { await pickLocation() }   // uses your existing picker bridge
                )
            }
            .sheet(isPresented: $showEditSheet)
            {
                if let editing = selectedMeet {
                    MeetFormView(
                        mode: .update(existing: editing),
                        onUpdate: { body in
                            let token = try await fetchIdToken()
                            _ = try await AuthAPI.updateMeet(baseURL: Env.apiBaseURL, token: token, body: body)
                            await loadMeets()
                            await MainActor.run {
                                showEditSheet = false
                                showMeetOverlay = false
                            }
                        },
                        onClose: { showEditSheet = false },
                        onPickLocation: nil
                        // onPickLocation: { await editMeetPickLocation() } // if you have one
                    )
                }
            }
            // Add this after MeetCardOverlay in your ZStack
            if isLoadingMeets
            {
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
        // RELOAD BUTTON
        .overlay(alignment: .topLeading) {
            // Hide reload button when any overlay is active OR badge is expanded
            if !showMeetOverlay && !showLocationPopup && !showEditSheet && !isBadgeExpanded && !showBadgeRadiusSelector {
                NeonReloadButton(isLoading: isLoadingMeets) {
                    Task { await loadMeets() }
                }
                .padding(.top, 16)
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showMeetOverlay)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showLocationPopup)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showEditSheet)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isBadgeExpanded)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showBadgeRadiusSelector)
            }
        }
        .onAppear { lm.requestWhenInUse() }
        .task(id: lm.userLocation)
        {
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
                DockView(
                    onSignOut: { signOutAndGoStart() },
                    onSearch:  { print("Search tapped") },
                    onCreateMeet: { showCreateForm = true }
                )
                Spacer()
            }
            .padding(.bottom, 8)
        }
        .confirmationDialog("Sign out?", isPresented: $confirmSignOut)
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
        //.overlay(RefreshShim(onRefresh: { await loadMeets() }))
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
            
            let pinCoord = location.coordinate
            let regionRadius: Double = (placemark.region as? CLCircularRegion)?.radius ?? 500.0

            let locationInfo = LocationInfo(
                Coordinate: Coordinate(pinCoord.latitude, pinCoord.longitude),
                RegionCoordinate: Coordinate(pinCoord.latitude, pinCoord.longitude), // ← center at the pin
                RegionRadius: regionRadius,
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
