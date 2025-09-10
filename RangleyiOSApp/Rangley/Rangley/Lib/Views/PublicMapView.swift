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
import SQLite3


struct ContentViewTest: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Auth Register") { UserRegisterFlow() }
                Button("Debug: print ID token") {
                    Task {
                        do { print(try await CognitoTokens.idToken()) }
                        catch { print("No token:", error) }
                    }
                }
            }
            .navigationTitle("Dev Tools")
        }
    }
}
#Preview { ContentViewTest() }   // ← match the struct name


private enum ActiveSheet: Identifiable, Equatable {
    case CreateMeet
    case Meet(MeetCardData)

    var id: String {
        switch self {
        case .CreateMeet: return "create"
        case .Meet(let m): return "meet:\(m.id)"
        }
    }
}


public struct PublicMapView: View {
    
    // TODO: userManager is a temp solution to not having a session and knowing who is logged in
   // @EnvironmentObject var userManager: UserManager
    
    
    // MARK: - Map Location
    
    // TODO: Place it at the Users location ... or their last location if unknown
    // PUBLIC MAP ALWAYS STARTS HERE
    @State private var cameraPosition : MapCameraPosition = .region( MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.9211, longitude: -87.6338), // Lincoln Park Zoo approx
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)))
    
    @State private var selectedAnchor: CGPoint?

    // MARK: - END Map Location
    
    
    @State private var isPlacingEvent       : Bool = false
    @State private var visibleRegion        : MKCoordinateRegion?
    @State private var tappedRegion         : MKCoordinateRegion?
    @State private var selectedCoordinate   : CLLocationCoordinate2D?
    @State private var selectedLocationInfo : LocationInfo?
        
    // MARK: - MEET POPUP CARD Objects
    @State private var selectedMeetCardToView    : MeetCardData?  = nil          // popup
    
    //TODO: Now we have to delete from this?? or do we want to reload it???
    // 1) Track a reload token to avoid hammering DB
    @State private var meetDisplays             : [MeetCardData]    = [] // should this be in a class?? or struct???
    @State private var needsReloadAfterDelete   : Bool             = false
    @State private var modifyMeetBatch          : ModifyMeetBatch? = nil // if need to modify mee

    // MARK: - END MEET POPUP CARD Objects


    // MARK: MEET CREATE CARD
    @State private var createDraft = CreateMeetDraft()           // for CreateMeetCard

    
    // MARK: - TAPPABLE ANNOTATIONS
    @State private var activeSheet: ActiveSheet?

    // Option 1: Separate @State variables (Recommended)

    @State private var error: Error?
    
    // TODO: Consider creating some meetbatch class
    @State private var currentMeetBatch = MeetBatch(
        User: User(UserId: 0,FirstName: "",LastName: "",CellPhone: "",Email: "",UID: "")
    )
    @State private var currentMeetAddressId     : Int64?
    @State private var currentMeetId            : Int64?

    
    // Keep this in PublicMapView so helpers can see it
    @State private var lastSpan = MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)

    // =========================================================
    // MARK: - Helpers (PLACE THESE HERE, inside PublicMapView)
    
    
    // =========================================================
    private enum PopupMetrics
    {
        static let cardW    : CGFloat = 320
        static let cardH    : CGFloat = 200
        static let clearance: CGFloat = 28
        static let pinHeight: CGFloat = 40   // match your pin size
        static let buffer   : CGFloat = 20
    }

    // Rule 3: nudge camera if the pin is too close to screen edges (buffer)
    private func maybeNudgeForEdgeBuffer(anchor: CGPoint, size: CGSize, insets: EdgeInsets, proxy: MapProxy)
    {
        let safeMinX = insets.leading
        let safeMaxX = size.width  - insets.trailing
        let safeMinY = insets.top
        let safeMaxY = size.height - insets.bottom

        let leftGap   = anchor.x - safeMinX
        let rightGap  = safeMaxX - anchor.x
        let topGap    = anchor.y - safeMinY
        let bottomGap = safeMaxY - anchor.y

        var dx: CGFloat = 0
        var dy: CGFloat = 0
        if leftGap   < PopupMetrics.buffer { dx += (PopupMetrics.buffer - leftGap) }
        if rightGap  < PopupMetrics.buffer { dx -= (PopupMetrics.buffer - rightGap) }
        if topGap    < PopupMetrics.buffer { dy += (PopupMetrics.buffer - topGap) }
        if bottomGap < PopupMetrics.buffer { dy -= (PopupMetrics.buffer - bottomGap) }

        guard dx != 0 || dy != 0 else { return }

        let centerX = (safeMinX + safeMaxX) / 2
        let centerY = (safeMinY + safeMaxY) / 2
        let newCenterScreen = CGPoint(x: centerX - dx, y: centerY - dy)

        if let newCenterCoord = proxy.convert(newCenterScreen, from: .local) {
            withAnimation(.easeInOut(duration: 0.22)) {
                cameraPosition = .region(MKCoordinateRegion(center: newCenterCoord, span: lastSpan))
            }
        }
    }

    // =========================================================
    // MARK: - Anchored popup view (PLACE THIS HERE, inside PublicMapView)
    // =========================================================
    private struct AnchoredMeetCard: View {
        let meet: MeetCardData
        let anchor: CGPoint
        let mapSize: CGSize
        let safeInsets: EdgeInsets
        var onClose: () -> Void
        var onDelete: (MeetCardData) -> Void

        private static func cardCenter(anchor: CGPoint, mapSize: CGSize, safeInsets: EdgeInsets) -> CGPoint
        {
            let minX = safeInsets.leading + PopupMetrics.buffer
            let maxX = mapSize.width  - safeInsets.trailing - PopupMetrics.buffer - PopupMetrics.cardW
            let minY = safeInsets.top + PopupMetrics.buffer
            let maxY = mapSize.height - safeInsets.bottom   - PopupMetrics.buffer - PopupMetrics.cardH

            let midY = (safeInsets.top + (mapSize.height - safeInsets.bottom)) / 2
            let pinHalf = PopupMetrics.pinHeight / 2
            let placeBelow = (anchor.y <= midY)

            // base placement
            let rawTopY: CGFloat = placeBelow
                ? (anchor.y + pinHalf + PopupMetrics.clearance)                      // BELOW pin
                : (anchor.y - pinHalf - PopupMetrics.clearance - PopupMetrics.cardH) // ABOVE pin

            // bump up more when placing ABOVE
            let aboveBumpFactor: CGFloat = 2.0
            let adjustedTopY = placeBelow ? rawTopY : (rawTopY - aboveBumpFactor * PopupMetrics.pinHeight)

            let rawLeftX = anchor.x - (PopupMetrics.cardW / 2)

            let clampedX = max(min(rawLeftX, maxX), minX)
            let clampedY = max(min(adjustedTopY,  maxY), minY)

            return CGPoint(x: clampedX + PopupMetrics.cardW/2,
                           y: clampedY + PopupMetrics.cardH/2)
        }

        var body: some View {
            let center = Self.cardCenter(anchor: anchor, mapSize: mapSize, safeInsets: safeInsets)

            MeetCardView(
                meetCardData: meet,
                onCloseMeetCard: { _ in onClose() },
                onDeleteMeet: { m in onDelete(m) }
            )
            .frame(width: PopupMetrics.cardW, height: PopupMetrics.cardH)
            .position(center)
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 8)
        }
    }



    // =========================================================
    // MARK: - Body (your existing body stays below)
    // =========================================================

    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            GeometryReader{ geo in
                MapReader{ proxy in
                    Map(position: $cameraPosition) {
                        MeetPinsMapContent(Meets: meetDisplays) { m in
                            isPlacingEvent = false

                            let coord = CLLocationCoordinate2D(latitude: m.Latitude, longitude: m.Longitude)
                            selectedCoordinate = coord

                            if let pt = proxy.convert(coord, to: .local) {
                                // Nudge the map if the pin is hugging an edge (Rule 3)
                                maybeNudgeForEdgeBuffer(
                                    anchor: pt,
                                    size: geo.size,
                                    insets: geo.safeAreaInsets,
                                    proxy: proxy
                                )
                                selectedAnchor = pt
                            }

                            selectedMeetCardToView = m
                        }
                    }
                    // Map tap should only create when placing, and not if a sheet is already up
                    .gesture(
                        SpatialTapGesture().onEnded { value in
                            // Don’t queue another sheet if one is already up
                            guard activeSheet == nil else { return }
                            
                            let position = value.location
                            if let coordinate = proxy.convert(position, from: .local) {
                                let geocoder = CLGeocoder()
                                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                                
//                                Task {
//                                    guard
//                                        let li   = await createLocationInfoObject(geocoder, location),
//                                        let _ = "aa"
//                                    else { return }
//                                    
//                                    // load dynamic categories once (outside MainActor)
//                                    let cats = DbRangle.loadCategories(DbManager.shared.database)
//                                    let initialCategory = UserDefaults.standard.string(forKey: "lastCategory")
//                                    ?? cats.first?.Name ?? ""
//                                    
//                                    await MainActor.run {
//                                        currentMeetBatch.LocationInfo = li
//
//
//                                        createDraft = CreateMeetDraft(
//                                            name        : "",
//                                            notes       : "",
//                                            categoryName: initialCategory,                 // <-- dynamic
//                                            dttmStart   : Date().addingTimeInterval(60*30),
//                                            dttmEnd     :   Date().addingTimeInterval(60*90),
//                                            capacity    : 4,
//                                            placeName   : li.Name ?? li.Locality
//                                        )
//                                        
//                                        activeSheet = .CreateMeet
//                                    }
//                                    
//                                }
                            }
                        }
                    )
                    
                    .ignoresSafeArea()
                    .onMapCameraChange(frequency: .onEnd) { context in
                        visibleRegion = context.region
                        lastSpan = context.region.span
                        // keep the callout following the pin when the map moves
                        if let coord = selectedCoordinate, selectedMeetCardToView != nil,
                           let pt = proxy.convert(coord, to: .local) {
                            selectedAnchor = pt
                        }

                    }

                    .onAppear {
                        //                    if let u = userManager.anthony { currentMeetBatch.User = u }
                        loadMeets()
                    }
                    .tabItem {
                        Image(systemName: "map")
                        Text("Map")
                    }
                }
                // FULL SCREEN TARGET TO DISMISS
                .overlay {
                    
                    if let m = selectedMeetCardToView, let anchor = selectedAnchor {
                        ZStack {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                        selectedMeetCardToView = nil
                                        selectedAnchor = nil
                                    }
                                }
//                            print("anchorY:", anchor.y, "midY:", (safeInsets.top + (mapSize.height - safeInsets.bottom))/2,
//                                  "pinHalf:", PopupMetrics.pinHeight/2, "placeBelow:", anchor.y <= (safeInsets.top + (mapSize.height - safeInsets.bottom))/2)

                            AnchoredMeetCard(
                                meet: m,
                                anchor: anchor,
                                mapSize: geo.size,
                                safeInsets: geo.safeAreaInsets,
                                onClose: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                        selectedMeetCardToView = nil
                                        selectedAnchor = nil
                                    }
                                },
                                onDelete: { deleted in
                                    handleDeleteMeet(deleted)
                                }
                            )
                        }
                        .allowsHitTesting(true)
                    }
                }
            }

            // TODO: ADD THE ACTION BAR IT SHOULD WORK ALSO ADD BUTTONS...
//
//            VStack {
//                Spacer()
//                ActionBar(isPlacingEvent: $isPlacingEvent)
//                    .padding(.bottom, 40)
//            }
            
            
//            // TODO: this is blocking the compass that appears when you two finger rotate screen...
//            .safeAreaInset(edge: .top) {
//                DateWheel()
//            }
        }

//        .meetPopup(
//            item: $selectedMeetCardToView,
//            onCloseMeetCard: { _ in
//                // just dismiss / no DB change
//                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
//                    selectedMeetCardToView = nil
//                }
//            },
//            onDeleteMeet: { deleted in
//                // DB delete already happened inside MeetCard.
//                // Here, refresh UI / local cache.
//                if let idx = meetDisplays.firstIndex(where: { $0.id == deleted.id }) {
//                    meetDisplays.remove(at: idx)
//                }
//                // Or just reload from DB:
//                // loadMeets()
//
//                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
//                    selectedMeetCardToView = nil
//                }
//            }
//        )
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        // ONE sheet for everything
        .sheet(item: $activeSheet) { which in
            switch which {
            case .CreateMeet:
                NavigationView {
                    CreateMeet(meetBatch: currentMeetBatch) {
                        loadMeets()  // refresh pins on save
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)

            case .Meet:
                EmptyView()
            }
        }
    }

    // MARK: - END Body
    
    private func handleDeleteMeet(_ deleted: MeetCardData) {
        if let idx = meetDisplays.firstIndex(where: { $0.id == deleted.id }) {
            meetDisplays.remove(at: idx)
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            selectedMeetCardToView = nil
            selectedAnchor = nil
        }
    }

    
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
    
    private func loadMeets()
    {
        let (rows, err) = DbRangle.tryViewMeetCardData(DbManager.shared.database!)
        if let err { print("Error loading meets: \(err.localizedDescription)") }
        self.meetDisplays = rows
    }
    
    // MARK: - END Utilities

}



//#Preview {
//    return PublicMap()
//}
