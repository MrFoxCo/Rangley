//
//  AuthAPI.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/2/25.
//

import Foundation

enum AuthAPIError: Error, LocalizedError {
    case http(Int, String?)
    case decode
    var errorDescription: String? {
        switch self {
        case .http(let c, let r): return "HTTP \(c): \(r ?? "Unknown error")"
        case .decode:            return "Decode error"
        }
    }
}

struct AuthAPI {
    // POST /i/auth-register  (protected; Bearer ID token)
    static func register(baseURL: URL, token: String, payload: UserRegisterModel) async throws -> UserRegisterResult {
        var req = URLRequest(url: baseURL.appendingPathComponent("/i/auth-register"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else { throw AuthAPIError.http(http.statusCode, extractReason(from: data)) }

        // Some handlers may return 204/empty on success.
        if data.isEmpty { return UserRegisterResult(is_success: true) }

        do { return try JSONDecoder().decode(UserRegisterResult.self, from: data) }
        catch { throw AuthAPIError.decode }
    }

    // GET /auth/whoami  (protected; Bearer ID token)
    static func whoAmI(baseURL: URL, token: String) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("/auth/whoami"))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else { throw AuthAPIError.http(http.statusCode, extractReason(from: data)) }

        if let json = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
           let s = String(data: pretty, encoding: .utf8) { return s }
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - helpers
    private static func extractReason(from data: Data) -> String? {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return (obj["reason"] as? String) ?? (obj["message"] as? String) ?? (obj["error"] as? String)
        }
        return String(data: data, encoding: .utf8)
    }
}
