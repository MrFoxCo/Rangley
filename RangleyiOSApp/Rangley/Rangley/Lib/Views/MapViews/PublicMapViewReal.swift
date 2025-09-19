////
////  PublicMapView 2.swift
////  Rangley
////
////  Created by Anthony Guzzardo on 9/18/25.
////
//
//
////
////  ContentView.swift
////  Rangley
////
////  Created by Anthony Guzzardo on 7/1/25.
////
//import CoreLocation
//import MapKit
//import SwiftUI
//import Foundation
//import Amplify
//import UIKit
//import AWSPluginsCore
//
//// =========================================================
//// =========================================================
//// =========================================================
//// MARK: - IGNORE THE BELOW TODOs FOR NOW
//// TODO: - FIGURE OUT A WAY TO TRIGER UPDATES ON OTHER PHONES WHEN MEETS ARE CREATED OR UPDATED
//// TODO: - Fix the rotating screen view -- probably should look to be vertical
//// TODO: - Create UNDO for deletes and updates
//// TODO: - Create UNDO for deletes and updates
//// TODO: - Fix recenter compass top right
//// TODO: - return to user tap
//// TODO: - Remeber User when Login Option and for Create New Account
//// TODO: - NEED TO ADD categories and max capacties as options
//// TODO: - Figure out why the forms are slightly lagging between continues
//// TODO: - MASSIVE ISSUE THE REFRESH TOKEN ISN'T REFRESHING THE SESSION BASICALLY EXPIRES AND CAN'T TALK TO SERVER
//// MARK: - IGNORE THE ABOVE TODOs FOR NOW
//// =========================================================
//// =========================================================
//// =========================================================
//@MainActor
//public struct PublicMapView: View
//{
//    
//    // =========================================================
//    // MARK: - Map Component Rendering
//    // =========================================================
//    
//    
//    // =========================================================
//    // MARK: - Map Component Rendering
//    // =========================================================
//    
//    //@EnvironmentObject private var session: SessionModel
//    // =========================================================
//    // MARK: - Toggle Day Night Theme
//    // =========================================================
//    
//    @State private var clock: Date = .init()
//    private let dayNightTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect() // 5 min
//
//    private var isDaylight: Bool {
//        // Simple heuristic: 6am ≤ local time < 8pm
//        let hour = Calendar.current.component(.hour, from: clock)
//        return hour >= 6 && hour < 20
//    }
//
//    // =========================================================
//    // MARK: - END Toggle Day Night Theme
//    // =========================================================
//    
//    // =========================================================
//    // MARK: - Managing Taps
//    // =========================================================
//    @State private var tapTask: Task<Void, Never>?
//    private func handleMapTap(_ proxy: MapProxy, _ value: SpatialTapGesture.Value)
//    {
//        guard !showLocationPopup && !showMeetOverlay else { return }
//        
//        // cancel previous debounce
//        tapTask?.cancel()
//        tapTask = Task {
//            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
//            
//            let position = value.location
//            if let coordinate = proxy.convert(position, from: .local) {
//                let geocoder = CLGeocoder()
//                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
//                if let locationInfo = await createLocationInfoObject(geocoder, location) {
//                    await MainActor.run {
//                        selectedLocation = locationInfo
//                        showLocationPopup = true
//                    }
//                }
//            }
//        }
//    }
//    // =========================================================
//    // MARK: - END Managing Taps
//    // =========================================================
//    
//    // =========================================================
//    // MARK: - USER LOCATION
//    // =========================================================
//    @StateObject private var lm = LocationManager()
//    
//    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
//        center: CLLocationCoordinate2D(latitude: 41.9211, longitude: -87.6338),
//        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04) // ~3 mile radius
//    ))
//    
//    @State private var selectedAnchor: CGPoint?
//    
//    // Keep this in PublicMapView so helpers can see it
//    @State private var lastSpan = MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
//    
//    @State private var geocodeCache: [String: LocationInfo] = [:]
//    //    @State private var geocodeCache: [String: LocationInfo] = [:] {
//    //        didSet {
//    //            // Limit cache to 100 entries
//    //            if geocodeCache.count > 100 {
//    //                let keysToRemove = Array(geocodeCache.keys.prefix(20))
//    //                keysToRemove.forEach { geocodeCache.removeValue(forKey: $0) }
//    //            }
//    //        }
//    //    }
//    // =========================================================
//    // MARK: - END USER LOCATION
//    // =========================================================
//    
//    // =========================================================
//    // MARK: - Meet Creation FLow
//    // =========================================================
//    @State private var selectedLocation: LocationInfo?
//    @State private var showLocationPopup = false
//    
//
//    private func createMeetOnly(
//        locationInfo: LocationInfo,name: String,startTime: Date,endTime:Date) async throws
//    {
//        
//        let body = buildMeetBody(
//            locationInfo: locationInfo,
//            name: name,
//            startTime: startTime,
//            endTime: endTime
//        )
//        
//        let idToken = try await fetchIdToken()
//        
//        let res = try await AuthAPI.createMeet(
//            baseURL: Env.apiBaseURL,
//            token: idToken,
//            body: body
//        )
//        
//        print("Meet created: \(res.num_inserted)")
//    }
//
//    private func createMeetWithInvites(
//        locationInfo: LocationInfo, name: String,
//        startTime: Date,endTime: Date,invitedUsers: [UUID]
//    ) async throws
//    {
//        
//        let body = buildMeetWithInvitesBody(
//            locationInfo: locationInfo,
//            name: name,
//            startTime: startTime,
//            endTime: endTime,
//            invitedUsers: invitedUsers
//        )
//        
//        let idToken = try await fetchIdToken()
//        
//        let res = try await AuthAPI.createMeetWithInvites(
//            baseURL: Env.apiBaseURL,
//            token: idToken,
//            body: body
//        )
//        
//        print("Meet with invites created: \(res.num_inserted)")
//    }
//
//    // MARK: - Helper Functions
//
//    private func buildMeetBody(
//        locationInfo: LocationInfo,
//        name: String,
//        startTime: Date,
//        endTime: Date
//    ) -> MeetInsertBody
//    {
//        
//        let lat = locationInfo.Coordinate.latitude
//        let lon = locationInfo.Coordinate.longitude
//        let rLat = locationInfo.RegionCoordinate.latitude
//        let rLon = locationInfo.RegionCoordinate.longitude
//        let rRad = locationInfo.RegionRadius.rounded()
//        
//        return MeetInsertBody(
//            latitude: lat,
//            longitude: lon,
//            region_latitude: rLat,
//            region_longitude: rLon,
//            region_radius: rRad,
//            name: name,
//            dttm_start_utc: startTime,
//            dttm_end_utc: endTime,
//            description: "", // TODO: Add logic to incorporate these
//            meet_category_id: 1,
//            max_capacity: 8
//        )
//    }
//
//    private func buildMeetWithInvitesBody(
//        locationInfo: LocationInfo,
//        name: String,
//        startTime: Date,
//        endTime: Date,
//        invitedUsers: [UUID]
//    ) -> MeetWithInvitesInsertBody
//    {
//        
//        let lat = locationInfo.Coordinate.latitude
//        let lon = locationInfo.Coordinate.longitude
//        let rLat = locationInfo.RegionCoordinate.latitude
//        let rLon = locationInfo.RegionCoordinate.longitude
//        let rRad = locationInfo.RegionRadius.rounded()
//        
//        return MeetWithInvitesInsertBody(
//            initial_invitee_uuids: invitedUsers,
//            latitude: lat,
//            longitude: lon,
//            region_latitude: rLat,
//            region_longitude: rLon,
//            region_radius: rRad,
//            name: name,
//            dttm_start_utc: startTime,
//            dttm_end_utc: endTime,
//            description: "",
//            meet_category_id: 1,
//            max_capacity: 8,
//            invitation_message: ""
//        )
//    }
//
//    // MARK: - Form Handler
//
//    private func handleMeetSubmission(
//        locationInfo: LocationInfo, name: String,
//        startTime: Date, endTime: Date, invitedUsers: [ViewUsersModel]
//    ) async throws
//    {
//        
//        let invitedUserUUIDs = invitedUsers.map(\.user_uuid)
//        
//        print("=== Meet Submission Debug ===")
//        print("Invited users count: \(invitedUsers.count)")
//        print("Invited UUIDs count: \(invitedUserUUIDs.count)")
//        print("UUIDs isEmpty: \(invitedUserUUIDs.isEmpty)")
//        print("Will use createMeetOnly: \(invitedUserUUIDs.isEmpty)")
//
//        // Decision logic at the form level
//        if invitedUserUUIDs.isEmpty
//        {
//            print("→ Calling createMeetOnly")
//            try await createMeetOnly(
//                locationInfo: locationInfo,
//                name: name,
//                startTime: startTime,
//                endTime: endTime
//            )
//        } else
//        {
//            print("→ Calling createMeetWithInvites")
//            try await createMeetWithInvites(
//                locationInfo: locationInfo,
//                name: name,
//                startTime: startTime,
//                endTime: endTime,
//                invitedUsers: invitedUserUUIDs
//            )
//            //try? await Task.sleep(nanoseconds: 500_000_000)
//        }
//    }
//    
//    // Add this after your @State variables and before submitMeet
//    @State private var currentRegion = MKCoordinateRegion(
//        center: CLLocationCoordinate2D(latitude: 41.9211, longitude: -87.6338),
//        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
//    )
//    private func isInVisibleRegion(_ meet: ViewMeetsModel) -> Bool
//    {
//        let r = currentRegion
//        let latMin = r.center.latitude  - r.span.latitudeDelta  / 2
//        let latMax = r.center.latitude  + r.span.latitudeDelta  / 2
//        let lonMin = r.center.longitude - r.span.longitudeDelta / 2
//        let lonMax = r.center.longitude + r.span.longitudeDelta / 2
//
//        return meet.latitude  >= latMin && meet.latitude  <= latMax &&
//               meet.longitude >= lonMin && meet.longitude <= lonMax
//    }
//
//
//    private func checkBounds(meet: ViewMeetsModel, region: MKCoordinateRegion) -> Bool
//    {
//        let meetCoordinate = CLLocationCoordinate2D(latitude: meet.latitude, longitude: meet.longitude)
//        
//        let latMin = region.center.latitude - region.span.latitudeDelta / 2
//        let latMax = region.center.latitude + region.span.latitudeDelta / 2
//        let lonMin = region.center.longitude - region.span.longitudeDelta / 2
//        let lonMax = region.center.longitude + region.span.longitudeDelta / 2
//        
//        return meetCoordinate.latitude >= latMin && meetCoordinate.latitude <= latMax &&
//        meetCoordinate.longitude >= lonMin && meetCoordinate.longitude <= lonMax
//    }
//    
//    private func seedFromUser() -> LocationInfo?
//    {
//        guard let c = lm.userLocation?.coordinate else { return nil }
//        let coord = Coordinate(c.latitude, c.longitude)
//        return LocationInfo(
//            Coordinate: coord, RegionCoordinate: coord, RegionRadius: 600,
//            Name: nil, ThoroughFare: nil, SubThoroughFare: nil,
//            Locality: nil, SubLocality: nil, AdministrativeArea: nil,
//            SubAdministrativeArea: nil, PostalCode: nil, Country: nil,
//            IsoCountryCode: nil, TimeZone: nil, InlandWater: nil, Ocean: nil
//        )
//    }
//
//    
//    // =========================================================
//    // MARK: - END Meet Creation FLow
//    // =========================================================
//    // =========================================================
//    // MARK: - Meet Creation No Tap Flow
//    // =========================================================
//    
//    @State private var showCreateForm = false
//    
//    private func seedForCreate() -> LocationInfo?
//    {
//        if let sel = selectedLocation { return sel }     // from tap, if any
//        if let user = seedFromUser() { return user }     // your helper
//        // fall back to current map center
//        let c = currentRegion.center
//        let coord = Coordinate(c.latitude, c.longitude)
//        return LocationInfo(
//            Coordinate: coord, RegionCoordinate: coord, RegionRadius: 600,
//            Name: nil, ThoroughFare: nil, SubThoroughFare: nil, Locality: nil, SubLocality: nil,
//            AdministrativeArea: nil, SubAdministrativeArea: nil, PostalCode: nil,
//            Country: nil, IsoCountryCode: nil, TimeZone: nil, InlandWater: nil, Ocean: nil
//        )
//    }
//    
//    
//    // =========================================================
//    // MARK: - END Meet Creation No Tap Flow
//    // =========================================================
//    
//    // =========================================================
//    // MARK: - Edit Meet FLow
//    // =========================================================
//    
//    // Add these state variables to PublicMapView
//    @State private var showEditSheet = false
//    @State private var isDeletingMeet = false
//    @State private var deleteError: String?
//    
//    @MainActor
//    private func deleteMeet(_ meet: ViewMeetsModel) async
//    {
//        guard !isDeletingMeet else { return }
//        
//        isDeletingMeet = true
//        deleteError = nil
//        
//        do {
//            let deleteBody = DeletedMeetInsertBody(meet_id_uuid: meet.id)
//            let token = try await fetchIdToken()
//            
//            _ = try await AuthAPI.deleteMeet(
//                baseURL: Env.apiBaseURL,
//                token: token,
//                body: deleteBody
//            )
//            
//            await loadMeets()
//            
//            // Clean up UI state
//            showMeetOverlay = false
//            selectedMeet = nil
//            deleteError = nil
//            
//        } catch {
//            deleteError = error.localizedDescription
//        }
//        
//        isDeletingMeet = false
//    }
//    
//    // =========================================================
//    // MARK: - END Edit Meet FLow
//    // =========================================================
//
//    // =========================================================
//    // MARK: - Display MeetMarkers + MeetCard
//    // =========================================================
//    @State private var meets: [ViewMeetsModel] = []
//    @State private var meetsError: String?
//    @State private var isLoadingMeets = false
//    
//    // Bubble → Card morph
//    @State private var selectedMeet: ViewMeetsModel?
//    @State private var showMeetOverlay = false
//    @Namespace private var meetNS
//    
//    // Loader
//    private func fetchIdToken() async throws -> String
//    {
//        let session = try await Amplify.Auth.fetchAuthSession()
//        guard let provider = session as? AuthCognitoTokensProvider else {
//            throw AuthAPIError.http(-1, "No Cognito token provider")
//        }
//        return try provider.getCognitoTokens().get().idToken
//    }
//    
//    private func loadMeets() async {
//        guard !isLoadingMeets else { return }
//        isLoadingMeets = true
//        defer { isLoadingMeets = false }
//
//        do {
//            let token = try await fetchIdToken()
//            let rows: [ViewMeetsModel] = try await AuthAPI.viewMeets(baseURL: Env.apiBaseURL, token: token)
//
//            // assign
//            meets = rows
//
//            // re-hydrate currently selected meet (if any)
//            if let sel = selectedMeet,
//               let refreshed = rows.first(where: { $0.meet_id_uuid == sel.meet_id_uuid }) {
//                selectedMeet = refreshed
//            }
//
//            meetsError = nil
//        } catch {
//            meetsError = String(describing: error)
//        }
//    }
//
//    
//    // =========================================================
//    // MARK: - END Display MeetMarkers + MeetCard
//    // =========================================================
//    
//    // =========================================================
//    // MARK: - Meets in Radius / NearbyMeetsBadge
//    // =========================================================
//    @State private var selectedRadius: Double = 2.0 // Default 2 mile radius
//    
//    // TODO: what is this used for??
//    @State private var userLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 41.9211, longitude: -87.6338) // Default to Lincoln Park
//    
//    // Add these with your other @State variables
//    @State private var isBadgeExpanded = false
//    @State private var showBadgeRadiusSelector = false
//    // =========================================================
//    // MARK: - END Meets in Radius / NearbyMeetsBadge
//    // =========================================================
//    
//    // =========================================================
//    // MARK: - Hamburger Menu
//    // =========================================================
//    @State private var showStart        = false
//    @State private var signingOut       = false
//    @State private var confirmSignOut   = false
//    
//    private func signOutAndGoStart()
//    {
//        Task {
//            guard !signingOut else { return }
//            signingOut = true; defer { signingOut = false }
//            _ = await Amplify.Auth.signOut()
//            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
//            showStart = true
//        }
//    }
//    
//    // =========================================================
//    // MARK: - END Hamburger Menu
//    // =========================================================
//    
//    // =========================================================
//    // MARK: - DockView Menu
//    // =========================================================
//    @State private var currentToken: String = ""
//    private func ensureToken() async {
//        if currentToken.isEmpty {
//            do {
//                currentToken = try await fetchIdToken()
//            } catch {
//                print("Failed to get token: \(error)")
//            }
//        }
//    }
//    // =========================================================
//    // MARK: - END DockView Menu
//    // =========================================================
//    
//    // =========================================================
//    // MARK: - Body (your existing body stays below)
//    // =========================================================
//    
//    public var body: some View
//    {
//        ZStack
//        {
//            GeometryReader
//            { geo in
//                MapReader
//                { proxy in
//                    Map(position: $cameraPosition)
//                    { // MARK: WARNING THIS TAKES FOREVER TO COMPILE -- COMMENT OUT IF BUILD IS STALLING
//                        ForEach(meets.filter { isInVisibleRegion($0) })
//                        { meet in
//                            Annotation(
//                                meet.name,
//                                coordinate: CLLocationCoordinate2D(latitude: meet.latitude, longitude: meet.longitude),
//                                anchor: .center // Instead of .bottom
//                            ) {
//                                MeetBubbleButton(meet: meet, ns: meetNS) {
//                                    selectedMeet = meet
//                                    showMeetOverlay = true
//                                }
//                            }
//                        }
//                        UserAnnotation() // THIS IS HOW WE DISPLAY THE USER'S LOCATION
//                    }
//                    .environment(\.colorScheme, isDaylight ? .light : .dark)
//                    .onReceive(dayNightTimer) { clock = $0 }
//                    .onMapCameraChange(frequency: .onEnd) { ctx in
//                        lastSpan = ctx.region.span
//                        currentRegion = ctx.region
//                    }
//                    .gesture(
//                        SpatialTapGesture().onEnded { value in
//                            Task {
//                                try? await Task.sleep(nanoseconds: 200_000_000)
//                                guard !showLocationPopup && !showMeetOverlay else { return }
//                                tapTask?.cancel()
//                                tapTask = Task {
//                                    try? await Task.sleep(nanoseconds: 300_000_000)
//                                    let point = value.location
//                                    if let coordinate = proxy.convert(point, from: .local) {
//                                        let geocoder = CLGeocoder()
//                                        let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
//                                        if let locationInfo = await createLocationInfoObject(geocoder, clLocation) {
//                                            await MainActor.run {
//                                                selectedLocation = locationInfo
//                                                showLocationPopup = true
//                                            }
//                                        }
//                                    }
//                                }
//                            }
//                        }
//                    )
//                    .ignoresSafeArea()
//                    .simultaneousGesture(
//                        // This allows both gestures to work
//                        TapGesture().onEnded { _ in }
//                    )
//                }
//            }
//            // Nearby Meets Badge - positioned in top-right
//            VStack
//            {
//                HStack {
//                    Spacer()
//                    
//                    NearbyMeetsBadgeView(
//                        meets: meets,
//                        userLocation: userLocation,
//                        selectedRadius: $selectedRadius,
//                        onExpandedChange: { isExpanded in
//                            isBadgeExpanded = isExpanded
//                        },
//                        onRadiusSelectorChange: { showSelector in
//                            showBadgeRadiusSelector = showSelector
//                        }
//                    )
//                }
//                .padding(.horizontal, 16)
//                .padding(.top, 16)
//                
//                Spacer()
//            }
//            .allowsHitTesting(!showMeetOverlay && !showLocationPopup)
//            // ADD THIS: Pink location popup overlay
//            MeetCreationOverlayByTap(
//                selectedLocation: $selectedLocation,
//                showPopup: $showLocationPopup,
//                baseURL: Env.apiBaseURL, // You'll need to pass this
//                token: currentToken,     // You'll need to pass this
//                onCreateMeet: { location, name, start, end, invitedUsers in
//                    Task {
//                        do {
//                            try await handleMeetSubmission(
//                                locationInfo: location,
//                                name: name,
//                                startTime: start,
//                                endTime: end,
//                                invitedUsers: invitedUsers
//                            )
//                            await loadMeets()
//                        } catch let error as AuthAPIError {
//                            print("Meet creation failed: \(error.errorDescription ?? "Unknown")")
//                            // Show user-friendly error in UI
//                            switch error {
//                            case .http(let code, let reason):
//                                if code == 500 {
//                                    print("Server error - likely stored procedure issue")
//                                }
//                                print("HTTP \(code): \(reason ?? "No details")")
//                            default:
//                                print("Error: \(error)")
//                            }
//                        } catch {
//                            print("Unexpected error: \(error)")
//                        }
//                    }
//                }
//            )
//            // Meet viewer overlay (bubble → card morph)
//            MeetCardOverlay(
//                selectedMeet: $selectedMeet,
//                isPresented: $showMeetOverlay,
//                ns: meetNS,
//                onEdit: { meet in
//                    selectedMeet = meet
//                    showEditSheet = true
//                },
//                onDelete: { meet in
//                    Task {
//                        await deleteMeet(meet)
//                    }
//                }
//            )
//            .allowsHitTesting(showMeetOverlay)
//            // Replace your sheet modifier for showCreateForm with this:
//            .sheet(isPresented: $showCreateForm) {
//                MeetCreationFormView(
//                    mode: .create(location: seedForCreate()),
//                    onCreate: { body in
//                        Task {
//                            do {
//                                // Cache coordinates before async calls
//                                let newLat = body.latitude
//                                let newLon = body.longitude
//                                
//                                let token = try await fetchIdToken()
//                                _ = try await AuthAPI.createMeet(baseURL: Env.apiBaseURL, token: token, body: body)
//                                await loadMeets()
//                                
//                                // Dismiss sheet first, THEN animate camera
//                                await MainActor.run {
//                                    showCreateForm = false
//                                }
//                                
//                                // Add a small delay to ensure sheet is fully dismissed
//                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
//                                
//                                // Now animate to the new location
//                                await MainActor.run {
//                                    withAnimation(.easeInOut(duration: 1.0)) {
//                                        cameraPosition = .region(MKCoordinateRegion(
//                                            center: CLLocationCoordinate2D(latitude: newLat, longitude: newLon),
//                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//                                        ))
//                                    }
//                                }
//                            } catch {
//                                print("createMeet error:", error)
//                            }
//                        }
//                    },
//                    onClose: { showCreateForm = false },
//                    onPickLocation: nil
//                )
//            }
//            // REMOVE or comment out these lines:
//            .sheet(isPresented: $showEditSheet) {
//                if let editing = selectedMeet {
//                    MeetFormView(
//                        mode: .update(existing: editing),
//                        onUpdate: { body in
//                            let token = try await fetchIdToken()
//                            _ = try await AuthAPI.updateMeet(baseURL: Env.apiBaseURL, token: token, body: body)
//                            // Remove this loadMeets call from here
//                        },
//                        onClose: { showEditSheet = false },
//                        onPickLocation: nil,
//                        onLoadMeets: { await loadMeets() }  // Pass the parent's loadMeets
//                    )
//                }
//            }
//            // Add this after MeetCardOverlay in your ZStack
//            if isLoadingMeets
//            {
//                Color.black.opacity(0.3)
//                    .ignoresSafeArea()
//                
//                VStack {
//                    ProgressView()
//                        .scaleEffect(1.5)
//                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                    Text("Loading meets...")
//                        .foregroundColor(.white)
//                        .padding(.top, 8)
//                }
//            }
//        }
//        .environment(\.colorScheme, .dark)
//        // RELOAD BUTTON
//        .overlay(alignment: .topLeading) {
//            // Hide reload button when any overlay is active OR badge is expanded
//            if !showMeetOverlay && !showLocationPopup && !showEditSheet && !isBadgeExpanded && !showBadgeRadiusSelector {
//                NeonReloadButton(isLoading: isLoadingMeets) {
//                    Task { await loadMeets() }
//                }
//                .padding(.top, 16)
//                .padding(.leading, 16)
//                .transition(.opacity.combined(with: .scale(scale: 0.9)))
//                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showMeetOverlay)
//                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showLocationPopup)
//                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showEditSheet)
//                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isBadgeExpanded)
//                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showBadgeRadiusSelector)
//            }
//        }
//        .onAppear { lm.requestWhenInUse() }
//        .task(id: lm.userLocation)
//        {
//            if let c = lm.userLocation?.coordinate {
//                userLocation = c
//                cameraPosition = .region(.init(center: c, span: .init(latitudeDelta: 0.04, longitudeDelta: 0.04)))
//            }
//        }
//        .ignoresSafeArea(.keyboard, edges: .bottom)
//        .toolbarBackground(.visible, for: .tabBar)
//        .toolbarColorScheme(.dark, for: .tabBar)
//        .safeAreaInset(edge: .bottom)
//        {
//            HStack {
//                Spacer()
//                DockView(
//                    baseURL: Env.apiBaseURL,
//                    token: currentToken,
//                    onSignOut: { signOutAndGoStart() },
//                    onCreateMeet: { showCreateForm = true },
//                    onMeetSelected: { meet in
//                        selectedMeet = meet
//                        showMeetOverlay = true
//                    },
//                    onUserSelected: { user in
//                        print("Selected user: \(user.display_name)")
//                        // Handle user selection - maybe show user profile or invite to meet
//                    }
//                )
//                Spacer()
//            }
//            .padding(.bottom, 8)
//        }
//        .confirmationDialog("Sign out?", isPresented: $confirmSignOut)
//        {
//            Button("Sign Out", role: .destructive) { signOutAndGoStart() }
//            Button("Cancel", role: .cancel) { }
//        }
//        // Full-screen handoff to StartScreenView after sign-out
//        .fullScreenCover(isPresented: $showStart)
//        {
//            StartScreenView(onAuthenticated: {      // ← add this
//                showStart = false                   // dismiss after successful auth
//            })
//            .preferredColorScheme(.dark)
//        }
//        // Load on appear
//        .task
//        {
//            await ensureToken()
//            await loadMeets()
//        }
//        .onAppear { clock = Date() }
//        //.overlay(RefreshShim(onRefresh: { await loadMeets() }))
//    }
//    
//    // =========================================================
//    // MARK: - END Body (your existing body stays below)
//    // =========================================================
//    
//    
//    // THIS IS FIRST THING GENERATED NEED FOR MEET CREATION
//    
//    private func createLocationInfoObject(_ geocoder: CLGeocoder, _ location: CLLocation) async -> LocationInfo?
//    {
//        let cacheKey = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
//        
//        // Check cache first
//        if let cached = geocodeCache[cacheKey] {
//            print("Using cached location info")
//            return cached
//        }
//        do {
//            let placemarks = try await geocoder.reverseGeocodeLocation(location)
//            guard let placemark = placemarks.first else { return nil }
//            
//            print("--- Reverse Geocoded Placemark ---")
//            print("Name                : \(placemark.name ?? "nil")")
//            print("Thoroughfare        : \(placemark.thoroughfare ?? "nil")")         // Street name
//            print("SubThoroughfare     : \(placemark.subThoroughfare ?? "nil")")     // Street number
//            print("SubLocality         : \(placemark.subLocality ?? "nil")")         // Neighborhood
//            print("Locality            : \(placemark.locality ?? "nil")")            // City
//            print("SubAdministrativeArea: \(placemark.subAdministrativeArea ?? "nil")") // County
//            print("AdministrativeArea  : \(placemark.administrativeArea ?? "nil")")  // State / Province
//            print("PostalCode          : \(placemark.postalCode ?? "nil")")
//            print("Country             : \(placemark.country ?? "nil")")
//            print("ISO Country Code    : \(placemark.isoCountryCode ?? "nil")")
//            print("TimeZone            : \(placemark.timeZone?.identifier ?? "nil")")
//            print("Region              : \(placemark.region?.identifier ?? "nil")")
//            print("Location (lat,long) : \(placemark.location?.coordinate.latitude ?? 0), \(placemark.location?.coordinate.longitude ?? 0)")
//            
//            let pinCoord = location.coordinate
//            let regionRadius: Double = (placemark.region as? CLCircularRegion)?.radius ?? 500.0
//
//            let locationInfo = LocationInfo(
//                Coordinate: Coordinate(pinCoord.latitude, pinCoord.longitude),
//                RegionCoordinate: Coordinate(pinCoord.latitude, pinCoord.longitude), // ← center at the pin
//                RegionRadius: regionRadius,
//                Name: placemark.name,
//                ThoroughFare: placemark.thoroughfare,
//                SubThoroughFare: placemark.subThoroughfare,
//                Locality: placemark.locality,
//                SubLocality: placemark.subLocality,
//                AdministrativeArea: placemark.administrativeArea,
//                SubAdministrativeArea: placemark.subAdministrativeArea,
//                PostalCode: placemark.postalCode,
//                Country: placemark.country,
//                IsoCountryCode: placemark.isoCountryCode,
//                TimeZone: placemark.timeZone?.identifier,
//                InlandWater: placemark.inlandWater,
//                Ocean: placemark.ocean
//            )
//
//            await MainActor.run {
//                geocodeCache[cacheKey] = locationInfo
//            }
//            
//            return locationInfo
//        } catch {
//            print("Reverse geocoding error: \(error.localizedDescription)")
//            return nil
//        }
//    }
//    
//    // MARK: - END Utilities
//}
////#Preview {
////    return PublicMapView()
////}
