//
//  MeetGroupFormView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/6/25.
//

import SwiftUI

// MARK: - Inline Meet Group Creation Form
struct MeetGroupFormView: View
{
    let baseURL: URL
    let token: String
    let preselectedUsers: [ViewUsersModel]
    let onGroupCreated: (Int64) -> Void
    let onCancel: () -> Void
    
    @State private var groupName = ""
    @State private var selectedIcon = "person.3.fill"
    @State private var isCreating = false
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
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Save as Group")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppPalette.Text.tertiary)
                }
            }
            
            // Group Name
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
            
            // Icon Picker
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
                                .foregroundStyle(iconColor(for: icon))
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
                        .disabled(isCreating)
                    }
                }
            }
            
            // Selected Users Preview
            if !preselectedUsers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(preselectedUsers.count) member\(preselectedUsers.count == 1 ? "" : "s") will be invited")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.Text.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(preselectedUsers, id: \.user_uuid) { user in
                                Text(user.display_name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppPalette.Text.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
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
            
            // Error Message
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
            }
            
            Spacer()
            
            // Create Button
            Button(action: createGroup) {
                HStack {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Text("Create Group")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating
                                ? AppPalette.Brand.neonPink.opacity(0.5)
                                : AppPalette.Brand.neonPink
                        )
                )
            }
            .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(AppPalette.Brand.formBlack)
    }
    
    // MARK: - Actions
    
    ///Contains content violation warnings
    private func createGroup()
    {
        Task {
            isCreating = true
            errorMessage = nil
            
            do {
                let createBody = InsertGroupBody(
                    group_name: groupName.trimmingCharacters(in: .whitespacesAndNewlines),
                    image_reference: selectedIcon
                )
                
                let createResponse = try await AuthAPI.insertMeetGroup(
                    baseURL: baseURL,
                    token: token,
                    body: createBody
                )
                
                // CHECK FOR VALIDATION FAILURE
                if createResponse.validation_failed {
                    errorMessage = createResponse.validation_message ?? "Content violates community guidelines"
                    isCreating = false
                    return
                }
                
                guard createResponse.success, let groupId = createResponse.meet_group_id else {
                    errorMessage = createResponse.message.isEmpty ? "Unable to create group" : createResponse.message
                    isCreating = false
                    return
                }
                
                // Step 2: Invite preselected users if any
                if !preselectedUsers.isEmpty {
                    let inviteBody = InviteMembersBody(
                        meet_group_id: groupId,
                        user_uuids: preselectedUsers.map { $0.user_uuid }
                    )
                    
                    let inviteResponse = try await AuthAPI.inviteMembersToMeetGroup(
                        baseURL: baseURL,
                        token: token,
                        body: inviteBody
                    )
                    
                    if !inviteResponse.success {
                        print("Warning: Group created but failed to invite members: \(inviteResponse.message)")
                    }
                }
                
                await MainActor.run {
                    onGroupCreated(groupId)
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Unable to create group. Please try again."
                    isCreating = false
                }
            }
        }
    }
}
