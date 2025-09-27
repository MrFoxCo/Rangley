//
//  AuthAPI.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/2/25.
//

import Foundation

enum AuthAPIError: Error, LocalizedError
{
    case http(Int, String?)
    case decode(String?) // Enhanced to include details
    case encode
    case transport(Error)

    // MARK: LocalizedError
    var errorDescription: String? {
        switch self {
        case .http(let code, let reason):
            return "HTTP \(code): \(reason ?? "Unknown error")"
        case .decode(let details):
            return "Decode error\(details.map { ": \($0)" } ?? "")"
        case .encode:
            return "Encode error"
        case .transport(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        }
    }

    var failureReason: String? {
        switch self {
        case .http(_, let reason): return reason
        case .decode(let details): return details ?? "Response couldn't be decoded."
        case .encode:              return "Request body couldn't be encoded."
        case .transport(let e):    return e.localizedDescription
        }
    }
}

extension AuthAPIError
{
    static func map(_ error: Error) -> AuthAPIError {
        if let e = error as? AuthAPIError { return e }
        return .transport(error)
    }
}

extension AuthAPI
{
    /// GET /v/users — browse all discoverable (no filters). Server should allow no filters here.
    static func browseAllUsers(
        baseURL: URL,token: String,limit: Int? = nil,offset: Int? = nil
    ) async throws -> [ViewUsersModel]
    {
        var url = makeURL(baseURL, ["v", "users"])
        if let limit, let offset {
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            comps.queryItems = [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            url = comps.url!
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("=== Browse Users Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }

        do {
            let wrapper = try isoDecoder.decode(UsersSearchResponse.self, from: data)
            return wrapper.results
        } catch {
            #if DEBUG
            print("=== Decode Error in browseAllUsers ===")
            print("Error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.decode(error.localizedDescription)
        }
    }
}


struct AuthAPI
{
    
    // JSON enc/dec with ISO-8601 dates
    private static var isoEncoder: JSONEncoder
    {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
    
    private static var isoDecoder: JSONDecoder
    {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()

            // 1) Try string → ISO8601 (± fractional seconds) → or numeric seconds in a string
            if let s = try? c.decode(String.self) {
                let f1 = ISO8601DateFormatter()
                f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let dt = f1.date(from: s) { return dt }

                let f2 = ISO8601DateFormatter()
                f2.formatOptions = [.withInternetDateTime]
                if let dt = f2.date(from: s) { return dt }

                if let secs = Double(s) { return Date(timeIntervalSince1970: secs) }
                throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "Unparseable date string: \(s)"))
            }

            // 2) Try numeric epoch seconds
            if let secs = try? c.decode(Double.self) {
                return Date(timeIntervalSince1970: secs)
            }

            throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "Date was neither string nor number"))
        }
        return d
    }

    
    // POST /i/auth-register  (protected; Bearer ID token)
    static func register(baseURL: URL, token: String, payload: UserRegisterModel) async throws -> UserRegisterResult
    {
        var req = URLRequest(url: makeURL(baseURL, ["auth", "register"]))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try isoEncoder.encode(payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("=== Registration Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }

        if data.isEmpty { return UserRegisterResult(is_success: true) }
        do {
            return try isoDecoder.decode(UserRegisterResult.self, from: data)
        } catch {
            #if DEBUG
            print("=== Decode Error in register ===")
            print("Error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.decode(error.localizedDescription)
        }
    }

    // Add these methods to your AuthAPI struct


        
    // MARK: - Phone Verification API
        
    /// POST /auth/send-verification - Send SMS verification code
    static func sendVerificationCode(baseURL: URL, phone: String) async throws -> Void
    {
        let body = SendVerificationRequest(phone: phone)
        
        var req = URLRequest(url: makeURL(baseURL, ["auth", "send-verification"]))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            req.httpBody = try isoEncoder.encode(body)
        } catch {
            throw AuthAPIError.encode
        }
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw AuthAPIError.http(-1, "No HTTPURLResponse")
        }
        
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("=== Send Verification Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        
        // Success - no response body expected for 200 OK
    }
    
    /// POST /auth/verify-phone - Verify SMS code
    static func verifyPhoneCode(baseURL: URL, phone: String, code: String) async throws -> VerifyPhoneResponse
    {
        let body = VerifyPhoneRequest(phone: phone, code: code)
        
        var req = URLRequest(url: makeURL(baseURL, ["auth", "verify-phone"]))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            req.httpBody = try isoEncoder.encode(body)
        } catch {
            throw AuthAPIError.encode
        }
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw AuthAPIError.http(-1, "No HTTPURLResponse")
        }
        
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("=== Verify Phone Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        
        do {
            return try isoDecoder.decode(VerifyPhoneResponse.self, from: data)
        } catch {
            #if DEBUG
            print("=== Decode Error in verifyPhoneCode ===")
            print("Error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.decode(error.localizedDescription)
        }
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
            #if DEBUG
            print("=== WhoAmI Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        
        do {
            return try JSONDecoder().decode(WhoAmI.self, from: data)
        } catch {
            #if DEBUG
            print("=== Decode Error in whoAmI ===")
            print("Error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.decode(error.localizedDescription)
        }
    }

    
    // GET /v/me  (protected; Bearer ID token)
    static func me(baseURL: URL, token: String) async throws -> ViewUserMeModel
    {
        var req = URLRequest(url: makeURL(baseURL, ["v", "me"]))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("=== Me Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        
        do {
            return try isoDecoder.decode(ViewUserMeModel.self, from: data)
        } catch {
            #if DEBUG
            print("=== Decode Error in me ===")
            print("Error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.decode(error.localizedDescription)
        }
    }

    
    // MARK: - Optional debug helper (pretty raw JSON)
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
    
    // THE VERY FIRST MEET corresponds to SystemInsertMeet
    static func createMeet(baseURL: URL, token: String, body: MeetInsertBody) async throws -> MeetInsertResponse
    {
        var req = URLRequest(url: makeURL(baseURL, ["s", "meet"]))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try isoEncoder.encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("=== Meet Creation Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        
        do {
            return try JSONDecoder().decode(MeetInsertResponse.self, from: data)
        } catch {
            #if DEBUG
            print("=== Decode Error in createMeet ===")
            print("Error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.decode(error.localizedDescription)
        }
    }
    
    
    // THE VERY FIRST MEET corresponds to SystemInsertMeet
    static func createMeetWithInvites(baseURL: URL, token: String, body: MeetWithInvitesInsertBody) async throws -> MeetWithInvitesInsertResponse
    {
        var req = URLRequest(url: makeURL(baseURL, ["s", "meet-with-invites"]))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try isoEncoder.encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw AuthAPIError.http(-1, "No HTTPURLResponse")
        }
        
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("=== Meet With Invites Creation Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        
        do {
            return try isoDecoder.decode(MeetWithInvitesInsertResponse.self, from: data)
        } catch {
            #if DEBUG
            print("=== Decode Error in createMeetWithInvites ===")
            print("Error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.decode(error.localizedDescription)
        }
    }
    
    // THE VERY FIRST MEET corresponds to SystemInsertMeet
    static func insertAdditionalParticipantsToMeet(baseURL: URL, token: String, body: InsertAddtionalParticpantsModelBody) async throws -> InsertAddtionalParticpantsModelResponse
    {
        var req = URLRequest(url: makeURL(baseURL, ["s", "insert-additional-participants-to-meet"]))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try isoEncoder.encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw AuthAPIError.http(-1, "No HTTPURLResponse")
        }
        
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("=== Insert New Participants Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        
        do {
            return try isoDecoder.decode(InsertAddtionalParticpantsModelResponse.self, from: data)
        } catch {
            #if DEBUG
            print("=== Decode Error in insertAdditionalParticipantsToMeet ===")
            print("Error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.decode(error.localizedDescription)
        }
    }
    
    
    // Corresponds to SystemInsertUpdatedMeet in VAPOR
    static func updateMeet(baseURL: URL,
                           token: String, body: UpdatedMeetInsertBody) async throws -> UpdatedMeetInsertResponse
    {
        guard body.isCoordinateSetValid else
        {
            throw AuthAPIError.http(400, "Provide all 5 coordinate fields or none")
        }

        var req = URLRequest(url: makeURL(baseURL, ["s", "updated-meet"]))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try isoEncoder.encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("=== Meet Update Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        
        do {
            return try JSONDecoder().decode(UpdatedMeetInsertResponse.self, from: data)
        } catch {
            #if DEBUG
            print("=== Decode Error in updateMeet ===")
            print("Error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.decode(error.localizedDescription)
        }
    }
    
    
    // Corresponds to SystemInsertUpdatedMeet in VAPOR
    static func deleteMeet(baseURL: URL,
                           token: String, body: DeletedMeetInsertBody) async throws -> DeletedMeetInsertResponse
    {
        var req = URLRequest(url: makeURL(baseURL, ["s", "deleted-meet"]))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try isoEncoder.encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("=== Meet Deletion Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        
        do {
            return try JSONDecoder().decode(DeletedMeetInsertResponse.self, from: data)
        } catch {
            #if DEBUG
            print("=== Decode Error in deleteMeet ===")
            print("Error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.decode(error.localizedDescription)
        }
    }
    
    /// GET /v/meets  (protected; Bearer ID token)
    static func viewMeets(baseURL: URL, token: String) async throws -> [ViewMeetsModel]
    {
        var req = URLRequest(url: makeURL(baseURL, ["v", "meets"]))
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("=== View Meets Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        
        do {
            return try isoDecoder.decode([ViewMeetsModel].self, from: data)
        } catch {
            #if DEBUG
            print("=== Decode Error in viewMeets ===")
            print("Error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.decode(error.localizedDescription)
        }
    }
    
    static func viewNotifications(baseURL: URL, token: String) async throws -> [ViewNotificationsModel]
    {
        var req = URLRequest(url: makeURL(baseURL, ["v", "notifications"]))
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("=== View Notifications Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }
        
        do {
            let wrapper = try isoDecoder.decode(NotificationsResponse.self, from: data)
            return wrapper.results
        } catch {
            #if DEBUG
            print("=== Decode Error in viewNotifications ===")
            print("Error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.decode(error.localizedDescription)
        }
    }
 
    // MARK: - Invitations API
    
    static func respondToInvitation(baseURL: URL, token: String, body: RespondToInviteBody) async throws -> RespondToInviteResponse
    {
        var req = URLRequest(url: makeURL(baseURL, ["s", "meets", "invitations", "respond"]))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try isoEncoder.encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
           #if DEBUG
           print("=== Respond to Invitation Failed ===")
           print("Status Code: \(http.statusCode)")
           print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
           #endif
           throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }

        do {
           return try JSONDecoder().decode(RespondToInviteResponse.self, from: data)
        } catch {
           #if DEBUG
           print("=== Decode Error in respondToInvitation ===")
           print("Error: \(error)")
           print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
           #endif
           throw AuthAPIError.decode(error.localizedDescription)
        }
    }
    
    static func updateParticipantStatus(baseURL: URL, token: String, body: UpdateParticipantStatusBody) async throws -> UpdateParticipantStatusResponse
    {
        var req = URLRequest(url: makeURL(baseURL, ["s", "update-participant-status"]))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try isoEncoder.encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
           #if DEBUG
           print("=== Update Participant Status Failed ===")
           print("Status Code: \(http.statusCode)")
           print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
           #endif
           throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }

        do {
           return try JSONDecoder().decode(UpdateParticipantStatusResponse.self, from: data)
        } catch {
           #if DEBUG
           print("=== Decode Error in updateParticipantStatus ===")
           print("Error: \(error)")
           print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
           #endif
           throw AuthAPIError.decode(error.localizedDescription)
        }
    }
    
    // MARK: - DTOs for Users API

    private struct UsersSearchBody: Codable, Sendable
    {
        let usernames: [String]?
        let emails:    [String]?
        let phones:    [String]?
    }

    private struct UsersSearchResponse: Codable, Sendable
    {
        let results: [ViewUsersModel]
    }

    
    /// GET /v/users — filtered search via query (?usernames=a&usernames=b&emails=...)
    /// NOTE: your server 400s if no filters; we pre-check client-side.
    static func viewUsers(
        baseURL: URL,token: String,
        usernames: [String]? = nil,emails: [String]? = nil,phones: [String]? = nil
    ) async throws -> [ViewUsersModel]
    {
        // sanitize
        func clean(_ xs: [String]?) -> [String]? {
            let r = xs?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                       .filter { !$0.isEmpty }
            return (r?.isEmpty == false) ? r : nil
        }
        let cu = clean(usernames), ce = clean(emails), cp = clean(phones)

        let hasFilters = (cu != nil) || (ce != nil) || (cp != nil)
        guard hasFilters else {
            throw AuthAPIError.http(400, "Provide at least one of usernames, emails, or phones.")
        }

        var comps = URLComponents(url: makeURL(baseURL, ["v", "users"]), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = []
        cu?.forEach { items.append(.init(name: "usernames", value: $0)) }
        ce?.forEach { items.append(.init(name: "emails",    value: $0)) }
        cp?.forEach { items.append(.init(name: "phones",    value: $0)) }
        comps.queryItems = items
        let url = comps.url!

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data: Data, resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw AuthAPIError.transport(error)
        }

        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("=== View Users Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }

        do {
            let wrapper = try isoDecoder.decode(UsersSearchResponse.self, from: data)
            return wrapper.results
        } catch {
            #if DEBUG
            print("=== Decode Error in viewUsers ===")
            print("Error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.decode(error.localizedDescription)
        }
    }

    
    /// POST /s/users/search — filtered search with JSON body
    static func searchUsers(
        baseURL: URL,token: String,
        usernames: [String]? = nil, emails: [String]? = nil,phones: [String]? = nil
    ) async throws -> [ViewUsersModel]
    {
        // sanitize
        func clean(_ xs: [String]?) -> [String]? {
            let r = xs?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                       .filter { !$0.isEmpty }
            return (r?.isEmpty == false) ? r : nil
        }
        let body = UsersSearchBody(usernames: clean(usernames), emails: clean(emails), phones: clean(phones))

        var req = URLRequest(url: makeURL(baseURL, ["s", "users", "search"]))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            req.httpBody = try isoEncoder.encode(body)
        } catch {
            throw AuthAPIError.encode
        }

        let data: Data, resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            throw AuthAPIError.transport(error)
        }

        guard let http = resp as? HTTPURLResponse else { throw AuthAPIError.http(-1, "No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            print("=== Search Users Failed ===")
            print("Status Code: \(http.statusCode)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.http(http.statusCode, extractReason(from: data))
        }

        do {
            let wrapper = try isoDecoder.decode(UsersSearchResponse.self, from: data)
            return wrapper.results
        } catch {
            #if DEBUG
            print("=== Decode Error in searchUsers ===")
            print("Error: \(error)")
            print("Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            #endif
            throw AuthAPIError.decode(error.localizedDescription)
        }
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
    private static func makeURL(_ base: URL, _ segments: [String]) -> URL
    {
        segments.reduce(base) { $0.appendingPathComponent($1) }
    }
}
