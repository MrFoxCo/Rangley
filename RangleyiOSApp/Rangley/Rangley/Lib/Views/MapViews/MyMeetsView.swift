//
//  MyMeetsView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/16/25.
//

import SwiftUI
import Foundation

struct MyMeetsView: View
{
    @State private var isPresented = false
    @State private var meets: [ViewMeetsModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // These would come from your app's environment/state management
    let baseURL: URL
    let authToken: String
    
    // Callback for when a meet is selected
    let onMeetSelected: ((ViewMeetsModel) -> Void)?
    
    init(baseURL: URL, authToken: String, onMeetSelected: ((ViewMeetsModel) -> Void)? = nil) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.onMeetSelected = onMeetSelected
    }
    
    var body: some View {
        Button(action: {
            isPresented = true
            Task {
                await loadMeets()
            }
        }) {
            VStack(spacing: 2) {
        //                        Image(systemName: "tray")
        //                            .font(.system(size: 14, weight: .semibold))
        //                            .imageScale(.medium)
        //                            .foregroundStyle(AppPalette.Brand.neonPink)
                
                Text("My Meets")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(AppPalette.Brand.neonPink)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppPalette.Brand.neonPink.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppPalette.Brand.neonPink.opacity(0.55), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .frame(height: 48)                // keep height
            .fixedSize(horizontal: true, vertical: false) // let width grow to fit "Meets"
            .lineLimit(1)
            .foregroundColor(.white)
        }
        .sheet(isPresented: $isPresented) {
            MyMeetsOverlay(
                meets: meets,
                isLoading: isLoading,
                errorMessage: errorMessage,
                onRetry: {
                    Task {
                        await loadMeets()
                    }
                },
                onMeetSelected: { meet in
                    isPresented = false  // Close the sheet
                    onMeetSelected?(meet)  // Call the callback
                }
            )
        }
    }
    
    private func loadMeets() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let allMeets = try await AuthAPI.viewMeets(baseURL: baseURL, token: authToken)
            await MainActor.run {
                self.meets = allMeets
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct MyMeetsOverlay: View
{
    let meets: [ViewMeetsModel]
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    let onMeetSelected: ((ViewMeetsModel) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    private var ownedMeets: [ViewMeetsModel] {
        meets.filter { $0.is_owner }
    }
    
    private var invitedMeets: [ViewMeetsModel] {
        // Placeholder logic - will be implemented later
        // For now, return meets where we're not the owner
        meets.filter { !$0.is_owner }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with close button
                headerView
                
                // Main content
                ZStack {
                    AppPalette.Brand.russianViolet.opacity(0.05)
                        .ignoresSafeArea()
                    
                    if isLoading {
                        loadingView
                    } else if let errorMessage = errorMessage {
                        errorView(errorMessage)
                    } else if meets.isEmpty {
                        emptyStateView
                    } else {
                        meetsListView
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppPalette.Brand.neonPink.opacity(0.1))
                    )
            }
            
            Spacer()
            
            Text("My Meets")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primary)
            
            Spacer()
            
            // Invisible spacer for balance
            Color.clear
                .frame(width: 32, height: 32)
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
            
            Text("Loading your meets...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.orange.opacity(0.7))
            
            VStack(spacing: 8) {
                Text("Unable to Load Meets")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.primary)
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Retry") {
                onRetry()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppPalette.Brand.neonPink)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No Meets Yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.primary)
                
                Text("Your created meets and invitations will appear here")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Meets List
    private var meetsListView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 16) {
                // Owned Meets Section
                if !ownedMeets.isEmpty {
                    meetsSection(
                        title: "My Meets",
                        icon: "crown.fill",
                        count: ownedMeets.count,
                        meets: ownedMeets
                    )
                }
                
                // Invited Meets Section (Placeholder)
                meetsSection(
                    title: "Invitations",
                    icon: "envelope",
                    count: 0,
                    meets: [],
                    isPlaceholder: true
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    private func meetsSection(
        title: String,
        icon: String,
        count: Int,
        meets: [ViewMeetsModel],
        isPlaceholder: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isPlaceholder ? Color.secondary : AppPalette.Brand.neonPink)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primary)
                
                if isPlaceholder {
                    Text("(Coming soon)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.secondary)
                } else {
                    Text("(\(count))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            if meets.isEmpty {
                emptyMeetsSectionView(isPlaceholder: isPlaceholder)
            } else {
                ForEach(meets) { meet in
                    MeetCard(meet: meet, onTap: { onMeetSelected?(meet) })
                }
            }
        }
    }
    
    private func emptyMeetsSectionView(isPlaceholder: Bool) -> some View {
        VStack(spacing: 12) {
            Image(systemName: isPlaceholder ? "clock" : "calendar.badge.plus")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.secondary.opacity(0.6))
            
            Text(isPlaceholder ? "Your invitations will appear here" : "You haven't created any meets yet")
                .font(.system(size: 16))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        )
        .opacity(isPlaceholder ? 0.6 : 1.0)
    }
}

struct MeetCard: View
{
    let meet: ViewMeetsModel
    let onTap: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meet.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                        
                        Text(meet.category_name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppPalette.Brand.neonPink)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if meet.is_owner {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.orange)
                        }
                        
                        // Category icon
                        Image(systemName: categoryIcon(for: meet.category_name))
                            .font(.system(size: 16))
                            .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
                    }
                }
                
                // Description
                if !meet.description.isEmpty {
                    Text(meet.description)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }
                
                // Meta info row
                HStack {
                    Label(dateFormatter.string(from: meet.dttm_start_utc), systemImage: "calendar")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary)
                    
                    Spacer()
                    
                    Label("\(meet.max_capacity)", systemImage: "person.3")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "activity": return "figure.run"
        case "sports": return "sportscourt"
        case "outdoors": return "tree"
        case "social": return "person.2"
        case "music": return "music.note"
        case "food": return "fork.knife"
        case "planned trip": return "airplane"
        default: return "calendar"
        }
    }
}
