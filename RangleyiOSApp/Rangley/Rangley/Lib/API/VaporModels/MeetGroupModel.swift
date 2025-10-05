//
//  MeetGroupModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/4/25.
//

import Foundation

struct InsertGroupBody: Codable, Sendable
{
    let group_name: String
    let image_reference: String?  // Optional, defaults to 'person.3.fill' in PostgreSQL
}

struct InsertGroupResponse: Codable, Sendable
{
    let success: Bool
    let message: String
    let meet_group_id: Int64?
}

// NEW DTO: For adding members directly (not inviting)
struct InsertMembersBody: Codable, Sendable
{
    let meet_group_id: Int64
    let user_uuids: [UUID]
}

struct InsertMembersResponse: Codable, Sendable
{
    let success: Bool
    let message: String
    let added_count: Int32
    let skipped_count: Int32
}

struct InviteMembersBody: Codable, Sendable
{
    let meet_group_id: Int64
    let user_uuids: [UUID]
}

struct InviteMembersResponse: Codable, Sendable
{
    let success: Bool
    let message: String
    let invited_count: Int32
    let skipped_count: Int32
}

struct RespondInvitationBody: Codable, Sendable
{
    let invitation_id: Int64
    let accept: Bool
}

struct RespondInvitationResponse: Codable, Sendable
{
    let success: Bool
    let message: String
}

struct RemoveMembersBody: Codable, Sendable
{
    let meet_group_id: Int64
    let user_uuids: [UUID]
}

struct RemoveMembersResponse: Codable, Sendable
{
    let success: Bool
    let message: String
    let removed_count: Int32
}

struct DeleteGroupBody: Codable, Sendable
{
    let meet_group_id: Int64
}

struct DeleteGroupResponse: Codable, Sendable
{
    let success: Bool
    let message: String
}

struct MeetGroup: Codable, Sendable
{
    let meet_group_id: Int64
    let name: String
    let image_type: String
    let image_reference: String
    let image_url: String?
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
    let is_owner: Bool
}

struct ViewMembersBody: Codable, Sendable
{
    let meet_group_id: Int64
}

struct ModifyImageBody: Codable, Sendable
{
    let meet_group_id: Int64
    let image_reference: String
}

struct ModifyImageResponse: Codable, Sendable
{
    let success: Bool
    let message: String
}

struct LeaveMeetGroupBody: Codable, Sendable
{
    let meet_group_id: Int64
}

struct LeaveMeetGroupResponse: Codable, Sendable
{
    let success: Bool
    let message: String
}
