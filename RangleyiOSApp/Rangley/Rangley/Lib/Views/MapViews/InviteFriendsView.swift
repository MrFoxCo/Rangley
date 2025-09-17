//
//  InviteFriendsView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/17/25.
//

import SwiftUI

public struct InviteFriendsView: View {
    @State private var searchText = ""
    @State private var searchResults: [ViewUsersModel] = []
    @State private var selectedUsers: [ViewUsersModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // Dependencies
    let baseURL: URL
    let token: String
    let onDismiss: () -> Void
    let onInvite: ([ViewUsersModel]) -> Void // For future server submission
    
    // Search configuration
    private let searchDelay: TimeInterval = 0.5
    @State private var searchTask: Task<Void, Never>?
    
    public init(
        baseURL: URL,
        token: String,
        onDismiss: @escaping () -> Void,
        onInvite: @escaping ([ViewUsersModel]) -> Void
    ) {
        self.baseURL = baseURL
        self.token = token
        self.onDismiss = onDismiss
        self.onInvite = onInvite
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                inviteHeader
                
                // Selected users grid (show only if we have selections)
                if !selectedUsers.isEmpty {
                    selectedUsersSection
                }
                
                // Search field
                searchField
                
                // Results
                if isLoading {
                    loadingView
                } else if searchText.isEmpty {
                    emptyStateView
                } else if searchResults.isEmpty {
                    noResultsView
                } else {
                    userResultsList
                }
                
                Spacer()
            }
            .background(AppPalette.bgGradient)
            .navigationBarHidden(true)
        }
        .alert("Search Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
    }
    
    // MARK: - Header
    private var inviteHeader: some View {
        HStack(spacing: 16) {
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppPalette.Brand.neonPink.opacity(0.1))
                    )
            }
            
            // Title
            VStack(spacing: 2) {
                Text("Invite Friends")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                if !selectedUsers.isEmpty {
                    Text("\(selectedUsers.count) selected")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                }
            }
            
            Spacer()
            
            // Send invites button (for future use)
            Button(action: {
                onInvite(selectedUsers)
            }) {
                Text("Send")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selectedUsers.isEmpty ? AppPalette.Text.tertiary : AppPalette.Brand.neonPink)
                    .frame(minWidth: 44)
            }
            .disabled(selectedUsers.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Selected Users Section
    private var selectedUsersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Selected")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.secondary)
                
                Spacer()
                
                Button("Clear All") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedUsers.removeAll()
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppPalette.Brand.neonPink)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(selectedUsers) { user in
                        selectedUserChip(user)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 16)
    }
    
    private func selectedUserChip(_ user: ViewUsersModel) -> some View {
        HStack(spacing: 8) {
            // Avatar
            Circle()
                .fill(AppPalette.Brand.neonPink.opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(user.display_name.prefix(1))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                )
            
            Text(user.display_name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppPalette.Text.primary)
                .lineLimit(1)
            
            // Remove button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedUsers.removeAll { $0.id == user.id }
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(AppPalette.Text.secondary.opacity(0.2))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Search Field
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
            
            TextField("Search by username...", text: $searchText)
                .font(.system(size: 16))
                .foregroundStyle(Color.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppPalette.Brand.neonPink)
            
            Text("Searching users...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("Find Friends")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("Search by username to invite friends to this meet")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - No Results View
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No Users Found")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("Try searching for the exact username")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Results List
    private var userResultsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(searchResults) { user in
                    UserInviteCard(
                        user: user,
                        isSelected: selectedUsers.contains { $0.id == user.id },
                        onTap: {
                            toggleUserSelection(user)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - User Selection Logic
    private func toggleUserSelection(_ user: ViewUsersModel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let existingIndex = selectedUsers.firstIndex(where: { $0.id == user.id }) {
                selectedUsers.remove(at: existingIndex)
            } else {
                selectedUsers.append(user)
            }
        }
    }
    
    // MARK: - Search Logic
    private func performSearch(query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            // Debounce search
            try? await Task.sleep(for: .milliseconds(Int(searchDelay * 1000)))
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                let results = try await searchUsers(query: query.trimmingCharacters(in: .whitespacesAndNewlines))
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    searchResults = results
                    isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    searchResults = []
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func searchUsers(query: String) async throws -> [ViewUsersModel] {
        // Don't search if query is empty or just whitespace
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        do {
            return try await AuthAPI.searchUsers(
                baseURL: baseURL,
                token: token,
                usernames: [query]
            )
        } catch {
            print("User search failed: \(error)")
            throw error
        }
    }
}

// MARK: - User Invite Card

private struct UserInviteCard: View {
    let user: ViewUsersModel
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(AppPalette.Brand.neonPink.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(user.display_name.prefix(1))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppPalette.Brand.neonPink)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.display_name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.Text.primary)
                        .lineLimit(1)
                    
                    Text("@\(user.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.Text.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppPalette.Brand.neonPink : AppPalette.Text.tertiary, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(AppPalette.Brand.neonPink)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AppPalette.Brand.neonPink.opacity(0.05) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? AppPalette.Brand.neonPink.opacity(0.5) : AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
}
