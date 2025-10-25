//
//  ClaudeModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/25/25.
//

import Foundation

enum ClaudeModel
{
    struct ChatMessage: Codable {
        let role: String  // "user" or "assistant"
        let content: String
    }

    struct ChatbotRequest: Codable {
        let message: String
        let history: [ChatMessage]?
    }

    struct ChatbotResponse: Codable {
        let message: String
    }

}

