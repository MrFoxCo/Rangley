//
//  MyProfileView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/4/25.
//

import SwiftUI
import Amplify
import AWSPluginsCore

struct IdentifiableFriendsList: Identifiable {
    let id = UUID()
    let friends: [FriendItem]
}

struct MyProfileView: View
{
    let baseURL: URL
    let token: String
    let onDismiss: () -> Void
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var myProfile: ViewUserMeModel?
    @State private var profileStats: ViewUserProfileModelResponse?
    @State private var presentedFriendsList: IdentifiableFriendsList?
    @State private var showUnfriendConfirmation = false
    @State private var friendToRemove: FriendItem?
    @State private var showSettings = false
    
    var body: some View
    {
        ZStack {
            AppPalette.Brand.formBlack
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    header
                    
                    if let profile = myProfile {
                        profileHeader(profile)
                        statsSection
                        bioSection
                        activitySection
                    }
                    
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
        .sheet(item: $presentedFriendsList) { wrapper in
            FriendsListView(
                friends: wrapper.friends,
                baseURL: baseURL,
                token: token,
                onUnfriend: { friend in
                    friendToRemove = friend
                    showUnfriendConfirmation = true
                },
                onDismiss: { presentedFriendsList = nil }
            )
        }
        .sheet(isPresented: $showSettings) {
            if let profile = myProfile {
                ProfileSettingsView(
                    profile: profile,
                    baseURL: baseURL,
                    token: token,
                    onDismiss: { showSettings = false }
                )
            }
        }
        .task {
            await loadMyProfile()
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
            
            Text("My Profile")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            Spacer()
            
            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppPalette.Brand.neonPink)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Profile Header
    private func profileHeader(_ profile: ViewUserMeModel) -> some View
    {
        VStack(spacing: 16) {
            Circle()
                .fill(AppPalette.Brand.neonPink.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(
                    Text(profile.display_name.prefix(1))
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                )
            
            VStack(spacing: 6) {
                Text(profile.display_name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("@\(profile.username)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppPalette.Text.secondary)
            }
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View
    {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            if let stats = profileStats {
                HStack(spacing: 16) {
                    statCard(
                        value: "\(stats.meets_created)",
                        label: "Meets Created",
                        icon: "plus.circle.fill"
                    )
                    
                    statCard(
                        value: "\(stats.meets_attended)",
                        label: "Meets Attended",
                        icon: "checkmark.circle.fill"
                    )
                    
                    Button(action: {
                        if stats.friend_count > 0 {
                            Task { await loadFriendsList() }
                        }
                    }) {
                        statCard(
                            value: "\(stats.friend_count)",
                            label: "Friends",
                            icon: "person.2.fill"
                        )
                    }
                    .disabled(stats.friend_count == 0)
                }
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
    
    // MARK: - Bio Section
    private var bioSection: some View
    {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("Available in future updates")
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.Text.secondary)
                .italic()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
    
    // MARK: - Activity Section
    private var activitySection: some View
    {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("Available in future updates")
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.Text.secondary)
                .italic()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
    
    // MARK: - Data Loading
    private func loadMyProfile() async
    {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let profile = try await AuthAPI.viewUserMe(baseURL: baseURL, token: token)
            myProfile = profile
            
            let stats = try await AuthAPI.viewUsersProfile(
                baseURL: baseURL,
                token: token,
                userUUID: profile.user_uuid
            )
            profileStats = stats
        } catch {
            print("Failed to load my profile: \(error)")
            errorMessage = "Failed to load profile data"
        }
    }
    
    private func loadFriendsList() async
    {
        do {
            let friends = try await AuthAPI.getFriendsList(baseURL: baseURL, token: token)
            presentedFriendsList = IdentifiableFriendsList(friends: friends)
        } catch {
            print("Failed to load friends: \(error)")
            errorMessage = "Failed to load friends list"
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
                if let currentList = presentedFriendsList {
                    let updated = currentList.friends.filter { $0.id != friend.id }
                    presentedFriendsList = IdentifiableFriendsList(friends: updated)
                }
                await loadMyProfile()
            } else {
                errorMessage = response.message
            }
        } catch {
            errorMessage = "Failed to remove friend: \(error.localizedDescription)"
        }
    }
}

// MARK: - Profile Settings View

struct ProfileSettingsView: View
{
    let profile: ViewUserMeModel
    let baseURL: URL
    let token: String
    let onDismiss: () -> Void
    
    @State private var showingPasswordReset = false
    @State private var showingDeleteConfirmation = false
    @State private var showingFinalDeleteWarning = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
    
    var body: some View
    {
        NavigationView {
            ZStack {
                AppPalette.Brand.formBlack
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        accountDetailsSection
                        securitySection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Settings")
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
        .alert("Delete Account?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                showingFinalDeleteWarning = true
            }
        } message: {
            Text("This action cannot be undone. All your meets, participations, and account data will be permanently deleted.")
        }
        .alert("Final Confirmation", isPresented: $showingFinalDeleteWarning) {
            TextField("Type DELETE to confirm", text: $deleteConfirmationText)
            Button("Cancel", role: .cancel) {
                deleteConfirmationText = ""
            }
            Button("Delete Forever", role: .destructive) {
                if deleteConfirmationText.uppercased() == "DELETE" {
                    Task { await deleteAccount() }
                }
                deleteConfirmationText = ""
            }
            .disabled(deleteConfirmationText.uppercased() != "DELETE")
        } message: {
            Text("Type DELETE to permanently delete your account. This will:\n\n• Delete all your meets\n• Remove you from all participations\n• Permanently delete your profile\n• Sign you out of all devices")
        }
        .alert("Delete Failed", isPresented: .constant(deleteError != nil)) {
            Button("OK") {
                deleteError = nil
            }
        } message: {
            if let error = deleteError {
                Text(error)
            }
        }
        .sheet(isPresented: $showingPasswordReset) {
            ChangePasswordView()
        }
    }
    
    // MARK: - Account Details Section
    private var accountDetailsSection: some View
    {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Details")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            VStack(spacing: 12) {
                accountInfoRow(label: "Username", value: profile.username)
                accountInfoRow(label: "Display Name", value: profile.display_name)
                accountInfoRow(label: "Email", value: profile.email)
                accountInfoRow(label: "Phone", value: profile.cellphone)
                accountInfoRow(label: "Date of Birth", value: formatDobString(profile.dob))
                accountInfoRow(label: "Member Since", value: formatDate(profile.dttm_created_utc))
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
    }
    
    private func accountInfoRow(label: String, value: String?) -> some View
    {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
            
            Spacer()
            
            Text(value ?? "—")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppPalette.Text.primary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Security Section
    private var securitySection: some View
    {
        VStack(alignment: .leading, spacing: 16) {
            Text("Security")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            Button(action: { showingPasswordReset = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Change Password")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppPalette.Text.primary)
                        
                        Text("Update your account password")
                            .font(.system(size: 13))
                            .foregroundStyle(AppPalette.Text.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.Text.secondary)
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
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { showingDeleteConfirmation = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppPalette.Action.delete)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete Account")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppPalette.Action.delete)
                        
                        Text("Permanently remove your account")
                            .font(.system(size: 13))
                            .foregroundStyle(AppPalette.Text.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.Text.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(AppPalette.Brand.japPurple))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppPalette.Action.delete.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func deleteAccount() async
    {
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        
        do {
            let result = try await AuthAPI.deleteUser(baseURL: baseURL, token: token)
            
            if result.is_success {
                try await Amplify.Auth.deleteUser()
                NotificationCenter.default.post(name: .userAccountDeleted, object: nil)
                await MainActor.run {
                    onDismiss()
                }
            } else {
                await MainActor.run {
                    deleteError = "Account deletion failed. Please try again."
                }
            }
        } catch AuthAPIError.http(let code, let reason) {
            await MainActor.run {
                if code == 401 {
                    deleteError = "Session expired. Please sign in and try again."
                } else {
                    deleteError = "Delete failed: \(reason ?? "Unknown error")"
                }
            }
        } catch let authError as AuthError {
            await MainActor.run {
                deleteError = "Failed to delete from Cognito: \(authError.localizedDescription)"
            }
        } catch {
            await MainActor.run {
                deleteError = "Unable to delete account. Please try again later."
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String
    {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatDobString(_ dateString: String) -> String
    {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        outputFormatter.timeStyle = .none
        
        guard let date = inputFormatter.date(from: dateString) else {
            return dateString
        }
        
        return outputFormatter.string(from: date)
    }
}
