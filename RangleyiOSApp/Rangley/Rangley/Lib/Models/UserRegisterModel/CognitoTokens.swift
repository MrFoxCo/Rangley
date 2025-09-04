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

enum CognitoTokenError: Error { case noTokens }

enum CognitoTokens {
    static func idToken() async throws -> String {
        let session = try await Amplify.Auth.fetchAuthSession()
        guard let p = session as? AuthCognitoTokensProvider else { throw CognitoTokenError.noTokens }
        let tokens = try p.getCognitoTokens().get()
        return tokens.idToken
    }
}
