//
//  FriendsModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/4/25.
//

import Foundation

// MARK: - Friendship Status
enum FriendshipStatus: String, Codable, Sendable {
    case none = "none"
    case pendingSent = "pending_sent"
    case pendingReceived = "pending_received"
    case friends = "friends"
}

// MARK: - Get Friendship Status
struct FriendshipStatusResponse: Codable, Sendable {
    let status: FriendshipStatus
    let friend_request_id: Int64?
}

// MARK: - Get Friends List
struct FriendItem: Codable, Sendable, Identifiable {
    let user_uuid: UUID
    let username: String
    let display_name: String
    let friend_since: Date
    
    var id: UUID { user_uuid }
}

// MARK: - Unfriend Response
struct UnfriendResponse: Codable, Sendable {
    let success: Bool
    let message: String
}
