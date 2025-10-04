//
//  UserProfileView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/3/25.
//

import SwiftUI

struct UserProfileView: View
{
    let user: ViewUsersModel
    let baseURL: URL
    let token: String
    let onDismiss: () -> Void
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var profileStats: ViewUserProfileModelResponse?
    
    var body: some View
    {
        ZStack {
            AppPalette.Brand.formBlack
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header with close button
                    header
                    
                    // Avatar and basic info
                    profileHeader
                    
                    // Action buttons
                    actionButtons
                    
                    // Stats section
                    if let stats = profileStats {
                        statsSection(stats)
                    }
                    
                    // Bio section (placeholder for future)
                    bioSection
                    
                    // Recent activity (placeholder for future)
                    activitySection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(AppPalette.Brand.neonPink)
            }
        }
        .task {
            await loadProfileData()
        }
    }
    
    // MARK: - Header
    private var header: some View
    {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppPalette.Brand.neonPink)
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppPalette.Text.secondary)
            }
            .disabled(true) // Enable when more options are ready
            .opacity(0.6)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View
    {
        VStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(AppPalette.Brand.neonPink.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(
                    Text(user.display_name.prefix(1))
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                )
            
            // Name and username
            VStack(spacing: 6) {
                Text(user.display_name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("@\(user.username)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppPalette.Text.secondary)
            }
            
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View
    {
        VStack(spacing: 12) {
            // Primary action (will become friend request)
            Button(action: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("Add Friend")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppPalette.Brand.neonPink)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(true)
            .opacity(0.6)
            
            HStack(spacing: 12) {
                // Secondary actions
                secondaryActionButton(icon: "paperplane.fill", text: "Message")
                secondaryActionButton(icon: "bell.fill", text: "Notify")
            }
        }
        .padding(.vertical, 8)
    }
    
    private func secondaryActionButton(icon: String, text: String) -> some View
    {
        Button(action: {}) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(text)
                    .font(.system(size: 15, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.clear)
            .foregroundStyle(AppPalette.Brand.neonPink)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppPalette.Brand.neonPink.opacity(0.5), lineWidth: 1)
            )
        }
        .disabled(true)
        .opacity(0.6)
    }
    
    private func statsSection(_ stats: ViewUserProfileModelResponse) -> some View
    {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            HStack(spacing: 16) {
                statCard(value: "\(stats.meets_created)", label: "Meets Created", icon: "plus.circle.fill")
                statCard(value: "\(stats.meets_attended)", label: "Meets Attended", icon: "checkmark.circle.fill")
                statCard(value: "\(stats.friend_count)", label: "Friends", icon: "person.2.fill")
            }
        }
        .padding(.top, 8)
    }
    
    private func statCard(value: String, label: String, icon: String) -> some View
    {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(AppPalette.Brand.neonPink)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(AppPalette.Brand.japPurple))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Bio Section (Placeholder)
    private var bioSection: some View
    {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("Bio and additional profile info will appear here.")
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.Text.secondary)
                .italic()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
    
    // MARK: - Activity Section (Placeholder)
    private var activitySection: some View
    {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("Recent meets and activity will appear here.")
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.Text.secondary)
                .italic()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
    
    // MARK: - Helper Views
    private func matchBadge(text: String, icon: String, color: Color) -> some View
    {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Data Loading
    private func loadProfileData() async
    {
        isLoading = true
        defer { isLoading = false }
        
        do {
            profileStats = try await AuthAPI.viewUsersProfile(
                baseURL: baseURL,
                token: token,
                userUUID: user.user_uuid
            )
        } catch {
            print("Failed to load profile: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct ProfileStats
{
    let meetsCreated: Int
    let meetsAttended: Int
    let friendCount: Int
}
