//
//  BiometricAuth.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/27/25.
//

import LocalAuthentication

enum BiometricAuth {
    enum BiometricType {
        case none
        case touchID
        case faceID
        case opticID
        
        var displayName: String {
            switch self {
            case .none:
                return "None"
            case .touchID:
                return "Touch ID"
            case .faceID:
                return "Face ID"
            case .opticID:
                return "Optic ID"
            }
        }
    }
    
    enum BiometricError: Error, LocalizedError {
        case notAvailable
        case notEnrolled
        case lockout
        case systemCancel
        case userCancel
        case userFallback
        case authenticationFailed
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "Biometric authentication is not available"
            case .notEnrolled:
                return "No biometric credentials are enrolled"
            case .lockout:
                return "Biometric authentication is locked out"
            case .systemCancel:
                return "System canceled authentication"
            case .userCancel:
                return "User canceled authentication"
            case .userFallback:
                return "User selected fallback"
            case .authenticationFailed:
                return "Authentication failed"
            case .unknown(let error):
                return "Unknown error: \(error.localizedDescription)"
            }
        }
    }
    
    /// Check if biometric authentication is available on this device
    static func isAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    /// Get the type of biometric authentication available
        static func availableType() -> BiometricType {
            let context = LAContext()
            var error: NSError?
            
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
                return .none
            }
            
            if #available(iOS 17.0, *) {
                switch context.biometryType {
                case .none:
                    return .none
                case .touchID:
                    return .touchID
                case .faceID:
                    return .faceID
                case .opticID:
                    return .opticID
                default:
                    return .none
                }
            } else {
                switch context.biometryType {
                case .none:
                    return .none
                case .touchID:
                    return .touchID
                case .faceID:
                    return .faceID
                default:
                    return .none
                }
            }
        }
    
    /// Check if device has passcode set
    static func hasPasscode() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
    
    /// Perform biometric authentication
    static func authenticate(
        reason: String,
        fallbackTitle: String? = nil,
        cancelTitle: String? = nil
    ) async throws -> Bool {
        let context = LAContext()
        
        if let fallbackTitle = fallbackTitle {
            context.localizedFallbackTitle = fallbackTitle
        }
        
        if #available(iOS 13.0, *), let cancelTitle = cancelTitle {
            context.localizedCancelTitle = cancelTitle
        }
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return result
        } catch let error as LAError {
            throw mapLAError(error)
        } catch {
            throw BiometricError.unknown(error)
        }
    }
    
    /// Perform device authentication (biometric or passcode fallback)
    static func authenticateWithFallback(
        reason: String,
        fallbackTitle: String? = "Use Passcode",
        cancelTitle: String? = nil
    ) async throws -> Bool {
        let context = LAContext()
        
        if let fallbackTitle = fallbackTitle {
            context.localizedFallbackTitle = fallbackTitle
        }
        
        if #available(iOS 13.0, *), let cancelTitle = cancelTitle {
            context.localizedCancelTitle = cancelTitle
        }
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return result
        } catch let error as LAError {
            throw mapLAError(error)
        } catch {
            throw BiometricError.unknown(error)
        }
    }
    
    // MARK: - Private Helpers
    
    private static func mapLAError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .biometryLockout:
            return .lockout
        case .systemCancel:
            return .systemCancel
        case .userCancel:
            return .userCancel
        case .userFallback:
            return .userFallback
        case .authenticationFailed:
            return .authenticationFailed
        default:
            return .unknown(error)
        }
    }
}

// MARK: - Convenience Extensions

extension BiometricAuth {
    /// Quick check if Face ID specifically is available
    static var isFaceIDAvailable: Bool {
        return availableType() == .faceID
    }
    
    /// Quick check if Touch ID specifically is available
    static var isTouchIDAvailable: Bool {
        return availableType() == .touchID
    }
    
    /// Quick check if Optic ID specifically is available (iOS 17+)
    static var isOpticIDAvailable: Bool {
        return availableType() == .opticID
    }
    
    /// Get a user-friendly description of available biometric type
    static var availableTypeDescription: String {
        return availableType().displayName
    }
}

#if DEBUG
extension BiometricAuth {
    /// Debug helper to print biometric capabilities
    static func debugPrintCapabilities() {
        print("=== Biometric Debug Info ===")
        print("Available: \(isAvailable())")
        print("Type: \(availableType().displayName)")
        print("Has Passcode: \(hasPasscode())")
        print("===========================")
    }
}
#endif
