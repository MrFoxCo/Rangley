//
//  LeaveMeetsModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/4/25.
//

import Foundation

// TODO: - ADD SHIT HERE FOR RESPOND TO MEET INVITES
struct LeaveMeetBody: Codable, Sendable
{
    let meet_id_uuid: UUID
}

struct LeaveMeetResponse: Codable, Sendable
{
    let success: Bool
    let message: String
    let old_status_id: Int16?
}
