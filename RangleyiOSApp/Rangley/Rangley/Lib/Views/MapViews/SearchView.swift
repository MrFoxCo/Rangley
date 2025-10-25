//
//  SearchView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/14/25.
//

import SwiftUI

public struct SearchView: View
{
    @State private var searchText = ""
    @State private var selectedScope: SearchScope = .all
    @State private var searchResults = SearchResults()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedUser: ViewUsersModel?
    @State private var showUserProfile = false
    
    // Dependencies
    let baseURL: URL
    let token: String
    let onDismiss: () -> Void
    let onMeetSelected: (ViewMeetsModel) -> Void
    let onUserSelected: (ViewUsersModel) -> Void
    
    // Search configuration
    private let searchDelay: TimeInterval = 0.5
    @State private var searchTask: Task<Void, Never>?
    
    public init(
        baseURL: URL,
        token: String,
        onDismiss: @escaping () -> Void,
        onMeetSelected: @escaping (ViewMeetsModel) -> Void,
        onUserSelected: @escaping (ViewUsersModel) -> Void
    ) {
        self.baseURL = baseURL
        self.token = token
        self.onDismiss = onDismiss
        self.onMeetSelected = onMeetSelected
        self.onUserSelected = onUserSelected
    }
    
    public var body: some View
    {
        NavigationView
        {
            VStack(spacing: 0) {
                // Search header
                searchHeader
                
                // Scope selector
                scopeSelector
                
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
                
                Spacer()
            }
            .background(AppPalette.Brand.formBlack)
            .navigationBarHidden(true)
        }
        .alert("Search Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .sheet(item: $selectedUser) { user in
            UserProfileView(
                user: user,
                baseURL: baseURL,
                token: token,
                onDismiss: {
                    selectedUser = nil
                }
            )
        }

        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
        .onChange(of: selectedScope) { _, _ in
            if !searchText.isEmpty {
                performSearch(query: searchText)
            }
        }
    }
    
    // MARK: - Search Header
    private var searchHeader: some View
    {
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
                
                TextField("Search meets and users...", text: $searchText)
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Text.primary)
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
                            .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Scope Selector
    private var scopeSelector: some View
    {
        HStack(spacing: 12) {
            ForEach(SearchScope.allCases, id: \.self) { scope in
                Button(action: { selectedScope = scope }) {
                    HStack(spacing: 6) {
                        Image(systemName: scope.icon)
                            .font(.system(size: 12, weight: .medium))
                        
                        Text(scope.title)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(selectedScope == scope ? Color.white : AppPalette.Brand.neonPink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(selectedScope == scope ? AppPalette.Brand.neonPink : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(AppPalette.Brand.neonPink.opacity(selectedScope == scope ? 0 : 0.5), lineWidth: 1)
                            )
                    )
                }
                .animation(.easeInOut(duration: 0.2), value: selectedScope)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Loading View
    private var loadingView: some View
    {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppPalette.Brand.neonPink)
            
            Text("Searching...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View
    {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("Search Rangley")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("Find meets by name or users by username")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - No Results View
    private var noResultsView: some View
    {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No Results Found")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("Try adjusting your search terms or scope")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Results List
    private var searchResultsList: some View
    {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 16) {
                // Meets Section
                if !searchResults.meets.isEmpty && (selectedScope == .all || selectedScope == .meets)
                {
                    searchSection(
                        title: "Meets",
                        icon: "calendar",
                        count: searchResults.meets.count
                    ) {
                        ForEach(searchResults.meets) { meet in
                            MeetSearchResultCard(meet: meet) {
                                onMeetSelected(meet)
                            }
                        }
                    }
                }
                
                // Users Section
                if !searchResults.users.isEmpty && (selectedScope == .all || selectedScope == .users)
                {
                    searchSection(
                        title: "Users",
                        icon: "person",
                        count: searchResults.users.count
                    ) {
                        ForEach(searchResults.users) { user in
                            UserSearchResultCard(user: user) {
                                selectedUser = user
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private func searchSection<Content: View>(
        title: String,
        icon: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View
    {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("(\(count))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppPalette.Text.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            content()
        }
    }
    
    // MARK: - Search Logic
    private func performSearch(query: String)
    {
        // Cancel previous search
        searchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = SearchResults()
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
                let results = try await executeSearch(query: query.trimmingCharacters(in: .whitespacesAndNewlines))
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    searchResults = results
                    isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    searchResults = SearchResults()
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func executeSearch(query: String) async throws -> SearchResults
    {
        // Capture the current scope to avoid actor isolation issues
        let currentScope = await MainActor.run { selectedScope }
        
        // Execute searches concurrently
        async let meetsTask: [ViewMeetsModel] = searchMeets(query: query, scope: currentScope)
        async let usersTask: [ViewUsersModel] = searchUsers(query: query, scope: currentScope)
        
        let (meets, users) = await (meetsTask, usersTask)
        return SearchResults(meets: meets, users: users)
    }
    
    private func searchMeets(query: String, scope: SearchScope) async -> [ViewMeetsModel]
    {
        guard scope == .all || scope == .meets else {
            return []
        }
        
        do {
            let allMeets = try await AuthAPI.viewMeets(baseURL: baseURL, token: token)
            return allMeets.filter { meet in
                meet.name.localizedCaseInsensitiveContains(query) ||
                meet.description.localizedCaseInsensitiveContains(query) ||
                meet.category_name.localizedCaseInsensitiveContains(query)
            }
        } catch {
            // Log error but don't fail entire search
            print("Meet search failed: \(error)")
            return []
        }
    }
    
    /// need to input exactly the username
    private func searchUsers(query: String, scope: SearchScope) async -> [ViewUsersModel]
    {
        guard scope == .all || scope == .users else {
            return []
        }
        
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
            return []
        }
    }
    
    /// partial search deprecated
    private func browseUsers(query: String, scope: SearchScope) async -> [ViewUsersModel]
    {
        guard scope == .all || scope == .users else {
            return []
        }
        
        do {
            let allUsers = try await AuthAPI.browseAllUsers(
                baseURL: baseURL,
                token: token,
                limit: 1000
            )

            return allUsers.filter { user in
                user.username.localizedCaseInsensitiveContains(query) ||
                user.display_name.localizedCaseInsensitiveContains(query)
            }
        } catch {
            print("User browse failed: \(error)")
            return []
        }
    }
}

// MARK: - Supporting Types

private enum SearchScope: String, CaseIterable
{
    case all = "all"
    case meets = "meets"
    case users = "users"
    
    var title: String {
        switch self {
        case .all: return "All"
        case .meets: return "Meets"
        case .users: return "Users"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .meets: return "calendar"
        case .users: return "person"
        }
    }
}

private struct SearchResults
{
    var meets: [ViewMeetsModel] = []
    var users: [ViewUsersModel] = []
    
    var isEmpty: Bool
    {
        meets.isEmpty && users.isEmpty
    }
}

// MARK: - Result Cards

struct MeetSearchResultCard: View
{
    let meet: ViewMeetsModel
    let onTap: () -> Void
    
    var body: some View
    {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meet.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppPalette.Text.primary)
                            .lineLimit(1)
                        
                        Text(meet.category_name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppPalette.Brand.neonPink)
                    }
                    
                    Spacer()
                    
                    if meet.is_owner {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.orange)
                    }
                }
                
                if !meet.description.isEmpty {
                    Text(meet.description)
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.Text.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Label(meet.display_name, systemImage: "person")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppPalette.Text.secondary)
                    // TODO: - unccoment when max capacity is a feature
//
//                    Spacer()
//                    
//                    Label("\(meet.max_capacity)", systemImage: "person.3")
//                        .font(.system(size: 12, weight: .medium))
//                        .foregroundStyle(AppPalette.Text.secondary)
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
        .buttonStyle(PlainButtonStyle())
    }
}

struct UserSearchResultCard: View
{
    let user: ViewUsersModel
    let onTap: () -> Void
    
    var body: some View
    {
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

                if user.can_invite {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppPalette.Text.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(AppPalette.Brand.formBlack))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func matchBadge(text: String, color: Color) -> some View
    {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 18, height: 18)
            .background(
                Circle()
                    .fill(color.opacity(0.2))
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.5), lineWidth: 1)
                    )
            )
    }
}

