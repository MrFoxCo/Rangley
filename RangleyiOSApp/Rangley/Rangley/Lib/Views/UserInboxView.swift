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
    @State private var showClearConfirmation = false
    @State private var friendRequestsExpanded = true
    @State private var meetInvitationsExpanded = true
    
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
        .task {
            await inbox.refresh(force: true)
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
            
            Text("Inbox")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            Spacer()
            
            // Clear all button
            Button(action: {
                showClearConfirmation = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppPalette.Action.delete)
            }
            .disabled(inbox.inboxNotifications.isEmpty)
            .opacity(inbox.inboxNotifications.isEmpty ? 0.3 : 1.0)
            .confirmationDialog(
                "Clear Inbox",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Notifications", role: .destructive) {
                    Task {
                        try? await inbox.clearInbox()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear all read notifications. Pending invitations and friend requests will remain.")
            }
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
            LazyVStack(spacing: 16) {
                // Friend Requests Section (always first if present)
                if !friendRequests.isEmpty {
                    CollapsibleSection(
                        title: "Friend Requests",
                        icon: "person.badge.plus",
                        count: friendRequests.count,
                        isExpanded: $friendRequestsExpanded
                    ) {
                        ForEach(friendRequests) { notification in
                            NotificationCard(
                                notification: notification,
                                onTap: { await handleNotificationTap(notification) },
                                onDelete: { await deleteNotification(notification) },
                                onAcceptFriendRequest: { await acceptFriendRequest(notification) },
                                onDeclineFriendRequest: { await declineFriendRequest(notification) },
                                onAcceptMeetInvitation: { await acceptMeetInvitation(notification) },
                                onDeclineMeetInvitation: { await declineMeetInvitation(notification) }
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                // Meet Invitations Section (second if present)
                if !meetInvitations.isEmpty {
                    CollapsibleSection(
                        title: "Meet Invitations",
                        icon: "envelope.fill",
                        count: meetInvitations.count,
                        isExpanded: $meetInvitationsExpanded
                    ) {
                        ForEach(meetInvitations) { notification in
                            NotificationCard(
                                notification: notification,
                                onTap: { await handleNotificationTap(notification) },
                                onDelete: { await deleteNotification(notification) },
                                onAcceptFriendRequest: { await acceptFriendRequest(notification) },
                                onDeclineFriendRequest: { await declineFriendRequest(notification) },
                                onAcceptMeetInvitation: { await acceptMeetInvitation(notification) },
                                onDeclineMeetInvitation: { await declineMeetInvitation(notification) }
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                }
                
                // Other Notifications
                if !otherNotifications.isEmpty {
                    ForEach(otherNotifications) { notification in
                        NotificationCard(
                            notification: notification,
                            onTap: { await handleNotificationTap(notification) },
                            onDelete: { await deleteNotification(notification) },
                            onAcceptFriendRequest: { await acceptFriendRequest(notification) },
                            onDeclineFriendRequest: { await declineFriendRequest(notification) },
                            onAcceptMeetInvitation: { await acceptMeetInvitation(notification) },
                            onDeclineMeetInvitation: { await declineMeetInvitation(notification) }
                        )
                        .padding(.horizontal, 20)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await deleteNotification(notification)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
    }

    private func deleteNotification(_ notification: InboxNotificationModelBody) async
    {
        do {
            try await inbox.deleteNotification(notification.notification_id)
        } catch {
            print("Failed to delete: \(error)")
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
    
    // MARK: - Filtered Notifications
    private var filteredNotifications: [InboxNotificationModelBody]
    {
        switch selectedTab {
        case .all:
            return inbox.inboxNotifications
        case .friendRequests:
            return inbox.inboxNotifications.filter { $0.notification_type_id == 15 }
        case .meets:
            return inbox.inboxNotifications.filter { $0.isMeetRelated }
        }
    }
    
    // Separate notifications by priority
    private var friendRequests: [InboxNotificationModelBody] {
        filteredNotifications.filter { $0.notification_type_id == 15 }
    }
    
    private var meetInvitations: [InboxNotificationModelBody] {
        filteredNotifications.filter { $0.notification_type_id == 8 }
    }
    
    private var otherNotifications: [InboxNotificationModelBody] {
        filteredNotifications.filter { $0.notification_type_id != 15 && $0.notification_type_id != 8 }
    }
    
    // MARK: - Actions
    private func acceptFriendRequest(_ notification: InboxNotificationModelBody) async
    {
        do {
            try await inbox.respondToFriendRequest(notification, accept: true)
        } catch {
            print("Failed to accept: \(error)")
        }
    }
    
    private func declineFriendRequest(_ notification: InboxNotificationModelBody) async
    {
        do {
            try await inbox.respondToFriendRequest(notification, accept: false)
        } catch {
            print("Failed to decline: \(error)")
        }
    }
    
    private func acceptMeetInvitation(_ notification: InboxNotificationModelBody) async
    {
        do {
            try await inbox.respondToMeetInvitation(notificationId: notification.notification_id, statusId: 6) // 6 = Accepted
        } catch {
            print("Failed to accept meet invitation: \(error)")
        }
    }
    
    private func declineMeetInvitation(_ notification: InboxNotificationModelBody) async
    {
        do {
            try await inbox.respondToMeetInvitation(notificationId: notification.notification_id, statusId: 5) // 5 = Declined
        } catch {
            print("Failed to decline meet invitation: \(error)")
        }
    }
}

// MARK: - Collapsible Section
struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    let count: Int
    @Binding var isExpanded: Bool
    let content: Content
    
    init(
        title: String,
        icon: String,
        count: Int,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.count = count
        self._isExpanded = isExpanded
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
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
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
            }
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            
            // Expandable Content
            if isExpanded {
                content
            }
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
    let onDelete: () async -> Void
    let onAcceptFriendRequest: () async -> Void
    let onDeclineFriendRequest: () async -> Void
    let onAcceptMeetInvitation: () async -> Void
    let onDeclineMeetInvitation: () async -> Void
    
    @State private var isProcessing = false
    
    var body: some View
    {
        VStack(alignment: .leading, spacing: 12) {
            // Main content area
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
            .contentShape(Rectangle())
            .onTapGesture {
                // Only allow general tap for non-actionable notifications
                if notification.notification_type_id != 15 && notification.notification_type_id != 8 {
                    Task { await onTap() }
                }
            }
            
            // Friend request actions
            if notification.notification_type_id == 15 {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            isProcessing = true
                            await onAcceptFriendRequest()
                            isProcessing = false
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Text("Accept")
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppPalette.Brand.neonPink)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(isProcessing)
                    .buttonStyle(.plain)
                    
                    Button {
                        Task {
                            isProcessing = true
                            await onDeclineFriendRequest()
                            isProcessing = false
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(AppPalette.Brand.neonPink)
                            } else {
                                Text("Decline")
                            }
                        }
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
                    .buttonStyle(.plain)
                }
                .allowsHitTesting(!isProcessing)
            }
            
            // Meet invitation actions
            if notification.notification_type_id == 8 {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            isProcessing = true
                            await onAcceptMeetInvitation()
                            isProcessing = false
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.black)
                            } else {
                                Text("Accept")
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppPalette.Brand.spearmintGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(isProcessing)
                    .buttonStyle(.plain)
                    
                    Button {
                        Task {
                            isProcessing = true
                            await onDeclineMeetInvitation()
                            isProcessing = false
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(AppPalette.Brand.neonPink)
                            } else {
                                Text("Decline")
                            }
                        }
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
                    .buttonStyle(.plain)
                }
                .allowsHitTesting(!isProcessing)
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
        switch notification_type_id {
        case 15: return "Friend Request"
        case 16: return "Friend Request Accepted"
        case 17: return "Friend Request Declined"
        case 8: return "Meet Invitation"
        default: return notification_type
        }
    }
    
    var message: String? {
        created_by_display_name
    }
}

// Make it Identifiable for ForEach
extension InboxNotificationModelBody: Identifiable
{
    var id: Int64 { notification_id }
}
