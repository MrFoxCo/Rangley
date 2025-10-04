//
//  RespondToFriendRequestModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/3/25.
//

import SwiftUI

struct RespondToFriendRequestModelBody: Codable, Sendable
{
    let friend_request_id: Int
    let accept: Bool
}

struct RespondToFriendRequestModelResponse: Codable, Sendable
{
    let success: Bool
    let message: String
}
