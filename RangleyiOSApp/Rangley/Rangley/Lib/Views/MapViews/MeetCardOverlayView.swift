//
//  MeetCardOverlayView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

import MapKit
import CoreLocation
import SwiftUI
import Amplify
import AWSPluginsCore

// MARK: - Bubble (the little circle)
struct MeetBubbleButton: View
{
    let meet: ViewMeetsModel
    let ns: Namespace.ID
    let onTap: () -> Void

    private var initials: String {
        let n = meet.display_name.trimmingCharacters(in: .whitespaces)
        let parts = n.split(separator: " ")
        let chars = parts.prefix(2).compactMap { $0.first }
        return String(chars).uppercased()
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { onTap() }
        } label: {
            Image("RangleySticker")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .shadow(color: AppPalette.Brand.neonPink, radius: 8, x: 0, y: 0)
                .shadow(color: AppPalette.Brand.neonPink.opacity(0.6), radius: 16, x: 0, y: 0)
                .shadow(color: AppPalette.Brand.neonPink.opacity(0.3), radius: 24, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .frame(width: 90, height: 90) // Slightly larger hit area
        .contentShape(Rectangle()) // Ensure entire frame is tappable
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
    let meet: ViewMeetsModel
    let onClose: () -> Void
    let onEdit: (ViewMeetsModel) -> Void
    let onDelete: (ViewMeetsModel) -> Void

    @State private var showDeleteConfirm = false
    @State private var addressText: String = "Loading address..."
    @State private var geocodingTask: Task<Void, Never>?

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
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2)
                {
                    Text("Created by")
                        .font(.caption)
                        .foregroundStyle(AppPalette.Text.tertiary)
                    Text(meet.display_name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.Text.primary)
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
            HStack(spacing: 12) {
                Chip(text: meet.category_name, systemImage: "tag.fill")
                Chip(text: "\(meet.max_capacity) spots", systemImage: "person.2.fill")
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

// MARK: - Chip Component
private struct Chip: View {
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

