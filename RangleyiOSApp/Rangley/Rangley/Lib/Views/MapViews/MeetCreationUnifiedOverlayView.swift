//
//  MeetCreationUnifiedOverlayView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/23/25.
//

import SwiftUI
import UIKit

struct MeetCreationUnifiedOverlay: View
{
    // MARK: Configuration
    @Binding var showOverlay: Bool
    @Binding var entryMode: MeetCreationEntryMode?
    let baseURL: URL
    let token: String
    let onCreateMeet: (LocationInfo, String, Date, Date, [ViewUsersModel]) async throws -> Void
    
    // MARK: State
    @State private var isAnimating = false
    @State private var isExploding = false
    @State private var showConfetti = false
    @State private var showLocationConfirm = false
    @State private var isSoftDismissing = false
    
    // MARK: Body
    var body: some View {
        ZStack {
            if showOverlay, let mode = entryMode {
                // Dark backdrop
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Only allow backdrop dismiss if showing location confirm
                        if showLocationConfirm {
                            dismiss()
                        }
                    }
                
                // Content
                ZStack {
                    // For tap-on-map: show location confirm first
                    if case .tapOnMap(let location) = mode, showLocationConfirm {
                        LocationConfirmationPopupView(
                            locationInfo: location,
                            onConfirm: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showLocationConfirm = false
                                }
                            },
                            onCancel: dismiss
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                    }
                    
                    // Main form (for both flows)
                    if !showLocationConfirm {
                        MeetCreationUnifiedFormView(
                            entryMode: mode,
                            baseURL: baseURL,
                            token: token,
                            onCreate: { body in
                                try await handleCreateMeet(body: body, invites: [])
                            },
                            onCreateWithInvites: { body in
                                try await handleCreateMeetWithInvites(body: body)
                            },
                            onClose: { softDismiss() }
                        )
                        .allowsHitTesting(!isExploding)
                        .scaleEffect(isExploding ? 0.6 : (isSoftDismissing ? 0.95 : 1.0))
                        .opacity(isExploding ? 0.0 : (isSoftDismissing ? 0.0 : 1.0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExploding)
                        .animation(.easeOut(duration: 0.25), value: isSoftDismissing)
                    }
                    
                    // Confetti overlay
                    if showConfetti {
                        ConfettiBurst(
                            color: UIColor(AppPalette.Brand.neonPink),
                            duration: 1.0,
                            intensity: 1.0
                        )
                        .allowsHitTesting(false)
                        .transition(.opacity)
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showOverlay)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showLocationConfirm)
        .onAppear {
            // For tap-on-map, show location confirm first
            if case .tapOnMap = entryMode {
                showLocationConfirm = true
            }
        }
    }
    
    // MARK: Handlers
    private func handleCreateMeet(body: MeetInsertBody, invites: [ViewUsersModel]) async throws {
        // Extract location from body for callback
        let location = LocationInfo(
            Coordinate: .init(body.latitude, body.longitude),
            RegionCoordinate: .init(body.region_latitude, body.region_longitude),
            RegionRadius: body.region_radius,
            Name: body.name,
            ThoroughFare: nil,
            SubThoroughFare: nil,
            Locality: nil,
            SubLocality: nil,
            AdministrativeArea: nil,
            SubAdministrativeArea: nil,
            PostalCode: nil,
            Country: nil,
            IsoCountryCode: nil,
            TimeZone: nil,
            InlandWater: nil,
            Ocean: nil
        )
        
        try await onCreateMeet(
            location,
            body.name,
            body.dttm_start_utc,
            body.dttm_end_utc,
            invites
        )
        
        await MainActor.run { explodeThenDismiss() }
    }
    
    private func handleCreateMeetWithInvites(body: MeetWithInvitesInsertBody) async throws {
        // Extract location from body
        let location = LocationInfo(
            Coordinate: .init(body.latitude, body.longitude),
            RegionCoordinate: .init(body.region_latitude, body.region_longitude),
            RegionRadius: body.region_radius,
            Name: body.name,
            ThoroughFare: nil,
            SubThoroughFare: nil,
            Locality: nil,
            SubLocality: nil,
            AdministrativeArea: nil,
            SubAdministrativeArea: nil,
            PostalCode: nil,
            Country: nil,
            IsoCountryCode: nil,
            TimeZone: nil,
            InlandWater: nil,
            Ocean: nil
        )
        
        // Convert UUIDs back to ViewUsersModel (simplified - in real app you'd need actual user data)
        let invitedUsers = body.initial_invitee_uuids.map { uuid in
            ViewUsersModel(
                user_uuid: uuid,
                username: "",
                display_name: "",
                matched_by: [],
                can_invite: false
            )
        }
        
        try await onCreateMeet(
            location,
            body.name,
            body.dttm_start_utc,
            body.dttm_end_utc,
            invitedUsers
        )
        
        await MainActor.run { explodeThenDismiss() }
    }
    
    // MARK: Actions
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showOverlay = false
            entryMode = nil
            showLocationConfirm = false
        }
    }
    
    private func softDismiss() {
        guard !isExploding else { return }
        isSoftDismissing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            showOverlay = false
            entryMode = nil
            showLocationConfirm = false
            isSoftDismissing = false
        }
    }
    
    private func explodeThenDismiss() {
        guard !isExploding else { return }
        isExploding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            showConfetti = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showConfetti = false
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showOverlay = false
                entryMode = nil
                showLocationConfirm = false
                isExploding = false
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Usage Example
/*
 In your main map view:
 
 @State private var showMeetCreation = false
 @State private var meetCreationMode: MeetCreationEntryMode?
 
 // For tap on map:
 .onTapGesture { location in
     let locationInfo = LocationInfo(...)
     meetCreationMode = .tapOnMap(location: locationInfo)
     showMeetCreation = true
 }
 
 // For create button:
 Button("Create Meet") {
     meetCreationMode = .createButton
     showMeetCreation = true
 }
 
 // Overlay:
 .overlay {
     MeetCreationUnifiedOverlay(
         showOverlay: $showMeetCreation,
         entryMode: $meetCreationMode,
         baseURL: baseURL,
         token: token,
         onCreateMeet: { location, name, start, end, invites in
             // Handle meet creation
         }
     )
 }
 */
