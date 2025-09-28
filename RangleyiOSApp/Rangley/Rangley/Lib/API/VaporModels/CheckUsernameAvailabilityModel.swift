//
//  CheckUsernameAvailabilityModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/28/25.
//

// Input model - no longer needed since we use query parameters
// but keeping for potential future use or documentation
struct CheckUsernameAvailabilityModelBody: Codable, Sendable
{
    let username: String
}

// Response model - matches the Postgres function JSON response
struct CheckUsernameAvailabilityModelResponse: Codable, Sendable
{
    let available: Bool
    let reason: String
    let message: String
    
    // Convenience computed properties for easy usage
    var isAvailable: Bool { available }
    var errorMessage: String? { available ? nil : message }
    
    // Common reason checking
    var isTaken: Bool { reason == "username_taken" }
    var isTooShort: Bool { reason == "username_too_short" }
    var isTooLong: Bool { reason == "username_too_long" }
    var hasInvalidChars: Bool { reason == "username_invalid_chars" }
    var isReserved: Bool { reason == "username_reserved" }
    var isInappropriate: Bool { reason == "username_inappropriate" }
}
