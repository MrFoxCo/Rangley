//
//  CognitoAdminService.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 11/4/25.
//

import Vapor
@preconcurrency import AWSCognitoIdentityProvider

struct CognitoAdminService : Sendable
{
    let client      : CognitoIdentityProviderClient
    let userPoolId  : String
    
    init(region: String, userPoolId: String) async throws {
        // AWS SDK will use environment credentials or IAM role
        let config = try await CognitoIdentityProviderClient.CognitoIdentityProviderClientConfiguration(
            region: region
        )
        self.client = CognitoIdentityProviderClient(config: config)
        self.userPoolId = userPoolId
    }
    
    /// Check if user exists by phone number
    func userExists(phone: String) async throws -> Bool {
        let input = ListUsersInput(
            filter: "phone_number = \"\(phone)\"",
            userPoolId: userPoolId
        )
        
        let output = try await client.listUsers(input: input)
        return !(output.users?.isEmpty ?? true)
    }
    
    /// Set user password (admin action, no old password required)
    func setUserPassword(username: String, password: String, permanent: Bool = true) async throws {
        let input = AdminSetUserPasswordInput(
            password: password,
            permanent: permanent,
            userPoolId: userPoolId,
            username: username

        )
        
        _ = try await client.adminSetUserPassword(input: input)
    }
}

// Storage key for Vapor
struct CognitoAdminServiceKey: StorageKey
{
    typealias Value = CognitoAdminService
}

extension Application {
    var cognitoAdmin: CognitoAdminService {
        get {
            guard let service = storage[CognitoAdminServiceKey.self] else {
                fatalError("CognitoAdminService not configured")
            }
            return service
        }
        set {
            storage[CognitoAdminServiceKey.self] = newValue
        }
    }
}

extension Request {
    var cognitoAdmin: CognitoAdminService {
        application.cognitoAdmin
    }
}


// SMALL CHANGE
