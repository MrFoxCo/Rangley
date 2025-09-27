//
//  UserInboxView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/27/25.
//

import SwiftUI
import Foundation

// MARK: - Message Models
struct InboxMessage: Identifiable, Codable {
    let id: UUID
    let messageType: MessageType
    let title: String
    let body: String
    let timestamp: Date
    let isRead: Bool
    let meetId: UUID?
    let fromUserId: UUID?
    let fromUserName: String?
    
    enum MessageType: String, Codable, CaseIterable {
        case inviteAccepted = "invite_accepted"
        case inviteDeclined = "invite_declined"
        case meetCancelled = "meet_cancelled"
        case meetUpdated = "meet_updated"
        case newInvite = "new_invite"
        case participantJoined = "participant_joined"
        case participantLeft = "participant_left"
        case general = "general"
        
        var icon: String {
            switch self {
            case .inviteAccepted: return "checkmark.circle.fill"
            case .inviteDeclined: return "xmark.circle.fill"
            case .meetCancelled: return "trash.circle.fill"
            case .meetUpdated: return "pencil.circle.fill"
            case .newInvite: return "envelope.circle.fill"
            case .participantJoined: return "person.badge.plus.fill"
            case .participantLeft: return "person.badge.minus.fill"
            case .general: return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .inviteAccepted, .participantJoined: return .green
            case .inviteDeclined, .meetCancelled, .participantLeft: return .red
            case .meetUpdated: return AppPalette.Brand.lemonZest
            case .newInvite: return AppPalette.Brand.neonPink
            case .general: return .blue
            }
        }
    }
}

// MARK: - Inbox Button (for top right of map)
struct InboxButton: View {
    let unreadCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Main button
                Image(systemName: "tray.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(AppPalette.Surface.fieldFill)
                            .overlay(
                                Circle().stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                            )
                    )
                
                // Unread badge
                if unreadCount > 0 {
                    Text("\(min(unreadCount, 99))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(
                            Circle()
                                .fill(.red)
                        )
                        .offset(x: 16, y: -16)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Main Inbox Overlay
struct InboxOverlay: View {
    @Binding var isPresented: Bool
    @State private var messages: [InboxMessage] = []
    @State private var isLoading = true
    @State private var selectedMessage: InboxMessage?
    
    let baseURL: URL
    let token: String
    
    var unreadCount: Int {
        messages.filter { !$0.isRead }.count
    }
    
    var body: some View {
        ZStack {
            if isPresented {
                // Background overlay
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { close() }
                
                // Main inbox view
                VStack(spacing: 0) {
                    // Header
                    InboxHeader(
                        unreadCount: unreadCount,
                        onClose: close,
                        onMarkAllRead: markAllAsRead
                    )
                    
                    Divider()
                        .background(AppPalette.Surface.fieldStroke)
                    
                    // Content
                    if isLoading {
                        LoadingView()
                    } else if messages.isEmpty {
                        EmptyInboxView()
                    } else {
                        MessageListView(
                            messages: messages,
                            onMessageTap: { message in
                                selectedMessage = message
                                markAsRead(message)
                            },
                            onDeleteMessage: deleteMessage
                        )
                    }
                }
                .frame(maxWidth: 400, maxHeight: 600)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppPalette.Brand.japDarkerPurple)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                        )
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
                .padding(.horizontal, 20)
                .padding(.top, 100) // Position below top UI elements
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: isPresented)
        .task {
            if isPresented {
                await loadMessages()
            }
        }
        .sheet(item: $selectedMessage) { message in
            MessageDetailView(message: message)
        }
    }
    
    private func close() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            isPresented = false
        }
    }
    
    private func loadMessages() async {
        isLoading = true
        
        // Simulate API call - replace with actual implementation
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Mock data - replace with actual API call
        let mockMessages = [
            InboxMessage(
                id: UUID(),
                messageType: .inviteAccepted,
                title: "John accepted your invite",
                body: "John Smith accepted your invitation to 'Morning Coffee Run'",
                timestamp: Date().addingTimeInterval(-3600),
                isRead: false,
                meetId: UUID(),
                fromUserId: UUID(),
                fromUserName: "John Smith"
            ),
            InboxMessage(
                id: UUID(),
                messageType: .newInvite,
                title: "New meet invitation",
                body: "Sarah invited you to 'Sunset Yoga Session' on Saturday",
                timestamp: Date().addingTimeInterval(-7200),
                isRead: false,
                meetId: UUID(),
                fromUserId: UUID(),
                fromUserName: "Sarah Johnson"
            ),
            InboxMessage(
                id: UUID(),
                messageType: .inviteDeclined,
                title: "Mike declined your invite",
                body: "Mike Wilson declined your invitation to 'Weekend Hike'",
                timestamp: Date().addingTimeInterval(-86400),
                isRead: true,
                meetId: UUID(),
                fromUserId: UUID(),
                fromUserName: "Mike Wilson"
            )
        ]
        
        await MainActor.run {
            messages = mockMessages.sorted { $0.timestamp > $1.timestamp }
            isLoading = false
        }
    }
    
    private func markAsRead(_ message: InboxMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[index] = InboxMessage(
            id: message.id,
            messageType: message.messageType,
            title: message.title,
            body: message.body,
            timestamp: message.timestamp,
            isRead: true,
            meetId: message.meetId,
            fromUserId: message.fromUserId,
            fromUserName: message.fromUserName
        )
        
        // TODO: Send API call to mark as read
    }
    
    private func markAllAsRead() {
        messages = messages.map { message in
            InboxMessage(
                id: message.id,
                messageType: message.messageType,
                title: message.title,
                body: message.body,
                timestamp: message.timestamp,
                isRead: true,
                meetId: message.meetId,
                fromUserId: message.fromUserId,
                fromUserName: message.fromUserName
            )
        }
        
        // TODO: Send API call to mark all as read
    }
    
    private func deleteMessage(_ message: InboxMessage) {
        withAnimation(.easeOut(duration: 0.3)) {
            messages.removeAll { $0.id == message.id }
        }
        
        // TODO: Send API call to delete message
    }
}

// MARK: - Inbox Header
private struct InboxHeader: View {
    let unreadCount: Int
    let onClose: () -> Void
    let onMarkAllRead: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Inbox")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                if unreadCount > 0 {
                    Text("\(unreadCount) unread")
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                } else {
                    Text("All caught up!")
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.Text.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                if unreadCount > 0 {
                    Button("Mark all read", action: onMarkAllRead)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                }
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppPalette.Text.secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(AppPalette.Surface.fieldFill)
                                .overlay(
                                    Circle().stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Message List
private struct MessageListView: View {
    let messages: [InboxMessage]
    let onMessageTap: (InboxMessage) -> Void
    let onDeleteMessage: (InboxMessage) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(messages) { message in
                    MessageRowView(
                        message: message,
                        onTap: { onMessageTap(message) },
                        onDelete: { onDeleteMessage(message) }
                    )
                    
                    if message.id != messages.last?.id {
                        Divider()
                            .background(AppPalette.Surface.fieldStroke.opacity(0.3))
                            .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
}

// MARK: - Message Row
private struct MessageRowView: View {
    let message: InboxMessage
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirm = false
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: message.timestamp, relativeTo: Date())
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Message type icon
                ZStack {
                    Circle()
                        .fill(message.messageType.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: message.messageType.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(message.messageType.color)
                }
                
                // Message content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(message.title)
                            .font(.system(size: 16, weight: message.isRead ? .medium : .semibold))
                            .foregroundStyle(AppPalette.Text.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(timeAgo)
                            .font(.system(size: 12))
                            .foregroundStyle(AppPalette.Text.tertiary)
                    }
                    
                    Text(message.body)
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.Text.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Unread indicator
                if !message.isRead {
                    Circle()
                        .fill(AppPalette.Brand.neonPink)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                Rectangle()
                    .fill(message.isRead ? Color.clear : AppPalette.Brand.neonPink.opacity(0.05))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
            }
        }
        .alert("Delete message?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Loading View
private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppPalette.Brand.neonPink)
            
            Text("Loading messages...")
                .font(.system(size: 16))
                .foregroundStyle(AppPalette.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Empty Inbox View
private struct EmptyInboxView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(AppPalette.Text.tertiary)
            
            VStack(spacing: 8) {
                Text("No messages yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("When you receive invites or updates about your meets, they'll appear here.")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Message Detail View
private struct MessageDetailView: View {
    let message: InboxMessage
    @Environment(\.dismiss) private var dismiss
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Message header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(message.messageType.color.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: message.messageType.icon)
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(message.messageType.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.title)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(AppPalette.Text.primary)
                                
                                if let fromUserName = message.fromUserName {
                                    Text("From \(fromUserName)")
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppPalette.Text.secondary)
                                }
                                
                                Text(formattedDate)
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppPalette.Text.tertiary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    Divider()
                        .background(AppPalette.Surface.fieldStroke)
                    
                    // Message body
                    Text(message.body)
                        .font(.system(size: 16))
                        .foregroundStyle(AppPalette.Text.primary)
                        .lineSpacing(4)
                    
                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .background(AppPalette.Brand.japDarkerPurple)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(AppPalette.Brand.neonPink)
                }
            }
        }
    }
}

// MARK: - Usage Example (add to your main map view)
/*
struct MapViewWithInbox: View {
    @State private var showInbox = false
    @State private var messages: [InboxMessage] = []
    
    var unreadCount: Int {
        messages.filter { !$0.isRead }.count
    }
    
    var body: some View {
        ZStack {
            // Your existing map view
            MapView()
            
            // Top right UI elements
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // Your existing NearbyMeetsBadgeView
                        NearbyMeetsBadgeView(...)
                        
                        // New inbox button
                        InboxButton(unreadCount: unreadCount) {
                            showInbox = true
                        }
                    }
                    .padding(.trailing, 20)
                }
                .padding(.top, 60)
                
                Spacer()
            }
            
            // Inbox overlay
            InboxOverlay(
                isPresented: $showInbox,
                baseURL: baseURL,
                token: token
            )
        }
    }
}
*/
