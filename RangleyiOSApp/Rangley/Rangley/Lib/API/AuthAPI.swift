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
// JSON encoder with ISO8601 dates (to match Vapor)
private extension AuthAPI {
    static var isoEncoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

struct AuthAPI {
    // POST /i/auth-register  (protected; Bearer ID token)
    static func register(baseURL: URL, token: String, payload: UserRegisterModel) async throws -> UserRegisterResult
    {
        var req = URLRequest(url: baseURL.appendingPathComponent("/auth/register"))
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
    static func whoAmI(baseURL: URL, token: String) async throws -> WhoAmI
    {
        var req = URLRequest(url: makeURL(baseURL, ["auth", "whoami"]))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        do { return try JSONDecoder().decode(WhoAmI.self, from: data) }
        catch { throw AuthAPIError.decode }
    }

    // GET /v/me  (protected; Bearer ID token)
    static func me(baseURL: URL, token: String) async throws -> ViewUserMe
    {
        var req = URLRequest(url: makeURL(baseURL, ["v", "me"]))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        do { return try isoDecoder.decode(ViewUserMe.self, from: data) }
        catch { throw AuthAPIError.decode }
    }

    // MARK: - Optional debug helper (pretty raw JSON)
    // Different name to avoid signature clash with the typed whoAmI above.
    static func whoAmIPrettyRaw(baseURL: URL, token: String) async throws -> String
    {
        var req = URLRequest(url: makeURL(baseURL, ["auth", "whoami"]))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }

        if let obj = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
           let s = String(data: pretty, encoding: .utf8) { return s }
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    static func createMeet(baseURL: URL, token: String, body: MeetInsertBody) async throws -> MeetInsertResponse
    {
        var req = URLRequest(url: makeURL(baseURL, ["s", "meet"]))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try isoEncoder.encode(body)        // ISO-8601 dates

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        do { return try JSONDecoder().decode(MeetInsertResponse.self, from: data) }
        catch { throw AuthAPIError.decode }
    }
    
    /// GET /v/meets  (protected; Bearer ID token)
    static func viewMeets(baseURL: URL, token: String) async throws -> [ViewMeetsModel]
    {
        var req = URLRequest(url: makeURL(baseURL, ["v", "meets"]))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        do { return try isoDecoder.decode([ViewMeetsModel].self, from: data) }
        catch { throw AuthAPIError.decode }
    }


    // MARK: - helpers

    
    
    private static func extractReason(from data: Data) -> String?
    {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return (obj["reason"] as? String) ?? (obj["message"] as? String) ?? (obj["error"] as? String)
        }
        return String(data: data, encoding: .utf8)
    }

    // Build URLs safely without %2F issues
    private static func makeURL(_ base: URL, _ segments: [String]) -> URL {
        segments.reduce(base) { $0.appendingPathComponent($1) }
    }

    // JSON decoder with ISO8601 dates (matches Vapor config)
    private static var isoDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
