//
//  CognitoJWTMiddleware.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 8/31/25.
//

// CognitoJWTMiddleware.swift
import Vapor
import JWT       // gives you req.jwt / app.jwt
import JWTKit    // gives you JWKS, claims types

// Thread-safe JWKS cache
actor JWKSCache {
    static let shared = JWKSCache()
    private var jwks: JWKS?
    private var lastFetch: Date?

    func get(client: any Client, url: URI) async throws -> JWKS {
        if let jwks, let lastFetch, Date().timeIntervalSince(lastFetch) < 3600 {
            return jwks
        }
        let res = try await client.get(url)
        let fresh = try res.content.decode(JWKS.self)
        self.jwks = fresh
        self.lastFetch = Date()
        return fresh
    }
}

struct CognitoJWTMiddleware: AsyncMiddleware {
    let jwksURL: URI
    let issuer: String
    let audience: String

    func respond(to req: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let bearer = req.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing bearer token")
        }

        // 1) Fetch/refresh JWKS
        let jwks = try await JWKSCache.shared.get(client: req.client, url: jwksURL)

        // 2) Load JWKS into the app's key collection
        try await req.application.jwt.keys.add(jwks: jwks)   // <- not .use(...)

        struct Claims: JWTPayload {
            var iss: IssuerClaim
            var sub: SubjectClaim
            var exp: ExpirationClaim
            var token_use: String
            var client_id: String?

            func verify(using _: some JWTAlgorithm) async throws {
                try exp.verifyNotExpired()
            }
        }


        // 3) Verify (note: async in your toolchain)
        let payload = try await req.jwt.verify(bearer, as: Claims.self)

        // 4) Hard checks
        guard payload.iss.value == issuer else { throw Abort(.unauthorized, reason: "Bad issuer") }
        guard payload.token_use == "access" else { throw Abort(.unauthorized, reason: "Not an access token") }
        if let cid = payload.client_id, cid != audience { throw Abort(.unauthorized, reason: "Wrong client_id") }

        // 5) Expose sub
        req.storage[UserKey.self] = payload.sub.value
        return try await next.respond(to: req)
    }
}

private struct UserKey: StorageKey { typealias Value = String }
extension Request { var cognitoSub: String? { storage[UserKey.self] } }
