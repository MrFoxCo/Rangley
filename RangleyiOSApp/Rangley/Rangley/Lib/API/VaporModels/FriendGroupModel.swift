//
//  FriendGroupModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/4/25.
//

// TODO: NEED A WAY TO REFRESH FRIEND GROUPS FOR NEW INCOMING ONES

import Foundation

struct CreateGroupBody: Codable, Sendable
{
    let group_name: String
}

struct CreateGroupResponse: Codable, Sendable
{
    let success: Bool
    let message: String
    let friend_group_id: Int64?
}

struct AddFriendsBody: Codable, Sendable
{
    let friend_group_id : Int64
    let friend_uuids    : [UUID]
}

struct AddFriendsResponse: Codable, Sendable
{
    let success: Bool
    let message: String
    let added_count: Int32
    let skipped_count: Int32
}

struct DeleteFriendsBody: Codable, Sendable
{
    let friend_group_id: Int64
    let friend_uuids: [UUID]
}

struct DeleteFriendsResponse: Codable, Sendable
{
    let success: Bool
    let message: String
    let removed_count: Int32
}

struct DeleteGroupBody: Codable, Sendable
{
    let friend_group_id: Int64
}

struct DeleteGroupResponse: Codable, Sendable
{
    let success: Bool
    let message: String
}

struct FriendGroup: Codable, Sendable
{
    let friend_group_id: Int64
    let name: String
    let member_count: Int64
    let dttm_created_utc: Date
    let dttm_modified_utc: Date?
}

struct GroupMember: Codable, Sendable
{
    let user_uuid: UUID
    let username: String
    let display_name: String
    let dttm_added_utc: Date
}

struct ViewMembersBody: Codable, Sendable
{
    let friend_group_id: Int64
}

