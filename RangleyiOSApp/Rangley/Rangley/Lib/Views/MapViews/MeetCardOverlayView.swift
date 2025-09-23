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

    var body: some View {
        ZStack {
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
                .frame(maxWidth: 420, maxHeight: 600)
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
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: isPresented)
    }

    private func close() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            isPresented = false
        }
    }
}

// MARK: - Card content (no background; background is provided by overlay for the morph)
private struct MeetCardView: View
{
    let meet    : ViewMeetsModel
    let onClose : () -> Void
    let onEdit  : (ViewMeetsModel) -> Void
    let onDelete: (ViewMeetsModel) -> Void

    @State private var showDeleteConfirm = false
    @State private var addressText: String = "Loading address..."
    @State private var geocodingTask: Task<Void, Never>?
    
    // "Live" time awareness
    @State private var now: Date = .init()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private var isActive: Bool { now >= meet.dttm_start_utc && now < meet.dttm_end_utc }
    private let liveGreen = Color(hex: "#39FF14") // swap to AppPalette.Brand.neonGreen if you have it


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

                // Safer extraction (no out-of-bounds)
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
        VStack(alignment: .leading, spacing: 16)
        {
            // Header with creator name and action buttons
            HStack(alignment: .center)
            {
                HStack(spacing: 8) {
                    if isActive {
                        LiveDot(color: liveGreen) // small, inline; won't overlap content
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
                    // Only show edit and delete buttons if user is owner
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
            
            // Category and Capacity side by side
            // TODO: - Setup Max Capacity this in Version 2
            HStack(spacing: 12) {
                Chip(text: meet.category_name, systemImage: "tag.fill")
               // Chip(text: "\(meet.max_capacity) spots", systemImage: "person.2.fill")
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
            // Participant Information
            VStack(alignment: .leading, spacing: 12) {
                Text("Participants")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                if meet.is_owner {
                    // Show detailed participant list for owners
                    if let participants = meet.participant_details, !participants.isEmpty {
                        // Horizontal scrolling profile circles
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(participants, id: \.user_uuid) { participant in
                                    ProfileCircle(
                                        name: participant.display_name,
                                        statusId: participant.participant_status_id
                                    )
                                }
                            }
                        }
                        .frame(height: 44) // Fixed height for the scroll view
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
        .task { loadAddress() }
        .onDisappear { geocodingTask?.cancel() }
        .alert("Delete this meet?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete(meet)
                onClose()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
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

private struct ParticipantStatusChip: View {
    let statusId: Int16
    
    private var statusInfo: (text: String, color: Color) {
        switch statusId {
        case 4: return ("Invited", Color.gray)
        case 5: return ("Declined", Color.red)
        case 6: return ("Accepted", Color.green)
        default: return ("Unknown", Color.gray)
        }
    }
    
    var body: some View {
        Text(statusInfo.text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(statusInfo.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(statusInfo.color.opacity(0.15))
                    .overlay(
                        Capsule().stroke(statusInfo.color.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}


// TODO: - COnsider remvoign
struct FlowLayout: Layout
{
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? .infinity,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                sizes.append(size)
                
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// TODO: - consider removing
private struct ParticipantPill: View {
    let name: String
    let statusId: Int16
    
    var body: some View {
        HStack(spacing: 6) {
            // Initial circle (like in your screenshot)
            Circle()
                .fill(AppPalette.Brand.neonPink.opacity(0.3))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(name.prefix(1).uppercased()))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                )
            
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppPalette.Text.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppPalette.Surface.fieldFill.opacity(0.5))
                .overlay(
                    Capsule()
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
// Add this new ProfileCircle view

private struct ProfileCircle: View
{
    let name: String
    let statusId: Int16
    
    /// participant status id numbers: 4 = invited, 5 = declined, 6 = accepted, 7 = owner
    private var statusColor: Color {
        switch statusId {
        case 6: return Color.green  // Accepted
        case 5: return Color.red    // Declined
        case 7: return AppPalette.Brand.neonPink  // Owner
        default: return Color.gray  // Invited (4) or unknown
        }
    }
    
    var body: some View {
        Circle()
            .fill(AppPalette.Brand.neonPink.opacity(0.2))
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(name.prefix(1).uppercased()))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
            )
            .overlay(
                // Status indicator dot (optional - remove if not needed)
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .offset(x: 14, y: -14)
            )
    }
}
