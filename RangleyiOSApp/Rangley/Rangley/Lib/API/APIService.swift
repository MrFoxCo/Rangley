//
//  APIService.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/3/25.
//
import Combine
import Foundation
import Amplify
import AWSPluginsCore

// MARK: - API Service Protocol
protocol APIServiceProtocol
{
    func fetchMeets() async throws -> [ViewMeetsModel]
    func createMeet(_ body: MeetInsertBody) async throws
    func createMeetWithInvites(_ body: MeetWithInvitesInsertBody) async throws
    func updateMeet(_ body: UpdatedMeetInsertBody) async throws
    func deleteMeet(_ body: DeletedMeetInsertBody) async throws
    func leaveMeet(_ meetId: UUID) async throws
    func removeParticipant(meetId: UUID, participantId: UUID) async throws
    func inviteUsersToMeet(meetId: UUID, userIds: [UUID]) async throws
}


// MARK: - API Service Implementation
class APIService: APIServiceProtocol
{
    private func getAuthToken() async throws -> String
    {
        let session = try await Amplify.Auth.fetchAuthSession()
        guard let provider = session as? AuthCognitoTokensProvider else {
            throw AuthAPIError.http(-1, "No Cognito token provider")
        }
        return try provider.getCognitoTokens().get().idToken
    }
    
    func fetchMeets() async throws -> [ViewMeetsModel]
    {
        let token = try await getAuthToken()
        return try await AuthAPI.viewMeets(baseURL: Env.apiBaseURL, token: token)
    }
    
    func createMeet(_ body: MeetInsertBody) async throws
    {
        let token = try await getAuthToken()
        let response = try await AuthAPI.createMeet(baseURL: Env.apiBaseURL, token: token, body: body)
        
        // Check validation fields in response
        if response.validation_failed {
            let violation = ContentViolation(
                reason: response.validation_reason ?? "content_violation",
                message: response.validation_message ?? "Content violates community guidelines"
            )
            throw ContentViolationError(violation: violation)
        }
    }
    
    func createMeetWithInvites(_ body: MeetWithInvitesInsertBody) async throws
    {
        let token = try await getAuthToken()
        let response = try await AuthAPI.createMeetWithInvites(baseURL: Env.apiBaseURL, token: token, body: body)
        
        // Check validation fields in response
        if response.validation_failed {
            let violation = ContentViolation(
                reason: response.validation_reason ?? "content_violation",
                message: response.validation_message ?? "Content violates community guidelines"
            )
            throw ContentViolationError(violation: violation)
        }
    }
    
    func updateMeet(_ body: UpdatedMeetInsertBody) async throws
    {
        let token = try await getAuthToken()
        let response = try await AuthAPI.updateMeet(baseURL: Env.apiBaseURL, token: token, body: body)
        
        // Check validation fields in response
        if response.validation_failed {
            let violation = ContentViolation(
                reason: response.validation_reason ?? "content_violation",
                message: response.validation_message ?? "Content violates community guidelines"
            )
            throw ContentViolationError(violation: violation)
        }
    }
    
    func deleteMeet(_ body: DeletedMeetInsertBody) async throws
    {
        let token = try await getAuthToken()
        _ = try await AuthAPI.deleteMeet(baseURL: Env.apiBaseURL, token: token, body: body)
    }
    
    func leaveMeet(_ meetId: UUID) async throws
    {
        let token = try await getAuthToken()
        let body = RespondToInviteBody(
            meet_id_uuid: meetId,
            response_status_id: 8
        )
        _ = try await AuthAPI.respondToInvitation(baseURL: Env.apiBaseURL, token: token, body: body)
    }
    
    func removeParticipant(meetId: UUID, participantId: UUID) async throws
    {
        let token = try await getAuthToken()
        let body = UpdateParticipantStatusBody(
            meet_id_uuid: meetId,
            target_user_uuid: participantId,
            new_status_id: 9
        )
        _ = try await AuthAPI.updateParticipantStatus(baseURL: Env.apiBaseURL, token: token, body: body)
    }
    
    func inviteUsersToMeet(meetId: UUID, userIds: [UUID]) async throws
    {
            let token = try await getAuthToken()
            
            // Get current user UUID for the inviter_user_uuid field
            let currentUser = try await AuthAPI.viewUserMe(baseURL: Env.apiBaseURL, token: token)
            
            let body = InsertAddtionalParticpantsModelBody(
                meet_id_uuid                    : meetId,
                inviter_user_uuid               : currentUser.user_uuid,
                additional_invitee_user_uuids   : userIds,
                invitation_message               : nil
            )
            
            _ = try await AuthAPI.insertAdditionalParticipantsToMeet(
                baseURL: Env.apiBaseURL,
                token: token,
                body: body
            )
        }
}
