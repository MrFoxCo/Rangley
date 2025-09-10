//
//  CognitoTokens.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/3/25.
//

// CognitoTokens.swift
import Foundation
import Amplify
import AWSPluginsCore   // gives AuthCognitoTokensProvider

enum CognitoTokenError: LocalizedError {
    case notSignedIn, noTokens
    var errorDescription: String? {
        switch self { case .notSignedIn: return "Not signed in."; case .noTokens: return "No Cognito tokens available." }
    }
}

enum CognitoTokens {
    static func idToken() async throws -> String {
        let session = try await Amplify.Auth.fetchAuthSession()
        guard session.isSignedIn else { throw CognitoTokenError.notSignedIn }
        guard let p = session as? AuthCognitoTokensProvider else { throw CognitoTokenError.noTokens }
        let tokens = try p.getCognitoTokens().get()
        return tokens.idToken
    }
}
