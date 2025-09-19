//
//  NearbyMeetsBadgeView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/13/25.
//

// =========================================================
// =========================================================
// =========================================================
// MARK: - IGNORE THE BELOW TODOs FOR NOW

// TODO: - Might be some unreachable code you need to remove
// TODO: - Consider removing Opacity from here

// MARK: - IGNORE THE ABOVE TODOs FOR NOW
// =========================================================
// =========================================================
// =========================================================

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
    @State private var isExpanded = false
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
    
    // Break down by time periods
    private var todayMeets: [ViewMeetsModel]
    {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return nearbyMeets.filter { meet in
            meet.dttm_start_utc >= today && meet.dttm_start_utc < tomorrow
        }
    }
    
    private var thisWeekMeets: [ViewMeetsModel]
    {
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        return nearbyMeets.filter { meet in
            meet.dttm_start_utc <= weekFromNow
        }
    }
    
    // Category breakdown
    private var categoryBreakdown: [String: Int]
    {
        Dictionary(grouping: nearbyMeets, by: \.category_name)
            .mapValues { $0.count }
    }
    
    private var badgeColor: Color
    {
        let count = nearbyMeets.count
        if count >= 10 { return AppPalette.Brand.neonPink }
        if count >= 5 { return .orange }
        if count >= 1 { return .yellow }
        return .gray
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // RADIUS SELECTOR DROPDOWN MENU - The big white menu that appears when you tap the badge
            if showRadiusSelector
            {
                radiusSelectorView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8)),
                        removal: .opacity.combined(with: .scale(scale: 0.9))
                    ))
            }
            else // this may be unreachable
            {
                // MAIN BADGE BUTTON - The floating capsule that shows "X nearby" or expanded info
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if showRadiusSelector {
                            // If radius selector is showing, close everything
                            showRadiusSelector = false
                            isExpanded = false
                        } else if isExpanded {
                            // If expanded, show radius selector
                            showRadiusSelector = true
                        } else {
                            // If compact, expand
                            isExpanded = true
                        }
                    }
                } label:
                {
                    HStack(spacing: 8) {
                        // Activity indicator dot
                        Circle()
                            .fill(badgeColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: badgeColor.opacity(0.6), radius: 4)
                        
                        if isExpanded {
                            expandedContent // EXPANDED BADGE CONTENT - Shows detailed info when badge is tapped once
                        } else {
                            compactContent // COMPACT BADGE CONTENT - Initial "X nearby" view
                        }
                        
                        // Add close/chevron indicator when expanded
                        if isExpanded || showRadiusSelector {
                            Image(systemName: showRadiusSelector ? "xmark.circle.fill" : "chevron.down.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(AppPalette.Brand.neonPink)
                                .opacity(0.8)
                                .rotationEffect(.degrees(showRadiusSelector ? 0 : 0))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        // MAIN BADGE BACKGROUND - Controls the translucency of the floating badge
                        Capsule()
                            .fill(AppPalette.Surface.nearByBadgeFill.opacity(0.95))
                            .overlay(
                                Capsule()
                                    .stroke(showRadiusSelector ? AppPalette.Brand.neonPink.opacity(0.5) : AppPalette.Surface.fieldStroke.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }

        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showRadiusSelector)
        .onChange(of: isExpanded) { _, newValue in
            onExpandedChange?(newValue)
        }
        .onChange(of: showRadiusSelector) {_, newValue in
            onRadiusSelectorChange?(newValue)
        }
        // Add tap gesture to dismiss when tapping outside
        .onTapGesture {
            // This won't interfere with button tap since button consumes the gesture first
        }
    }
    
    // COMPACT BADGE CONTENT - The initial small view showing just "X nearby"
    @ViewBuilder
    private var compactContent: some View
    {
        HStack(spacing: 4) {
            Text("\(nearbyMeets.count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppPalette.Brand.neonPink)
            
            Text("nearby")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.Text.nearByBadgeFillSecondary)
        }
    }
    
    // EXPANDED BADGE CONTENT - The larger view with detailed breakdown when badge is tapped once
    @ViewBuilder
    private var expandedContent: some View
    {
        VStack(alignment: .leading, spacing: 4)
        {
            // Main count with radius
            HStack(alignment: .firstTextBaseline, spacing: 4)
            {
                Text("\(nearbyMeets.count)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                
                Text("meets within")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppPalette.Text.nearByBadgeFillSecondary)
                
                Text("\(selectedRadius.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", selectedRadius) : String(format: "%.1f", selectedRadius))mi")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showRadiusSelector = false
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
                }
                .buttonStyle(.plain)
                
            }
            
            // Time breakdown (if there are meets)
            if nearbyMeets.count > 0 {
                HStack(spacing: 8) {
                    if todayMeets.count > 0 {
                        timeChip(count: todayMeets.count, label: "today") // TIME CHIPS - Small pills showing "today" and "this week"
                    }
                    if thisWeekMeets.count > todayMeets.count {
                        timeChip(count: thisWeekMeets.count - todayMeets.count, label: "this week") // TIME CHIPS
                    }
                }
            }
            
            // Tap to configure hint - now shows different message based on state
            Text(showRadiusSelector ? "Tap × to close" : "Tap ↓ to change radius")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppPalette.Brand.neonPink)
                .opacity(0.7)
        }
    }
    
    // TIME CHIPS - Small capsule-shaped elements showing time-based counts (today/this week)
    @ViewBuilder
    private func timeChip(count: Int, label: String) -> some View
    {
        HStack(spacing: 3) {
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppPalette.Brand.neonPink)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppPalette.Text.nearByBadgeFillSecondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            // TIME CHIP BACKGROUND - Controls the translucency of the small time pills
            Capsule()
                .fill(AppPalette.Surface.nearByBadgeFill.opacity(0.6))
                .overlay(
                    Capsule()
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
    
    // RADIUS SELECTOR DROPDOWN MENU - The big white popup menu for choosing search radius
    @ViewBuilder
    private var radiusSelectorView: some View
    {
        VStack(alignment: .trailing, spacing: 8) {
            HStack {
                Text("Search Radius")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                
                Spacer()
                
                // Close button for the radius selector
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showRadiusSelector = false
                        isExpanded = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            
            VStack(spacing: 3) {
                ForEach(radiusOptions, id: \.self) { radius in
                    // RADIUS OPTION BUTTON - Individual selectable radius option in the dropdown
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedRadius = radius
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showRadiusSelector = false
                            isExpanded = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(selectedRadius == radius ? AppPalette.Brand.neonPink : Color.clear)
                                .frame(width: 6, height: 6)
                                .overlay(
                                    Circle()
                                        .stroke(selectedRadius == radius ? AppPalette.Brand.neonPink : .gray, lineWidth: 1)
                                )
                            
                            Text("\(radius.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", radius) : String(format: "%.1f", radius))mi")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(selectedRadius == radius ? AppPalette.Brand.neonPink : AppPalette.Text.nearByBadgeFillPrimary)
                            
                            Spacer()
                            
                            // Show count for this radius
                            let countForRadius = meets.filter { meet in
                                let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                                let meetLocation = CLLocation(latitude: meet.latitude, longitude: meet.longitude)
                                let radiusInMeters = radius * 1609.34
                                return userCLLocation.distance(from: meetLocation) <= radiusInMeters
                            }.count
                            
                            Text("(\(countForRadius))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            // RADIUS OPTION BACKGROUND - Individual button backgrounds in the dropdown
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedRadius == radius ? AppPalette.Brand.neonPink.opacity(0.15) : AppPalette.Surface.nearByBadgeFill.opacity(0.9))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(selectedRadius == radius ? AppPalette.Brand.neonPink.opacity(0.4) : AppPalette.Surface.fieldStroke.opacity(0.6), lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Add a subtle hint at the bottom
            Text("Tap to select")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.6))
                .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: 160) // Constrain the width
        .background(
            // DROPDOWN MENU BACKGROUND - The main white background of the entire dropdown menu
            RoundedRectangle(cornerRadius: 12)
                .fill(AppPalette.Surface.nearByBadgeFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 15, y: 8)
    }
}

// MARK: - Collapse when tapping outside
extension NearbyMeetsBadgeView {
    func collapse() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded = false
            showRadiusSelector = false
        }
    }
}
