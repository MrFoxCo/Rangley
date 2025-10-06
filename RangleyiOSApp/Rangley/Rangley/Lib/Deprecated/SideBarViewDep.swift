//
//  SideBarView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/5/25.
//

import SwiftUI

// MARK: - Main Sidebar View
struct SideBarView: View
{
    let groups: [MeetGroup]
    @Binding var selectedGroup: MeetGroup?
    let baseURL: URL
    let token: String
    let onGroupsChanged: () async -> Void
    let onGroupTapped: () -> Void
    
    @EnvironmentObject var authState: AuthStateStore
    @EnvironmentObject var inbox: InboxStore
    
    @State private var showMessenger = false
    @State private var showInbox = false
    @State private var showCreateGroup = false
    
    var body: some View
    {
        VStack(spacing: 0) {
            // Top fixed buttons
            VStack(spacing: 12) {
                // Messenger button
                SideBarIconButton(
                    icon: "bubble.left.and.bubble.right.fill",
                    badgeCount: 0, // TODO: Add unread message count
                    color: AppPalette.Brand.neonPink,
                    onTap: { showMessenger = true }
                )
                
                // Inbox button
                SideBarIconButton(
                    icon: "tray.fill",
                    badgeCount: inbox.unreadCount,
                    color: AppPalette.Brand.spearmintGreen,
                    onTap: { showInbox = true }
                )
                
                // Divider
                Rectangle()
                    .fill(AppPalette.Brand.neonPink.opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                
                Button(action: { showCreateGroup = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                        .frame(width: 44, height: 44)
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
            }
            .padding(.top, 20)
            .padding(.horizontal, 10)
            
            // Scrollable groups section
            if groups.isEmpty {
                emptyGroupsState
            } else {
                groupsList
            }
            
            Spacer()
        }
        .frame(width: 70)
        .background(sidebarBackground)
        .shadow(color: AppPalette.Brand.neonPink.opacity(0.2), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showMessenger) {
            MessengerView(
                baseURL: baseURL,
                token: token,
                onDismiss: { showMessenger = false }
            )
        }
        .sheet(isPresented: $showInbox) {
            UserInboxView(
                onDismiss: { showInbox = false },
                onMeetGroupsChanged: onGroupsChanged
            )
        }
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
    
    // MARK: - Subviews
    
    private var emptyGroupsState: some View
    {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(AppPalette.Text.tertiary)
            
            Text("No groups")
                .font(.system(size: 12))
                .foregroundStyle(AppPalette.Text.tertiary)
        }
        .frame(maxHeight: .infinity)
        .padding(.top, 40)
    }
    
    private var groupsList: some View
    {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(groups, id: \.meet_group_id) { group in
                    GroupVerticalButton(
                        group: group,
                        isSelected: selectedGroup?.meet_group_id == group.meet_group_id,
                        baseURL: baseURL,
                        token: token,
                        onTap: {
                            selectedGroup = group
                            onGroupTapped()
                        },
                        onDelete: {
                            deleteGroup(group)
                        },
                        onLeave: {
                            leaveGroup(group)
                        }
                    )
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }
    
    private var sidebarBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(AppPalette.Brand.japDarkerPurple)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppPalette.Brand.neonPink.opacity(0.6), lineWidth: 2)
            )
    }
    
    // MARK: - Actions
    
    private func leaveGroup(_ group: MeetGroup)
    {
        Task {
            do {
                let body = LeaveMeetGroupBody(meet_group_id: group.meet_group_id)
                let response = try await AuthAPI.leaveMeetGroup(baseURL: baseURL, token: token, body: body)
                
                if response.success {
                    if selectedGroup?.meet_group_id == group.meet_group_id {
                        selectedGroup = nil
                    }
                    await onGroupsChanged()
                }
            } catch {
                print("Failed to leave group: \(error)")
            }
        }
    }
    
    private func deleteGroup(_ group: MeetGroup)
    {
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

// MARK: - Sidebar Icon Button (for Messenger/Inbox)
private struct SideBarIconButton: View
{
    let icon: String
    let badgeCount: Int
    let color: Color
    let onTap: () -> Void
    
    var body: some View
    {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor(for: icon))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(AppPalette.Brand.japPurple)
                    )
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.4), lineWidth: 1.5)
                    )
                
                // Badge for unread count
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Circle().fill(Color.red))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Group Vertical Button
private struct GroupVerticalButton: View
{
    let group: MeetGroup
    let isSelected: Bool
    let baseURL: URL
    let token: String
    let onTap: () -> Void
    let onDelete: () -> Void
    let onLeave: () -> Void
    
    @EnvironmentObject var authState: AuthStateStore
    @State private var members: [GroupMember] = []
    @State private var showConfirm = false
    @State private var showCreateMeet = false
    
    private var isOwner: Bool {
        guard let userUUID = authState.currentUser?.user_uuid else { return false }
        return members.first(where: { $0.user_uuid == userUUID })?.is_owner ?? false
    }
    
    private var groupIcon: String {
        return group.image_reference
    }
    
    var body: some View
    {
        Button(action: onTap) {
            Image(systemName: groupIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor(for: groupIcon))
                .frame(width: 44, height: 44)
                .background(buttonBackground)
                .overlay(buttonBorder)
                .shadow(
                    color: isSelected ? AppPalette.Brand.neonPink.opacity(0.4) : .clear,
                    radius: isSelected ? 8 : 0
                )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    showCreateMeet = true
                }
        )
        .task {
            await loadMembers()
        }
        .contextMenu {
            contextMenuContent
        }
        .alert(isOwner ? "Delete \(group.name)?" : "Leave \(group.name)?", isPresented: $showConfirm) {
            alertButtons
        } message: {
            alertMessage
        }
        .sheet(isPresented: $showCreateMeet) {
            Text("Create Meet with \(group.name)")
                .padding()
        }
    }
    
    // MARK: - Subviews
    
    private var buttonBackground: some View {
        Circle()
            .fill(
                isSelected
                    ? AppPalette.Brand.neonPink
                    : AppPalette.Brand.japPurple
            )
    }
    
    private var buttonBorder: some View {
        Circle()
            .stroke(
                isSelected
                    ? AppPalette.Brand.neonPink
                    : AppPalette.Brand.neonPink.opacity(0.4),
                lineWidth: isSelected ? 2 : 1.5
            )
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button {
            showCreateMeet = true
        } label: {
            Label("Create Meet", systemImage: "calendar.badge.plus")
        }
        
        if isOwner {
            Button(role: .destructive) {
                showConfirm = true
            } label: {
                Label("Delete Group", systemImage: "trash")
            }
        } else {
            Button(role: .destructive) {
                showConfirm = true
            } label: {
                Label("Leave Group", systemImage: "arrow.right.square")
            }
        }
    }
    
    @ViewBuilder
    private var alertButtons: some View {
        Button(isOwner ? "Delete" : "Leave", role: .destructive) {
            if isOwner {
                onDelete()
            } else {
                onLeave()
            }
        }
        Button("Cancel", role: .cancel) {}
    }
    
    @ViewBuilder
    private var alertMessage: some View {
        if isOwner {
            Text("This will remove the group for all members. This action cannot be undone.")
        } else {
            Text("You will no longer be a member of this group.")
        }
    }
    
    // MARK: - Actions
    
    private func loadMembers() async {
        do {
            let fetchedMembers = try await AuthAPI.viewMeetGroupMembers(
                baseURL: baseURL,
                token: token,
                meetGroupId: group.meet_group_id
            )
            await MainActor.run {
                members = fetchedMembers
            }
        } catch {
            print("Failed to load members: \(error)")
        }
    }
}
