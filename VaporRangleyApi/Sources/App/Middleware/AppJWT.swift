//
//  AppJWT.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 9/3/25.
//

import Vapor
import JWT
import Foundation

// MARK: - App token claims (Codable by default)

struct AppPayload: JWTPayload, Sendable, Codable
{
    var iss: IssuerClaim
    var sub: SubjectClaim           // Cognito sub
    var exp: ExpirationClaim
    var iat: IssuedAtClaim
    var jti: IDClaim
    var user_id: Int64?             // <— plain optional Int64, not Claim<T>
    var roles: [String]?

    func verify(using _: some JWTAlgorithm) async throws {
        try exp.verifyNotExpired()
    }
}

private struct AppSubKey: StorageKey { typealias Value = String }
private struct AppUserIdKey: StorageKey { typealias Value = Int64 }

extension Request
{
    var appSub: String?   { storage[AppSubKey.self] }
    var appUserId: Int64? { storage[AppUserIdKey.self] }
}

// MARK: - END App token claims (Codable by default)




// MARK: - Middleware verifying with HS256 secret

struct AppJWTMiddleware: AsyncMiddleware
{
    func respond(to req: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // v5: verify bearer from Authorization header automatically
        let payload = try await req.jwt.verify(as: AppPayload.self)
        guard payload.iss.value == req.application.appAuth.issuer
        else { throw Abort(.unauthorized, reason: "Bad issuer") }

        req.storage[AppSubKey.self] = payload.sub.value
        if let id = payload.user_id { req.storage[AppUserIdKey.self] = id }

        return try await next.respond(to: req)
    }
}

// MARK: - END Middleware verifying with HS256 secret
