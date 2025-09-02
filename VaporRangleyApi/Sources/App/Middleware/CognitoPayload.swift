//
//  CognitoPayload.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 9/1/25.
//

import JWT

struct CognitoPayload: JWTPayload {
    var subject: SubjectClaim   // "sub"
    var exp: ExpirationClaim

    // v5 signature — no JWTSigner type, and it's async
    func verify(using algorithm: some JWTAlgorithm) async throws {
        try exp.verifyNotExpired()
    }
}
