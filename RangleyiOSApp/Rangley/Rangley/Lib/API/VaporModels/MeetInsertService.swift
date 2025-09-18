//
//  MeetInsertService.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/18/25.
//

import Foundation
import Amplify
import AWSPluginsCore

protocol AuthTokenProvider { func idToken() async throws -> String }

final class AmplifyTokenProvider: AuthTokenProvider {
    func idToken() async throws -> String {
        let session = try await Amplify.Auth.fetchAuthSession()
        guard let p = session as? AuthCognitoTokensProvider
        else { throw AuthAPIError.http(-1, "No Cognito token provider") }
        return try p.getCognitoTokens().get().idToken
    }
}
//
//actor MeetInsertService {
//    private let baseURL: URL
//    private let tokenProvider: AuthTokenProvider
//
//    init(baseURL: URL = Env.apiBaseURL,
//         tokenProvider: AuthTokenProvider = AmplifyTokenProvider()) {
//        self.baseURL = baseURL
//        self.tokenProvider = tokenProvider
//    }
//
//    func createMeetOnly(
//        info: LocationInfo, name: String, start: Date, end: Date
//    ) async throws -> MeetInsertResponse {
//        let body = buildMeetBody(locationInfo: info, name: name, startTime: start, endTime: end)
//        let token = try await tokenProvider.idToken()
//        return try await AuthAPI.createMeet(baseURL: baseURL, token: token, body: body)
//    }
//
//    func createMeetWithInvites(
//        info: LocationInfo, name: String, start: Date, end: Date, invited: [UUID]
//    ) async throws -> MeetInsertResponse {
//        let body = buildMeetWithInvitesBody(locationInfo: info, name: name, startTime: start, endTime: end, invitedUsers: invited)
//        let token = try await tokenProvider.idToken()
//        return try await AuthAPI.createMeetWithInvites(baseURL: baseURL, token: token, body: body)
//    }
//}
