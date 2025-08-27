//
//  config.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 8/27/25.
//
import Vapor

public struct AppConfig : Sendable{
    public let dbHost: String
    public let dbPort: Int
    public let dbName: String
    public let dbUser: String
}

extension Application {
    private struct AppConfigKey: StorageKey { typealias Value = AppConfig }
    public var config: AppConfig {
        get {
            guard let c = storage[AppConfigKey.self] else {
                fatalError("AppConfig not set. Did you call configure(_:)?")
            }
            return c
        }
        set { storage[AppConfigKey.self] = newValue }
    }
}
