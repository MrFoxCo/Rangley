//
//  CognitoErrorHandler.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 11/4/25.
//

import Foundation
import Amplify

// MARK: - Cognito Error Types
enum CognitoErrorType: String {
    // Authentication errors
    case incorrectCredentials = "NotAuthorizedException"
    case userNotFound = "UserNotFoundException"
    case userNotConfirmed = "UserNotConfirmedException"
    case passwordAttemptsExceeded = "PasswordAttemptsExceeded"
    case tooManyFailedAttempts = "TooManyFailedAttemptsException"
    
    // Password reset errors
    case invalidVerificationCode = "CodeMismatchException"
    case expiredVerificationCode = "ExpiredCodeException"
    case tooManyRequests = "TooManyRequestsException"
    case limitExceeded = "LimitExceededException"
    case attemptLimitExceeded = "AttemptLimitExceededException" // Same as above but different message
    
    // Rate limiting
    case throttlingException = "ThrottlingException"
    
    // Password policy
    case invalidPassword = "InvalidPasswordException"
    
    // Network
    case networkError = "NetworkError"
    
    // Unknown
    case unknown = "Unknown"
}

// MARK: - User-Friendly Error Messages
struct CognitoError {
    let type: CognitoErrorType
    let userMessage: String
    let retryAfterMinutes: Int?
    let actionRequired: String?
    
    static func from(_ error: Error) -> CognitoError {
        guard let authError = error as? AuthError else {
            return CognitoError(
                type: .unknown,
                userMessage: "Something went wrong. Please try again.",
                retryAfterMinutes: nil,
                actionRequired: nil
            )
        }
        
        // Extract the underlying error code
        let errorCode = extractErrorCode(from: authError)
        let errorMessage = authError.errorDescription.lowercased()
        
        // Check for password attempts exceeded FIRST (most specific)
        if errorMessage.contains("password attempts exceeded") {
            return CognitoError(
                type: .passwordAttemptsExceeded,
                userMessage: "Too many failed login attempts. Your account is temporarily locked.",
                retryAfterMinutes: 60,
                actionRequired: "Wait 1 hour, or reset your password to unlock immediately"
            )
        }
        
        // Check for attempt limit exceeded in password reset
        if errorMessage.contains("attempt limit exceeded") {
            return CognitoError(
                type: .attemptLimitExceeded,
                userMessage: "Too many password reset attempts.",
                retryAfterMinutes: 60,
                actionRequired: "Wait 1 hour before trying again"
            )
        }
        
        // Map by error code
        switch errorCode {
        case "NotAuthorizedException":
            // This could mean wrong password OR wrong username format
            return CognitoError(
                type: .incorrectCredentials,
                userMessage: "Incorrect phone number or password. Make sure to use your phone number (e.g., +13125551234) to sign in.",
                retryAfterMinutes: nil,
                actionRequired: "Double-check your phone number format and password"
            )
            
        case "UserNotFoundException":
            return CognitoError(
                type: .userNotFound,
                userMessage: "No account found with this phone number.",
                retryAfterMinutes: nil,
                actionRequired: "Check your phone number or sign up for a new account"
            )
            
        case "UserNotConfirmedException":
            return CognitoError(
                type: .userNotConfirmed,
                userMessage: "Your account is not confirmed yet.",
                retryAfterMinutes: nil,
                actionRequired: "Check your phone for a verification code"
            )
            
        case "CodeMismatchException":
            return CognitoError(
                type: .invalidVerificationCode,
                userMessage: "Invalid verification code.",
                retryAfterMinutes: nil,
                actionRequired: "Double-check the code and try again"
            )
            
        case "ExpiredCodeException":
            return CognitoError(
                type: .expiredVerificationCode,
                userMessage: "Verification code has expired.",
                retryAfterMinutes: nil,
                actionRequired: "Request a new verification code"
            )
            
        case "TooManyRequestsException":
            return CognitoError(
                type: .tooManyRequests,
                userMessage: "Too many requests. Slow down.",
                retryAfterMinutes: 15,
                actionRequired: "Wait 15 minutes before trying again"
            )
            
        case "LimitExceededException":
            return CognitoError(
                type: .limitExceeded,
                userMessage: "Rate limit exceeded.",
                retryAfterMinutes: 60,
                actionRequired: "Wait 1 hour before trying again"
            )
            
        case "ThrottlingException":
            return CognitoError(
                type: .throttlingException,
                userMessage: "Too many attempts from your location.",
                retryAfterMinutes: 5,
                actionRequired: "Wait 5 minutes before trying again"
            )
            
        case "InvalidPasswordException":
            return CognitoError(
                type: .invalidPassword,
                userMessage: "Password doesn't meet requirements.",
                retryAfterMinutes: nil,
                actionRequired: "Password must be 8+ characters with uppercase, lowercase, number, and special character"
            )
            
        default:
            return CognitoError(
                type: .unknown,
                userMessage: "Something went wrong: \(errorCode)",
                retryAfterMinutes: nil,
                actionRequired: "Try again or contact support if this persists"
            )
        }
    }
    
    // Extract error code from various locations in AuthError
    private static func extractErrorCode(from error: AuthError) -> String {
        if let underlying = error.underlyingError as NSError? {
            // Check __type first (AWS standard)
            if let type = underlying.userInfo["__type"] as? String {
                return type
            }
            // Check code
            if let code = underlying.userInfo["code"] as? String {
                return code
            }
            // Fall back to domain
            return underlying.domain
        }
        
        // Try to extract from error description
        let desc = error.errorDescription
        if desc.contains("NotAuthorizedException") { return "NotAuthorizedException" }
        if desc.contains("UserNotFoundException") { return "UserNotFoundException" }
        if desc.contains("CodeMismatch") { return "CodeMismatchException" }
        if desc.contains("ExpiredCode") { return "ExpiredCodeException" }
        if desc.contains("TooManyRequests") { return "TooManyRequestsException" }
        if desc.contains("LimitExceeded") { return "LimitExceededException" }
        if desc.contains("InvalidPassword") { return "InvalidPasswordException" }
        
        return "Unknown"
    }
}

// MARK: - Convenience Extensions
extension CognitoError {
    /// Full error message with action if available
    var fullMessage: String {
        if let action = actionRequired {
            return "\(userMessage)\n\n\(action)"
        }
        return userMessage
    }
    
    /// Short message for inline display
    var shortMessage: String {
        return userMessage
    }
    
    /// Whether this error requires waiting
    var requiresWait: Bool {
        return retryAfterMinutes != nil
    }
    
    /// Retry date if applicable
    var retryAfter: Date? {
        guard let minutes = retryAfterMinutes else { return nil }
        return Date().addingTimeInterval(TimeInterval(minutes * 60))
    }
    
    /// Is this a rate limit error?
    var isRateLimit: Bool {
        switch type {
        case .passwordAttemptsExceeded, .tooManyRequests, .limitExceeded, .attemptLimitExceeded, .throttlingException, .tooManyFailedAttempts:
            return true
        default:
            return false
        }
    }
    
    /// Should show "reset password" option?
    var shouldOfferPasswordReset: Bool {
        switch type {
        case .incorrectCredentials, .passwordAttemptsExceeded:
            return true
        default:
            return false
        }
    }
}

// MARK: - Logging Helper
extension CognitoError {
    func log(context: String) {
        Log.auth.error("[\(context)] Cognito Error - Type: \(type.rawValue), Message: \(userMessage)")
        if let retry = retryAfterMinutes {
            Log.auth.error("[\(context)] Retry after: \(retry) minutes")
        }
        if let action = actionRequired {
            Log.auth.error("[\(context)] Action required: \(action)")
        }
    }
}
