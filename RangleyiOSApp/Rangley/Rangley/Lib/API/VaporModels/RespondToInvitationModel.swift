//  RespondToInviteResponse.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/22/25.
//

import Foundation

// Response from invitation response endpoint
struct RespondToInviteResponse: Codable, Identifiable, Sendable
{
    let meet_id_uuid: UUID
    let response_status_id: Int16
    let is_success: Bool
    let message: String?
    
    public var id: UUID { meet_id_uuid }
}

struct RespondToInviteBody: Codable, Sendable
{
    let meet_id_uuid: UUID
    let response_status_id: Int16
}

extension RespondToInviteResponse: Equatable {
    public static func == (lhs: RespondToInviteResponse, rhs: RespondToInviteResponse) -> Bool {
        lhs.id == rhs.id
    }
}
