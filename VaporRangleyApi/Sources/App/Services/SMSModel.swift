//
//  SMSModel.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 9/25/25.
//

import Vapor
import Foundation

// Simple, concurrency-safe verification code store
actor VerificationCodeStore {
    static let shared: VerificationCodeStore = {
        let store = VerificationCodeStore()
        Task {
            await store.startCleanup()
        }
        return store
    }()
    
    private var codes: [String: CodeEntry] = [:]
    private var cleanupTask: Task<Void, Never>?
    
    private struct CodeEntry {
        let code: String
        let expires: Date
    }
    
    private init() {
        // Empty initializer
    }
    
    private func startCleanup() {
        cleanupTask = Task { [unowned self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                await self.cleanupExpired()
            }
        }
    }
    
    func store(phone: String, code: String, expiryMinutes: Int = 5) {
        let expires = Date().addingTimeInterval(TimeInterval(expiryMinutes * 60))
        codes[phone] = CodeEntry(code: code, expires: expires)
    }
    
    func verify(phone: String, code: String) -> Bool {
        guard let stored = codes[phone],
              stored.expires > Date(),
              stored.code == code else {
            return false
        }
        
        codes.removeValue(forKey: phone)
        return true
    }
    
    private func cleanupExpired() async {
        let now = Date()
        codes = codes.filter { $0.value.expires > now }
    }
    
    deinit {
        cleanupTask?.cancel()
    }
}

// MARK: - Request/Response Models

struct PhoneVerificationRequest: Content {
    let phone: String
}

struct VerifyCodeRequest: Content {
    let phone: String
    let code: String
}

struct VerificationResponse: Content {
    let verified: Bool
    let token: String?
    let message: String?
    
    init(verified: Bool, token: String? = nil, message: String? = nil) {
        self.verified = verified
        self.token = token
        self.message = message
    }
}
