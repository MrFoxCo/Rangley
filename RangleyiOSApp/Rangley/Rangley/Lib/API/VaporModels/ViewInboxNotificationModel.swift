//
//  InboxNotificationModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/3/25.
//

import SwiftUI




struct InboxNotificationModelResponse: Codable, Sendable
{
    let notifications: [InboxNotificationModelBody]
}

struct InboxNotificationModelBody: Codable, Sendable
{
    let notification_id         : Int64
    let notification_type_id    : Int16
    let notification_type       : String
    let meet_id_uuid            : UUID?
    let created_by_user_uuid    : UUID
    let created_by_username     : String
    let created_by_display_name : String
    let payload_json            : String
    let dttm_created_utc        : Date
    let dttm_received_utc       : Date
    let dttm_opened_utc         : Date?
    let is_read                 : Bool
    
    // MARK: - Payload Accessors
    
    /// Decode into a typed payload
    func payload<T: Decodable>(_ type: T.Type = T.self) -> T? {
        guard let data = Self.normalizeToUTF8JSONData(payload_json) else { return nil }
        return try? Self.jsonDecoder.decode(T.self, from: data)
    }

    /// Decode into `Any` for generic access
    func payloadAny() -> Any? {
        guard let data = Self.normalizeToUTF8JSONData(payload_json) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
    
    /// Convenience accessor for friend_request_id
    var friendRequestId: Int64? {
        guard let dict = payloadAny() as? [String: Any] else { return nil }
        return dict["friend_request_id"] as? Int64
    }
    
    /// Convenience accessor for meet group invitation_id
    var meetGroupInvitationId: Int64? {
        guard let dict = payloadAny() as? [String: Any] else { return nil }
        return dict["invitation_id"] as? Int64
    }
}

struct ClearInboxResponse: Codable, Sendable
{
    let success      : Bool
    let message      : String
    let cleared_count: Int32
}


struct DeleteNotificationBody: Codable, Sendable
{
    let notification_id: Int64
}

struct DeleteNotificationResponse: Codable, Sendable
{
    let success: Bool
    let message: String
}

struct FriendRequestPayload: Codable {
    let friend_request_id: Int64
    // TODO: ?? Add any other fields backend includes
}

// MARK: - Private helpers (keep the leniency, but simplified now that server sends JSON text)
private extension InboxNotificationModelBody
{
    static var jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            if let s = try? c.decode(String.self) {
                let f1 = ISO8601DateFormatter(); f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let dt = f1.date(from: s) { return dt }
                let f2 = ISO8601DateFormatter(); f2.formatOptions = [.withInternetDateTime]
                if let dt = f2.date(from: s) { return dt }
                if let secs = Double(s) { return Date(timeIntervalSince1970: secs) }
                throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "Bad date: \(s)"))
            }
            if let secs = try? c.decode(Double.self) { return Date(timeIntervalSince1970: secs) }
            throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "Date not string/number"))
        }
        return d
    }()

    /// Accepts raw DB output (JSON text; tolerate double-quoting/base64 leftovers)
    static func normalizeToUTF8JSONData(_ raw: String) -> Data? {
        // 1) If it’s valid JSON text already, use it.
        if let d = raw.data(using: .utf8), JSONSerialization.isValidJSONObjectSafe(d) { return d }

        // 2) If the JSON text was double-quoted, unquote once and retry.
        if raw.first == "\"", raw.last == "\"",
           let unq = Self.parseJSONString(raw),
           let d2 = unq.data(using: .utf8),
           JSONSerialization.isValidJSONObjectSafe(d2) {
            return d2
        }

        // 3) Try base64 decode (legacy), then parse as JSON or JSON-in-a-string.
        if let b64 = Data(base64Encoded: raw, options: [.ignoreUnknownCharacters]) {
            if JSONSerialization.isValidJSONObjectSafe(b64) { return b64 }
            if let str = String(data: b64, encoding: .utf8),
               let d3 = str.data(using: .utf8),
               JSONSerialization.isValidJSONObjectSafe(d3) {
                return d3
            }
        }

        // Fallback: best-effort utf8 (lets typed decode try anyway)
        return raw.data(using: .utf8)
    }

    static func parseJSONString(_ s: String) -> String? {
        guard let d = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(String.self, from: d)
    }
}

private extension JSONSerialization
{
    /// “Safe” check that doesn’t require the *top-level* to be object/array first;
    /// we attempt decode and accept fragments via `.fragmentsAllowed`.
    static func isValidJSONObjectSafe(_ data: Data) -> Bool {
        (try? jsonObject(with: data, options: [.fragmentsAllowed])) != nil
    }
}
