//
//  CognitoAuth.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 9/9/25.
//

//
//  CognitoAuth.swift
//  VaporRangleyApi
//

import Vapor
import JWT // (Vapor’s JWTKit re-export)

/// Cognito ID token payload
struct CognitoIDToken: JWTPayload, Codable, Sendable {
    // Standard claims
    var iss: IssuerClaim
    var sub: SubjectClaim
    var aud: AudienceClaim            // Cognito sets aud = App Client ID
    var exp: ExpirationClaim
    var iat: IssuedAtClaim

    // Cognito-specific fields we care about
    var token_use: String             // "id" for ID tokens
    var email: String?
    var phone_number: String?
    // NOTE: On ID tokens the key is literally "cognito:username".
    // Use CodingKeys to map it to a Swift identifier.
    var cognito_username: String?

    enum CodingKeys: String, CodingKey {
        case iss, sub, aud, exp, iat, email, phone_number, token_use
        case cognito_username = "cognito:username"
    }

    // JWTKit v5-style verify signature is async and uses `some JWTAlgorithm`
    func verify(using _: some JWTAlgorithm) async throws {
        try exp.verifyNotExpired()
        guard token_use == "id" else {
            throw Abort(.unauthorized, reason: "token_use != id")
        }
    }
}

// Storage keys must be module-internal (NOT private) so other files can read them.
enum CognitoPayloadKey: StorageKey { typealias Value = CognitoIDToken }
enum IssuerKey: StorageKey        { typealias Value = String }
enum AudienceKey: StorageKey      { typealias Value = String }

/// Middleware that verifies a *Cognito ID token* from Authorization: Bearer <JWT>
struct CognitoIDMiddleware: AsyncMiddleware {
    func respond(to req: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let bearer = req.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing bearer token")
        }

        // v5 API: verify is async
        let payload = try await req.jwt.verify(bearer, as: CognitoIDToken.self)

        // Compare iss/aud
        let issuer   = req.application.storage[IssuerKey.self]!
        let audience = req.application.storage[AudienceKey.self]!

        // AudienceClaim.value is [String]
        guard payload.iss.value == issuer else {
            throw Abort(.unauthorized, reason: "Bad iss")
        }
        guard payload.aud.value.contains(audience) else {
            throw Abort(.unauthorized, reason: "Bad aud")
        }

        req.storage[CognitoPayloadKey.self] = payload
        return try await next.respond(to: req)
    }
}

extension Request {
    var cognito: CognitoIDToken {
        guard let p = storage[CognitoPayloadKey.self] else {
            fatalError("CognitoIDToken missing. Ensure CognitoIDMiddleware is applied.")
        }
        return p
    }
}

