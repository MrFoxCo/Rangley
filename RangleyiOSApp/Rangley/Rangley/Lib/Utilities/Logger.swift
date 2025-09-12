//
//  Logger.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

import os
import Foundation

// Central log channels you can filter on in Console.app
enum Log
{
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.mrfoxco.app"

    // Core channels
    static let app     = Logger(subsystem: subsystem, category: "App")
    static let auth    = Logger(subsystem: subsystem, category: "Auth")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let db      = Logger(subsystem: subsystem, category: "DB")
    static let ui      = Logger(subsystem: subsystem, category: "UI")

    // Optional extras (use if helpful)
    static let amplify = Logger(subsystem: subsystem, category: "Amplify")
    static let media   = Logger(subsystem: subsystem, category: "Media")

    // Signpost helpers for performance tracing
    // Use Console ➜ Action: Enable “Points of Interest”
    static let spAuth    = OSSignposter(logger: auth)
    static let spNetwork = OSSignposter(logger: network)
}

// MARK: - Convenience helpers

extension Logger
{
    /// Logs an error with redacted details (never prints tokens/PII).
    func error(_ message: String, error: Error)
    {
        self.error("\(message, privacy: .public) — \(error.localizedDescription, privacy: .private)")
    }

    /// Debug log for optional string with private redaction.
    func debugPrivate(_ label: String, _ value: String?)
    {
        if let v = value { self.debug("\(label, privacy: .public)=\(v, privacy: .private)") }
        else { self.debug("\(label, privacy: .public)=nil") }
    }

    /// Pretty-print JSON data (size-limited) without leaking huge payloads.
    func prettyJSON(_ data: Data, limit: Int = 16_384)
    {
        guard !data.isEmpty else { self.debug("JSON: <empty>"); return }
        let clipped = data.count > limit ? data.prefix(limit) : data[...]
        if let obj = try? JSONSerialization.jsonObject(with: Data(clipped)),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
           let s = String(data: pretty, encoding: .utf8) {
            self.debug("JSON (\(data.count) B, shown \(clipped.count) B):\n\(s, privacy: .private)")
        } else {
            self.debug("JSON raw (\(data.count) B, shown \(clipped.count) B)")
        }
    }

    /// Time a synchronous block and log its duration (ms).
    @discardableResult
    func time<T>(_ label: StaticString = "duration", _ work: () throws -> T) rethrows -> T
    {
        let start = DispatchTime.now()
        let result = try work()
        let end = DispatchTime.now()
        let ms = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
        self.debug("\(label) \(ms, format: .fixed(precision: 2)) ms")
        return result
    }
}

// MARK: - DEBUG-only shims (no-ops in Release)

#if DEBUG
@inline(__always) func DLOG(_ block: () -> Void) { block() }
#else
@inline(__always) func DLOG(_ block: () -> Void) { /* no-op */ }
#endif
