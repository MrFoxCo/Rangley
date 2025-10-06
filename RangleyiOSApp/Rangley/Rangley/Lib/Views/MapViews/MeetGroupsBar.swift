//
//  MeetGroupBar.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/4/25.
//


import SwiftUI

// MARK: - Meet Group Bar (Floating Vertical Dock Style)
struct MeetGroupBar: View
{
    let groups: [MeetGroup]
    @Binding var selectedGroup: MeetGroup?
    let baseURL: URL
    let token: String
    let onGroupsChanged: () async -> Void
    let onGroupTapped: () -> Void
    
    @State private var showCreateGroup = false
    
    var body: some View
    {
        HStack(spacing: 0) {
            // Plus button - fixed on left
            Button(action: { showCreateGroup = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(AppPalette.Brand.japPurple)
                    )
                    .overlay(
                        Circle()
                            .stroke(AppPalette.Brand.neonPink.opacity(0.4), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            
            // Divider
            Rectangle()
                .fill(AppPalette.Brand.neonPink.opacity(0.25))
                .frame(width: 1)
                .padding(.horizontal, 12)
            
            // Empty state or scrollable groups
            if groups.isEmpty {
                // Empty state label
                Text("My Meet Groups")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 16)
            } else {
                // Scrollable groups
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(groups, id: \.meet_group_id) { group in
                            GroupHorizontalButton(
                                group: group,
                                isSelected: selectedGroup?.meet_group_id == group.meet_group_id,
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
                    .padding(.horizontal, 4)
                }
                .padding(.trailing, 16)
            }
        }
        .frame(height: 66)
        .background(
            RoundedRectangle(cornerRadius: 33, style: .continuous)
                .fill(AppPalette.Brand.neonPink.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 33, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppPalette.Brand.neonPink.opacity(0.12), radius: 12, x: 0, y: 4)
        .sheet(isPresented: $showCreateGroup) {
            CreateMeetGroupView(
                baseURL: baseURL,
                token: token,
                onDismiss: {
                    showCreateGroup = false
                    Task { await onGroupsChanged() }
                }
            )
        }
    }
    
    private func deleteGroup(_ group: MeetGroup) {
        Task {
            do {
                let body = DeleteGroupBody(meet_group_id: group.meet_group_id)
                let response = try await AuthAPI.deleteMeetGroup(baseURL: baseURL, token: token, body: body)
                
                if response.success {
                    if selectedGroup?.meet_group_id == group.meet_group_id {
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

private struct GroupHorizontalButton: View
{
    let group: MeetGroup
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirm = false
    
    private var groupIcon: String {
        return group.image_reference
    }
    
    var body: some View
    {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: groupIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        isSelected ? .white : AppPalette.Brand.neonPink
                    )
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(
                                isSelected
                                    ? AppPalette.Brand.neonPink
                                    : AppPalette.Brand.japPurple
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected
                                    ? AppPalette.Brand.neonPink
                                    : AppPalette.Brand.neonPink.opacity(0.4),
                                lineWidth: isSelected ? 2 : 1.5
                            )
                    )
                    .shadow(
                        color: isSelected ? AppPalette.Brand.neonPink.opacity(0.4) : .clear,
                        radius: isSelected ? 8 : 0
                    )
                
                // Group name - only show if selected
                if isSelected {
                    Text(group.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppPalette.Text.primary)
                        .lineLimit(1)
                        .frame(maxWidth: 70)
                }
            }
            .padding(.vertical, 4)
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

// MARK: - Group Dock Button
private struct GroupDockButton: View
{
    let group: MeetGroup
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirm = false
    
    private var groupIcon: String {
        // Use the image_reference for SF Symbol
        return group.image_reference
    }
    
    var body: some View
    {
        Button(action: onTap) {
            Image(systemName: groupIcon)
                .font(.system(size: 20, weight: .semibold))
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

// MARK: - Updated MeetGroupDetailView (Invitation Only)
struct MeetGroupDetailView: View
{
    @EnvironmentObject var authState: AuthStateStore
    
    let group           : MeetGroup
    let baseURL         : URL
    let token           : String
    let onDismiss       : () -> Void
    let onGroupChanged  : () async -> Void
    
    @State private var members: [GroupMember] = []
    @State private var currentUserUUID: UUID?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var showImagePicker = false
    @State private var showInviteMembers = false // REMOVED: showAddMembers
    
    
    private var isCurrentUserOwner: Bool
    {
        guard let userUUID = authState.currentUser?.user_uuid else { return false }
        return members.first(where: { $0.user_uuid == userUUID })?.is_owner ?? false
    }
    
    var body: some View
    {
        NavigationView {
            ZStack {
                AppPalette.Brand.formBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Group info header
                    VStack(spacing: 12) {
                        // MARK: -  Group icon
                        Button {
                            showImagePicker = true
                        } label: {
                            Image(systemName: group.image_reference)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(AppPalette.Brand.neonPink)
                                .frame(width: 80, height: 80)
                                .background(
                                    Circle()
                                        .fill(AppPalette.Brand.neonPink.opacity(0.2))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(AppPalette.Brand.neonPink.opacity(0.8), lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        
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
                    
                    // MARK: -  Action button (ONLY INVITE)
                    if isCurrentUserOwner {
                       VStack(spacing: 12) {
                           Button {
                               showInviteMembers = true
                           } label: {
                               HStack(spacing: 8) {
                                   Image(systemName: "envelope.badge.person.crop")
                                       .font(.system(size: 14, weight: .semibold))
                                   Text("Invite Members")
                                       .font(.system(size: 14, weight: .semibold))
                               }
                               .foregroundStyle(.white)
                               .frame(maxWidth: .infinity)
                               .frame(height: 44)
                               .background(
                                   RoundedRectangle(cornerRadius: 10)
                                       .fill(AppPalette.Brand.neonPink)
                               )
                           }
                           .buttonStyle(.plain)
                           .padding(.horizontal, 20)
                           .padding(.bottom, 16)
                       }
                   }
                    
                    // MARK: -  Content area
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
                    }
                    if !members.isEmpty
                    {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(members, id: \.user_uuid) { member in
                                    HStack(spacing: 12) {
                                        ZStack(alignment: .topTrailing) {
                                            Circle()
                                                .fill(AppPalette.Brand.japPurple)
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Text(String(member.display_name.prefix(1)))
                                                        .font(.system(size: 18, weight: .semibold))
                                                        .foregroundStyle(AppPalette.Text.primary)
                                                )
                                            
                                            // Crown for owner
                                            if member.is_owner {
                                                Image(systemName: "crown.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(AppPalette.Brand.neonPink)
                                                    .offset(x: 4, y: -4)
                                            }
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(member.display_name)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(AppPalette.Text.primary)
                                            
                                            Text("@\(member.username)")
                                                .font(.system(size: 14))
                                                .foregroundStyle(AppPalette.Text.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        // Only show remove button if current user is owner AND member is not owner
                                        if isCurrentUserOwner && !member.is_owner {
                                            Button {
                                                removeMember(member)
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(.red.opacity(0.8))
                                            }
                                            .buttonStyle(.plain)
                                        }
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
                    
                    // MARK: - Bottom buttons
                    VStack(spacing: 12)
                    {
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
                        
                        if isCurrentUserOwner {
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
                       } else {
                           Button {
                               leaveGroup()
                           } label: {
                               HStack(spacing: 12) {
                                   Image(systemName: "arrow.right.square")
                                       .font(.system(size: 16, weight: .semibold))
                                   Text("Leave Group")
                                       .font(.system(size: 16, weight: .semibold))
                               }
                               .foregroundStyle(.white)
                               .frame(maxWidth: .infinity)
                               .frame(height: 50)
                               .background(
                                   RoundedRectangle(cornerRadius: 12)
                                       .fill(Color.orange)
                               )
                           }
                           .buttonStyle(.plain)
                       }
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
        .sheet(isPresented: $showImagePicker) {
            MeetGroupIconPicker(
                currentIcon: group.image_reference,
                baseURL: baseURL,
                token: token,
                groupId: group.meet_group_id,
                onDismiss: { showImagePicker = false }
            )
        }
        .sheet(isPresented: $showInviteMembers) {
            InviteMembersToMeetGroupView(
                group: group,
                baseURL: baseURL,
                token: token,
                onDismiss: {
                    showInviteMembers = false
                }
            )
        }
    }
    
    private func removeMember(_ member: GroupMember)
    {
        Task {
            do {
                let body = RemoveMembersBody(
                    meet_group_id: group.meet_group_id,
                    user_uuids: [member.user_uuid]
                )
                let response = try await AuthAPI.deleteMembersFromMeetGroup(baseURL: baseURL, token: token, body: body)
                
                if response.success {
                    await loadMembers()
                    await onGroupChanged()
                }
            } catch {
                errorMessage = "Failed to remove member"
            }
        }
    }
    
    private func deleteGroup()
    {
        Task {
            isDeleting = true
            
            do {
                let body = DeleteGroupBody(meet_group_id: group.meet_group_id)
                let response = try await AuthAPI.deleteMeetGroup(baseURL: baseURL, token: token, body: body)
                
                if response.success {
                    await onGroupChanged()
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
            let fetchedMembers = try await AuthAPI.viewMeetGroupMembers(baseURL: baseURL, token: token, meetGroupId: group.meet_group_id)
            
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
    
    private func leaveGroup()
    {
        Task {
            do {
                let body = LeaveMeetGroupBody(meet_group_id: group.meet_group_id)
                let response = try await AuthAPI.leaveMeetGroup(baseURL: baseURL, token: token, body: body)
                
                if response.success {
                    await onGroupChanged()
                    onDismiss()
                } else {
                    errorMessage = response.message
                }
            } catch {
                errorMessage = "Failed to leave group"
            }
        }
    }
}

// MARK: - Meet Group Icon Picker
struct MeetGroupIconPicker: View
{
    let currentIcon: String
    let baseURL: URL
    let token: String
    let groupId: Int64
    let onDismiss: () -> Void
    
    @State private var isUpdating = false
    @State private var errorMessage: String?
    
    private let availableIcons = [
        "person.3.fill",
        "basketball.fill",
        "football.fill",
        "fork.knife",
        "book.fill",
        "figure.run",
        "gamecontroller.fill",
        "music.note",
        "airplane",
        "cup.and.saucer.fill",
        "film.fill",
        "paintbrush.fill",
        "leaf.fill",
        "brain.head.profile",
        "heart.fill",
        "wineglass.fill",
        "tennis.racket"
    ]
    
    var body: some View
    {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose Group Icon")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppPalette.Text.primary)
                    .padding(.top, 20)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button {
                            updateIcon(icon)
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(
                                    currentIcon == icon ? AppPalette.Brand.neonPink : AppPalette.Text.primary
                                )
                                .frame(width: 60, height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            currentIcon == icon
                                                ? AppPalette.Brand.neonPink.opacity(0.2)
                                                : AppPalette.Brand.japPurple
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            currentIcon == icon
                                                ? AppPalette.Brand.neonPink
                                                : AppPalette.Brand.neonPink.opacity(0.3),
                                            lineWidth: currentIcon == icon ? 2 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isUpdating)
                    }
                }
                .padding(.horizontal, 20)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
                
                Spacer()
            }
            .background(AppPalette.Brand.formBlack)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { onDismiss() }
                        .foregroundStyle(AppPalette.Brand.neonPink)
                        .disabled(isUpdating)
                }
            }
            .overlay {
                if isUpdating {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(AppPalette.Brand.neonPink)
                    }
                }
            }
        }
    }
    
    private func updateIcon(_ icon: String) {
        Task {
            isUpdating = true
            errorMessage = nil
            
            do {
                let body = ModifyImageBody(
                    meet_group_id: groupId,
                    image_reference: icon
                )
                let response = try await AuthAPI.modifyMeetGroupImage(baseURL: baseURL, token: token, body: body)
                
                if response.success {
                    onDismiss()
                } else {
                    errorMessage = response.message
                    isUpdating = false
                }
            } catch {
                errorMessage = "Failed to update icon"
                isUpdating = false
            }
        }
    }
}

// MARK: - Create Meet Group View
struct CreateMeetGroupView: View
{
    let baseURL: URL
    let token: String
    let onDismiss: () -> Void
    
    @State private var groupName = ""
    @State private var selectedIcon = "person.3.fill"
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var navigationPath = NavigationPath()
    @State private var createdGroupId: Int64?
    @State private var selectedUsers: [ViewUsersModel] = []
    
    private let availableIcons = [
        "person.3.fill",
        "basketball.fill",
        "football.fill",
        "fork.knife",
        "book.fill",
        "figure.run",
        "gamecontroller.fill",
        "music.note",
        "airplane",
        "cup.and.saucer.fill",
        "film.fill",
        "paintbrush.fill",
        "leaf.fill",
        "brain.head.profile",
        "heart.fill",
        "wineglass.fill",
        "tennis.racket"
    ]
    
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
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Icon")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.Text.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(
                                        selectedIcon == icon ? AppPalette.Brand.neonPink : AppPalette.Text.primary
                                    )
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                selectedIcon == icon
                                                    ? AppPalette.Brand.neonPink.opacity(0.2)
                                                    : AppPalette.Brand.japPurple
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                selectedIcon == icon
                                                    ? AppPalette.Brand.neonPink
                                                    : AppPalette.Brand.neonPink.opacity(0.3),
                                                lineWidth: selectedIcon == icon ? 2 : 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
            .navigationTitle("Create Meet Group")
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
                InviteMembersToMeetGroupInlineView(
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
                let body = InsertGroupBody(
                    group_name: groupName.trimmingCharacters(in: .whitespacesAndNewlines),
                    image_reference: selectedIcon
                )
                
                print("=== Creating group with body: \(body)")
                let response = try await AuthAPI.insertMeetGroup(baseURL: baseURL, token: token, body: body)
                print("=== Response received: \(response)")
                
                guard let groupId = response.meet_group_id else {
                    print("=== ERROR: meet_group_id is nil in response")
                    errorMessage = "Failed to create group: No group ID returned"
                    isCreating = false
                    return
                }
                
                navigationPath.append(groupId)
                isCreating = false
            } catch {
                print("=== Error creating group: \(error)")
                errorMessage = "Failed to create group: \(error.localizedDescription)"
                isCreating = false
            }
        }
    }
}


// MARK: - Invite Members to Meet Group (Send Invitations)
struct InviteMembersToMeetGroupView: View
{
    let group: MeetGroup
    let baseURL: URL
    let token: String
    let onDismiss: () -> Void
    
    @State private var selectedUsers: [ViewUsersModel] = []
    @State private var isInviting = false
    @State private var errorMessage: String?
    @State private var showUserSearch = false
    
    var body: some View
    {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Invite members to")
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.Text.secondary)
                    
                    Text(group.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppPalette.Text.primary)
                    
                    Text("They'll receive an invitation to join")
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.Text.tertiary)
                }
                .padding(.top, 20)
                
                if !selectedUsers.isEmpty {
                    SelectedUsersChips(selectedUsers: $selectedUsers)
                }
                
                Button {
                    showUserSearch = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.badge.person.crop")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(selectedUsers.isEmpty ? "Search People to Invite" : "Add More People")
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
            .navigationTitle("Send Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .foregroundStyle(AppPalette.Text.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: inviteMembers) {
                        if isInviting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(AppPalette.Brand.neonPink)
                        } else {
                            Text(selectedUsers.isEmpty ? "Skip" : "Invite")
                                .foregroundStyle(AppPalette.Brand.neonPink)
                        }
                    }
                    .disabled(isInviting)
                }
            }
        }
        .sheet(isPresented: $showUserSearch) {
            UserSearchView(
                baseURL: baseURL,
                token: token,
                selectedUsers: $selectedUsers,
                excludedUserUUIDs: [],
                onDismiss: { showUserSearch = false }
            )
        }
    }
    
    private func inviteMembers()
    {
        guard !selectedUsers.isEmpty else {
            onDismiss()
            return
        }
        
        Task {
            isInviting = true
            
            do {
                let body = InviteMembersBody(
                    meet_group_id: group.meet_group_id,
                    user_uuids: selectedUsers.map { $0.user_uuid }
                )
                let response = try await AuthAPI.inviteMembersToMeetGroup(baseURL: baseURL, token: token, body: body)
                
                if response.success {
                    onDismiss()
                } else {
                    errorMessage = response.message
                    isInviting = false
                }
            } catch {
                errorMessage = "Failed to send invitations"
                isInviting = false
            }
        }
    }
}

// Inline invite members for creation flow
struct InviteMembersToMeetGroupInlineView: View
{
    let groupId: Int64
    let groupName: String
    let baseURL: URL
    let token: String
    @Binding var selectedUsers: [ViewUsersModel]
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isInviting = false
    @State private var errorMessage: String?
    
    var body: some View
    {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Invite members to")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.Text.secondary)
                
                Text(groupName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("They'll receive an invitation to join")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.Text.tertiary)
            }
            .padding(.top, 20)
            
            if !selectedUsers.isEmpty {
                SelectedUsersChips(selectedUsers: $selectedUsers)
            }
            
            NavigationLink(value: "userSearch") {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.badge.person.crop")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(selectedUsers.isEmpty ? "Search Users to Invite" : "Add More Users")
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
        .navigationTitle("Send Invitations")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: sendInvitations) {
                    if isInviting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(AppPalette.Brand.neonPink)
                    } else {
                        Text(selectedUsers.isEmpty ? "Skip" : "Invite")
                            .foregroundStyle(AppPalette.Brand.neonPink)
                    }
                }
                .disabled(isInviting)
            }
        }
    }
    
    private func sendInvitations()
    {
        guard !selectedUsers.isEmpty else {
            onComplete()
            return
        }
        
        Task {
            isInviting = true
            
            do {
                let body = InviteMembersBody(
                    meet_group_id: groupId,
                    user_uuids: selectedUsers.map { $0.user_uuid }
                )
                let response = try await AuthAPI.inviteMembersToMeetGroup(baseURL: baseURL, token: token, body: body)
                
                if response.success {
                    onComplete()
                } else {
                    errorMessage = response.message
                    isInviting = false
                }
            } catch {
                errorMessage = "Failed to send invitations"
                isInviting = false
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
