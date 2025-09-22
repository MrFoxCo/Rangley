//
//  ViewNotificationsModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/22/25.
//

import Foundation

struct ViewNotificationsModel: Codable, Identifiable, Sendable
{
    let notification_id: Int64
    let notification_type_id: Int16
    let notification_name: String
    let meet_id_uuid: UUID
    let creator_display_name: String?  // Can be NULL from LEFT JOIN
    let payload_json: String?  // Store as JSON string (more compatible than Data for Codable)
    let dttm_notification_created_utc: Date
    let dttm_received_utc: Date
    let dttm_opened_utc: Date?  // Can be NULL (unread notifications)
    let is_read: Bool
    
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

extension ViewNotificationsModel: Equatable {
    public static func == (lhs: ViewNotificationsModel, rhs: ViewNotificationsModel) -> Bool {
        lhs.id == rhs.id
    }
}
