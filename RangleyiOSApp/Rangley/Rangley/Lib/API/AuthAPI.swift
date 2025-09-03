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

import Foundation

struct AuthAPI {
    static func register(baseURL: URL,token: String,payload: UserRegisterModel) async throws -> UserRegisterResult
    {
        var url = baseURL
        url.append(path: "/i/user")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw AuthAPIError.http(-1, "No HTTPURLResponse")
        }

        if (200..<300).contains(http.statusCode) {
            return try JSONDecoder().decode(UserRegisterResult.self, from: data)
        } else {
            let reason = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["reason"] as? String
            throw AuthAPIError.http(http.statusCode, reason)
        }
    }
}

