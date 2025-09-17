//
//  LocationConfirmationPopupView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

import SwiftUI
import CoreLocation

struct LocationConfirmationPopupView: View
{
    let locationInfo: LocationInfo
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var isAnimating = false
    
    private var locationDisplayName: String {
        // Build a nice display name from the location info
        if let name = locationInfo.Name, !name.isEmpty {
            return name
        } else if let thoroughfare = locationInfo.ThoroughFare {
            if let subThoroughfare = locationInfo.SubThoroughFare {
                return "\(subThoroughfare) \(thoroughfare)"
            }
            return thoroughfare
        } else if let locality = locationInfo.Locality {
            return locality
        }
        return "This location"
    }
    
    private var locationDetails: String {
        var details: [String] = []
        
        if let subLocality = locationInfo.SubLocality {
            details.append(subLocality)
        }
        if let locality = locationInfo.Locality {
            details.append(locality)
        }
        if let admin = locationInfo.AdministrativeArea {
            details.append(admin)
        }
        
        return details.joined(separator: ", ")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                // Title
                Text("Create Meet Here?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppPalette.Text.primary)

                // Location name
                Text(locationDisplayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppPalette.Brand.neonPink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                // Location details
                if !locationDetails.isEmpty {
                    Text(locationDetails)
                        .font(.system(size: 14))
                        .foregroundColor(AppPalette.Text.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                }

                // Buttons
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppPalette.Text.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }

                    Button(action: onConfirm) {
                        Text("Create Meet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppPalette.Brand.neonPink)
                            )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppPalette.Brand.russianViolet)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 360)          // <- keep it compact
            .padding(.horizontal, 20)      // <- breathing room on small phones
            .shadow(color: AppPalette.Brand.neonPink.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .scaleEffect(isAnimating ? 1 : 0.5)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                isAnimating = true
            }
        }
    }

}

// Overlay modifier for the map
struct LocationPopupOverlay: View {
    @Binding var selectedLocation: LocationInfo?
    @Binding var showPopup: Bool
    let onCreateMeet: (LocationInfo) -> Void
    
    var body: some View {
        ZStack {
            if showPopup, let location = selectedLocation {
                // Dark background overlay
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showPopup = false
                        }
                    }
                
                LocationConfirmationPopupView(
                    locationInfo: location,
                    onConfirm: {
                        onCreateMeet(location)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showPopup = false
                        }
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showPopup = false
                        }
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPopup)
    }
}


