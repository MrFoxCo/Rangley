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
    
    var body: some View {
        Button(action: {
            isPresented = true
            Task {
                await loadMeets()
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 20))
                Text("My Meets")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
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
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading your meets...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text("Unable to Load Meets")
                            .font(.headline)
                        
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            onRetry()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Owned Meets Section
                            MeetsSectionView(
                                title: "My Meets",
                                subtitle: "\(ownedMeets.count) meet\(ownedMeets.count == 1 ? "" : "s")",
                                meets: ownedMeets,
                                emptyMessage: "You haven't created any meets yet"
                            )
                            
                            // Invited Meets Section (Placeholder)
                            MeetsSectionView(
                                title: "Invitations",
                                subtitle: "Coming soon",
                                meets: [],
                                emptyMessage: "Your invitations will appear here",
                                isPlaceholder: true
                            )
                        }
                    }
                }
            }
            .navigationTitle("My Meets")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct MeetsSectionView: View
{
    let title: String
    let subtitle: String
    let meets: [ViewMeetsModel]
    let emptyMessage: String
    let isPlaceholder: Bool
    
    init(title: String, subtitle: String, meets: [ViewMeetsModel], emptyMessage: String, isPlaceholder: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.meets = meets
        self.emptyMessage = emptyMessage
        self.isPlaceholder = isPlaceholder
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    if isPlaceholder {
                        Text("🚧")
                            .font(.title3)
                    }
                }
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Meets List
            if meets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: isPlaceholder ? "clock" : "calendar.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .opacity(isPlaceholder ? 0.6 : 1.0)
            } else {
                ForEach(meets) { meet in
                    MeetRowView(meet: meet)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 1)
                }
            }
            
            // Divider between sections
            if !isPlaceholder {
                Divider()
                    .padding(.top, 20)
            }
        }
    }
}

struct MeetRowView: View
{
    let meet: ViewMeetsModel
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Category Icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.pink.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: categoryIcon(for: meet.category_name))
                            .foregroundColor(.pink)
                            .font(.system(size: 18))
                    )
                
                // Meet Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(meet.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(meet.category_name)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.pink.opacity(0.1))
                        .foregroundColor(.pink)
                        .cornerRadius(4)
                    
                    Text(dateFormatter.string(from: meet.dttm_start_utc))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !meet.description.isEmpty {
                        Text(meet.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
                
                // Status/Info
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(meet.max_capacity)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 12)
            
            Divider()
        }
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            // Handle meet selection - navigate to meet details
            print("Tapped meet: \(meet.name)")
        }
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
