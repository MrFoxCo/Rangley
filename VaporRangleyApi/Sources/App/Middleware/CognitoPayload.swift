//
//  CognitoPayload.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 9/1/25.
//

import JWT

struct CognitoPayload: JWTPayload, Sendable
{
    let sub: SubjectClaim
    let iss: IssuerClaim
    let token_use: String
    let email: String?
    let phone_number: String?
    let given_name: String?
    let family_name: String?
    let preferred_username: String?
    let exp: ExpirationClaim

    func verify(using _: some JWTAlgorithm) throws
    {
        try exp.verifyNotExpired()
        guard token_use == "id" else { throw Abort(.unauthorized, reason: "wrong token_use") }
        // Optionally check `iss` matches your pool.
    }
}
