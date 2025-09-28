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
