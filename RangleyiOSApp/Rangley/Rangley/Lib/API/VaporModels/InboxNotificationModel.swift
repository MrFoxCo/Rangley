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
