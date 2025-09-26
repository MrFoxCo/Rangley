//
//  MeetCardOverlayView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

// =========================================================
// =========================================================
// =========================================================
// MARK: - IGNORE THE BELOW TODOs FOR NOW

// TODO: - Delete on one screen isn't refreshign for the user on the other screen
// ... but if you tap on my meets button it will reset the shit

// MARK: - IGNORE THE ABOVE TODOs FOR NOW
// =========================================================
// =========================================================
// =========================================================

import MapKit
import CoreLocation
import SwiftUI
import Amplify
import AWSPluginsCore

// MARK: - Fixed Meet Bubble Button (Key Fix!)
struct MeetBubbleButton: View
{
    let meet    : ViewMeetsModel
    let ns      : Namespace.ID
    let onTap   : () -> Void
    
    @State private var now: Date = .init()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private var isActive: Bool { now >= meet.dttm_start_utc && now < meet.dttm_end_utc }
    
    @State private var pulse = false
    
    private let g1 = Color(hex: "#39FF14")
    
    var body: some View {
        ZStack {
            // Active pulse
            if isActive {
                Circle()
                    .fill(g1.opacity(0.22))
                    .frame(width: 89, height: 89)
                    .blur(radius: 7)
                    .scaleEffect(pulse ? 1.06 : 0.98)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                
                Circle()
                    .stroke(g1.opacity(0.9), lineWidth: 3)
                    .frame(width: 89, height: 89)
                    .blur(radius: 0.5)
            }
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    onTap()
                }
            } label: {
                Image("RangleySticker")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .opacity(0.8)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())   // <- ensures the whole frame is tappable
        }
        .frame(width: 120, height: 120)
        .onReceive(timer) { now = $0 }
        .onAppear { pulse = true }
    }
}

// MARK: - Overlay (expanded card)
struct MeetCardOverlay: View
{
    @Binding var selectedMeet   : ViewMeetsModel?
    @Binding var isPresented    : Bool
    let ns                      : Namespace.ID
    let currentUserUUID         : UUID?
    let baseURL                 : URL
    let token                   : String
    
    var onEdit              :   (ViewMeetsModel) -> Void = { _ in }
    var onDelete            :   (ViewMeetsModel) -> Void = { _ in }
    var onLeave             :   (ViewMeetsModel) -> Void = { _ in }
    var onRemoveParticipant : (ViewMeetsModel, ParticipantDetail) -> Void = { _, _ in }  // NEW
    var onInviteUsers       : (ViewMeetsModel, [ViewUsersModel]) -> Void = { _, _ in }

    
    
    var body: some View
    {
        ZStack
        {
            if isPresented, let meet = selectedMeet {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { close() }

                MeetCardView(
                    meet: meet,
                    currentUserUUID: currentUserUUID,
                    onClose: close,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onLeave: onLeave,
                    onRemoveParticipant: onRemoveParticipant,
                    baseURL: baseURL,
                    token: token,
                    onInviteUsers: onInviteUsers
                )
                .frame(maxWidth: 420, maxHeight: 490)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppPalette.Brand.japDarkerPurple)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "meet-bg-\(meet.meet_id_uuid)", in: ns)
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: isPresented)
    }

    private func close()
    {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            isPresented = false
        }
    }
}

// MARK: - Updated MeetCardView with Overlay Implementation
private struct MeetCardView: View
{
    private var hasConfirmedMapsAccess: Bool {
        UserDefaults.standard.bool(forKey: "hasConfirmedMapsAccess")
    }
    
    let meet                : ViewMeetsModel
    let currentUserUUID     : UUID?
    let onClose             : () -> Void
    let onEdit              : (ViewMeetsModel) -> Void
    let onDelete            : (ViewMeetsModel) -> Void
    let onLeave             : (ViewMeetsModel) -> Void
    let onRemoveParticipant : (ViewMeetsModel, ParticipantDetail) -> Void
    let baseURL: URL
    let token: String
    let onInviteUsers: (ViewMeetsModel, [ViewUsersModel]) -> Void

    
    @State private var showDirectionConfirm      = false
    @State private var showDirectionOptions      = false
    @State private var showDeleteConfirm         = false
    @State private var showLeaveConfirm          = false
    @State private var addressText      : String = "Loading address..."
    @State private var geocodingTask    : Task<Void, Never>?
    
    // For participant detail overlay - UPDATED
    @State private var selectedParticipant: ParticipantDetail?
    @State private var showingParticipantDetail = false
    
    // "Live" time awareness
    @State private var now: Date = .init()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private var isActive: Bool { now >= meet.dttm_start_utc && now < meet.dttm_end_utc }
    private let liveGreen = Color(hex: "#39FF14")

    // Address components from geocoding
    @State private var displayAddressName  : String = ""
    @State private var displayAddress      : String = ""
    @State private var displayCityAndState : String = ""
    @State private var displaySubLocality  : String = ""
    
    @State private var showInviteSheet = false // Replace showInviteOverlay
    @State private var selectedInviteUsers: [ViewUsersModel] = []
    private var canInvite: Bool {
        meet.is_owner || isAcceptedParticipant
    }

    private var dateRangeText: String
    {
        let f = DateIntervalFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: meet.dttm_start_utc, to: meet.dttm_end_utc)
    }
    
    private var isAcceptedParticipant: Bool {
        guard let _ = currentUserUUID else { return false }
        return !meet.is_owner
    }
    
    // Geocoding function to get address from coordinates
    private func loadAddress()
    {
        geocodingTask?.cancel()
        geocodingTask = Task {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: meet.latitude, longitude: meet.longitude)

            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                guard let p = placemarks.first else {
                    await MainActor.run { addressText = "Address unavailable" }
                    return
                }

                let name      = p.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                let street    = p.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines)
                let number    = p.subThoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines)
                let subLocal  = p.subLocality?.trimmingCharacters(in: .whitespacesAndNewlines)
                let city      = p.locality?.trimmingCharacters(in: .whitespacesAndNewlines)
                let state     = p.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines)
                let postal    = p.postalCode?.trimmingCharacters(in: .whitespacesAndNewlines)
                let country   = p.country?.trimmingCharacters(in: .whitespacesAndNewlines)

                let fullAddress = [name, street, number, subLocal, city, state, postal, country]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")

                await MainActor.run {
                    displayAddressName  = name ?? street ?? "Dropped Pin"
                    displayAddress      = [number, street].compactMap { $0 }.joined(separator: " ")
                    displaySubLocality  = subLocal ?? ""
                    displayCityAndState = [city, state].compactMap { $0 }.joined(separator: ", ")
                    addressText         = fullAddress.isEmpty ? "Address unavailable" : fullAddress
                }
            } catch {
                await MainActor.run { addressText = "Address unavailable" }
                print("Geocoding error: \(error)")
            }
        }
    }
    
    private func openInMaps()
    {
        let coordinate = CLLocationCoordinate2D(latitude: meet.latitude, longitude: meet.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        // Set the name for the destination
        if !displayAddressName.isEmpty {
            mapItem.name = displayAddressName
        } else if !meet.name.isEmpty {
            mapItem.name = meet.name
        } else {
            mapItem.name = "Meet Location"
        }
        
        // Open Maps with directions
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
        
        // Provide haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    var body: some View
    {
        ZStack {
            VStack(alignment: .leading, spacing: 16)
            {
                // Header with creator name and action buttons
                HStack(alignment: .center)
                {
                    HStack(spacing: 8) {
                        if isActive {
                            LiveDot(color: liveGreen)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Created by")
                                .font(.caption)
                                .foregroundStyle(AppPalette.Text.tertiary)
                            Text(meet.display_name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppPalette.Text.primary)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8)
                    {
                        
                        // In the header HStack with action buttons, add this before the existing buttons:
                        // Direct invite button - opens UserSearchView sheet immediately
                        if canInvite {
                            Button {
                                showInviteSheet = true
                            } label: {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(8)
                                    .background(AppPalette.Surface.fieldFill, in: Circle())
                                    .overlay(Circle().stroke(AppPalette.Surface.fieldStroke, lineWidth: 1))
                                    .foregroundStyle(AppPalette.Brand.neonPink)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if meet.is_owner {
                            Button { onEdit(meet) } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(8)
                                    .background(AppPalette.Surface.fieldFill, in: Circle())
                                    .overlay(Circle().stroke(AppPalette.Surface.fieldStroke, lineWidth: 1))
                                    .foregroundStyle(AppPalette.Brand.neonPink)
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive) { showDeleteConfirm = true } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(8)
                                    .background(AppPalette.Surface.fieldFill, in: Circle())
                                    .overlay(Circle().stroke(AppPalette.Surface.fieldStroke, lineWidth: 1))
                                    .foregroundStyle(AppPalette.Brand.neonPink)
                            }
                            .buttonStyle(.plain)
                        } else if isAcceptedParticipant {
                            // Leave Meet button for accepted participants (not owners)
                            Button(role: .destructive) { showLeaveConfirm = true } label: {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(8)
                                    .background(AppPalette.Surface.fieldFill, in: Circle())
                                    .overlay(Circle().stroke(AppPalette.Surface.fieldStroke, lineWidth: 1))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .padding(8)
                                .background(AppPalette.Surface.fieldFill, in: Circle())
                                .overlay(Circle().stroke(AppPalette.Surface.fieldStroke, lineWidth: 1))
                                .foregroundStyle(AppPalette.Text.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Divider()
                    .background(AppPalette.Surface.fieldStroke)
                
                // Event Name (the main title)
                Text(meet.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.Text.primary)
                    .lineLimit(2)
                
                // Date and Time
                Label {
                    Text(dateRangeText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.Text.primary)
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundStyle(AppPalette.Brand.neonPink)
                }
                
                // Category
                HStack(spacing: 12) {
                    Chip(text: meet.category_name, systemImage: "figure.run")
                }
                
                // MARK: Location Information

                VStack(alignment: .leading, spacing: 8)
                {
                    Button(action: {
                        if hasConfirmedMapsAccess {
                            openInMaps()
                        } else {
                            showDirectionConfirm = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            // Location icon
                            Image(systemName: "location.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AppPalette.Brand.neonPink)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                // Primary location name
                                Text(!displayAddressName.isEmpty ? displayAddressName : "Location")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppPalette.Text.primary)
                                    .lineLimit(1)
                                
                                // Condensed address line
                                HStack(spacing: 4) {
                                    if !displayAddress.isEmpty || !displayCityAndState.isEmpty {
                                        let addressParts = [displayAddress, displayCityAndState]
                                            .filter { !$0.isEmpty }
                                        
                                        Text(addressParts.joined(separator: " • "))
                                            .font(.system(size: 13))
                                            .foregroundStyle(AppPalette.Text.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Subtle navigation hint
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.6))
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppPalette.Surface.fieldFill.opacity(0.4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppPalette.Surface.fieldStroke.opacity(0.8), lineWidth: 1)
                                )
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                // Description (if exists)
                if !meet.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppPalette.Text.primary)
                        Text(meet.description)
                            .font(.system(size: 14))
                            .foregroundStyle(AppPalette.Text.secondary)
                            .lineLimit(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                }
                
                // Participant Information - UPDATED SECTION
                VStack(alignment: .leading, spacing: 12) {
                    Text("Participants")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.Text.primary)
                    
                    if meet.is_owner {
                        // Show detailed participant list for owners
                        if let participants = meet.participant_details, !participants.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(participants, id: \.user_uuid) { participant in
                                        SimpleProfileCircle(
                                            name: participant.display_name,
                                            statusId: participant.participant_status_id
                                        ) {
                                            selectedParticipant = participant
                                            showingParticipantDetail = true
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .frame(height: 40)
                        } else {
                            Text("No participants yet")
                                .font(.system(size: 13))
                                .foregroundStyle(AppPalette.Text.tertiary)
                                .italic()
                        }
                    } else {
                        // Show just the count for non-owners
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(AppPalette.Brand.neonPink)
                            
                            Text("\(meet.accepted_count) accepted")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppPalette.Text.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppPalette.Surface.fieldFill.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.top, 4)

                Spacer(minLength: 0)
            }
            .padding(20)
            
            // PARTICIPANT DETAIL OVERLAY - UPDATED WITH REMOVE FUNCTIONALITY
            if showingParticipantDetail, let participants = meet.participant_details {
                ParticipantDetailOverlay(
                    participants: participants,
                    selectedParticipant: $selectedParticipant,
                    showingDetail: $showingParticipantDetail,
                    isOwner: meet.is_owner,  // NEW: Pass owner status
                    onRemoveUser: { participant in  // NEW: Remove user callback
                        onRemoveParticipant(meet, participant)
                    }
                )
            }

        }
        .task { loadAddress() }
        .onDisappear { geocodingTask?.cancel() }
        .onReceive(timer) { now = $0 }
        .sheet(isPresented: $showInviteSheet) {
            UserSearchView(
                baseURL: baseURL,
                token: token,
                selectedUsers: $selectedInviteUsers,
                onDismiss: {
                    showInviteSheet = false
                    // If users were selected, send the invites
                    if !selectedInviteUsers.isEmpty {
                        onInviteUsers(meet, selectedInviteUsers)
                        selectedInviteUsers.removeAll()
                    }
                }
            )
        }
        .alert("Delete this meet?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete(meet)
                onClose()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Leave this meet?", isPresented: $showLeaveConfirm) {
            Button("Leave", role: .destructive) {
                onLeave(meet)
                onClose()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to leave this meet?")
        }
        .alert("Open in Maps?", isPresented: $showDirectionConfirm) {
            Button("Get Directions") {
                UserDefaults.standard.set(true, forKey: "hasConfirmedMapsAccess")
                openInMaps()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will open Apple Maps with driving directions to the location.")
        }
        //message: {Text("This will open Apple Maps.")}
    }
}

// MARK: - Live badge
private struct LiveDot: View
{
    let color: Color
    var body: some View
    {
        ZStack {
            Circle()
                .fill(color.opacity(0.22))
                .frame(width: 20, height: 20)
                .blur(radius: 1.0)
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
        }
        .padding(10) // nudges it off the top-left corner of the card
        .accessibilityLabel("Live")
    }
}

// MARK: - Chip Component
private struct Chip: View
{
    let text: String
    let systemImage: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(AppPalette.Text.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppPalette.Surface.fieldFill, in: Capsule())
        .overlay(Capsule().stroke(AppPalette.Surface.fieldStroke, lineWidth: 1))
    }
}

// Replace the existing ProfileCircle struct with this updated version:

private struct SimpleProfileCircle: View
{
    let name: String
    let statusId: Int16
    let onTap: () -> Void
    
    private var statusColor: Color {
        switch statusId {
        case 6: return Color.green  // Accepted
        case 5: return Color.red    // Declined
        case 7: return AppPalette.Brand.neonPink  // Owner
        default: return Color.gray  // Invited (4) or unknown
        }
    }
    
    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1))
            let second = String(components[1].prefix(1))
            return (first + second).uppercased()
        } else if components.count == 1 {
            let word = String(components[0])
            if word.count >= 2 {
                return String(word.prefix(2)).uppercased()
            } else {
                return word.uppercased()
            }
        }
        return ""
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(AppPalette.Brand.neonPink.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppPalette.Brand.neonPink)
                    )
                    .overlay(
                        Group {
                            if statusId == 7 {
                                // Crown icon for Owner status
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.yellow)
                            } else {
                                // Regular colored circle for other statuses
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 10, height: 10)
                            }
                        }
                        .offset(x: 14, y: -14)
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ParticipantDetailOverlay: View
{
    let participants: [ParticipantDetail]
    @Binding var selectedParticipant: ParticipantDetail?
    @Binding var showingDetail: Bool
    let isOwner: Bool
    let onRemoveUser: (ParticipantDetail) -> Void
    
    @State private var showRemoveConfirm = false
    
    private var currentIndex: Int {
        guard let selected = selectedParticipant,
              let index = participants.firstIndex(where: { $0.user_uuid == selected.user_uuid }) else {
            return 0
        }
        return index
    }
    
    private var participant: ParticipantDetail? {
        selectedParticipant
    }
    
    private var statusText: String {
        guard let participant = participant else { return "" }
        switch participant.participant_status_id {
        case 6: return "Accepted"
        case 5: return "Declined"
        case 7: return "Owner"
        default: return "Invited"
        }
    }
    
    private var statusColor: Color {
        guard let participant = participant else { return .gray }
        switch participant.participant_status_id {
        case 6: return Color.green
        case 5: return Color.red
        case 7: return AppPalette.Brand.neonPink
        default: return Color.gray
        }
    }
    
    private var initials: String {
        guard let participant = participant else { return "" }
        let components = participant.display_name.split(separator: " ")
        if components.count >= 2 {
            let first = String(components[0].prefix(1))
            let second = String(components[1].prefix(1))
            return (first + second).uppercased()
        } else if components.count == 1 {
            let word = String(components[0])
            if word.count >= 2 {
                return String(word.prefix(2)).uppercased()
            } else {
                return word.uppercased()
            }
        }
        return ""
    }
    
    private var canRemoveParticipant: Bool {
        guard let participant = participant, isOwner else { return false }
        // Can't remove the owner (themselves) or users who already left/were removed
        return participant.participant_status_id != 7 &&
               participant.participant_status_id != 8 &&
               participant.participant_status_id != 9
    }
    
    private func navigateToParticipant(at index: Int) {
        guard index >= 0 && index < participants.count else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedParticipant = participants[index]
        }
    }
    
    var body: some View
    {
        ZStack
        {
            // Main card
            VStack(spacing: 0)
            {
                if let participant = participant {
                    VStack(spacing: 24) {
                        // Header with close and remove buttons
                        HStack {
                            // Remove button (only for owner, only for removable participants)
                            if canRemoveParticipant {
                                Button {
                                    showRemoveConfirm = true
                                } label: {
                                    Image(systemName: "person.badge.minus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.red)
                                        .frame(width: 28, height: 28)
                                        .background(
                                            Circle()
                                                .fill(Color.red.opacity(0.1))
                                        )
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showingDetail = false
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppPalette.Brand.neonPink)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle()
                                            .fill(AppPalette.Brand.neonPink.opacity(0.1))
                                    )
                            }
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                        
                        // Profile section
                        VStack(spacing: 16) {
                            // Large profile circle
                            ZStack {
                                Circle()
                                    .fill(AppPalette.Brand.neonPink.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text(initials)
                                            .font(.system(size: 36, weight: .semibold))
                                            .foregroundStyle(AppPalette.Brand.neonPink)
                                    )
                                    .overlay(
                                        Group {
                                            if participant.participant_status_id == 7 {
                                                // Crown icon for Owner status
                                                Image(systemName: "crown.fill")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(.yellow)
                                            } else {
                                                // Regular colored circle for other statuses
                                                Circle()
                                                    .fill(statusColor)
                                                    .frame(width: 24, height: 24)
                                            }
                                        }
                                        .offset(x: 35, y: -35)
                                    )
                            }
                            
                            VStack(spacing: 8) {
                                Text(participant.display_name)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(AppPalette.Text.primary)
                                
                                Text(statusText)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(statusColor)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(statusColor.opacity(0.15))
                                            .overlay(
                                                Capsule().stroke(statusColor.opacity(0.4), lineWidth: 1)
                                            )
                                    )
                            }
                        }
                        
                        // Navigation indicators (only show if multiple participants)
                        if participants.count > 1 {
                            HStack(spacing: 10) {
                                ForEach(Array(participants.enumerated()), id: \.element.user_uuid) { index, p in
                                    Circle()
                                        .fill(index == currentIndex ?
                                              AppPalette.Brand.neonPink :
                                              AppPalette.Brand.neonPink.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentIndex)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .frame(width: 280, height: 320)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppPalette.Brand.japDarkerPurple)
                    .shadow(color: .black, radius: 20, x: 0, y: 10)
            )
            .scaleEffect(showingDetail ? 1.0 : 0.8)
            .opacity(showingDetail ? 1.0 : 0)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        
                        if value.translation.width > threshold && currentIndex > 0 {
                            // Swipe right - go to previous
                            navigateToParticipant(at: currentIndex - 1)
                        } else if value.translation.width < -threshold && currentIndex < participants.count - 1 {
                            // Swipe left - go to next
                            navigateToParticipant(at: currentIndex + 1)
                        }
                    }
            )
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingDetail)
        .alert("Remove participant?", isPresented: $showRemoveConfirm) {
            Button("Remove", role: .destructive) {
                if let participant = participant {
                    onRemoveUser(participant)
                    // Close the detail overlay after removing
                    withAnimation(.easeOut(duration: 0.3)) {
                        showingDetail = false
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let participant = participant {
                Text("Remove \(participant.display_name) from this meet?")
            }
        }
    }
}

// notused
private struct DirectionsSelectionOverlay: View {
    @Binding var showDirections: Bool
    let onDriving: () -> Void
    let onWalking: () -> Void
    let onTransit: () -> Void
    let onShowLocation: () -> Void
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showDirections = false
                    }
                }
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Get Directions")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppPalette.Text.primary)
                    
                    Text("Choose how you'd like to get to this location")
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.Text.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Direction options
                VStack(spacing: 0) {
                    DirectionOptionButton(
                        title: "Driving Directions",
                        icon: "car.fill",
                        color: AppPalette.Brand.neonPink,
                        action: {
                            onDriving()
                            withAnimation(.easeOut(duration: 0.2)) {
                                showDirections = false
                            }
                        }
                    )
                    
                    DirectionOptionButton(
                        title: "Walking Directions",
                        icon: "figure.walk",
                        color: .green,
                        action: {
                            onWalking()
                            withAnimation(.easeOut(duration: 0.2)) {
                                showDirections = false
                            }
                        }
                    )
                    
                    DirectionOptionButton(
                        title: "Transit Directions",
                        icon: "bus.fill",
                        color: .blue,
                        action: {
                            onTransit()
                            withAnimation(.easeOut(duration: 0.2)) {
                                showDirections = false
                            }
                        }
                    )
                    
                    DirectionOptionButton(
                        title: "Just Show Location",
                        icon: "location.circle.fill",
                        color: .orange,
                        showDivider: false,
                        action: {
                            onShowLocation()
                            withAnimation(.easeOut(duration: 0.2)) {
                                showDirections = false
                            }
                        }
                    )
                }
                .padding(.top, 16)
                
                // Cancel button
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showDirections = false
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppPalette.Text.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppPalette.Surface.fieldFill.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppPalette.Brand.japDarkerPurple)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                    )
            )
            .frame(maxWidth: 320)
            .scaleEffect(showDirections ? 1.0 : 0.8)
            .opacity(showDirections ? 1.0 : 0)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showDirections)
    }
}

private struct DirectionOptionButton: View {
    let title: String
    let icon: String
    let color: Color
    var showDivider: Bool = true
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 16) {
                    // Icon background
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(color)
                    }
                    
                    // Title
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppPalette.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Arrow
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.Text.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if showDivider {
                Divider()
                    .background(AppPalette.Surface.fieldStroke.opacity(0.5))
                    .padding(.leading, 76) // Align with text start
            }
        }
    }
}

private struct InviteUsersOverlay: View
{
    let meet: ViewMeetsModel
    let baseURL: URL
    let token: String
    @Binding var showingInvite: Bool
    let onInvite: ([ViewUsersModel]) -> Void
    
    @State private var selectedUsers: [ViewUsersModel] = []
    @State private var showUserSearch = false // Direct to UserSearchView
    
    var body: some View
    {
        ZStack {
            // Dark backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showingInvite = false
                    }
                }
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Button {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showingInvite = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppPalette.Text.secondary)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(AppPalette.Surface.fieldFill.opacity(0.3))
                                )
                        }
                        
                        Spacer()
                        
                        Text("Invite Friends")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppPalette.Text.primary)
                        
                        Spacer()
                        
                        // Placeholder for symmetry
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 28, height: 28)
                    }
                    .padding(.horizontal, 24)
                    
                    // Meet context card
                    VStack(spacing: 12) {
                        Text("Inviting friends to:")
                            .font(.system(size: 14))
                            .foregroundColor(AppPalette.Text.secondary)
                        
                        VStack(spacing: 8) {
                            Text(meet.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppPalette.Text.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppPalette.Brand.neonPink)
                                
                                Text(DateFormatter.shortDateTime.string(from: meet.dttm_start_utc))
                                    .font(.system(size: 13))
                                    .foregroundColor(AppPalette.Text.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppPalette.Surface.fieldFill.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                }
                
                // Selected users preview (if any)
                if !selectedUsers.isEmpty {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Selected (\(selectedUsers.count))")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppPalette.Text.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(selectedUsers, id: \.user_uuid) { user in
                                    SelectedUserChip(
                                        user: user,
                                        onRemove: {
                                            selectedUsers.removeAll { $0.user_uuid == user.user_uuid }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }
                
                // Main action button - DIRECTLY opens UserSearchView
                Button {
                    showUserSearch = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(selectedUsers.isEmpty ? "Search Friends to Invite" : "Add More Friends")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppPalette.Brand.neonPink)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                
                // Send invites button (only show if users selected)
                if !selectedUsers.isEmpty {
                    Button {
                        sendInvites()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .semibold))
                            
                            Text("Send \(selectedUsers.count) Invite\(selectedUsers.count == 1 ? "" : "s")")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(AppPalette.Brand.neonPink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppPalette.Brand.neonPink.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppPalette.Brand.neonPink, lineWidth: 2)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                }
                
                Spacer(minLength: 20)
            }
            .frame(maxWidth: 380, maxHeight: 500)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppPalette.Brand.japDarkerPurple)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                    )
            )
            .scaleEffect(showingInvite ? 1.0 : 0.8)
            .opacity(showingInvite ? 1.0 : 0)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingInvite)
        .sheet(isPresented: $showUserSearch) {
            UserSearchView(
                baseURL: baseURL,
                token: token,
                selectedUsers: $selectedUsers,
                onDismiss: {
                    showUserSearch = false
                }
            )
        }
    }
    
    private func sendInvites() {
        guard !selectedUsers.isEmpty else { return }
        
        onInvite(selectedUsers)
        
        withAnimation(.easeOut(duration: 0.3)) {
            showingInvite = false
        }
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}


// MARK: - DateFormatter Extension
extension DateFormatter {
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
