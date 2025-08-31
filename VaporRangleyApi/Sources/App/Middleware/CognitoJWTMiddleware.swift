//
//  CognitoJWTMiddleware.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 8/31/25.
//

// CognitoJWTMiddleware.swift
import Vapor
import JWT

struct CognitoJWTMiddleware: AsyncMiddleware {
    let jwksURL: URI
    let issuer: String          // e.g. "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_AbCdEf123"
    let audience: String        // your App Client Id

    // cache JWKs in memory
    private static var cachedJWKs: JWKSet?
    private static var lastFetch: Date?

    func fetchJWKs(_ client: Client) async throws -> JWKSet {
        if let s = Self.cachedJWKs, let t = Self.lastFetch, Date().timeIntervalSince(t) < 60*60 {
            return s
        }
        let res = try await client.get(jwksURL)
        let jwks = try res.content.decode(JWKSet.self)
        Self.cachedJWKs = jwks
        Self.lastFetch = Date()
        return jwks
    }

    func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let bearer = req.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing bearer token")
        }

        let jwks = try await fetchJWKs(req.client)
        let signers = JWTSigners()
        try signers.use(jwks: jwks)

        struct Claims: JWTPayload {
            var iss: IssuerClaim
            var sub: SubjectClaim
            var exp: ExpirationClaim
            var token_use: String
            var client_id: String?

            func verify(using signer: JWTSigner) throws {
                try exp.verifyNotExpired()
            }
        }

        let payload = try signers.verify(bearer, as: Claims.self)

        // hard checks
        guard payload.iss.value == issuer else { throw Abort(.unauthorized, reason: "Bad issuer") }
        guard payload.token_use == "access" else { throw Abort(.unauthorized, reason: "Not an access token") }
        if let cid = payload.client_id { guard cid == audience else { throw Abort(.unauthorized) } }

        // expose user id (Cognito sub) to handlers
        req.storage[UserKey.self] = payload.sub.value
        return try await next.respond(to: req)
    }
}

private struct UserKey: StorageKey { typealias Value = String }
extension Request {
    var cognitoSub: String? { storage[UserKey.self] }
}
