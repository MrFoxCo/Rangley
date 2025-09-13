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
    @Binding var selectedMeet: ViewMeetsModel?
    @Binding var isPresented: Bool
    let ns: Namespace.ID

    var body: some View {
        ZStack {
            if isPresented, let meet = selectedMeet {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { close() }

                MeetCardView(meet: meet, onClose: close)
                    .frame(maxWidth: 420, maxHeight: 600)
                    .background(
                        // Morph from the circular bubble to this rounded rect
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(AppPalette.bgGradient)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "meet-bg-\(meet.meet_id)", in: ns)
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
    let onClose: () -> Void
    
    @State private var addressText: String = "Loading address..."
    @State private var geocodingTask: Task<Void, Never>?
    @State private var displayName          : String = ""
    @State private var displayAddress       : String = ""
    @State private var displayCityAndState  : String = ""
    @State private var displaySubLocality   : String = ""
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
                guard let placemark = placemarks.first else {
                    await MainActor.run {
                        addressText = "Address unavailable"
                    }
                    return
                }
                
                // Create address string similar to your LocationInfo.address computed property
                let addressComponents = [
                    placemark.name,
                    placemark.thoroughfare,
                    placemark.subThoroughfare,
                    placemark.subLocality,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.postalCode,
                    placemark.country
                ]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                
                let address = addressComponents.joined(separator: ", ")
                
                displayName    = addressComponents[0]
                displayAddress = addressComponents[2] +  " " + addressComponents[1]
                displaySubLocality = addressComponents[3]
                displayCityAndState = addressComponents[4] + ", " + addressComponents[5]
                
                
                await MainActor.run {
                    addressText = address.isEmpty ? "Address unavailable" : address
                }
            } catch {
                await MainActor.run {
                    addressText = "Address unavailable"
                }
                print("Geocoding error: \(error)")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Creator
            HStack(alignment: .firstTextBaseline) {
                Text(meet.display_name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppPalette.Text.primary)
                Spacer()
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

            Text(meet.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppPalette.Text.primary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Chip(text: meet.category_name, systemImage: "tag")
                Chip(text: "Cap \(meet.max_capacity)", systemImage: "person.3")
            }

            Divider().overlay(AppPalette.Surface.fieldStroke)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundStyle(AppPalette.Brand.neonPink)
                Text(dateRangeText)
                    .foregroundStyle(AppPalette.Text.secondary)
                    .font(.subheadline)
            }

            HStack(alignment: .top, spacing: 12) {
                // Glowing map pin
                ZStack {
                    Circle()
                        .fill(AppPalette.Brand.neonPink.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                        .shadow(color: AppPalette.Brand.neonPink.opacity(0.4), radius: 4, x: 0, y: 0)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    // Main place name - bold and prominent
                    if !displayName.isEmpty {
                        Text(displayName)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppPalette.Text.primary)
                            .lineLimit(2)
                    }
                    
                    // Street address - clean and readable
                    if !displayAddress.isEmpty {
                        Text(displayAddress)
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundStyle(AppPalette.Text.secondary)
                            .lineLimit(1)
                    }
                    
                    // Neighborhood/area - subtle
                    if !displaySubLocality.isEmpty {
                        Text(displaySubLocality)
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundStyle(AppPalette.Text.tertiary)
                            .lineLimit(1)
                    }
                    
                    // City, State - final context
                    if !displayCityAndState.isEmpty {
                        Text(displayCityAndState)
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundStyle(AppPalette.Text.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
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
        .shadow(radius: 24, y: 8)
        .task {
            loadAddress()
        }
        .onDisappear {
            geocodingTask?.cancel()
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
