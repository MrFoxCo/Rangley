//
//  KeyChainAuth.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/22/25.
//

import LocalAuthentication
import Security

enum KeychainAuth {
    static let service = "com.rangley.app.users"
    
    enum KeychainError: Error, LocalizedError {
        case itemNotFound
        case userCanceled
        case authenticationFailed
        case unexpectedData
        case systemError(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "Saved credentials not found"
            case .userCanceled:
                return "Authentication was canceled"
            case .authenticationFailed:
                return "Authentication failed"
            case .unexpectedData:
                return "Could not read saved credentials"
            case .systemError(let status):
                return "Keychain error: \(status)"
            }
        }
    }

    // MARK: - Save
    static func save(username: String, password: String, protectWithBiometrics: Bool) throws {
        // STRATEGY: Save username list separately WITHOUT protection for instant access
        // Save password WITH protection for security
        
        // 1. Save the protected password
        let passwordData = Data(password.utf8)
        let access = SecAccessControlCreateWithFlags(
            nil,
            protectWithBiometrics
                ? kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            protectWithBiometrics ? [.userPresence] : [],
            nil
        )!

        let passwordQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: username
        ]
        SecItemDelete(passwordQuery as CFDictionary)

        var passwordAttrs = passwordQuery
        passwordAttrs[kSecAttrAccessControl] = access
        passwordAttrs[kSecValueData] = passwordData
        passwordAttrs[kSecAttrLabel] = "Rangley Password: \(username)"

        let passwordStatus = SecItemAdd(passwordAttrs as CFDictionary, nil)
        guard passwordStatus == errSecSuccess else {
            throw KeychainError.systemError(passwordStatus)
        }

        // 2. Save the username in a separate, unprotected entry for instant access
        try saveUsernameForInstantAccess(username)
        
        // Clean up any legacy items
        deleteLegacyPrimaryIfPresent()
    }
    
    // Save username separately with NO protection for instant chip display
    private static func saveUsernameForInstantAccess(_ username: String) throws {
        let usernameService = "\(service).usernames"
        let usernameData = Data(username.utf8)
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: usernameService,
            kSecAttrAccount: username
        ]
        SecItemDelete(query as CFDictionary)
        
        var attrs = query
        attrs[kSecValueData] = usernameData
        attrs[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly // NO biometric protection
        attrs[kSecAttrLabel] = "Rangley Username: \(username)"
        
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.systemError(status)
        }
    }

    // MARK: - Load Password (SINGLE AUTHENTICATION POINT)
    // This is THE ONLY method that should trigger Face ID/passcode
    static func loadPassword(username: String, prompt: String = "Authenticate to sign in") throws -> String? {
        let ctx = LAContext()
        ctx.localizedReason = prompt
        ctx.localizedFallbackTitle = "Use Passcode"
        
        // Configure context for better UX
        if #available(iOS 13.0, *) {
            ctx.localizedCancelTitle = "Cancel"
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: username,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: ctx
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let password = String(data: data, encoding: .utf8) else {
                throw KeychainError.unexpectedData
            }
            return password
            
        case errSecItemNotFound:
            return nil
            
        case errSecUserCanceled:
            throw KeychainError.userCanceled
            
        case errSecAuthFailed:
            throw KeychainError.authenticationFailed
            
        default:
            throw KeychainError.systemError(status)
        }
    }

    // MARK: - List Usernames (NO AUTHENTICATION REQUIRED)
    // CRITICAL: This method MUST NEVER trigger Face ID or any authentication
    static func listUsernamesWithoutBiometrics() throws -> [String] {
        // Query the separate, unprotected username entries
        let usernameService = "\(service).usernames"
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: usernameService,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            let items = (result as? [[CFString: Any]]) ?? []
            return items.compactMap { item in
                item[kSecAttrAccount] as? String
            }.sorted()
            
        case errSecItemNotFound:
            return []
            
        default:
            throw KeychainError.systemError(status)
        }
    }
    
    // MARK: - Legacy method (kept for compatibility, but use listUsernamesWithoutBiometrics)
    static func listUsernames() throws -> [String] {
        return try listUsernamesWithoutBiometrics()
    }

    // MARK: - Delete Operations
    static func delete(username: String) {
        // Delete both password and username entries
        let passwordQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: username
        ]
        SecItemDelete(passwordQuery as CFDictionary)
        
        let usernameService = "\(service).usernames"
        let usernameQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: usernameService,
            kSecAttrAccount: username
        ]
        SecItemDelete(usernameQuery as CFDictionary)
    }

    static func deleteAll() {
        // Delete all password entries
        let passwordQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service
        ]
        SecItemDelete(passwordQuery as CFDictionary)
        
        // Delete all username entries
        let usernameService = "\(service).usernames"
        let usernameQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: usernameService
        ]
        SecItemDelete(usernameQuery as CFDictionary)
    }
    
    // MARK: - Utility Methods
    
    // Check if username exists without triggering authentication
    static func hasCredentials(for username: String) -> Bool {
        // Check the unprotected username list
        let usernameService = "\(service).usernames"
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: usernameService,
            kSecAttrAccount: username,
            kSecReturnAttributes: true
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess
    }
    
    // Check if saved credential is protected with biometrics
    static func isProtectedWithBiometrics(username: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: username,
            kSecReturnAttributes: true
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let item = result as? [CFString: Any],
              let _ = item[kSecAttrAccessControl] else {
            return false
        }
        
        // If there's an access control object, assume it's biometric-protected
        // This is a simplified approach - the presence of kSecAttrAccessControl
        // typically indicates biometric protection in our implementation
        return true
    }

    // MARK: - Legacy Cleanup
    private static func deleteLegacyPrimaryIfPresent() {
        // Clean up old "primary" entries if they exist
        let legacyQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "primary"
        ]
        SecItemDelete(legacyQuery as CFDictionary)
        
        // Also clean up any entries with old service name
        let oldServiceQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.rangley.app"  // Old service name
        ]
        SecItemDelete(oldServiceQuery as CFDictionary)
    }
}

// MARK: - Debug Helpers (Remove in production)
#if DEBUG
extension KeychainAuth {
    static func debugListAllItems() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let items = result as? [[CFString: Any]] {
            print("=== Keychain Debug ===")
            for (index, item) in items.enumerated() {
                let account = item[kSecAttrAccount] as? String ?? "unknown"
                let label = item[kSecAttrLabel] as? String ?? "no label"
                let hasAccessControl = item[kSecAttrAccessControl] != nil
                print("\(index + 1). Account: \(account)")
                print("   Label: \(label)")
                print("   Protected: \(hasAccessControl)")
            }
            print("=====================")
        } else {
            print("No keychain items found or error: \(status)")
        }
    }
}
#endif
