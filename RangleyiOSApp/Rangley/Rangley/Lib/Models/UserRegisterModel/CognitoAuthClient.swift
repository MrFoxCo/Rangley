//
//  CognitoAuthClient.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/3/25.
//

import Foundation
import SotoCognitoIdentityProvider
import SotoCore

final class CognitoAuthClient {
    private let client: AWSClient
    private let cognito: CognitoIdentityProvider
    private let clientId: String

    init(region: Region, clientId: String) {
        self.client = AWSClient(httpClientProvider: .createNew)
        self.cognito = CognitoIdentityProvider(client: client, region: region)
        self.clientId = clientId
    }

    deinit {
        try? client.syncShutdown()
    }

    /// Login with username + password, return Cognito AccessToken
    func login(username: String, password: String) async throws -> String {
        let request = CognitoIdentityProvider.InitiateAuthRequest(
            authFlow: .userPasswordAuth,
            authParameters: [
                "USERNAME": username,
                "PASSWORD": password
            ],
            clientId: clientId
        )

        let response = try await cognito.initiateAuth(request)
        guard let token = response.authenticationResult?.accessToken else {
            throw NSError(domain: "CognitoAuth", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "No access token in response"])
        }
        return token
    }
}
