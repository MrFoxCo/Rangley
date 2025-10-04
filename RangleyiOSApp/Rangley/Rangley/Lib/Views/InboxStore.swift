//
//  InboxStore.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/22/25.
//

import Foundation

@MainActor
final class InboxStore: ObservableObject {
    // MARK: - Public state
    @Published private(set) var inviteCount = 0
    @Published private(set) var friendRequestCount = 0
    @Published private(set) var notifications: [ViewNotificationsModel] = []
    @Published private(set) var inboxNotifications: [InboxNotificationModelBody] = []  // NEW
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?
    @Published var unreadCount: Int = 0

    // MARK: - Config
    private let baseURL: URL
    private var token: String = ""

    private let minRefreshInterval: TimeInterval = 5
    private var lastRefreshAt: Date?
    private var refreshTask: Task<Void, Never>?

    // MARK: - Type-safe IDs
    private enum NotificationTypeId: Int16 {
        case meetInvitationReceived = 8
        case friendRequestReceived = 15
    }
    private enum ParticipantStatusId: Int16 {
        case pending = 4
    }

    init(baseURL: URL) { self.baseURL = baseURL }

    // MARK: - Token wiring
    func setToken(_ new: String?) async
    {
        let newToken = (new ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard newToken != token else { return }
        token = newToken

        if token.isEmpty {
            clear()
            return
        }
        await refresh(force: true)
    }

    // MARK: - Public API
    func refresh(force: Bool = false) async
    {
        guard !token.isEmpty else { return }

        if !force, let last = lastRefreshAt, Date().timeIntervalSince(last) < minRefreshInterval {
            return
        }
        lastRefreshAt = Date()

        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run { self.isLoading = true; self.errorMessage = nil }

            do {
                // Fetch both old and new notification systems
                async let oldNotifs = AuthAPI.viewNotifications(baseURL: self.baseURL, token: self.token)
                async let newInbox = AuthAPI.viewUserInbox(baseURL: self.baseURL, token: self.token)
                
                let (old, inbox) = try await (oldNotifs, newInbox)

                // Count pending meet invites (old system)
                let pendingInvites = old.filter {
                    $0.notification_type_id == NotificationTypeId.meetInvitationReceived.rawValue &&
                    $0.participant_status_id == ParticipantStatusId.pending.rawValue
                }.count
                
                // Count pending friend requests (new system)
                let pendingFriendRequests = inbox.filter {
                    $0.notification_type_id == 15 && !$0.is_read
                }.count
                
                // Total unread
                let totalUnread = inbox.filter { !$0.is_read }.count

                await MainActor.run {
                    self.notifications = old
                    self.inboxNotifications = inbox
                    self.inviteCount = pendingInvites
                    self.friendRequestCount = pendingFriendRequests
                    self.unreadCount = totalUnread
                    self.isLoading = false
                    self.errorMessage = nil
                    self.lastUpdated = Date()
                }
            } catch is CancellationError {
                // Silently ignore
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
        await refreshTask?.value
    }

    func respondToInvitation(_ n: ViewNotificationsModel, statusId: Int16) async throws
    {
        guard !token.isEmpty else { throw AuthAPIError.http(-1, "No auth token") }

        // Optimistic UI
        await MainActor.run {
            self.notifications.removeAll { $0.id == n.id }
            self.inviteCount = self.notifications.filter {
                $0.notification_type_id == 8 && $0.participant_status_id == 4
            }.count
        }

        let body = RespondToInviteBody(meet_id_uuid: n.meet_id_uuid, response_status_id: statusId)
        _ = try await AuthAPI.respondToInvitation(baseURL: baseURL, token: token, body: body)

        await refresh(force: true)
    }
    
    func respondToMeetInvitation(notificationId: Int64, statusId: Int16) async throws
    {
        guard !token.isEmpty else { throw AuthAPIError.http(-1, "No auth token") }
        
        // Extract meet_id from the notification's payload
        guard let notification = inboxNotifications.first(where: { $0.notification_id == notificationId }),
              let data = notification.payload_json.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let meetIdString = json["meet_id_uuid"] as? String,
              let meetId = UUID(uuidString: meetIdString) else {
            throw AuthAPIError.http(-1, "Invalid notification payload")
        }
        
        // Reuse existing respondToInvitation API
        let body = RespondToInviteBody(meet_id_uuid: meetId, response_status_id: statusId)
        _ = try await AuthAPI.respondToInvitation(baseURL: baseURL, token: token, body: body)
        
        await refresh(force: true)
    }
    
    
    // NEW: Respond to friend request
    func respondToFriendRequest(_ notification: InboxNotificationModelBody, accept: Bool) async throws
    {
        guard !token.isEmpty else { throw AuthAPIError.http(-1, "No auth token") }
        
        // Extract friend_request_id from payload_json
        guard let data = notification.payload_json.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let friendRequestId = json["friend_request_id"] as? Int64 else {
            throw AuthAPIError.http(-1, "Invalid payload")
        }
        
        // Optimistic UI
        await MainActor.run {
            self.inboxNotifications.removeAll { $0.notification_id == notification.notification_id }
            self.unreadCount = self.inboxNotifications.filter { !$0.is_read }.count
        }
        
        _ = try await AuthAPI.respondToFriendRequest(
            baseURL: baseURL,
            token: token,
            friendRequestId: friendRequestId,
            accept: accept
        )
        
        await refresh(force: true)
    }

    // MARK: - Helpers
    func clear() {
        notifications = []
        inboxNotifications = []
        inviteCount = 0
        friendRequestCount = 0
        unreadCount = 0
        isLoading = false
        errorMessage = nil
        lastUpdated = nil
        lastRefreshAt = nil
        refreshTask?.cancel()
        refreshTask = nil
    }
}
