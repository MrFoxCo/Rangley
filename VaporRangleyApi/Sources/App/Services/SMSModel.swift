//
//  SMSModel.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 9/25/25.
//

import Vapor
import Foundation

// Simple, concurrency-safe verification code store
actor VerificationCodeStore
{
    static let shared = VerificationCodeStore()
    
    private var codes: [String: CodeEntry] = [:]
    private var lastCleanup = Date()
    
    private struct CodeEntry {
        let code: String
        let expires: Date
    }
    
    private init() {
        // Empty init - cleanup happens on-demand
    }
    
    func store(phone: String, code: String, expiryMinutes: Int = 5) {
        cleanupIfNeeded()
        let expires = Date().addingTimeInterval(TimeInterval(expiryMinutes * 60))
        codes[phone] = CodeEntry(code: code, expires: expires)
    }
    
    func verify(phone: String, code: String) -> Bool {
        cleanupIfNeeded()
        guard let stored = codes[phone],
              stored.expires > Date(),
              stored.code == code else {
            return false
        }
        
        codes.removeValue(forKey: phone)
        return true
    }
    
    // Clean up expired codes if it's been more than 5 minutes since last cleanup
    private func cleanupIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(lastCleanup) > 300 { // 5 minutes
            codes = codes.filter { $0.value.expires > now }
            lastCleanup = now
        }
    }
}

actor PasswordResetCodeStore {
    static let shared = PasswordResetCodeStore()
    
    private var codes: [String: (code: String, expires: Date)] = [:]
    private var resetTokens: [String: (token: String, expires: Date)] = [:]
    
    func store(phone: String, code: String) {
        codes[phone] = (code, Date().addingTimeInterval(15 * 60)) // 15 min expiry
    }
    
    func verify(phone: String, code: String) -> Bool {
        guard let stored = codes[phone], stored.expires > Date() else {
            codes.removeValue(forKey: phone)
            return false
        }
        return stored.code == code
    }
    
    func storeResetToken(phone: String, token: String) {
        resetTokens[phone] = (token, Date().addingTimeInterval(10 * 60)) // 10 min to complete reset
    }
    
    func validateResetToken(phone: String, token: String) -> Bool {
        guard let stored = resetTokens[phone], stored.expires > Date() else {
            resetTokens.removeValue(forKey: phone)
            return false
        }
        return stored.token == token
    }
    
    func invalidateResetToken(phone: String, token: String) {
        resetTokens.removeValue(forKey: phone)
        codes.removeValue(forKey: phone)
    }
}

// MARK: - Request/Response Models

struct PhoneVerificationRequest: Content
{
    let phone: String
}

struct VerifyCodeRequest: Content
{
    let phone: String
    let code: String
}

struct VerificationResponse: Content
{
    let verified: Bool
    let token: String?
    let message: String?
    
    init(verified: Bool, token: String? = nil, message: String? = nil) {
        self.verified = verified
        self.token = token
        self.message = message
    }
}

struct PasswordResetRequest: Content
{
    let phone: String
}

struct PasswordResetVerifyRequest: Content
{
    let phone   : String
    let code    : String
}

struct PasswordResetVerifyResponse: Content
{
    let verified    : Bool
    let reset_token : String
    let message     : String
}

struct PasswordResetConfirmRequest: Content
{
    let phone       : String
    let reset_token : String
    let new_password: String
}

struct PasswordResetConfirmResponse: Content
{
    let success: Bool
    let message: String
}
