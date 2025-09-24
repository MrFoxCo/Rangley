//
//  UpdateParticipantStatusModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/24/25.
//

import Foundation

// Response from invitation response endpoint
struct UpdateParticipantStatusResponse: Codable, Sendable
{
    let success             : Bool
    let message             : String
    let participant_id_out  : Int64?
    let old_status_id       : Int16?
    let new_status_id       : Int16?
    // Intentionally omitting participant_id_out since client doesn't need it
}
struct UpdateParticipantStatusBody: Codable, Sendable
{
    let meet_id_uuid        : UUID
    let target_user_uuid    : UUID
    let new_status_id       : Int16  // 4=invited, 5=Declined, 6=Accepted, 7 = owner, 8=Left, 9 = removed
}
