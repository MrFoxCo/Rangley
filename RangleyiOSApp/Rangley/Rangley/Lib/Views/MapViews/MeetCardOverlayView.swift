//
//  MeetCardOverlayView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

import MapKit
import CoreLocation
import SwiftUI

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
    @EnvironmentObject private var session: SessionModel
    
    @Binding var selectedMeet: ViewMeetsModel?
    @Binding var isPresented: Bool
    let ns: Namespace.ID

    // NEW: pass the signed-in user's ID and a delete callback you can wire later
    let currentUserID: Int64
    var onDelete: (ViewMeetsModel) -> Void = { _ in }

    var body: some View {
        ZStack {
            if isPresented, let meet = selectedMeet {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { close() }

                MeetCardView(
                    meet: meet,
                    myUserID: session.me?.uuid,   // ← drives Delete visibility
                    onClose: close,
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
                        .matchedGeometryEffect(id: "meet-bg-\(meet.meet_uuid)", in: ns)
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

    private func close()
    {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) { isPresented = false }
    }
}

// MARK: - Card content (no background; background is provided by overlay for the morph)
private struct MeetCardView: View
{
    let meet: ViewMeetsModel
    let myUserID: Int64
    let onClose: () -> Void
    let onDelete: (ViewMeetsModel) -> Void

    @State private var addressText: String = "Loading address..."
    @State private var geocodingTask: Task<Void, Never>?
    @State private var displayName         : String = ""
    @State private var displayAddress      : String = ""
    @State private var displayCityAndState : String = ""
    @State private var displaySubLocality  : String = ""

    @State private var showDeleteConfirm: Bool = false

    private var dateRangeText: String {
        let f = DateIntervalFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: meet.dttm_start_utc, to: meet.dttm_end_utc)
    }

    // Geocoding function to get address from coordinates
    private func loadAddress() {
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
                    displayName         = name ?? street ?? "Dropped Pin"
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Creator + actions
            HStack(alignment: .firstTextBaseline) {
                Text(meet.display_name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppPalette.Text.primary)

                Spacer()

                if meet.created_by_user_uuid == myUserID {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                            .padding(8)
                            .background(AppPalette.Surface.fieldFill, in: Circle())
                            .overlay(Circle().stroke(AppPalette.Surface.fieldStroke, lineWidth: 1))
                            .foregroundStyle(AppPalette.Brand.neonPink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete meet")
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .padding(8)
                        .background(AppPalette.Surface.fieldFill, in: Circle())
                        .overlay(Circle().stroke(AppPalette.Surface.fieldStroke, lineWidth: 1))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                }
                .buttonStyle(.plain)
            }

            // Optional: show a compact date/address line if you want to surface it
            // Remove if you don't need it rendered here.
            VStack(alignment: .leading, spacing: 6) {
                Text(dateRangeText)
                    .foregroundStyle(AppPalette.Text.secondary)
                    .font(.subheadline)
                if !displayName.isEmpty {
                    Text(displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppPalette.Text.primary)
                        .lineLimit(2)
                }
                if !displayAddress.isEmpty {
                    Text(displayAddress)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppPalette.Text.secondary)
                        .lineLimit(1)
                }
                if !displaySubLocality.isEmpty {
                    Text(displaySubLocality)
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.Text.tertiary)
                        .lineLimit(1)
                }
                if !displayCityAndState.isEmpty {
                    Text(displayCityAndState)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.Text.secondary)
                        .lineLimit(1)
                }
            }

            if !meet.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("About")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.Text.primary)
                    Text(meet.description)
                        .foregroundStyle(AppPalette.Text.secondary)
                        .font(.callout)
                        .lineLimit(6)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .shadow(radius: 24, y: 8) // keep if you have an extension; otherwise use .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 8)
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


private struct Chip: View
{
    let text: String
    let systemImage: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(AppPalette.Text.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppPalette.Surface.fieldFill, in: Capsule())
        .overlay(Capsule().stroke(AppPalette.Surface.fieldStroke, lineWidth: 1))
    }
}

