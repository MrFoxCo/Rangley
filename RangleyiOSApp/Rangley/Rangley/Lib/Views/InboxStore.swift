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
    @Published private(set) var notifications: [ViewNotificationsModel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    // MARK: - Config
    private let baseURL: URL
    private var token: String = ""

    // Throttle refreshes a bit so we don’t spam the API
    private let minRefreshInterval: TimeInterval = 5
    private var lastRefreshAt: Date?

    // Coalesce concurrent refreshes
    private var refreshTask: Task<Void, Never>?

    // MARK: - Type-safe IDs (ditch magic numbers)
    private enum NotificationTypeId: Int16 {
        case meetInvitationReceived = 8
    }
    private enum ParticipantStatusId: Int16 {
        case pending = 4
    }

    init(baseURL: URL) { self.baseURL = baseURL }

    // MARK: - Token wiring
    /// Pass `""` or `nil` on sign-out to clear state.
    func setToken(_ new: String?) async {
        let newToken = (new ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard newToken != token else {
            // Same token: still allow a refresh if the caller wants to.
            return
        }
        token = newToken

        if token.isEmpty {
            clear()
            return
        }
        await refresh(force: true)
    }

    // MARK: - Public API
    func refresh(force: Bool = false) async {
        guard !token.isEmpty else { return }

        // Throttle
        if !force, let last = lastRefreshAt, Date().timeIntervalSince(last) < minRefreshInterval {
            return
        }
        lastRefreshAt = Date()

        // Cancel any in-flight refresh so we don’t race
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run { self.isLoading = true; self.errorMessage = nil }

            do {
                let all = try await AuthAPI.viewNotifications(baseURL: self.baseURL, token: self.token)

                // Pending invites: type == invitation + participant status == pending
                let pending = all.filter {
                    $0.notification_type_id == NotificationTypeId.meetInvitationReceived.rawValue &&
                    $0.participant_status_id == ParticipantStatusId.pending.rawValue
                }.count

                await MainActor.run {
                    self.notifications = all
                    self.inviteCount = pending
                    self.isLoading = false
                    self.errorMessage = nil
                    self.lastUpdated = Date()
                }
            } catch is CancellationError {
                // Silently ignore; a newer refresh will replace us
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
        await refreshTask?.value
    }

    func respondToInvitation(_ n: ViewNotificationsModel, statusId: Int16) async throws {
        guard !token.isEmpty else { throw AuthAPIError.http(-1, "No auth token") }
        let body = RespondToInviteBody(meet_id_uuid: n.meet_id_uuid, response_status_id: statusId)
        _ = try await AuthAPI.respondToInvitation(baseURL: baseURL, token: token, body: body)
        await refresh(force: true) // keep badge + list in sync
    }

    // MARK: - Helpers
    func clear() {
        notifications = []
        inviteCount = 0
        isLoading = false
        errorMessage = nil
        lastUpdated = nil
        lastRefreshAt = nil
        refreshTask?.cancel()
        refreshTask = nil
    }
}
