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
    
    var body: some View
    {
        NavigationView {
            HStack(spacing: 0) {
                FriendGroupBar(
                    groups: friendGroups,
                    selectedGroup: $selectedGroup,
                    baseURL: baseURL,
                    token: token,
                    onGroupsChanged: { await loadFriendGroups() }
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

// MARK: - Friend Group Bar
struct FriendGroupBar: View
{
    let groups: [FriendGroup]
    @Binding var selectedGroup: FriendGroup?
    let baseURL: URL
    let token: String
    let onGroupsChanged: () async -> Void
    
    @State private var showCreateGroup = false
    
    var body: some View
    {
        VStack(spacing: 12) {
            // Create group button at the top
            Button(action: { showCreateGroup = true }) {
                ZStack {
                    Circle()
                        .fill(AppPalette.Brand.japPurple)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(AppPalette.Brand.neonPink, lineWidth: 2)
                        )
                    
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                }
            }
            .buttonStyle(.plain)
            
            Divider()
                .background(AppPalette.Surface.fieldStroke)
                .padding(.horizontal, 8)
            
            // Scrollable group list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(groups, id: \.friend_group_id) { group in
                        GroupCircleButton(
                            group: group,
                            isSelected: selectedGroup?.friend_group_id == group.friend_group_id,
                            onTap: {
                                selectedGroup = group
                            }
                        )
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(width: 72)
        .background(AppPalette.Brand.formBlack)
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
}

// MARK: - Group Circle Button
private struct GroupCircleButton: View
{
    let group: FriendGroup
    let isSelected: Bool
    let onTap: () -> Void
    
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
            ZStack {
                Circle()
                    .fill(isSelected ? AppPalette.Brand.neonPink.opacity(0.3) : AppPalette.Brand.japPurple)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected ? AppPalette.Brand.neonPink : AppPalette.Surface.fieldStroke,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                
                Text(initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSelected ? AppPalette.Brand.neonPink : AppPalette.Text.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Friend Group View
struct CreateFriendGroupView: View
{
    let baseURL: URL
    let token: String
    let onDismiss: () -> Void
    
    @State private var groupName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View
    {
        NavigationView {
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
                            Text("Create")
                                .foregroundStyle(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppPalette.Text.tertiary : AppPalette.Brand.neonPink)
                        }
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
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
                _ = try await AuthAPI.createFriendGroup(baseURL: baseURL, token: token, body: body)
                onDismiss()
            } catch {
                errorMessage = "Failed to create group"
                isCreating = false
            }
        }
    }
}
