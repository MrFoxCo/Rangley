//
//  ClaudeConfig.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 10/25/25.
//

import Vapor

struct ClaudeConfig {
    let apiKey: String
    let apiVersion: String
    let baseURL: String
    let model: String
    let maxTokens: Int
    
    static func fromEnvironment() throws -> ClaudeConfig {
        guard let apiKey = Environment.get("CLAUDE_API_KEY") else {
            throw Abort(.internalServerError, reason: "CLAUDE_API_KEY not set in environment")
        }
        
        return ClaudeConfig(
            apiKey: apiKey,
            apiVersion: Environment.get("CLAUDE_API_VERSION") ?? "2023-06-01",
            baseURL: Environment.get("CLAUDE_BASE_URL") ?? "https://api.anthropic.com/v1",
            model: Environment.get("CLAUDE_MODEL") ?? "claude-sonnet-4-5-20250929",
            maxTokens: Int(Environment.get("CLAUDE_MAX_TOKENS") ?? "1024") ?? 1024
        )
    }
}

// Extension to add to Application
extension Application {
    struct ClaudeConfigKey: StorageKey {
        typealias Value = ClaudeConfig
    }
    
    var claudeConfig: ClaudeConfig? {
        get {
            self.storage[ClaudeConfigKey.self]
        }
        set {
            self.storage[ClaudeConfigKey.self] = newValue
        }
    }
}
