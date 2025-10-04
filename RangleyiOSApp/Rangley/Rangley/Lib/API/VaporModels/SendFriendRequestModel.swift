//
//  SendFriendRequestModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/3/25.
//

import SwiftUI

struct SenSendFriendRequestModelBody: Codable, Sendable
{
    let recipient_user_uuid: UUID
}

struct SendFriendRequestModelResponse: Codable, Sendable
{
    let friend_request_id: Int?
    let success: Bool
    let message: String
}
