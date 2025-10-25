//
//  MeetCreationInviteFriendsView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

// =========================================================
// =========================================================
// =========================================================
// MARK: - IGNORE THE BELOW TODOs FOR NOW

// TODO: - Closing the screens is a little too quick should be smoother
// TODO: - The search friends looks absolutely fantastic, maybe make the icons a little smaller tho


// MARK: - IGNORE THE ABOVE TODOs FOR NOW
// =========================================================
// =========================================================
// =========================================================

import UIKit
import SwiftUI
import CoreLocation
import QuartzCore // for confetti supports the CA_* stuff

// MARK: - Refactored Invite Friends Component
struct InviteFriendsEmbedded: View
{
    let baseURL: URL
    let token: String
    @Binding var selectedUsers: [ViewUsersModel]
    
    @State private var showUserSearch = false
    
    var body: some View {
        VStack(spacing: 16) {
            
            // Selected users chips (if any)
            // Replace the selected users section with this:
            // Selected users collapsible section
            // Replace the CollapsibleSelectedUsers section in InviteFriendsEmbedded with:
            if !selectedUsers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(selectedUsers.count) selected")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppPalette.Brand.neonPink)
                        
                        Spacer()
                        
                        Button("Clear All") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedUsers.removeAll()
                            }
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppPalette.Text.secondary)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedUsers, id: \.user_uuid) { user in
                                HStack(spacing: 6) {
                                    Text("@\(user.username)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppPalette.Text.primary)
                                    
                                    Button {
                                        selectedUsers.removeAll { $0.user_uuid == user.user_uuid }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(AppPalette.Text.secondary)
                                    }
                                }
                                .padding(.horizontal, 8)
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
                    .frame(height: 32)
                }
                .padding(.horizontal, 24)
            }
            // Search button - opens SearchView
            Button(action: {
                showUserSearch = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
                    
                    Text("Search by username...")
                        .font(.system(size: 16))
                        .foregroundStyle(AppPalette.Text.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppPalette.Brand.formBlack)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 3)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showUserSearch) {
            UserSearchView(
                baseURL: baseURL,
                token: token,
                selectedUsers: $selectedUsers,
                excludedUserUUIDs: [],
                onDismiss: {
                    showUserSearch = false
                }
            )
        }
    }
    
    // MARK: - Selected Users Section
    private var selectedUsersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(selectedUsers.count) selected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                
                Spacer()
                
                Button("Clear All") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedUsers.removeAll()
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120), spacing: 8)
            ], spacing: 8) {
                ForEach(selectedUsers) { user in
                    CompactUserCard(user: user) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedUsers.removeAll { $0.id == user.id }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Compact User Card (Updated for selected users display)
struct CompactUserCard: View
{
    let user: ViewUsersModel
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(user.display_name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppPalette.Text.primary)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(AppPalette.Text.secondary.opacity(0.2)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppPalette.Surface.fieldFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 3)
                )
        )
    }
}


struct CollapsibleSelectedUsers: View
{
    @Binding var selectedUsers: [ViewUsersModel]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Summary bar (always visible)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("\(selectedUsers.count) selected")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppPalette.Brand.neonPink.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppPalette.Brand.neonPink.opacity(0.4), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            
            // Expanded list (scrollable)
            if isExpanded {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(selectedUsers, id: \.user_uuid) { user in
                            HStack(spacing: 8) {
                                Text("@\(user.username)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppPalette.Text.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Button {
                                    selectedUsers.removeAll { $0.user_uuid == user.user_uuid }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppPalette.Text.tertiary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppPalette.Surface.fieldFill)
                            )
                        }
                    }
                }
                .frame(maxHeight: 120)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - User Search View (Specialized for user selection)
struct UserSearchView: View
{
    let baseURL: URL
    let token: String
    @Binding var selectedUsers: [ViewUsersModel]
    let excludedUserUUIDs: [UUID]
    let onDismiss: () -> Void
    
    @State private var searchText = ""
    @State private var searchResults: [ViewUsersModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // Search configuration
    private let searchDelay: TimeInterval = 0.5
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search header
                searchHeader
                
                // Results
                if isLoading {
                    loadingView
                } else if searchText.isEmpty {
                    emptyStateView
                } else if searchResults.isEmpty {
                    noResultsView
                } else {
                    searchResultsList
                }
                
                // Selected users section at bottom (if any)
                if !selectedUsers.isEmpty {
                    selectedUsersBottomSection
                }
            }
            .background(AppPalette.Brand.formBlack)
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
    
    // MARK: - Search Header
    private var searchHeader: some View {
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
            
            // Search field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
                
                TextField("Search by username...", text: $searchText)
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Surface.primary)
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
                    .fill(Color(AppPalette.Brand.formBlack))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 3)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
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
                    .foregroundStyle(AppPalette.Surface.primary)
                
                Text("Search by username to invite friends")
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
                    .foregroundStyle(AppPalette.Surface.primary)
                
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
    private var searchResultsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(filteredSearchResults) { user in
                    // Simple tap-to-add user card (no checkmarks)
                    TapToAddUserCard(user: user) {
                        addUser(user)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Selected Users Bottom Section
    private var selectedUsersBottomSection: some View {
        VStack(spacing: 0)
        {
            // Divider
            Rectangle()
                .fill(AppPalette.Brand.neonPink.opacity(0.2))
                .frame(height: 1)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(selectedUsers.count) friend\(selectedUsers.count == 1 ? "" : "s") selected")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                    
                    Spacer()
                    
                    Button("Clear All") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedUsers.removeAll()
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppPalette.Text.secondary)
                }
                
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 120), spacing: 8)
                ], spacing: 8) {
                    ForEach(selectedUsers) { user in
                        SelectedUserChip(user: user) {
                            removeUser(user)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(AppPalette.Brand.formBlack).opacity(0.95))

            Button(action: onDismiss) {
                Text("Continue")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppPalette.Brand.neonPink)
                    )
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Filter out already selected users from search results
    private var filteredSearchResults: [ViewUsersModel] {
        let selectedUserIds = Set(selectedUsers.map { $0.id })
        let excludedIds = Set(excludedUserUUIDs)
        return searchResults.filter {
            !selectedUserIds.contains($0.id) && !excludedIds.contains($0.user_uuid)
        }
    }
    
    // MARK: - User Selection Logic
    
    private func addUser(_ user: ViewUsersModel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedUsers.append(user)
        }
        // Clear search after adding
        searchText = ""
    }
    
    private func removeUser(_ user: ViewUsersModel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedUsers.removeAll { $0.id == user.id }
        }
    }
    
    // MARK: - Search Logic
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
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

// MARK: - Simple Tap-to-Add User Card (replaces SelectableUserSearchResultCard)
struct TapToAddUserCard: View
{
    let user: ViewUsersModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar placeholder
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
                
                // Match badges
                HStack(spacing: 6) {
                    if user.matchedByUsername {
                        matchBadge(text: "U", color: AppPalette.Brand.neonPink)
                    }
                    if user.matchedByEmail {
                        matchBadge(text: "E", color: Color.blue)
                    }
                    if user.matchedByPhone {
                        matchBadge(text: "P", color: Color.green)
                    }
                }
                
                Image(systemName: "plus.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(AppPalette.Brand.japPurple))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 3)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(0.98)
        .animation(.easeInOut(duration: 0.1), value: false)
    }
    
    private func matchBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 18, height: 18)
            .background(
                Circle()
                    .fill(color.opacity(0.2))
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.5), lineWidth: 3)
                    )
            )
    }
}

// MARK: - Selected User Chip (for bottom section)
struct SelectedUserChip: View
{
    let user: ViewUsersModel
    let onRemove: () -> Void
    
    var body: some View
    {
        HStack(spacing: 6) {
            // Avatar
            Circle()
                .fill(AppPalette.Brand.neonPink.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(user.display_name.prefix(1))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                )
            
            Text(user.display_name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.Text.primary)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Text.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppPalette.Surface.fieldFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 3)
                )
        )
    }
}

