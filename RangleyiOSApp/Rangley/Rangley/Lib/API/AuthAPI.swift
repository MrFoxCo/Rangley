//
//  ApiClient.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/2/25.
//

// AuthAPI.swift

import Foundation

enum AuthAPIError: Error, LocalizedError
{
    case badURL
    case http(Int, String?)
    case decode
    var errorDescription: String? {
        switch self {
        case .badURL: return "Bad URL"
        case .http(let code, let reason): return "HTTP \(code): \(reason ?? "Unknown error")"
        case .decode: return "Decode error"
        }
    }
}

struct AuthAPI
{
    /// baseURL like: https://api.yourdomain.com
    /// ^^ THIS NEEDS TO BE GRABBED FROM ENV
    static func register(baseURL: URL,
                         token: String,
                         payload: AuthRegisterRequest) async throws -> AuthRegisterResult {
        var url = baseURL
        url.append(path: "/i/auth-register")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }

        if (200..<300).contains(http.statusCode) {
            // Vapor procedure returns a row with is_success
            if let res = try? JSONDecoder().decode(AuthRegisterResult.self, from: data) {
                return res
            } else {
                // If your route wraps result (e.g., as array) adapt this decode
                throw AuthAPIError.decode
            }
        } else {
            // Vapor typically returns {"reason":"..."} on error
            let reason = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["reason"] as? String
            throw AuthAPIError.http(http.statusCode, reason)
        }
    }
}
