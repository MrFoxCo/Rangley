//
//  SessionModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/13/25.
//

import SwiftUI
import Amplify
import AWSPluginsCore

@MainActor
final class SessionModel: ObservableObject {
    @Published private(set) var me: ViewUserMeModel?
    @Published private(set) var isLoading = false

    func ensureMe() async {
        guard me == nil else { return }
        await reloadMe()
    }

    func reloadMe() async {
        guard !isLoading else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            guard let provider = session as? AuthCognitoTokensProvider else { return }
            let idToken = try provider.getCognitoTokens().get().idToken
            me = try await AuthAPI.me(baseURL: Env.apiBaseURL, token: idToken)
        } catch {
            print("reloadMe error:", error)
            me = nil
        }
    }

    func clear() { me = nil }
}
