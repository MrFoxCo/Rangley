//
//  CognitoJWTMiddleware.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 8/31/25.
//

import Vapor
import JWT
import JWTKit

actor JWKSCache {
    static let shared = JWKSCache()
    private var jwks: JWKS?
    private var lastFetch: Date?
    func get(client: any Client, url: URI) async throws -> JWKS {
        if let jwks, let lastFetch, Date().timeIntervalSince(lastFetch) < 3600 { return jwks }
        let res = try await client.get(url)
        let fresh = try res.content.decode(JWKS.self)
        self.jwks = fresh
        self.lastFetch = Date()
        return fresh
    }
}

struct CognitoClaims: JWTPayload {
    var iss: IssuerClaim
    var sub: SubjectClaim
    var exp: ExpirationClaim
    var token_use: String          // "id" or "access"
    var client_id: String?         // access token
    var aud: AudienceClaim?        // id token
    func verify(using _: some JWTAlgorithm) async throws { try exp.verifyNotExpired() }
}

private struct UserKey: StorageKey { typealias Value = String }
extension Request { var cognitoSub: String? { storage[UserKey.self] } }

struct CognitoJWTMiddleware: AsyncMiddleware {
    let jwksURL: URI
    let issuer: String
    let audience: String // App Client ID

    func respond(to req: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let bearer = req.headers.bearerAuthorization?.token
        else { throw Abort(.unauthorized, reason: "Missing bearer token") }

        // Fetch JWKS (cached) and load keys
        let jwks = try await JWKSCache.shared.get(client: req.client, url: jwksURL)

        // If your JWTKit allows resetting, uncomment the next line:
        // req.application.jwt.keys = .init()
        try await req.application.jwt.keys.add(jwks: jwks)

        // Verify and parse claims
        let payload = try await req.jwt.verify(bearer, as: CognitoClaims.self)

        // Issuer check
        guard payload.iss.value == issuer else {
            throw Abort(.unauthorized, reason: "Bad issuer")
        }

        // Audience / client_id checks depending on token type
        switch payload.token_use
        {
            case "id":
                guard let aud = payload.aud, aud.value.contains(audience)
                else { throw Abort(.unauthorized, reason: "Wrong audience for ID token") }

            case "access":
                if let cid = payload.client_id, cid != audience {
                    throw Abort(.unauthorized, reason: "Wrong client_id for access token")
                }

            default:
                throw Abort(.unauthorized, reason: "Unsupported token_use")
        }

        // Expose sub
        req.storage[UserKey.self] = payload.sub.value
        return try await next.respond(to: req)
    }
}


//one last question... what makes more sense than user-by-auth-rega or user-by-auth-register?
