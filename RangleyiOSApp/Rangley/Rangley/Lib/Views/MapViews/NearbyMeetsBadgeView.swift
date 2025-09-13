//
//  NearbyMeetsBadgeView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/13/25.
//

import SwiftUI
import CoreLocation
import MapKit

struct NearbyMeetsBadgeView: View {
    let meets: [ViewMeetsModel]
    let userLocation: CLLocationCoordinate2D
    @Binding var selectedRadius: Double // in miles
    @State private var isExpanded = false
    @State private var showRadiusSelector = false
    
    private let radiusOptions: [Double] = [1, 2, 5, 10, 15] // miles
    
    // Calculate meets within selected radius
    private var nearbyMeets: [ViewMeetsModel] {
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let radiusInMeters = selectedRadius * 1609.34 // Convert miles to meters
        
        return meets.filter { meet in
            let meetLocation = CLLocation(latitude: meet.latitude, longitude: meet.longitude)
            return userCLLocation.distance(from: meetLocation) <= radiusInMeters
        }
    }
    
    // Break down by time periods
    private var todayMeets: [ViewMeetsModel] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return nearbyMeets.filter { meet in
            meet.dttm_start_utc >= today && meet.dttm_start_utc < tomorrow
        }
    }
    
    private var thisWeekMeets: [ViewMeetsModel] {
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        return nearbyMeets.filter { meet in
            meet.dttm_start_utc <= weekFromNow
        }
    }
    
    // Category breakdown
    private var categoryBreakdown: [String: Int] {
        Dictionary(grouping: nearbyMeets, by: \.category_name)
            .mapValues { $0.count }
    }
    
    private var badgeColor: Color {
        let count = nearbyMeets.count
        if count >= 10 { return AppPalette.Brand.neonPink }
        if count >= 5 { return .orange }
        if count >= 1 { return .yellow }
        return .gray
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Radius selector (appears when badge is tapped)
            if showRadiusSelector {
                radiusSelectorView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8)),
                        removal: .opacity.combined(with: .scale(scale: 0.9))
                    ))
            }
            
            // Main badge
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if isExpanded {
                        showRadiusSelector.toggle()
                    } else {
                        isExpanded = true
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    // Activity indicator dot
                    Circle()
                        .fill(badgeColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: badgeColor.opacity(0.6), radius: 4)
                    
                    if isExpanded {
                        expandedContent
                    } else {
                        compactContent
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(AppPalette.Surface.fieldFill.opacity(0.95))
                        .overlay(
                            Capsule()
                                .stroke(AppPalette.Surface.fieldStroke.opacity(0.5), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showRadiusSelector)
    }
    
    @ViewBuilder
    private var compactContent: some View {
        HStack(spacing: 4) {
            Text("\(nearbyMeets.count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("nearby")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
        }
    }
    
    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main count with radius
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(nearbyMeets.count)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("meets within")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppPalette.Text.secondary)
                
                Text("\(selectedRadius.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", selectedRadius) : String(format: "%.1f", selectedRadius))mi")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
            }
            
            // Time breakdown (if there are meets)
            if nearbyMeets.count > 0 {
                HStack(spacing: 8) {
                    if todayMeets.count > 0 {
                        timeChip(count: todayMeets.count, label: "today")
                    }
                    if thisWeekMeets.count > todayMeets.count {
                        timeChip(count: thisWeekMeets.count - todayMeets.count, label: "this week")
                    }
                }
            }
            
            // Tap to configure hint
            Text("Tap to change radius")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppPalette.Text.tertiary)
                .opacity(0.8)
        }
    }
    
    @ViewBuilder
    private func timeChip(count: Int, label: String) -> some View {
        HStack(spacing: 3) {
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppPalette.Text.primary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(AppPalette.Surface.fieldFill.opacity(0.6))
                .overlay(
                    Capsule()
                        .stroke(AppPalette.Surface.fieldStroke.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
    
    @ViewBuilder
    private var radiusSelectorView: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("Search Radius")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppPalette.Text.secondary)
            
            VStack(spacing: 4) {
                ForEach(radiusOptions, id: \.self) { radius in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedRadius = radius
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showRadiusSelector = false
                            isExpanded = false
                        }
                    } label: {
                        HStack {
                            Circle()
                                .fill(selectedRadius == radius ? AppPalette.Brand.neonPink : Color.clear)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(selectedRadius == radius ? AppPalette.Brand.neonPink : AppPalette.Text.tertiary, lineWidth: 1.5)
                                )
                            
                            Text("\(radius.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", radius) : String(format: "%.1f", radius)) miles")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selectedRadius == radius ? AppPalette.Text.primary : AppPalette.Text.secondary)
                            
                            Spacer()
                            
                            // Show count for this radius
                            let countForRadius = meets.filter { meet in
                                let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                                let meetLocation = CLLocation(latitude: meet.latitude, longitude: meet.longitude)
                                let radiusInMeters = radius * 1609.34
                                return userCLLocation.distance(from: meetLocation) <= radiusInMeters
                            }.count
                            
                            Text("(\(countForRadius))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppPalette.Text.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedRadius == radius ? AppPalette.Brand.neonPink.opacity(0.1) : AppPalette.Surface.fieldFill.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedRadius == radius ? AppPalette.Brand.neonPink.opacity(0.3) : AppPalette.Surface.fieldStroke.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppPalette.Surface.fieldFill.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppPalette.Surface.fieldStroke.opacity(0.8), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
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
