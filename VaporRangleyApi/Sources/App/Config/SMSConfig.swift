//
//  SMSConfig.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 9/25/25.
//

import Vapor

public struct SMSConfig: Sendable {
    public let region: String                     // e.g. "us-east-2"
    public let originationIdentity: String        // pool-xxx, pool ARN, phone-number ARN, or SenderId
    public let configurationSetName: String?      // optional
    public let defaultMessageType: String         // "TRANSACTIONAL" or "PROMOTIONAL"

    public init(
        region: String,
        originationIdentity: String,
        configurationSetName: String? = nil,
        defaultMessageType: String = "TRANSACTIONAL"
    ) {
        self.region = region
        self.originationIdentity = originationIdentity
        self.configurationSetName = configurationSetName
        self.defaultMessageType = defaultMessageType
    }
}

extension Application {
    private struct SMSConfigKey: StorageKey { typealias Value = SMSConfig }
    public var sms: SMSConfig {
        get {
            guard let c = storage[SMSConfigKey.self] else {
                fatalError("SMSConfig not set. Did you configure SMS in configure(_:)?")
            }
            return c
        }
        set { storage[SMSConfigKey.self] = newValue }
    }
}
