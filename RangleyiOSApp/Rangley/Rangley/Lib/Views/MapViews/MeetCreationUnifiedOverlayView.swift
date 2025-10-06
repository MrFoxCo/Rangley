//
//  MeetCreationUnifiedOverlayView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/23/25.
//

import SwiftUI
import UIKit
import CoreLocation

struct MeetCreationUnifiedOverlay: View
{
    // MARK: Configuration
    @Binding var showOverlay: Bool
    @Binding var entryMode: MeetCreationEntryMode?
    let baseURL: URL
    let token: String
    let onCreateMeet: (LocationInfo, String, Date, Date, [ViewUsersModel]) async throws -> Void
    let onContentViolation: (ContentViolation) -> Void
    
    // MARK: State
    @State private var isAnimating = false
    @State private var isExploding = false
    @State private var showConfetti = false
    @State private var showCreateForm = false
    @State private var isSoftDismissing = false
    
    // MARK: Body
    var body: some View
    {
        ZStack {
            if showOverlay, let mode = entryMode {
                // Dark backdrop
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Allow backdrop dismiss only when showing confirmation
                        if !showCreateForm {
                            dismiss()
                        }
                    }
                
                // Content
                ZStack {
                    // Initial confirmation popup (for both flows)
                    if !showCreateForm {
                        CreateMeetConfirmationPopup(
                            entryMode: mode,
                            onConfirm: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showCreateForm = true
                                }
                            },
                            onCancel: dismiss
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                    }
                    
                    // Main form (after confirmation)
                    if showCreateForm {
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
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showCreateForm)
    }
    
    // MARK: Handlers
    private func handleCreateMeet(body: MeetInsertBody, invites: [ViewUsersModel]) async throws
    {
        let location = LocationInfo(
            Coordinate: .init(body.latitude, body.longitude),
            RegionCoordinate: .init(body.region_latitude, body.region_longitude),
            RegionRadius: body.region_radius,
            Name: body.name,
            ThoroughFare: nil, SubThoroughFare: nil, Locality: nil, SubLocality: nil,
            AdministrativeArea: nil, SubAdministrativeArea: nil, PostalCode: nil,
            Country: nil, IsoCountryCode: nil, TimeZone: nil, InlandWater: nil, Ocean: nil
        )
        
        do {
            try await onCreateMeet(location, body.name, body.dttm_start_utc, body.dttm_end_utc, invites)
            await MainActor.run { explodeThenDismiss() }
        } catch {
            if let violation = parseContentViolation(from: error) {
                await MainActor.run {
                    onContentViolation(violation)
                }
                throw error // Re-throw so the form can reset isSubmitting
            } else {
                throw error
            }
        }
    }

    private func handleCreateMeetWithInvites(body: MeetWithInvitesInsertBody) async throws
    {
        let location = LocationInfo(
            Coordinate: .init(body.latitude, body.longitude),
            RegionCoordinate: .init(body.region_latitude, body.region_longitude),
            RegionRadius: body.region_radius,
            Name: body.name,
            ThoroughFare: nil, SubThoroughFare: nil, Locality: nil, SubLocality: nil,
            AdministrativeArea: nil, SubAdministrativeArea: nil, PostalCode: nil,
            Country: nil, IsoCountryCode: nil, TimeZone: nil, InlandWater: nil, Ocean: nil
        )
        
        let invitedUsers = body.initial_invitee_uuids.map { uuid in
            ViewUsersModel(user_uuid: uuid, username: "", display_name: "", matched_by: [], can_invite: false)
        }
        
        do {
            try await onCreateMeet(location, body.name, body.dttm_start_utc, body.dttm_end_utc, invitedUsers)
            await MainActor.run { explodeThenDismiss() }
        } catch {
            if let violation = parseContentViolation(from: error) {
                await MainActor.run {
                    onContentViolation(violation)
                }
                throw error // Re-throw so the form can reset isSubmitting
            } else {
                throw error
            }
        }
    }
    
    // MARK: ^^ HELPER FUNCTION
    private func parseContentViolation(from error: Error) -> ContentViolation? {
        if let contentError = error as? ContentViolationError {
            return contentError.violation
        }
        return nil
    }
    
    // MARK: Actions
    private func dismiss()
    {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8))
        {
            showOverlay = false
            entryMode = nil
            showCreateForm = false
        }
    }
    
    private func softDismiss()
    {
        guard !isExploding else { return }
        isSoftDismissing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            showOverlay = false
            entryMode = nil
            showCreateForm = false
            isSoftDismissing = false
        }
    }
    
    private func explodeThenDismiss()
    {
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
                showCreateForm = false
                isExploding = false
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - form to ask if users actually want to create a meet
struct CreateMeetConfirmationPopup: View
{
    let entryMode: MeetCreationEntryMode
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var isAnimating = false
    @State private var locationName: String = "Loading location..."
    
    private var title: String {
        switch entryMode {
        case .tapOnMap: return "Create Meet Here?"
        case .createButton: return "Create New Meet?"
        }
    }
    
    private var subtitle: String {
        switch entryMode {
        case .tapOnMap: return locationName
        case .createButton: return "Start planning your meetup"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(AppPalette.Brand.neonPink)
            
            // Title
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppPalette.Text.primary)
                .multilineTextAlignment(.center)

            // Subtitle/Location
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppPalette.Text.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            // Buttons
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppPalette.Text.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }

                Button(action: onConfirm) {
                    Text("Yes, Create")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppPalette.Brand.neonPink)
                        )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppPalette.Brand.japDarkerPurple)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: 280)
        .shadow(color: AppPalette.Brand.neonPink.opacity(0.3), radius: 15, x: 0, y: 8)
        .scaleEffect(isAnimating ? 1 : 0.5)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isAnimating = true
            }
            loadLocationNameIfNeeded()
        }
    }
    
    private func loadLocationNameIfNeeded() {
        guard case .tapOnMap(let location) = entryMode else { return }
        
        let clLocation = CLLocation(
            latitude: location.Coordinate.latitude,
            longitude: location.Coordinate.longitude
        )
        
        CLGeocoder().reverseGeocodeLocation(clLocation) { placemarks, error in
            DispatchQueue.main.async {
                if error != nil {
                    locationName = "Selected location"
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    locationName = "Selected location"
                    return
                }
                
                // Build location name similar to other components
                var components: [String] = []
                
                if let name = placemark.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                    components.append(name)
                } else if let street = placemark.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines), !street.isEmpty {
                    if let number = placemark.subThoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines), !number.isEmpty {
                        components.append("\(number) \(street)")
                    } else {
                        components.append(street)
                    }
                }
                
                if let city = placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty {
                    components.append(city)
                }
                
                locationName = components.isEmpty ? "Selected location" : components.joined(separator: ", ")
            }
        }
    }
}
