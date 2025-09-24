//  RespondToInviteResponse.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/22/25.
//

import Foundation

// Response from invitation response endpoint
struct RespondToInviteResponse: Codable, Sendable {
    let success: Bool
    let message: String
    let old_status_id: Int16?
    let new_status_id: Int16?
}
struct RespondToInviteBody: Codable, Sendable
{
    let meet_id_uuid: UUID
    let response_status_id: Int16
}
