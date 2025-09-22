// ViewNotificationsModel.swift

import Foundation

struct ViewNotificationsModel: Codable, Identifiable, Sendable {
    let notification_id                 : Int64
    let notification_type_id            : Int16
    let notification_name               : String
    let participant_status_id           : Int16
    let meet_id_uuid                    : UUID
    let creator_display_name            : String?
    let payload_json                    : String?   // now JSON text from server
    let dttm_notification_created_utc   : Date
    let dttm_received_utc               : Date
    let dttm_opened_utc                 : Date?
    let is_read                         : Bool

    public var id: Int64 { notification_id }
}

// MARK: - Public, UI-friendly API (call these from views)
extension ViewNotificationsModel {
    /// Decode into a typed payload (e.g., InvitationPayload.self).
    func payload<T: Decodable>(_ type: T.Type = T.self) -> T? {
        guard let raw = payload_json, let data = Self.normalizeToUTF8JSONData(raw) else { return nil }
        return try? Self.jsonDecoder.decode(T.self, from: data)
    }

    /// Decode into `Any` for generic key/value rendering.
    func payloadAny() -> Any? {
        guard let raw = payload_json, let data = Self.normalizeToUTF8JSONData(raw) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    /// Pretty printed JSON for a “Show raw JSON” panel.
    func payloadPretty() -> String? {
        guard let any = payloadAny(),
              JSONSerialization.isValidJSONObject(any),
              let d = try? JSONSerialization.data(withJSONObject: any, options: [.prettyPrinted, .sortedKeys])
        else { return nil }
        return String(data: d, encoding: .utf8)
    }
}

// MARK: - Private helpers (keep the leniency, but simplified now that server sends JSON text)
private extension ViewNotificationsModel {
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

private extension JSONSerialization {
    /// “Safe” check that doesn’t require the *top-level* to be object/array first;
    /// we attempt decode and accept fragments via `.fragmentsAllowed`.
    static func isValidJSONObjectSafe(_ data: Data) -> Bool {
        (try? jsonObject(with: data, options: [.fragmentsAllowed])) != nil
    }
}

// Your server-shape payload (adjust fields to match your jsonb_build_object)
struct InvitationPayload: Codable {
    let meet_end: Date
    let meet_name: String
    let meet_start: Date
    let meet_id_uuid: UUID
    let category_name: String
    let meet_location: Location
    let action_required: String
    let invitation_message: String?
    let invited_by_username: String?
    let invited_by_display_name: String?

    struct Location: Codable { let latitude: Double; let longitude: Double }
}

struct NotificationsResponse: Codable, Sendable {
    let results: [ViewNotificationsModel]
}
