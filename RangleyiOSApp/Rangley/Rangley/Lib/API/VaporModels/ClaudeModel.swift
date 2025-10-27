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
        let message: String
        let history: [ChatMessage]

        // CRITICAL: These are now REQUIRED, not optional
        let currentTimeNatural: String      // "Monday, October 27, 2025 a10:41 AM"
        let userTimezone: String            // "America/Chicago"
        let userLocation: String            // "Near Lake View East, Chicago, IL"
        let userDisplayName: String         // "Anthony Guzzardo"

        let tapLocation: TapLocationContext?  // Optional - only if user tappemap
    }

    struct TapLocationContext: Codable
    {
        let name: String?              // "Millennium Park"
        let latitude: Double
        let longitude: Double
    }

    struct ChatbotResponse: Codable {
        let message: String
    }
}
