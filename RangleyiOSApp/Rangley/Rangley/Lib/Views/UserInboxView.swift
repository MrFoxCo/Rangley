//
//  UserInboxView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/3/25.
//

import SwiftUI

struct UserInboxView: View
{
    @EnvironmentObject var inbox: InboxStore

    let onDismiss: () -> Void

    @State private var selectedTab: InboxTab = .all
    
    var body: some View
    {
        VStack(spacing: 0) {
             header
             tabSelector
             
             if inbox.isLoading {
                 loadingView
             } else if filteredNotifications.isEmpty {
                 emptyStateView
             } else {
                 notificationsList
             }
        }
        .background(AppPalette.Brand.formBlack)
        .ignoresSafeArea()
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
            
            Text("Inbox")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            Spacer()
            
            // Placeholder for future "mark all read" button
            Button(action: {}) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppPalette.Text.secondary)
            }
            .disabled(true)
            .opacity(0.6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View
    {
        HStack(spacing: 12) {
            ForEach(InboxTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Text(tab.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(selectedTab == tab ? AppPalette.Brand.neonPink : AppPalette.Text.secondary)
                        
                        if selectedTab == tab {
                            Rectangle()
                                .fill(AppPalette.Brand.neonPink)
                                .frame(height: 2)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    // MARK: - Notifications List
    private var notificationsList: some View
    {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredNotifications) { notification in
                    NotificationCard(
                        notification: notification,
                        onTap: { await handleNotificationTap(notification) },
                        onAcceptFriendRequest: { await acceptFriendRequest(notification) },
                        onDeclineFriendRequest: { await declineFriendRequest(notification) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View
    {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppPalette.Brand.neonPink)
            
            Text("Loading...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View
    {
        VStack(spacing: 20) {
            Image(systemName: selectedTab.emptyIcon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
            
            VStack(spacing: 8) {
                Text(selectedTab.emptyTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text(selectedTab.emptyMessage)
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    
    private func handleNotificationTap(_ notification: InboxNotificationModelBody) async
    {
        // Mark as read
        // TODO: Implement mark as read API call
        print("Tapped notification: \(notification.notification_id)")
    }
    
    private var filteredNotifications: [InboxNotificationModelBody] {
        switch selectedTab {
        case .all:
            return inbox.inboxNotifications
        case .friendRequests:
            return inbox.inboxNotifications.filter { $0.notification_type_id == 15 }
        case .meets:
            return inbox.inboxNotifications.filter { $0.isMeetRelated }
        }
    }
    
    private func acceptFriendRequest(_ notification: InboxNotificationModelBody) async {
        do {
            try await inbox.respondToFriendRequest(notification, accept: true)
        } catch {
            print("Failed to accept: \(error)")
        }
    }
    
    private func declineFriendRequest(_ notification: InboxNotificationModelBody) async {
        do {
            try await inbox.respondToFriendRequest(notification, accept: false)
        } catch {
            print("Failed to decline: \(error)")
        }
    }
}

// MARK: - Supporting Types

enum InboxTab: String, CaseIterable
{
    case all = "all"
    case friendRequests = "friends"
    case meets = "meets"
    
    var title: String {
        switch self {
        case .all: return "All"
        case .friendRequests: return "Friends"
        case .meets: return "Meets"
        }
    }
    
    var emptyIcon: String {
        switch self {
        case .all: return "tray"
        case .friendRequests: return "person.2"
        case .meets: return "calendar"
        }
    }
    
    var emptyTitle: String {
        switch self {
        case .all: return "No Notifications"
        case .friendRequests: return "No Friend Requests"
        case .meets: return "No Meet Updates"
        }
    }
    
    var emptyMessage: String {
        switch self {
        case .all: return "You're all caught up!"
        case .friendRequests: return "Friend requests will appear here"
        case .meets: return "Meet invitations and updates will appear here"
        }
    }
}

// MARK: - Notification Card

struct NotificationCard: View
{
    let notification: InboxNotificationModelBody
    let onTap: () async -> Void
    let onAcceptFriendRequest: () async -> Void
    let onDeclineFriendRequest: () async -> Void
    
    @State private var isProcessing = false
    
    var body: some View
    {
        Button(action: { Task { await onTap() } }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // Icon
                    Circle()
                        .fill(notification.iconColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: notification.icon)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(notification.iconColor)
                        )
                    
                    // Content
                    VStack(alignment: .leading, spacing: 6) {
                        Text(notification.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppPalette.Text.primary)
                            .lineLimit(2)
                        
                        if let message = notification.message {
                            Text(message)
                                .font(.system(size: 14))
                                .foregroundStyle(AppPalette.Text.secondary)
                                .lineLimit(3)
                        }
                        
                        Text(notification.timeAgo)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppPalette.Text.tertiary)
                    }
                    
                    Spacer()
                    
                    // Unread indicator
                    if !notification.is_read {
                        Circle()
                            .fill(AppPalette.Brand.neonPink)
                            .frame(width: 8, height: 8)
                    }
                }
                
                // Friend request actions
                if notification.notification_type_id == 15 { // Friend Request Received
                    HStack(spacing: 12) {
                        Button(action: { Task { await handleAccept() } }) {
                            Text("Accept")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(AppPalette.Brand.neonPink)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(isProcessing)
                        
                        Button(action: { Task { await handleDecline() } }) {
                            Text("Decline")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppPalette.Brand.neonPink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppPalette.Brand.neonPink.opacity(0.5), lineWidth: 1)
                                )
                        }
                        .disabled(isProcessing)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(notification.is_read ? Color(AppPalette.Brand.formBlack) : Color(AppPalette.Brand.japPurple))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func handleAccept() async
    {
        isProcessing = true
        defer { isProcessing = false }
        await onAcceptFriendRequest()
    }
    
    private func handleDecline() async
    {
        isProcessing = true
        defer { isProcessing = false }
        await onDeclineFriendRequest()
    }
}

// MARK: - Notification Model Extensions

extension InboxNotificationModelBody
{
    var icon: String {
        switch notification_type_id {
        case 15: return "person.badge.plus" // Friend Request Received
        case 16: return "person.fill.checkmark" // Friend Request Accepted
        case 17: return "person.fill.xmark" // Friend Request Declined
        case 8: return "envelope.fill" // Meet Invitation Received
        case 9: return "checkmark.circle.fill" // Meet Invitation Accepted
        default: return "bell.fill"
        }
    }
    
    var iconColor: Color {
        switch notification_type_id {
        case 15, 16: return AppPalette.Brand.neonPink
        case 17: return .red
        case 8, 9: return .blue
        default: return .gray
        }
    }
    
    var isMeetRelated: Bool {
        [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14].contains(notification_type_id)
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: dttm_created_utc, relativeTo: Date())
    }
    
    
    var title: String {
        // Parse from notification_type or payload_json
        switch notification_type_id {
        case 15: return "Friend Request"
        case 16: return "Friend Request Accepted"
        case 17: return "Friend Request Declined"
        case 8: return "Meet Invitation"
        default: return notification_type
        }
    }
    
    var message: String? {
        // Parse from payload_json or use created_by_display_name
        "\(created_by_display_name)"
    }
}
// Make it Identifiable for ForEach
extension InboxNotificationModelBody: Identifiable {
    var id: Int64 { notification_id }
}
