//
//  PasswordRestModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 11/4/25.
//

// MARK: - Password Reset Models

struct PasswordResetRequestModel: Codable {
    let phone: String
}

struct PasswordResetVerifyRequestModel: Codable {
    let phone: String
    let code: String
}

struct PasswordResetVerifyResponseModel: Codable {
    let verified: Bool
    let reset_token: String
    let message: String
}

struct PasswordResetConfirmRequestModel: Codable {
    let phone: String
    let reset_token: String
    let new_password: String
}

struct PasswordResetConfirmResponseModel: Codable {
    let success: Bool
    let message: String
}
