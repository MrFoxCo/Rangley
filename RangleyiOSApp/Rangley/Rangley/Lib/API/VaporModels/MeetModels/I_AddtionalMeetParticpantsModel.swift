//
//  InsertAddtionalParticpantsModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/26/25.
//


import SwiftUI
import Foundation

struct InsertAddtionalParticpantsModelBody: Codable
{
    let meet_id_uuid                    : UUID
    let inviter_user_uuid               : UUID
    let additional_invitee_user_uuids    : [UUID]
    let invitation_message               : String?
}

/// USED FOR BOTH
struct InsertAddtionalParticpantsModelResponse: Codable
{
    let user_uuid                   : UUID
    let username                    : String
    let invitation_status           : String?
    let returned_notification_id    : Int64?
}
