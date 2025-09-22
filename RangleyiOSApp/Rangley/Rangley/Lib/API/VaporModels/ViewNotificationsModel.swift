//
//  ViewNotificationsModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/22/25.
//

import Foundation

struct ViewNotificationsModel: Codable, Identifiable, Sendable
{
    let notification_id                 : Int64
    let notification_type_id            : Int16
    let notification_name               : String
    let participant_status_id           : Int16
    let meet_id_uuid                    : UUID
    let creator_display_name            : String?  // Can be NULL from LEFT JOIN
    let payload_json                    : String?  // Store as JSON string (more compatible than Data for Codable)
    let dttm_notification_created_utc   : Date
    let dttm_received_utc               : Date
    let dttm_opened_utc                 : Date?  // Can be NULL (unread notifications)
    let is_read                         : Bool
    
    public var id: Int64 { notification_id }
    
    // Helper to decode payload_json if needed
    func decodedPayload<T: Codable>(_ type: T.Type) -> T? {
        guard let jsonString = payload_json,
              let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: jsonData)
    }
}

// In ViewNotificationsModel.swift (or your models file)
struct NotificationsResponse: Codable, Sendable {
    let results: [ViewNotificationsModel]
}

extension ViewNotificationsModel {
    /// Decodes `payload_json` into T.
    /// Handles base64 or raw JSON string (even if doubly-quoted).
    func decodePayload<T: Decodable>(as type: T.Type) -> T? {
        guard let raw = payload_json else { return nil }

        // Local lenient decoder (same rules as AuthAPI.isoDecoder)
        func makeDecoder() -> JSONDecoder {
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
                if let secs = try? c.decode(Double.self) {
                    return Date(timeIntervalSince1970: secs)
                }
                throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "Date not string/number"))
            }
            return d
        }
        let dec = makeDecoder()

        // 1) Try base64 → Data → T
        if let b64 = Data(base64Encoded: raw) {
            if let val = try? dec.decode(T.self, from: b64) { return val }

            // Sometimes base64 wraps a JSON string; try decode String → re-decode
            if let jsonString = try? dec.decode(String.self, from: b64),
               let reData = jsonString.data(using: .utf8),
               let val = try? dec.decode(T.self, from: reData) {
                return val
            }
        }

        // 2) Strip one layer of quotes if server double-quoted JSON
        let unwrapped = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        // 3) Try raw utf8 → T
        if let data = unwrapped.data(using: .utf8) {
            if let val = try? dec.decode(T.self, from: data) { return val }

            // As a last resort, maybe it's a JSON string holding JSON
            if let inner = try? dec.decode(String.self, from: data),
               let reData = inner.data(using: .utf8),
               let val = try? dec.decode(T.self, from: reData) {
                return val
            }
        }

        return nil
    }
}


// TODO: - udpate to use Coordinate()
struct InvitationPayload: Codable {
    let meet_id: Int64
    let meet_id_uuid: UUID
    let meet_name: String
    let meet_start: Date
    let meet_end: Date
    let meet_location: Location
    let category_name: String
    let meet_category_id: Int16
    let invited_by_user_id: Int64
    let invitation_message: String?
    let action_required: String
    
    struct Location: Codable
    {
        let latitude: Double
        let longitude: Double
    }
}
