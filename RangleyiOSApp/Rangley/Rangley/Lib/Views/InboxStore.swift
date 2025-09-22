//
//  InboxStore.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/22/25.
//

import Foundation

@MainActor
final class InboxStore: ObservableObject {
    @Published private(set) var inviteCount = 0
    @Published private(set) var notifications: [ViewNotificationsModel] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var baseURL: URL
    private var token: String = ""

    init(baseURL: URL) { self.baseURL = baseURL }

    func setToken(_ new: String) async {
        guard new != token else { return }
        token = new
        guard !token.isEmpty else { return }
        await refresh()
    }

    func refresh() async {
        guard !token.isEmpty else { return }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let all = try await AuthAPI.viewNotifications(baseURL: baseURL, token: token)
            let pending = all.filter { $0.notification_type_id == 8 && $0.participant_status_id == 4 }.count
            await MainActor.run {
                self.notifications = all
                self.inviteCount = pending
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func respondToInvitation(_ n: ViewNotificationsModel, statusId: Int16) async throws {
        let body = RespondToInviteBody(meet_id_uuid: n.meet_id_uuid, response_status_id: statusId)
        _ = try await AuthAPI.respondToInvitation(baseURL: baseURL, token: token, body: body)
        await refresh() // keep badge + list in sync
    }
}
