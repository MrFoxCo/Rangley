//
//  ValidateDisplayNameModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/28/25.
//

// Input model - no longer needed since we use query parameters
// but keeping for potential future use or documentation
struct ValidateDisplayNameModelBody: Codable, Sendable
{
    let display_name: String
}

// Response model - matches the Postgres function JSON response
struct ValidateDisplayNameModelResponse: Codable, Sendable
{
    let valid: Bool
    let reason: String
    let message: String
    
    // Convenience computed properties for easy usage
    var isValid: Bool { valid }
    var errorMessage: String? { valid ? nil : message }
    
    // Common reason checking
    var isEmpty: Bool { reason == "display_name_empty" }
    var isTooLong: Bool { reason == "display_name_too_long" }
    var isInappropriate: Bool { reason == "display_name_inappropriate" }
    var hasImpersonation: Bool { reason == "display_name_impersonation" }
    var containsContactInfo: Bool {
        reason == "display_name_contains_phone" ||
        reason == "display_name_contains_email" ||
        reason == "display_name_contains_url"
    }
}
