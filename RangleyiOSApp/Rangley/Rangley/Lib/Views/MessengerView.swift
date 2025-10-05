//
//  MessengerView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/4/25.
//

import SwiftUI

struct MessengerView: View
{
    let baseURL: URL
    let token: String
    let onDismiss: () -> Void
    
    @State private var friendGroups: [FriendGroup] = []
    @State private var selectedGroup: FriendGroup?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View
    {
        HStack(spacing: 0) {
            // Left sidebar with groups
            FriendGroupBar(
                groups: friendGroups,
                selectedGroup: $selectedGroup,
                baseURL: baseURL,
                token: token,
                onGroupsChanged: { await loadFriendGroups() }
            )
            
            // Main content area
            VStack(spacing: 0) {
                header
                
                ZStack {
                    AppPalette.Brand.formBlack
                        .ignoresSafeArea()
                    
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if let group = selectedGroup {
                        FriendGroupDetailView(
                            group: group,
                            baseURL: baseURL,
                            token: token,
                            onUpdate: { await loadFriendGroups() }
                        )
                    } else if friendGroups.isEmpty {
                        emptyGroupsView
                    } else {
                        emptySelectionView
                    }
                }
            }
        }
        .background(AppPalette.Brand.formBlack)
        .task {
            await loadFriendGroups()
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
            
            Text(selectedGroup?.name ?? "Groups")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .font(.system(size: 16, weight: .medium))
            .opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(AppPalette.Brand.formBlack)
    }
    
    private var emptySelectionView: some View
    {
        VStack(spacing: 20) {
            Image(systemName: "arrow.left")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
            
            Text("Select a group to view details")
                .font(.system(size: 16))
                .foregroundStyle(AppPalette.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyGroupsView: some View
    {
        VStack(spacing: 20) {
            Image(systemName: "person.2.crop.square.stack")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No Friend Groups")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("Tap the + button on the left to create your first group")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    private var loadingView: some View
    {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppPalette.Brand.neonPink)
            
            Text("Loading...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
        }
    }
    
    private func errorView(_ message: String) -> some View
    {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.orange.opacity(0.7))
            
            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(AppPalette.Text.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task { await loadFriendGroups() }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppPalette.Brand.neonPink)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 40)
    }
    
    private func loadFriendGroups() async
    {
        isLoading = true
        errorMessage = nil
        
        do {
            let groups = try await AuthAPI.viewFriendGroups(baseURL: baseURL, token: token)
            await MainActor.run {
                friendGroups = groups
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load friend groups"
                isLoading = false
            }
            print("Failed to load friend groups: \(error)")
        }
    }
}

// MARK: - Friend Group Detail View
struct FriendGroupDetailView: View
{
    let group: FriendGroup
    let baseURL: URL
    let token: String
    let onUpdate: () async -> Void
    
    @State private var showAddMembers = false
    @State private var selectedUsers: [ViewUsersModel] = []
    
    var body: some View
    {
        VStack(spacing: 20) {
            Text("\(group.member_count) member\(group.member_count == 1 ? "" : "s")")
                .font(.system(size: 16))
                .foregroundStyle(AppPalette.Text.secondary)
            
            Button {
                showAddMembers = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("Add Members")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppPalette.Brand.neonPink)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppPalette.Brand.formBlack)
        .sheet(isPresented: $showAddMembers) {
            UserSearchView(
                baseURL: baseURL,
                token: token,
                selectedUsers: $selectedUsers,
                excludedUserUUIDs: [],
                onDismiss: {
                    showAddMembers = false
                    if !selectedUsers.isEmpty {
                        Task {
                            await addMembersToGroup()
                        }
                    }
                }
            )
        }
    }
    
    private func addMembersToGroup() async
    {
        guard !selectedUsers.isEmpty else { return }
        
        do {
            let userIds = selectedUsers.map { $0.user_uuid }
            let body = AddFriendsBody(
                friend_group_id: group.friend_group_id,
                friend_uuids: userIds
            )
            try await AuthAPI.addMembersToFriendGroup(baseURL: baseURL, token: token, body: body)
            selectedUsers.removeAll()
            await onUpdate()
        } catch {
            print("Failed to add members: \(error)")
        }
    }
}
