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
    @State private var friendsList: [FriendItem] = []
    @State private var showFriendsList = false
    @State private var showUnfriendConfirmation = false
    @State private var friendToRemove: FriendItem?
    
    @State private var isSendingFriendRequest = false
    @State private var friendshipStatus: FriendshipStatus = .none
    
    var body: some View
    {
        ZStack {
            AppPalette.Brand.formBlack
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    header
                    profileHeader
                    actionButtons
                    
                    if let stats = profileStats {
                        statsSection(stats)
                    }
                    
                    bioSection
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
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .confirmationDialog(
            "Remove Friend",
            isPresented: $showUnfriendConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Friend", role: .destructive) {
                if let friend = friendToRemove {
                    Task { await unfriend(friend) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let friend = friendToRemove {
                Text("Are you sure you want to remove \(friend.display_name) from your friends?")
            }
        }
        .sheet(isPresented: $showFriendsList) {
            FriendsListView(
                friends: friendsList,
                baseURL: baseURL,
                token: token,
                onUnfriend: { friend in
                    friendToRemove = friend
                    showUnfriendConfirmation = true
                },
                onDismiss: { showFriendsList = false }
            )
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
            .disabled(true)
            .opacity(0.6)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View
    {
        VStack(spacing: 16) {
            Circle()
                .fill(AppPalette.Brand.neonPink.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(
                    Text(user.display_name.prefix(1))
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                )
            
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
            // Primary action based on friendship status
            primaryActionButton
            
            HStack(spacing: 12) {
                secondaryActionButton(icon: "paperplane.fill", text: "Message")
                secondaryActionButton(icon: "bell.fill", text: "Notify")
            }
        }
        .padding(.vertical, 8)
    }
    
    // Replace the primaryActionButton section with this:

    @ViewBuilder
    private var primaryActionButton: some View
    {
        switch friendshipStatus {
        case .none:
            Button(action: { Task { await sendFriendRequest() } }) {
                buttonContent(
                    icon: "person.badge.plus",
                    text: "Add Friend",
                    isLoading: isSendingFriendRequest
                )
            }
            .disabled(isSendingFriendRequest)
            
        case .pendingSent:
            Button(action: {}) {
                buttonContent(icon: "checkmark", text: "Request Sent", isLoading: false)
            }
            .disabled(true)
            .opacity(0.6)
            
        case .pendingReceived:
            Button(action: {}) {
                buttonContent(icon: "clock", text: "Pending Response", isLoading: false)
            }
            .disabled(true)
            .opacity(0.6)
            
        case .friends:
            Button(action: {
                friendToRemove = FriendItem(
                    user_uuid: user.user_uuid,
                    username: user.username,
                    display_name: user.display_name,
                    friend_since: Date()
                )
                showUnfriendConfirmation = true
            }) {
                buttonContent(icon: "checkmark.circle.fill", text: "Friends", isLoading: false)
            }
        }
    }
    
    private func buttonContent(icon: String, text: String, isLoading: Bool) -> some View
    {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.white)
            } else {
                Image(systemName: icon)
                Text(text)
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(buttonColor)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var buttonColor: Color
    {
        switch friendshipStatus {
        case .none: return AppPalette.Brand.neonPink
        case .pendingSent, .pendingReceived: return Color.orange
        case .friends: return Color.green
        }
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
                
                // Just show the count, not tappable
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
    
    // MARK: - Data Loading
    private func loadProfileData() async
    {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let statsTask = AuthAPI.viewUsersProfile(
                baseURL: baseURL,
                token: token,
                userUUID: user.user_uuid
            )
            
            async let statusTask = AuthAPI.getFriendshipStatus(
                baseURL: baseURL,
                token: token,
                userUUID: user.user_uuid
            )
            
            let (stats, status) = try await (statsTask, statusTask)
            
            profileStats = stats
            friendshipStatus = status.status
        } catch {
            print("Failed to load profile: \(error)")
            errorMessage = "Failed to load profile data"
        }
    }
    
    private func sendFriendRequest() async
    {
        isSendingFriendRequest = true
        defer { isSendingFriendRequest = false }
        
        do {
            let response = try await AuthAPI.sendFriendRequest(
                baseURL: baseURL,
                token: token,
                recipientUserUUID: user.user_uuid
            )
            
            if response.success {
                friendshipStatus = .pendingSent
            } else {
                errorMessage = response.message
            }
        } catch {
            errorMessage = "Error sending friend request: \(error.localizedDescription)"
        }
    }
    
    private func unfriend(_ friend: FriendItem) async
    {
        do {
            let response = try await AuthAPI.unfriend(
                baseURL: baseURL,
                token: token,
                userUUID: friend.user_uuid
            )
            
            if response.success {
                // Remove from local list
                friendsList.removeAll { $0.id == friend.id }
                
                // Update friendship status if unfriending the current profile user
                if friend.user_uuid == user.user_uuid {
                    friendshipStatus = .none
                }
                
                // Reload profile stats to update friend count
                await loadProfileData()
            } else {
                errorMessage = response.message
            }
        } catch {
            errorMessage = "Failed to remove friend: \(error.localizedDescription)"
        }
    }
}

// MARK: - Friends List View

struct FriendsListView: View
{
    let friends: [FriendItem]
    let baseURL: URL
    let token: String
    let onUnfriend: (FriendItem) -> Void
    let onDismiss: () -> Void
    
    var body: some View
    {
        NavigationView {
            ZStack {
                AppPalette.Brand.formBlack
                    .ignoresSafeArea()
                
                if friends.isEmpty {
                    emptyStateView
                } else {
                    friendsList
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundStyle(AppPalette.Brand.neonPink)
                }
            }
        }
    }
    
    private var emptyStateView: some View
    {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
            
            Text("No Friends Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("Add friends to see them here")
                .font(.system(size: 16))
                .foregroundStyle(AppPalette.Text.secondary)
        }
    }
    
    private var friendsList: some View
    {
        List {
            ForEach(friends) { friend in
                FriendRowView(friend: friend, onUnfriend: {
                    onUnfriend(friend)
                })
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Friend Row View

struct FriendRowView: View
{
    let friend: FriendItem
    let onUnfriend: () -> Void
    
    var body: some View
    {
        HStack(spacing: 12) {
            Circle()
                .fill(AppPalette.Brand.neonPink.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(friend.display_name.prefix(1))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.display_name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("@\(friend.username)")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.Text.secondary)
                
                Text("Friends since \(friendSinceText)")
                    .font(.system(size: 12))
                    .foregroundStyle(AppPalette.Text.tertiary)
            }
            
            Spacer()
            
            Button(action: onUnfriend) {
                Image(systemName: "person.fill.xmark")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Action.delete)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(AppPalette.Brand.japPurple))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var friendSinceText: String
    {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: friend.friend_since, relativeTo: Date())
    }
}
