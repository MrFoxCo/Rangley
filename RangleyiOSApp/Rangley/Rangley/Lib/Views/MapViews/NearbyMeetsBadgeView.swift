//
//  NearbyMeetsBadgeView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/13/25.
//


import SwiftUI
import CoreLocation
import MapKit

struct NearbyMeetsBadgeView: View
{
    let meets: [ViewMeetsModel]
    let userLocation: CLLocationCoordinate2D
    @Binding var selectedRadius: Double // in miles
    var onExpandedChange: ((Bool) -> Void)? = nil
    var onRadiusSelectorChange: ((Bool) -> Void)? = nil
    @State private var showRadiusSelector = false
    
    private let radiusOptions: [Double] = [1, 2, 5, 10, 15] // miles
    
    // Calculate meets within selected radius
    private var nearbyMeets: [ViewMeetsModel]
    {
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let radiusInMeters = selectedRadius * 1609.34 // Convert miles to meters
        
        return meets.filter { meet in
            let meetLocation = CLLocation(latitude: meet.latitude, longitude: meet.longitude)
            return userCLLocation.distance(from: meetLocation) <= radiusInMeters
        }
    }
    
    private var badgeColor: Color
    {
        let count = nearbyMeets.count
        if count >= 10 { return AppPalette.Brand.neonPink }
        if count >= 5 { return .orange }
        if count >= 1 { return .yellow }
        return .gray
    }
    
    var body: some View
    {
        VStack(alignment: .trailing, spacing: 8) {
            // RADIUS SELECTOR DROPDOWN
            if showRadiusSelector
            {
                radiusSelectorView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8)),
                        removal: .opacity.combined(with: .scale(scale: 0.9))
                    ))
            }
            else // Main badge only shows when selector is closed
            {
                // MAIN BADGE BUTTON
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showRadiusSelector.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        // Activity indicator dot
                        Circle()
                            .fill(badgeColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: badgeColor.opacity(0.6), radius: 4)
                        
                        // Compact content
                        HStack(spacing: 4) {
                            Text("\(nearbyMeets.count)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(AppPalette.Brand.neonPink)
                            
                            Text("nearby")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppPalette.Text.nearByBadgeFillSecondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppPalette.Surface.nearByBadgeFill.opacity(0.95))
                            .overlay(
                                Capsule()
                                    .stroke(AppPalette.Surface.fieldStroke.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showRadiusSelector)
        .onChange(of: showRadiusSelector) {_, newValue in
            onRadiusSelectorChange?(newValue)
            onExpandedChange?(newValue)
        }
    }

    // RADIUS SELECTOR DROPDOWN - With X button
    @ViewBuilder
    private var radiusSelectorView: some View
    {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Radius")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                
                Spacer()
                
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showRadiusSelector = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)
            
            VStack(spacing: 2) {
                ForEach(radiusOptions, id: \.self) { radius in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedRadius = radius
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showRadiusSelector = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(selectedRadius == radius ? AppPalette.Brand.neonPink : Color.clear)
                                .frame(width: 6, height: 6)
                                .overlay(
                                    Circle()
                                        .stroke(selectedRadius == radius ? AppPalette.Brand.neonPink : .gray.opacity(0.5), lineWidth: 1)
                                )
                            
                            Text("\(radius.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", radius) : String(format: "%.1f", radius))mi")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(selectedRadius == radius ? AppPalette.Brand.neonPink : AppPalette.Text.nearByBadgeFillPrimary)
                            
                            Spacer()
                            
                            // Count for this radius
                            let countForRadius = meets.filter { meet in
                                let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                                let meetLocation = CLLocation(latitude: meet.latitude, longitude: meet.longitude)
                                let radiusInMeters = radius * 1609.34
                                return userCLLocation.distance(from: meetLocation) <= radiusInMeters
                            }.count
                            
                            Text("\(countForRadius)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedRadius == radius ? AppPalette.Brand.neonPink.opacity(0.15) : AppPalette.Surface.nearByBadgeFill.opacity(0.9))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(selectedRadius == radius ? AppPalette.Brand.neonPink.opacity(0.4) : AppPalette.Surface.fieldStroke.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .frame(width: 120)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppPalette.Surface.nearByBadgeFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }
    
    
    
}

// MARK: - Collapse when tapping outside
extension NearbyMeetsBadgeView {
    func collapse() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showRadiusSelector = false
        }
    }
}
