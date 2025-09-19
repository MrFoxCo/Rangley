//
//  PublicMapView 2.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/18/25.
//

import CoreLocation
import Combine
import MapKit
import SwiftUI
import Foundation
import Amplify
import UIKit
import AWSPluginsCore


/// =========================================================
/// =========================================================
/// =========================================================
/// MARK: - IGNORE THE BELOW TODOs FOR NOW
/// TODO: - FIGURE OUT A WAY TO TRIGER UPDATES ON OTHER PHONES WHEN MEETS ARE CREATED OR UPDATED
/// TODO: - Fix the rotating screen view -- probably should look to be vertical
/// TODO: - Create UNDO for deletes and updates
/// TODO: - Create UNDO for deletes and updates
/// TODO: - Fix recenter compass top right
/// TODO: - return to user tap
/// TODO: - Remeber User when Login Option and for Create New Account
/// TODO: - NEED TO ADD categories and max capacties as options
/// MARK: - IGNORE THE ABOVE TODOs FOR NOW
/// =========================================================
/// =========================================================
/// =========================================================




@MainActor
class MapDataStore: ObservableObject
{
    @Published var meets: [ViewMeetsModel] = []
    @Published var selectedMeet: ViewMeetsModel?
    @Published var isLoading = false
    @Published var error: String?
    
    private let apiService: APIServiceProtocol
    private var lastRefreshTime: Date?
    private var refreshTimer: Timer?
    
    // Smart refresh configuration
    private let autoRefreshInterval: TimeInterval = 180 // 3 minutes
    private let minimumRefreshInterval: TimeInterval = 30 // Prevent spam refreshing
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
        startAutoRefreshTimer()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    func loadMeets() async {
        guard !isLoading else { return }
        guard shouldRefresh() else { return }
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
            lastRefreshTime = Date()
        }
        
        do {
            let newMeets = try await apiService.fetchMeets()
            meets = newMeets
            
            // Re-hydrate selected meet if it exists
            if let currentSelected = selectedMeet {
                selectedMeet = newMeets.first { $0.meet_id_uuid == currentSelected.meet_id_uuid }
            }
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    private func shouldRefresh() -> Bool {
        guard let lastRefresh = lastRefreshTime else { return true }
        return Date().timeIntervalSince(lastRefresh) >= minimumRefreshInterval
    }
    
    private func startAutoRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.loadMeets()
            }
        }
    }
    
    func forceRefresh() async {
        lastRefreshTime = nil // Reset to force refresh
        await loadMeets()
    }
    
    // Existing methods remain unchanged...
    func createMeet(_ body: MeetInsertBody) async throws {
        try await apiService.createMeet(body)
        await forceRefresh() // Force refresh after creation
    }
    
    func createMeetWithInvites(_ body: MeetWithInvitesInsertBody) async throws {
        try await apiService.createMeetWithInvites(body)
        await forceRefresh()
    }
    
    func updateMeet(_ body: UpdatedMeetInsertBody) async throws {
        try await apiService.updateMeet(body)
        await forceRefresh()
    }
    
    func deleteMeet(_ meetId: UUID) async throws {
        let deleteBody = DeletedMeetInsertBody(meet_id_uuid: meetId)
        try await apiService.deleteMeet(deleteBody)
        await forceRefresh()
        
        if selectedMeet?.meet_id_uuid == meetId {
            selectedMeet = nil
        }
    }
}


// MARK: - API Service Protocol
protocol APIServiceProtocol
{
    func fetchMeets() async throws -> [ViewMeetsModel]
    func createMeet(_ body: MeetInsertBody) async throws
    func createMeetWithInvites(_ body: MeetWithInvitesInsertBody) async throws
    func updateMeet(_ body: UpdatedMeetInsertBody) async throws
    func deleteMeet(_ body: DeletedMeetInsertBody) async throws
}

// MARK: - API Service Implementation
class APIService: APIServiceProtocol
{
    private func getAuthToken() async throws -> String {
        let session = try await Amplify.Auth.fetchAuthSession()
        guard let provider = session as? AuthCognitoTokensProvider else {
            throw AuthAPIError.http(-1, "No Cognito token provider")
        }
        return try provider.getCognitoTokens().get().idToken
    }
    
    func fetchMeets() async throws -> [ViewMeetsModel] {
        let token = try await getAuthToken()
        return try await AuthAPI.viewMeets(baseURL: Env.apiBaseURL, token: token)
    }
    
    func createMeet(_ body: MeetInsertBody) async throws {
        let token = try await getAuthToken()
        _ = try await AuthAPI.createMeet(baseURL: Env.apiBaseURL, token: token, body: body)
    }
    
    func createMeetWithInvites(_ body: MeetWithInvitesInsertBody) async throws {
        let token = try await getAuthToken()
        _ = try await AuthAPI.createMeetWithInvites(baseURL: Env.apiBaseURL, token: token, body: body)
    }
    
    func updateMeet(_ body: UpdatedMeetInsertBody) async throws {
        let token = try await getAuthToken()
        _ = try await AuthAPI.updateMeet(baseURL: Env.apiBaseURL, token: token, body: body)
    }
    
    func deleteMeet(_ body: DeletedMeetInsertBody) async throws {
        let token = try await getAuthToken()
        _ = try await AuthAPI.deleteMeet(baseURL: Env.apiBaseURL, token: token, body: body)
    }
}

// MARK: - Enhanced LocationDataStore with Location-Based Refresh
@MainActor
class LocationDataStore: ObservableObject
{
    @Published var userLocation: CLLocation?
    @Published var cameraPosition: MapCameraPosition
    @Published var currentRegion: MKCoordinateRegion
    
    private let locationManager = LocationManager()
    private var geocodeCache: [String: LocationInfo] = [:]
    private var lastRefreshLocation: CLLocation?
    private let significantLocationChangeDistance: CLLocationDistance = 100 // 100 meters
    
    // Callback for location-based refresh
    var onSignificantLocationChange: (() async -> Void)?
    
    init() {
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 41.9211, longitude: -87.6338),
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
        
        self.cameraPosition = .region(defaultRegion)
        self.currentRegion = defaultRegion
        
        locationManager.requestWhenInUse()
        
        // Observe location changes with smart refresh logic
        locationManager.$userLocation
            .compactMap { $0 }
            .sink { [weak self] newLocation in
                self?.handleLocationUpdate(newLocation)
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func handleLocationUpdate(_ newLocation: CLLocation) {
        userLocation = newLocation
        
        // Check for significant location change
        if let lastLocation = lastRefreshLocation {
            let distance = newLocation.distance(from: lastLocation)
            if distance >= significantLocationChangeDistance {
                lastRefreshLocation = newLocation
                Task {
                    await onSignificantLocationChange?()
                }
            }
        } else {
            lastRefreshLocation = newLocation
        }
    }
    
    // Existing methods remain unchanged...
    func updateRegion(_ region: MKCoordinateRegion) {
        currentRegion = region
    }
    
    func centerOnUser() {
        guard let location = userLocation else { return }
        
        withAnimation(.easeInOut(duration: 1.0)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
            ))
        }
    }
    
    func centerOn(coordinate: CLLocationCoordinate2D, span: MKCoordinateSpan? = nil) {
        let targetSpan = span ?? MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        
        withAnimation(.easeInOut(duration: 1.0)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: targetSpan
            ))
        }
    }
    
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> LocationInfo? {
        let cacheKey = "\(coordinate.latitude),\(coordinate.longitude)"
        
        if let cached = geocodeCache[cacheKey] {
            return cached
        }
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            
            let locationInfo = LocationInfo(
                Coordinate: Coordinate(coordinate.latitude, coordinate.longitude),
                RegionCoordinate: Coordinate(coordinate.latitude, coordinate.longitude),
                RegionRadius: (placemark.region as? CLCircularRegion)?.radius ?? 500.0,
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
            
            if geocodeCache.count > 100 {
                let keysToRemove = Array(geocodeCache.keys.prefix(20))
                keysToRemove.forEach { geocodeCache.removeValue(forKey: $0) }
            }
            
            geocodeCache[cacheKey] = locationInfo
            return locationInfo
            
        } catch {
            print("Reverse geocoding error: \(error)")
            return nil
        }
    }
}


// MARK: - Authentication State Manager
@MainActor
class AuthStateStore: ObservableObject
{
    @Published var isAuthenticated = false
    @Published var currentToken = ""
    @Published var isCheckingAuth = true
    
    init() {
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        Task {
            do {
                let session = try await Amplify.Auth.fetchAuthSession()
                await MainActor.run {
                    isAuthenticated = session.isSignedIn
                    isCheckingAuth = false
                }
                
                if session.isSignedIn {
                    await updateToken()
                }
            } catch {
                await MainActor.run {
                    isAuthenticated = false
                    isCheckingAuth = false
                    currentToken = ""
                }
            }
        }
    }
    
    func updateToken() async {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            guard let provider = session as? AuthCognitoTokensProvider else { return }
            let token = try provider.getCognitoTokens().get().idToken
            
            await MainActor.run {
                currentToken = token
            }
        } catch {
            print("Failed to get token: \(error)")
            await MainActor.run {
                currentToken = ""
            }
        }
    }
    
    func signOut() async {
        _ = await Amplify.Auth.signOut()
        await MainActor.run {
            isAuthenticated = false
            currentToken = ""
        }
    }
}

// MARK: - UI State Manager
@MainActor
class UIStateStore: ObservableObject
{
    @Published var showLocationPopup = false
    @Published var showMeetOverlay = false
    @Published var showCreateForm = false
    @Published var showEditSheet = false
    @Published var selectedLocation: LocationInfo?
    
    // Day/Night theme
    @Published var isDaylight = true
    private let dayNightTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
    
    init() {
        updateDaylightStatus()
    }
    
    private func updateDaylightStatus() {
        let hour = Calendar.current.component(.hour, from: Date())
        isDaylight = hour >= 6 && hour < 20
    }
    
    func startDayNightTimer() {
        dayNightTimer
            .sink { [weak self] _ in
                self?.updateDaylightStatus()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func dismissAllOverlays() {
        showLocationPopup = false
        showMeetOverlay = false
        showCreateForm = false
        showEditSheet = false
    }
}

// MARK: - Meet Creation Service
class MeetCreationService
{
    static func buildMeetBody(
        locationInfo: LocationInfo,
        name: String,
        startTime: Date,
        endTime: Date
    ) -> MeetInsertBody {
        MeetInsertBody(
            latitude: locationInfo.Coordinate.latitude,
            longitude: locationInfo.Coordinate.longitude,
            region_latitude: locationInfo.RegionCoordinate.latitude,
            region_longitude: locationInfo.RegionCoordinate.longitude,
            region_radius: locationInfo.RegionRadius.rounded(),
            name: name,
            dttm_start_utc: startTime,
            dttm_end_utc: endTime,
            description: "",
            meet_category_id: 1,
            max_capacity: 8
        )
    }
    
    static func buildMeetWithInvitesBody(
        locationInfo: LocationInfo,
        name: String,
        startTime: Date,
        endTime: Date,
        invitedUsers: [UUID]
    ) -> MeetWithInvitesInsertBody {
        MeetWithInvitesInsertBody(
            initial_invitee_uuids: invitedUsers,
            latitude: locationInfo.Coordinate.latitude,
            longitude: locationInfo.Coordinate.longitude,
            region_latitude: locationInfo.RegionCoordinate.latitude,
            region_longitude: locationInfo.RegionCoordinate.longitude,
            region_radius: locationInfo.RegionRadius.rounded(),
            name: name,
            dttm_start_utc: startTime,
            dttm_end_utc: endTime,
            description: "",
            meet_category_id: 1,
            max_capacity: 8,
            invitation_message: ""
        )
    }
}

// MARK: - Updated PublicMapView with Smart Refresh Integration
@MainActor
public struct PublicMapView: View
{
    @StateObject private var authState = AuthStateStore()
    @StateObject private var mapData = MapDataStore()
    @StateObject private var locationData = LocationDataStore()
    @StateObject private var uiState = UIStateStore()
    
    @Namespace private var meetNS
    @State private var tapTask: Task<Void, Never>?
    
    public var body: some View {
        Group {
            if authState.isCheckingAuth {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Checking authentication...")
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .foregroundColor(.white)
            } else if authState.isAuthenticated {
                ZStack {
                    MapView(
                        mapData: mapData,
                        locationData: locationData,
                        uiState: uiState,
                        meetNS: meetNS,
                        onMapTap: handleMapTap
                    )
                    
                    OverlaysView(
                        mapData: mapData,
                        locationData: locationData,
                        uiState: uiState,
                        meetNS: meetNS,
                        authToken: authState.currentToken
                    )
                    
                    ControlsView(
                        mapData: mapData,
                        locationData: locationData,
                        uiState: uiState,
                        authState: authState
                    )
                }
                .environment(\.colorScheme, uiState.isDaylight ? .light : .dark)
                .task {
                    // Set up location-based refresh callback
                    locationData.onSignificantLocationChange = {
                        await mapData.loadMeets()
                    }
                    
                    await mapData.loadMeets()
                    uiState.startDayNightTimer()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Refresh when app becomes active
                    Task {
                        await mapData.loadMeets()
                    }
                }
            } else {
                StartScreenView(onAuthenticated: {
                    authState.checkAuthenticationStatus()
                })
                .preferredColorScheme(.dark)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("amplify.auth.signedIn"))) { _ in
            authState.checkAuthenticationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("amplify.auth.signedOut"))) { _ in
            authState.checkAuthenticationStatus()
        }
    }
    
    private func handleMapTap(_ proxy: MapProxy, _ value: SpatialTapGesture.Value)
    {
        guard !uiState.showLocationPopup && !uiState.showMeetOverlay else { return }

        // If the tap is on/near any MeetBubble, do nothing (let the button handle it)
        if tapHitsAnnotation(proxy, value.location, meets: mapData.meets) {
            return
        }

        tapTask?.cancel()
        tapTask = Task {
            if let coordinate = proxy.convert(value.location, from: .local),
               let locationInfo = await locationData.reverseGeocode(coordinate: coordinate) {
                uiState.selectedLocation = locationInfo
                uiState.showLocationPopup = true
            }
        }
    }
}


// MARK: - Map View Component
struct MapView: View
{
    @ObservedObject var mapData: MapDataStore
    @ObservedObject var locationData: LocationDataStore
    @ObservedObject var uiState: UIStateStore
    let meetNS: Namespace.ID
    let onMapTap: (MapProxy, SpatialTapGesture.Value) -> Void
    
    private func isInVisibleRegion(_ meet: ViewMeetsModel) -> Bool {
        let r = locationData.currentRegion
        let latMin = r.center.latitude - r.span.latitudeDelta / 2
        let latMax = r.center.latitude + r.span.latitudeDelta / 2
        let lonMin = r.center.longitude - r.span.longitudeDelta / 2
        let lonMax = r.center.longitude + r.span.longitudeDelta / 2
        
        return meet.latitude >= latMin && meet.latitude <= latMax &&
               meet.longitude >= lonMin && meet.longitude <= lonMax
    }
    
    var body: some View
    {
        GeometryReader { geo in
            MapReader { proxy in
                Map(position: $locationData.cameraPosition)
                {
                    ForEach(mapData.meets.filter(isInVisibleRegion), id: \.meet_id_uuid) { meet in
                        Annotation(
                            meet.name,
                            coordinate: CLLocationCoordinate2D(latitude: meet.latitude, longitude: meet.longitude),
                            anchor: .center
                        ) {
                            MeetBubbleButton(meet: meet, ns: meetNS) {
                                mapData.selectedMeet = meet
                                uiState.showMeetOverlay = true
                            }
                        }
                    }
                    UserAnnotation()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    locationData.updateRegion(context.region)
                }
                .simultaneousGesture(
                    SpatialTapGesture().onEnded { value in
                        onMapTap(proxy, value)
                    }
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Overlays View Component
struct OverlaysView: View
{
    @ObservedObject var mapData: MapDataStore
    @ObservedObject var locationData: LocationDataStore
    @ObservedObject var uiState: UIStateStore
    let meetNS: Namespace.ID
    let authToken: String
    
    var body: some View {
        ZStack {
            // Meet Creation Overlay
            MeetCreationOverlayByTap(
                selectedLocation: $uiState.selectedLocation,
                showPopup: $uiState.showLocationPopup,
                baseURL: Env.apiBaseURL,
                token: authToken,
                onCreateMeet: { location, name, start, end, invitedUsers in
                    await handleMeetCreation(location, name, start, end, invitedUsers)
                }
            )
            
            // Meet Card Overlay
            MeetCardOverlay(
                selectedMeet: $mapData.selectedMeet,
                isPresented: $uiState.showMeetOverlay,
                ns: meetNS,
                onEdit: { meet in
                    uiState.showEditSheet = true
                },
                onDelete: { meet in
                    Task {
                        try? await mapData.deleteMeet(meet.meet_id_uuid)
                        uiState.showMeetOverlay = false
                    }
                }
            )
            
            // Loading Overlay
            if mapData.isLoading {
                LoadingOverlay()
            }
        }
        .sheet(isPresented: $uiState.showCreateForm) {
            MeetCreationFormView(
                mode: .create(location: seedForCreate()),
                onCreate: { body in
                    Task {
                        do {
                            let newLat = body.latitude
                            let newLon = body.longitude
                            
                            try await mapData.createMeet(body)
                            
                            await MainActor.run {
                                uiState.showCreateForm = false
                            }
                            
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            
                            locationData.centerOn(coordinate: CLLocationCoordinate2D(
                                latitude: newLat,
                                longitude: newLon
                            ))
                        } catch {
                            print("createMeet error:", error)
                        }
                    }
                },
                onClose: { uiState.showCreateForm = false },
                onPickLocation: nil
            )
        }
        .sheet(isPresented: $uiState.showEditSheet) {
            if let editing = mapData.selectedMeet {
                MeetFormView(
                    mode: .update(existing: editing),
                    onUpdate: { body in
                        try await mapData.updateMeet(body)
                    },
                    onClose: { uiState.showEditSheet = false },
                    onPickLocation: nil,
                    onLoadMeets: { await mapData.loadMeets() }
                )
            }
        }
    }
    
    private func seedForCreate() -> LocationInfo? {
        if let sel = uiState.selectedLocation { return sel }
        if let user = seedFromUser() { return user }
        
        let c = locationData.currentRegion.center
        let coord = Coordinate(c.latitude, c.longitude)
        return LocationInfo(
            Coordinate: coord, RegionCoordinate: coord, RegionRadius: 600,
            Name: nil, ThoroughFare: nil, SubThoroughFare: nil, Locality: nil, SubLocality: nil,
            AdministrativeArea: nil, SubAdministrativeArea: nil, PostalCode: nil,
            Country: nil, IsoCountryCode: nil, TimeZone: nil, InlandWater: nil, Ocean: nil
        )
    }
    
    private func seedFromUser() -> LocationInfo? {
        guard let c = locationData.userLocation?.coordinate else { return nil }
        let coord = Coordinate(c.latitude, c.longitude)
        return LocationInfo(
            Coordinate: coord, RegionCoordinate: coord, RegionRadius: 600,
            Name: nil, ThoroughFare: nil, SubThoroughFare: nil,
            Locality: nil, SubLocality: nil, AdministrativeArea: nil,
            SubAdministrativeArea: nil, PostalCode: nil, Country: nil,
            IsoCountryCode: nil, TimeZone: nil, InlandWater: nil, Ocean: nil
        )
    }
    
    private func handleMeetCreation(
        _ location: LocationInfo,
        _ name: String,
        _ start: Date,
        _ end: Date,
        _ invitedUsers: [ViewUsersModel]
    ) async {
        do {
            let invitedUUIDs = invitedUsers.map(\.user_uuid)
            
            if invitedUUIDs.isEmpty {
                let body = MeetCreationService.buildMeetBody(
                    locationInfo: location,
                    name: name,
                    startTime: start,
                    endTime: end
                )
                try await mapData.createMeet(body)
            } else {
                let body = MeetCreationService.buildMeetWithInvitesBody(
                    locationInfo: location,
                    name: name,
                    startTime: start,
                    endTime: end,
                    invitedUsers: invitedUUIDs
                )
                try await mapData.createMeetWithInvites(body)
            }
            
            locationData.centerOn(coordinate: CLLocationCoordinate2D(
                latitude: location.Coordinate.latitude,
                longitude: location.Coordinate.longitude
            ))
            
        } catch {
            print("Meet creation failed: \(error)")
        }
    }
}

// MARK: - Controls View Component
struct ControlsView: View
{
    @ObservedObject var mapData: MapDataStore
    @ObservedObject var locationData: LocationDataStore
    @ObservedObject var uiState: UIStateStore
    @ObservedObject var authState: AuthStateStore
    
    @State private var selectedRadius: Double = 2.0
    @State private var isBadgeExpanded = false
    @State private var showBadgeRadiusSelector = false
    
    var body: some View
    {
        VStack {
            // Top Controls
            HStack
            {
                // Nearby Meets Badge
                NearbyMeetsBadgeView(
                    meets: mapData.meets,
                    userLocation: locationData.userLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 41.9211, longitude: -87.6338),
                    selectedRadius: $selectedRadius,
                    onExpandedChange: { isExpanded in
                        isBadgeExpanded = isExpanded
                    },
                    onRadiusSelectorChange: { showSelector in
                        showBadgeRadiusSelector = showSelector
                    }
                )
                .padding(.trailing, 16)
            }
            .padding(.top, 16)
            
            Spacer()
            
            // Bottom Dock
            HStack {
                Spacer()
                DockView(
                    baseURL: Env.apiBaseURL,
                    token: authState.currentToken,
                    onSignOut: {
                        Task {
                            await authState.signOut()
                        }
                    },
                    onCreateMeet: {
                        uiState.showCreateForm = true
                    },
                    onMeetSelected: { meet in
                        mapData.selectedMeet = meet
                        uiState.showMeetOverlay = true
                    },
                    onUserSelected: { user in
                        print("Selected user: \(user.display_name)")
                        // Handle user selection - maybe show user profile or invite to meet
                    }
                )
                Spacer()
            }
            .padding(.bottom, 8)
        }
        .task {
            await authState.updateToken()
        }
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View
{
    var body: some View
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

private func tapHitsAnnotation(_ proxy: MapProxy, _ pt: CGPoint, meets: [ViewMeetsModel]) -> Bool
{
    // ~50–60pt radius ≈ your 80pt bubble + padding
    let r: CGFloat = 50
    for m in meets {
        let coord = CLLocationCoordinate2D(latitude: m.latitude, longitude: m.longitude)
        if let p = proxy.convert(coord, to: .local) {
            let dx = p.x - pt.x
            let dy = p.y - pt.y
            if (dx*dx + dy*dy) <= r*r { return true }
        }
    }
    return false
}
