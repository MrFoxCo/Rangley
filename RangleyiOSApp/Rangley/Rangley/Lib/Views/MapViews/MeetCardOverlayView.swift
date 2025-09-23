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
    let meet: ViewMeetsModel
    let ns: Namespace.ID
    let onTap: () -> Void
    
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
    @Binding var selectedMeet: ViewMeetsModel?
    @Binding var isPresented: Bool
    let ns: Namespace.ID

    var onEdit:   (ViewMeetsModel) -> Void = { _ in }
    var onDelete: (ViewMeetsModel) -> Void = { _ in }

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
                    onClose: close,
                    onEdit: onEdit,
                    onDelete: onDelete
                )
                .frame(maxWidth: 420, maxHeight: 490)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppPalette.bgGradient)
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
    let meet    : ViewMeetsModel
    let onClose : () -> Void
    let onEdit  : (ViewMeetsModel) -> Void
    let onDelete: (ViewMeetsModel) -> Void

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

    private var dateRangeText: String
    {
        let f = DateIntervalFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: meet.dttm_start_utc, to: meet.dttm_end_utc)
    }
    
    // Helper to check if current user is an accepted participant (not owner)
    private var isAcceptedParticipant: Bool
    {
        guard !meet.is_owner,
              let participants = meet.participant_details else { return false }
        
        // Check if current user has accepted (status 6)
        // Note: In a real implementation, you'd compare against current user's UUID
        // For now, we'll check if there's any accepted participant that's not the owner
        return participants.contains { $0.participant_status_id == 6 && $0.participant_status_id != 7 }
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
                                Image(systemName: "person.badge.minus")
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
                
                // Location Information
                VStack(alignment: .leading, spacing: 8)
                {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            if !displayAddressName.isEmpty {
                                Text(displayAddressName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppPalette.Text.primary)
                                    .lineLimit(1)
                            }
                            
                            if !displayAddress.isEmpty {
                                Text(displayAddress)
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppPalette.Text.secondary)
                                    .lineLimit(1)
                            }
                            
                            if !displaySubLocality.isEmpty {
                                Text(displaySubLocality)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppPalette.Text.tertiary)
                                    .lineLimit(1)
                            }
                            
                            if !displayCityAndState.isEmpty {
                                Text(displayCityAndState)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppPalette.Text.secondary)
                                    .lineLimit(1)
                            }
                        }
                    } icon: {
                        Image(systemName: "location.fill")
                            .foregroundStyle(AppPalette.Brand.neonPink)
                            .frame(width: 20)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppPalette.Surface.fieldFill.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                            )
                    )
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
            
            // PARTICIPANT DETAIL OVERLAY - REPLACES THE SHEET
            if showingParticipantDetail, let participants = meet.participant_details {
                ParticipantDetailOverlay(
                    participants: participants,
                    selectedParticipant: $selectedParticipant,
                    showingDetail: $showingParticipantDetail
                )
            }
        }
        .task { loadAddress() }
        .onDisappear { geocodingTask?.cancel() }
        .onReceive(timer) { now = $0 }
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
                // TODO: Implement leave meet functionality
                print("User chose to leave the meet")
                onClose()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to leave this meet?")
        }

        
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
                        // Close button
                        HStack {
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
                    .fill(AppPalette.Brand.russianViolet)
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
    }
}
