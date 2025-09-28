//
//  PublicMapView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/18/25.
//

// ==========================================================================================================
// ==========================================================================================================
// ==========================================================================================================
// MARK: - IGNORE THE BELOW TODOs FOR NOW
// MARK: - V2
// TODO: - Anyone can join a group if a link is sent?
// TODO: - Banner Notificaitons from outside the app
// TODO: - Joinable public groups by request to join
// TODO: - Create UNDO for deletes and updates
// TODO: - Fix return to user button only appears when not centered
// TODO: - NEED TO ADD categories and max capacties as options
// TODO: - add count for people inside radius to the meet bubble button
// TODO: - start planning version two features (filter by date, public join, friends, .etc, caching etc. etc.
// TODO: - AWS change username, change display name, wire the account settings to have all of that shit
// TODO: - meet invitaiton should be single repsonsiblity (maybe give leaveMeet or left meet new one
// TODO: - Out of App Notifcations???
// TODO: - Extermely important need to make sure we're not always refetching all the data... need to use cache
// TODO: - Tweak on Update Screen
// TODO: - ^^ and only grab the meet affected to what we were updating.
// TODO: - add a user inbox
// TODO: - Remeber User when Create New Account .. think this is good need check with dad's phone
// TODO: - Make sure can't duplicate username or cellphone
// TODO: - loading is kinda fixed
// TODO: -  ^^^^this is for first download or simply reopening the app... an ANYTIME open of the app load
// TODO: - Cleanup jump from MyMeetsView to meetscard overlay
// TODO: - Make sure KEYBOARDS ARE ALL THE SAME COLOR
// TODO: - Add throttling for too many requests
// TODO: - Add Technical Difficulties Page
// MARK: - V2
// MARK: - IGNORE THE ABOVE TODOs FOR NOW
// ==========================================================================================================
// ==========================================================================================================
// ==========================================================================================================

// ==========================================================================================================
// ==========================================================================================================
// ==========================================================================================================
// MARK: - IGNORE THE BELOW TODOs FOR NOW
// MARK: - V1
// TODO: - NEED TO FIX THE FUCKING locaiton bubble it's not shrinking
// TODO: - Username Spot Check
// MARK: - V1
// MARK: - IGNORE THE ABOVE TODOs FOR NOW
// ==========================================================================================================
// ==========================================================================================================
// ==========================================================================================================

import CoreLocation
import Combine
import MapKit
import SwiftUI
import Foundation
import Amplify
import UIKit
import AWSPluginsCore

// MARK: - Updated MapDataStore with leaveMeet
@MainActor
class MapDataStore: ObservableObject
{
    @Published var meets        : [ViewMeetsModel] = []
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
    
    private func silentRefresh() async {
        do {
            let newMeets = try await apiService.fetchMeets()
            
            withAnimation(.none) {
                meets = newMeets
                
                if let currentSelected = selectedMeet {
                    selectedMeet = newMeets.first { $0.meet_id_uuid == currentSelected.meet_id_uuid }
                }
            }
            
            lastRefreshTime = Date()
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func createMeet(_ body: MeetInsertBody) async throws {
        try await apiService.createMeet(body)
        await silentRefresh()
    }
    
    func createMeetWithInvites(_ body: MeetWithInvitesInsertBody) async throws {
        try await apiService.createMeetWithInvites(body)
        await silentRefresh()
    }
    
    func updateMeet(_ body: UpdatedMeetInsertBody) async throws {
        try await apiService.updateMeet(body)
        await silentRefresh()
    }
    
    func deleteMeet(_ meetId: UUID) async throws {
        let deleteBody = DeletedMeetInsertBody(meet_id_uuid: meetId)
        try await apiService.deleteMeet(deleteBody)
        await silentRefresh()
        
        if selectedMeet?.meet_id_uuid == meetId {
            selectedMeet = nil
        }
    }
    
    func leaveMeet(_ meetId: UUID) async throws {
        try await apiService.leaveMeet(meetId)
        await silentRefresh()
        
        if selectedMeet?.meet_id_uuid == meetId {
            selectedMeet = nil
        }
    }
    
    func removeParticipant(meetId: UUID, participantId: UUID, currentUserId: UUID? = nil) async throws {
        try await apiService.removeParticipant(meetId: meetId, participantId: participantId)
        await silentRefresh()
    }
    
    func inviteUsersToMeet(meetId: UUID, userIds: [UUID]) async throws {
        try await apiService.inviteUsersToMeet(meetId: meetId, userIds: userIds)
        await silentRefresh()
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
    func leaveMeet(_ meetId: UUID) async throws
    func removeParticipant(meetId: UUID, participantId: UUID) async throws
    func inviteUsersToMeet(meetId: UUID, userIds: [UUID]) async throws
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
    
    func leaveMeet(_ meetId: UUID) async throws {  // ADD THIS FUNCTION
        let token = try await getAuthToken()
        let body = RespondToInviteBody(
            meet_id_uuid: meetId,
            response_status_id: 8
        )
        _ = try await AuthAPI.respondToInvitation(baseURL: Env.apiBaseURL, token: token, body: body)
    }
    
    func removeParticipant(meetId: UUID, participantId: UUID) async throws {
        let token = try await getAuthToken()
        let body = UpdateParticipantStatusBody(
            meet_id_uuid: meetId,
            target_user_uuid: participantId,
            new_status_id: 9
        )
        _ = try await AuthAPI.updateParticipantStatus(baseURL: Env.apiBaseURL, token: token, body: body)
    }
    func inviteUsersToMeet(meetId: UUID, userIds: [UUID]) async throws
    {
            let token = try await getAuthToken()
            
            // Get current user UUID for the inviter_user_uuid field
            let currentUser = try await AuthAPI.me(baseURL: Env.apiBaseURL, token: token)
            
            let body = InsertAddtionalParticpantsModelBody(
                meet_id_uuid                    : meetId,
                inviter_user_uuid               : currentUser.user_uuid,
                additional_invitee_user_uuids   : userIds,
                invitation_message               : nil
            )
            
            _ = try await AuthAPI.insertAdditionalParticipantsToMeet(
                baseURL: Env.apiBaseURL,
                token: token,
                body: body
            )
        }
}


// MARK: - Enhanced LocationDataStore with Recenter Button Logic
@MainActor
class LocationDataStore: ObservableObject
{
    @Published var userLocation     : CLLocation?
    @Published var cameraPosition   : MapCameraPosition
    @Published var currentRegion    : MKCoordinateRegion
    @Published var shouldShowRecenterButton = false // New property

    private var hasInitiallyPositioned = false
    private let locationManager = LocationManager()
    private var geocodeCache: [String: LocationInfo] = [:]
    private var lastRefreshLocation: CLLocation?
    private let significantLocationChangeDistance: CLLocationDistance = 100 // 100 meters
    
    // Store the initial centered position and zoom level
    private var initialCenterCoordinate: CLLocationCoordinate2D?
    private var initialZoomLevel: Double?
    private let recenterThresholdDistance: CLLocationDistance = 500 // meters
    private let zoomThresholdMultiplier: Double = 2.0 // Show button if zoomed out 2x or more
    
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
        
        // Center on user location the first time we get it
        if !hasInitiallyPositioned {
            hasInitiallyPositioned = true
            
            // Store the initial position when we first center on user
            initialCenterCoordinate = newLocation.coordinate
            initialZoomLevel = 0.04 // Your default latitudeDelta
            
            print("Centering camera on user location: \(newLocation.coordinate)")
            withAnimation(.easeInOut(duration: 1.0)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: newLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                ))
            }
        }
        
        // Check for significant location change (existing code)
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
        
        // Update recenter button visibility
        updateRecenterButtonVisibility()
    }
    
    func updateRegion(_ region: MKCoordinateRegion) {
        currentRegion = region
        updateRecenterButtonVisibility()
    }
    
    private func updateRecenterButtonVisibility()
    {
        guard let userLocation = userLocation,
              let _ = initialCenterCoordinate,
              let initialZoom = initialZoomLevel else {
            shouldShowRecenterButton = false
            return
        }
        
        // Check if camera has moved significantly from user's location
        let currentCenter = CLLocation(latitude: currentRegion.center.latitude,
                                     longitude: currentRegion.center.longitude)
        let userLocationCL = CLLocation(latitude: userLocation.coordinate.latitude,
                                      longitude: userLocation.coordinate.longitude)
        
        let distanceFromUser = currentCenter.distance(from: userLocationCL)
        
        // Check if user has zoomed out significantly
        let currentZoomLevel = currentRegion.span.latitudeDelta
        let hasZoomedOut = currentZoomLevel > (initialZoom * zoomThresholdMultiplier)
        
        // Show button if either condition is met
        let hasMovedAway = distanceFromUser > recenterThresholdDistance
        
        shouldShowRecenterButton = hasMovedAway || hasZoomedOut
    }
    
    func centerOnUser()
    {
        guard let location = userLocation else { return }
        
        // Reset to initial zoom level when recentering
        let targetSpan = MKCoordinateSpan(latitudeDelta: initialZoomLevel ?? 0.04,
                                        longitudeDelta: initialZoomLevel ?? 0.04)
        
        withAnimation(.easeInOut(duration: 1.0)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: targetSpan
            ))
        }
        
        // Update the initial position to current user location
        initialCenterCoordinate = location.coordinate
    }
    
    func centerOn(coordinate: CLLocationCoordinate2D, span: MKCoordinateSpan? = nil)
    {
        let targetSpan = span ?? MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        
        withAnimation(.easeInOut(duration: 1.0)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: targetSpan
            ))
        }
    }
    
    // Rest of your existing methods remain unchanged...
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> LocationInfo?
    {
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
                Coordinate              : Coordinate(coordinate.latitude, coordinate.longitude),
                RegionCoordinate        : Coordinate(coordinate.latitude, coordinate.longitude),
                RegionRadius            : (placemark.region as? CLCircularRegion)?.radius ?? 500.0,
                Name                    : placemark.name,
                ThoroughFare            : placemark.thoroughfare,
                SubThoroughFare         : placemark.subThoroughfare,
                Locality                : placemark.locality,
                SubLocality             : placemark.subLocality,
                AdministrativeArea      : placemark.administrativeArea,
                SubAdministrativeArea   : placemark.subAdministrativeArea,
                PostalCode              : placemark.postalCode,
                Country                 : placemark.country,
                IsoCountryCode          : placemark.isoCountryCode,
                TimeZone                : placemark.timeZone?.identifier,
                InlandWater             : placemark.inlandWater,
                Ocean                   : placemark.ocean
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


// MARK: - UI State Manager
@MainActor
class UIStateStore: ObservableObject
{
    @Published var showLocationPopup    = false
    @Published var showMeetOverlay      = false
    @Published var showCreateForm       = false
    @Published var showUpdateOverlay    = false
    @Published var meetToEdit       : ViewMeetsModel?
    @Published var selectedLocation : LocationInfo?

    // TUTORIAL Objects
    @Published var showTutorial = false
    @Published var tutorialStep = 0
    @Published var shouldShowTutorialWhenReady = false
    
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
    
    private func checkTutorialDisplay() {
        if shouldShowTutorialWhenReady && canShowTutorial {
            shouldShowTutorialWhenReady = false
            startTutorial()
        }
    }
    
    func dismissAllOverlays() {
        showLocationPopup = false
        showMeetOverlay = false
        showCreateForm = false
        showUpdateOverlay = false
        checkTutorialDisplay()
    }
    
    // Tutorial state checks
    var hasActiveOverlays: Bool {
        showLocationPopup || showMeetOverlay || showCreateForm || showUpdateOverlay || showTutorial
    }
    
    var canShowTutorial: Bool {
        !showLocationPopup && !showMeetOverlay && !showCreateForm && !showUpdateOverlay
    }
    
    // Tutorial control methods
    func dismissAllIncludingTutorial() {
        dismissAllOverlays()
        showTutorial = false
        tutorialStep = 0
    }
    
    func startTutorial() {
        // CRITICAL FIX: Check if user has already seen tutorial
        guard !UserDefaults.standard.bool(forKey: "hasSeenTutorial") else { return }
        guard canShowTutorial else {
            // If we can't show now, mark to show when ready
            shouldShowTutorialWhenReady = true
            return
        }
        tutorialStep = 0
        showTutorial = true
    }
    
    func nextTutorialStep() {
        let maxSteps = TutorialConfig.steps.count - 1
        if tutorialStep < maxSteps {
            tutorialStep += 1
        } else {
            completeTutorial()
        }
    }
    
    func completeTutorial() {
        UserDefaults.standard.set(true, forKey: "hasSeenTutorial")
        showTutorial = false
        tutorialStep = 0
        shouldShowTutorialWhenReady = false // Clear the flag
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
    @EnvironmentObject private var authState: AuthStateStore
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var locationData   = LocationDataStore()


    @StateObject private var mapData        = MapDataStore()
    @StateObject private var uiState        = UIStateStore()
    @StateObject private var inbox = InboxStore(baseURL: Env.apiBaseURL)
    
    @Namespace private var meetNS
    @State private var tapTask: Task<Void, Never>?
    @State private var meetCreationMode: MeetCreationEntryMode?
    
    @StateObject private var tutorialStore = TutorialStore()


    public var body: some View
    {
        content
            .environmentObject(inbox)

            .onChange(of: scenePhase) { oldPhase, phase in
                guard phase == .active else { return }
                Task {
                    await mapData.loadMeets()
                    await inbox.refresh()
                }
            }

            .onChange(of: authState.isAuthenticated) { _, signedIn in
                if !signedIn {
                    Task { await inbox.setToken(nil) }
                }
            }
            // TODO: - bad was screwing up account creation
//            .onReceive(NotificationCenter.default.publisher(for: .init("amplify.auth.signedIn"))) { _ in
//                authState.checkAuthenticationStatus()
//            }
//            .onReceive(NotificationCenter.default.publisher(for: .init("amplify.auth.signedOut"))) { _ in
//                authState.checkAuthenticationStatus()
//            }
        
        
    }

    
    @ViewBuilder
    private var content: some View
    {
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
                authState: authState,
                tutorialStore: tutorialStore,
                meetNS: meetNS,
                authToken: authState.currentToken,
                meetCreationMode: $meetCreationMode
            )

            ControlsView(
                mapData: mapData,
                locationData: locationData,
                uiState: uiState,
                authState: authState,
                meetCreationMode: $meetCreationMode
            )
        }
        .environment(\.colorScheme, uiState.isDaylight ? .light : .dark)
        .task {
            // Check if tutorial should show on first launch
            if tutorialStore.checkShouldShowTutorial() {
                // Delay to allow UI to settle
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                uiState.startTutorial()
            }
            
            locationData.onSignificantLocationChange = {
                await mapData.loadMeets()
            }
            await mapData.loadMeets()
            uiState.startDayNightTimer()
        }
        .task(id: authState.currentToken) {
            await inbox.setToken(authState.currentToken.isEmpty ? nil : authState.currentToken)
        }
    }
    
    private func handleMapTap(_ proxy: MapProxy, _ value: SpatialTapGesture.Value)
    {
        guard !uiState.showLocationPopup && !uiState.showMeetOverlay else { return }
        
        if tapHitsAnnotation(proxy, value.location, meets: mapData.meets) {
            return
        }
        
        tapTask?.cancel()
        tapTask = Task {
            if let coordinate = proxy.convert(value.location, from: .local),
               let locationInfo = await locationData.reverseGeocode(coordinate: coordinate) {
                // Set entry mode for tap-on-map
                meetCreationMode = .tapOnMap(location: locationInfo)
                uiState.showLocationPopup = true
            }
        }
    }}


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
                            "",
//                            meet.name,
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
                .mapControls {
                    // Don't include MapCompass() - this removes it
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
    @ObservedObject var authState: AuthStateStore  // Add this parameter
    @ObservedObject var tutorialStore: TutorialStore  // Add this parameter
    
    let meetNS: Namespace.ID
    let authToken: String
    @Binding var meetCreationMode: MeetCreationEntryMode?
    
    var body: some View
    {
        ZStack
        {
            // Meet Creation Overlay (Unified)
            MeetCreationUnifiedOverlay(
                showOverlay: $uiState.showLocationPopup,
                entryMode: $meetCreationMode,
                baseURL: Env.apiBaseURL,
                token: authToken,
                onCreateMeet: { location, name, start, end, invitedUsers in
                    await handleMeetCreation(location, name, start, end, invitedUsers)
                }
            )
            
            
            
            // MARK: Meet Card Overlay - Fixed with authState parameter
            // MARK: In OverlaysView body, update the MeetCardOverlay call to:
            MeetCardOverlay(
                selectedMeet: $mapData.selectedMeet,
                isPresented: $uiState.showMeetOverlay,
                ns: meetNS,
                currentUserUUID: authState.currentUser?.user_uuid,
                baseURL: Env.apiBaseURL,
                token: authToken,
                onEdit: { meet in
                    uiState.meetToEdit = meet
                    uiState.showUpdateOverlay = true
                    uiState.showMeetOverlay = false  // Close the meet card
                },
                onDelete: { meet in
                    Task {
                        try? await mapData.deleteMeet(meet.meet_id_uuid)
                        uiState.showMeetOverlay = false
                    }
                },
                onLeave: { meet in
                    Task {
                        try? await mapData.leaveMeet(meet.meet_id_uuid)
                        uiState.showMeetOverlay = false
                    }
                },
                onRemoveParticipant: { meet, participant in
                    Task {
                        try? await mapData.removeParticipant(meetId: meet.meet_id_uuid, participantId: participant.user_uuid)
                    }
                },
                onInviteUsers: { meet, users in
                    Task {
                        let userIds = users.map { $0.user_uuid }
                        try? await mapData.inviteUsersToMeet(meetId: meet.meet_id_uuid, userIds: userIds)
                    }
                }
            )
            // Add this to the ZStack in OverlaysView body
            MeetUpdateUnifiedOverlay(
            showOverlay: $uiState.showUpdateOverlay,
            meetToEdit: $uiState.meetToEdit,
               onUpdate: { body in
                   try await mapData.updateMeet(body)
               },
               onLoadMeets: { await mapData.loadMeets() }
            )
            
            SimpleTutorialOverlay(uiState: uiState)
            
            
            // Loading Overlay
            if mapData.isLoading {
                LoadingOverlay()
            }
        }
    }
    
    private func seedForCreate() -> LocationInfo?
    {
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
    
    private func seedFromUser() -> LocationInfo?
    {
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
        _ location: LocationInfo,_ name: String,
        _ start: Date,_ end: Date,_ invitedUsers: [ViewUsersModel]) async
    {
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


// MARK: - Controls View Component (Updated with Conditional Recenter)
struct ControlsView: View
{
    @ObservedObject var mapData     : MapDataStore
    @ObservedObject var locationData: LocationDataStore
    @ObservedObject var uiState     : UIStateStore
    @ObservedObject var authState   : AuthStateStore
    
    @State private var selectedRadius: Double = 2.0
    @State private var isBadgeExpanded = false
    @State private var showBadgeRadiusSelector = false
    
    @Binding var meetCreationMode: MeetCreationEntryMode?
    
    private var shouldHideDock: Bool
    {
        uiState.showLocationPopup ||
        uiState.showMeetOverlay ||
        uiState.showUpdateOverlay
    }
    
    var body: some View
    {
        VStack {
            if !shouldHideDock {
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
                .transition(.move(edge: .top).combined(with: .opacity))
                    
                Spacer()
                
                // ==========================================
                // ABOVE DOCK (LEFT): Conditional Recenter button for map
                // ==========================================
                HStack {
                    // Only show recenter button when user has moved away or zoomed out
                    if locationData.shouldShowRecenterButton {
                        Button(action: { locationData.centerOnUser() }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(locationData.userLocation != nil ? AppPalette.Brand.neonPink : .gray)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(AppPalette.Brand.japPurple)
                                        //.overlay(Circle().stroke(AppPalette.Brand.japDarkerPurple, lineWidth: 6))
                                )
                                .shadow(radius: 2)
                        }
                        .disabled(locationData.userLocation == nil)
                        .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                }
                .padding(.leading, 36)
                .padding(.bottom, 20) // slightly above the dock
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: locationData.shouldShowRecenterButton)
                
                HStack
                {
                    Spacer()
                    DockView(
                        baseURL: Env.apiBaseURL,
                        token: authState.currentToken,
                        mapDataStore: mapData, // Pass the mapData store directly
                        onSignOut: {
                            Task {
                                await authState.signOut()
                            }
                        },
                        onCreateMeet: {
                            // Set entry mode for create button
                            meetCreationMode = .createButton
                            uiState.showLocationPopup = true  // Use same overlay
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            await authState.updateToken()
        }
        .animation(.easeInOut(duration: 0.1), value: shouldHideDock)
    }
}


// MARK: - Minimal Loading Overlay
struct LoadingOverlay: View {
    var body: some View {
        VStack {
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(1.0)
                    .progressViewStyle(CircularProgressViewStyle(tint: AppPalette.Brand.neonPink))
                    .padding(12)
                    .background(
                        Circle()
                            .fill(.regularMaterial)
                            .shadow(radius: 3)
                    )
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
            Spacer()
        }
    }
}


// TODO: - is this being used?
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
