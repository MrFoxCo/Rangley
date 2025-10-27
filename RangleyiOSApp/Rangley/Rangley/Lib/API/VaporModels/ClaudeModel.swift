//
//  ClaudeModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/25/25.
//

import Foundation

enum ClaudeModel
{
    struct ChatMessage: Codable
    {
        let role: String  // "user" or "assistant"
        let content: String
    }

    struct ChatbotRequest: Codable
    {
        let message         : String
        let history         : [ChatMessage]?
        let userTimezone    : String?
        let currentTimeISO  : String?
        let userLocation    : String?
        let userDisplayName : String?
        let tapLocation     : TapLocationContext?
    }

    struct TapLocationContext: Codable
    {
        let name        : String?              // "Millennium Park"
        let latitude    : Double
        let longitude   : Double
    }
    struct ChatbotResponse: Codable {
        let message: String
    }

}

