//
//  SMSModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/25/25.
//

struct SendVerificationRequest: Codable {
    let phone: String
}

struct VerifyPhoneRequest: Codable {
    let phone: String
    let code: String
}

struct VerifyPhoneResponse: Codable {
    let verified: Bool
    let token: String?
    let message: String?
}
