//
//  FriendGroupsBar.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/4/25.
//

import SwiftUI

// MARK: - Container for Sheet Presentation
struct FriendGroupBarContainer: View
{
    let baseURL: URL
    let token: String
    
    @State private var friendGroups: [FriendGroup] = []
    @State private var selectedGroup: FriendGroup?
    @State private var isLoading = false
    @State private var showGroupDetail = false
    
    var body: some View
    {
        NavigationView {
            HStack(spacing: 0) {
                FriendGroupBar(
                    groups: friendGroups,
                    selectedGroup: $selectedGroup,
                    baseURL: baseURL,
                    token: token,
                    onGroupsChanged: { await loadFriendGroups() },
                    onGroupTapped: {
                        showGroupDetail = true
                    }
                )
                
                VStack {
                    // Header
                    HStack {
                        Text("Groups")
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
                    
                    // Content
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(AppPalette.Brand.neonPink)
                        Spacer()
                    } else if let group = selectedGroup {
                        Text("Selected: \(group.name)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppPalette.Text.primary)
                            .padding()
                        Spacer()
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
                            
                            Text("Select a group")
                                .font(.system(size: 16))
                                .foregroundStyle(AppPalette.Text.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppPalette.Brand.formBlack)
            }
            .navigationBarHidden(true)
        }
        .task {
            await loadFriendGroups()
        }
        .sheet(isPresented: $showGroupDetail) {
            if let group = selectedGroup {
                FriendGroupDetailView(
                    group: group,
                    baseURL: baseURL,
                    token: token,
                    onDismiss: {
                        showGroupDetail = false
                    }
                )
            }
        }
    }
    
    private func loadFriendGroups() async
    {
        isLoading = true
        
        do {
            let groups = try await AuthAPI.viewFriendGroups(baseURL: baseURL, token: token)
            await MainActor.run {
                friendGroups = groups
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
            print("Failed to load friend groups: \(error)")
        }
    }
}

// MARK: - Friend Group Bar (Floating Vertical Dock Style)
struct FriendGroupBar: View
{
    let groups: [FriendGroup]
    @Binding var selectedGroup: FriendGroup?
    let baseURL: URL
    let token: String
    let onGroupsChanged: () async -> Void
    let onGroupTapped: () -> Void
    
    @State private var showCreateGroup = false
    
    var body: some View
    {
        VStack(spacing: 0) {
            Button(action: { showCreateGroup = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .imageScale(.large)
                    .foregroundStyle(AppPalette.Brand.neonPink)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(AppPalette.Brand.neonPink.opacity(0.14))
                    )
                    .overlay(
                        Circle()
                            .stroke(AppPalette.Brand.neonPink.opacity(0.55), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
            
            Rectangle()
                .fill(AppPalette.Brand.neonPink.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(groups, id: \.friend_group_id) { group in
                        GroupDockButton(
                            group: group,
                            isSelected: selectedGroup?.friend_group_id == group.friend_group_id,
                            onTap: {
                                selectedGroup = group
                                onGroupTapped()
                            },
                            onDelete: {
                                deleteGroup(group)
                            }
                        )
                    }
                }
            }
            
            Spacer()
        }
        .padding(.top, 20)
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppPalette.Brand.neonPink.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.25), lineWidth: 1)
                )
        )
        .shadow(color: AppPalette.Brand.neonPink.opacity(0.15), radius: 8, x: 0, y: 4)
        .frame(width: 64)
        .sheet(isPresented: $showCreateGroup) {
            CreateFriendGroupView(
                baseURL: baseURL,
                token: token,
                onDismiss: {
                    showCreateGroup = false
                    Task { await onGroupsChanged() }
                }
            )
        }
    }
    
    private func deleteGroup(_ group: FriendGroup) {
        Task {
            do {
                let body = DeleteGroupBody(friend_group_id: group.friend_group_id)
                let response = try await AuthAPI.deleteFriendGroup(baseURL: baseURL, token: token, body: body)
                
                if response.success {
                    if selectedGroup?.friend_group_id == group.friend_group_id {
                        selectedGroup = nil
                    }
                    await onGroupsChanged()
                }
            } catch {
                print("Failed to delete group: \(error)")
            }
        }
    }
}

// MARK: - Group Dock Button
private struct GroupDockButton: View
{
    let group: FriendGroup
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirm = false
    
    private var initials: String {
        let words = group.name.split(separator: " ")
        if words.count >= 2 {
            let first = String(words[0].prefix(1))
            let second = String(words[1].prefix(1))
            return (first + second).uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "G"
    }
    
    var body: some View
    {
        Button(action: onTap) {
            Text(initials)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(
                    isSelected ? AppPalette.Brand.neonPink : AppPalette.Text.primary
                )
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(
                            isSelected
                                ? AppPalette.Brand.neonPink.opacity(0.2)
                                : AppPalette.Brand.japPurple
                        )
                )
                .overlay(
                    Circle()
                        .stroke(
                            isSelected
                                ? AppPalette.Brand.neonPink.opacity(0.8)
                                : AppPalette.Brand.neonPink.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(
                    color: isSelected ? AppPalette.Brand.neonPink.opacity(0.3) : .clear,
                    radius: isSelected ? 8 : 0,
                    x: 0,
                    y: 0
                )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete Group", systemImage: "trash")
            }
        }
        .alert("Delete \(group.name)?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the group for all members. This action cannot be undone.")
        }
    }
}

// MARK: - Friend Group Detail View
struct FriendGroupDetailView: View
{
    let group: FriendGroup
    let baseURL: URL
    let token: String
    let onDismiss: () -> Void
    
    @State private var members: [GroupMember] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    
    var body: some View
    {
        NavigationView {
            ZStack {
                AppPalette.Brand.formBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Group info header
                    VStack(spacing: 12) {
                        Text(group.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppPalette.Text.primary)
                        
                        Text("\(members.count) member\(members.count == 1 ? "" : "s")")
                            .font(.system(size: 14))
                            .foregroundStyle(AppPalette.Text.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    
                    // Content area
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(AppPalette.Brand.neonPink)
                        Spacer()
                    } else if let error = errorMessage {
                        Spacer()
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .padding()
                        Spacer()
                    } else if members.isEmpty {
                        VStack(spacing: 0) {
                            Spacer()
                            VStack(spacing: 16) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundStyle(AppPalette.Text.tertiary)
                                
                                Text("No members yet")
                                    .font(.system(size: 16))
                                    .foregroundStyle(AppPalette.Text.secondary)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(members, id: \.user_uuid) { member in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(AppPalette.Brand.japPurple)
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Text(String(member.display_name.prefix(1)))
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundStyle(AppPalette.Text.primary)
                                            )
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(member.display_name)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(AppPalette.Text.primary)
                                            
                                            Text("@\(member.username)")
                                                .font(.system(size: 14))
                                                .foregroundStyle(AppPalette.Text.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(AppPalette.Surface.fieldFill)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                                            )
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 180)
                        }
                    }
                    
                    // Bottom buttons
                    VStack(spacing: 12) {
                        Divider()
                            .background(AppPalette.Surface.fieldStroke)
                        
                        if !members.isEmpty {
                            Button {
                                // TODO: Navigate to create meet with this group
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    Text("Create Meet with Group")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppPalette.Brand.neonPink)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Delete button
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                Text("Delete Group")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(AppPalette.Brand.formBlack)
                }
            }
            .navigationTitle("Group Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDismiss() }
                        .foregroundStyle(AppPalette.Brand.neonPink)
                }
            }
            .alert("Delete \(group.name)?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    deleteGroup()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the group for all members. This action cannot be undone.")
            }
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(AppPalette.Brand.neonPink)
                    }
                }
            }
        }
        .task {
            await loadMembers()
        }
    }
    
    private func deleteGroup() {
        Task {
            isDeleting = true
            
            do {
                let body = DeleteGroupBody(friend_group_id: group.friend_group_id)
                let response = try await AuthAPI.deleteFriendGroup(baseURL: baseURL, token: token, body: body)
                
                if response.success {
                    onDismiss()
                } else {
                    errorMessage = response.message
                    isDeleting = false
                }
            } catch {
                errorMessage = "Failed to delete group"
                isDeleting = false
            }
        }
    }
    
    private func loadMembers() async
    {
        isLoading = true
        errorMessage = nil
        
        do {
            let body = ViewMembersBody(friend_group_id: group.friend_group_id)
            let fetchedMembers = try await AuthAPI.viewFriendGroupMembers(baseURL: baseURL, token: token, body: body)
            
            await MainActor.run {
                members = fetchedMembers
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load members"
                isLoading = false
            }
            print("Failed to load group members: \(error)")
        }
    }
}

struct CreateFriendGroupView: View
{
    let baseURL: URL
    let token: String
    let onDismiss: () -> Void
    
    @State private var groupName = ""
    @State private var isCreating = false
    @State private var errorMessage     : String?
    @State private var navigationPath = NavigationPath()
    @State private var createdGroupId   : Int64?
    @State private var selectedUsers    : [ViewUsersModel] = []
    
    var body: some View
    {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Name")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.Text.secondary)
                    
                    TextField("e.g. Basketball Crew", text: $groupName)
                        .font(.system(size: 16))
                        .foregroundStyle(AppPalette.Text.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(AppPalette.Surface.fieldFill)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                        )
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
                
                Spacer()
            }
            .padding(20)
            .background(AppPalette.Brand.formBlack)
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .foregroundStyle(AppPalette.Text.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createGroup) {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(AppPalette.Brand.neonPink)
                        } else {
                            Text("Next")
                                .foregroundStyle(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppPalette.Text.tertiary : AppPalette.Brand.neonPink)
                        }
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
            .navigationDestination(for: Int64.self) { groupId in
                AddMembersInlineView(
                    groupId: groupId,
                    groupName: groupName,
                    baseURL: baseURL,
                    token: token,
                    selectedUsers: $selectedUsers,
                    onComplete: onDismiss
                )
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "userSearch" {
                    UserSearchInlineView(
                        baseURL: baseURL,
                        token: token,
                        selectedUsers: $selectedUsers
                    )
                }
            }
        }
    }
    
    private func createGroup()
    {
        Task {
            isCreating = true
            errorMessage = nil
            
            do {
                let body = CreateGroupBody(group_name: groupName.trimmingCharacters(in: .whitespacesAndNewlines))
                let response = try await AuthAPI.createFriendGroup(baseURL: baseURL, token: token, body: body)
                
                guard let groupId = response.friend_group_id else {
                    errorMessage = "Failed to create group: No group ID returned"
                    isCreating = false
                    return
                }
                
                navigationPath.append(groupId)
                isCreating = false
            } catch {
                errorMessage = "Failed to create group"
                isCreating = false
            }
        }
    }
}

struct SelectedUsersChips: View
{
    @Binding var selectedUsers: [ViewUsersModel]
    
    var body: some View
    {
        VStack(spacing: 12) {
            HStack {
                Text("Selected (\(selectedUsers.count))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.Text.primary)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(selectedUsers, id: \.user_uuid) { user in
                        HStack(spacing: 8) {
                            Text(user.display_name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppPalette.Text.primary)
                            
                            Button {
                                selectedUsers.removeAll { $0.user_uuid == user.user_uuid }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppPalette.Text.tertiary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AppPalette.Brand.neonPink.opacity(0.2))
                                .overlay(
                                    Capsule().stroke(AppPalette.Brand.neonPink.opacity(0.4), lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
    }
}

// Inline user search (no sheet)
struct UserSearchInlineView: View
{
    let baseURL: URL
    let token: String
    @Binding var selectedUsers: [ViewUsersModel]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View
    {
        UserSearchView(
            baseURL: baseURL,
            token: token,
            selectedUsers: $selectedUsers,
            excludedUserUUIDs: [],
            onDismiss: { dismiss() }
        )
        .navigationTitle("Search Friends")
        .navigationBarTitleDisplayMode(.inline)
    }
}


struct AddMembersInlineView: View
{
    let groupId: Int64
    let groupName: String
    let baseURL: URL
    let token: String
    @Binding var selectedUsers: [ViewUsersModel]
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isAdding = false
    @State private var errorMessage: String?
    
    var body: some View
    {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Add members to")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.Text.secondary)
                
                Text(groupName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppPalette.Text.primary)
            }
            .padding(.top, 20)
            
            if !selectedUsers.isEmpty {
                SelectedUsersChips(selectedUsers: $selectedUsers)
            }
            
            NavigationLink(value: "userSearch") {
                HStack(spacing: 12) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(selectedUsers.isEmpty ? "Search Friends to Add" : "Add More Friends")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppPalette.Brand.neonPink)
                )
            }
            .buttonStyle(.plain)
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(AppPalette.Brand.formBlack)
        .navigationTitle("Add Members")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: finishCreation) {
                    if isAdding {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(AppPalette.Brand.neonPink)
                    } else {
                        Text(selectedUsers.isEmpty ? "Skip" : "Done")
                            .foregroundStyle(AppPalette.Brand.neonPink)
                    }
                }
                .disabled(isAdding)
            }
        }
    }
    
    private func finishCreation()
    {
        guard !selectedUsers.isEmpty else {
            onComplete()
            return
        }
        
        Task {
            isAdding = true
            
            do {
                let body = AddFriendsBody(
                    friend_group_id: groupId,
                    friend_uuids: selectedUsers.map { $0.user_uuid }
                )
                _ = try await AuthAPI.addFriendsToGroup(baseURL: baseURL, token: token, body: body)
                onComplete()
            } catch {
                errorMessage = "Failed to add members"
                isAdding = false
            }
        }
    }
}
