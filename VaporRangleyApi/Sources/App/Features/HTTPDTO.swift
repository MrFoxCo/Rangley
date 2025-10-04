//
//  HTTPDTO.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 9/12/25.
//

import Vapor

/// HTTPDTO
/// =======
/// A lightweight namespace for **HTTP-layer data transfer objects** (DTOs).
/// These types model the JSON your API **receives** from clients and **returns**
/// to clients. They are intentionally decoupled from database/procedure models.
///
/// Why use `HTTPDTO`?
/// - **Separation of concerns**: HTTP contract stays stable even if DB schema or
///   stored procedures change. Route code translates between HTTPDTO ↔︎ DB params.
/// - **Security**: Client-facing DTOs omit sensitive/server-controlled fields
///   (e.g., `cognito_sub`). The server injects identity from the verified token.
/// - **Versioning**: You can evolve HTTP payloads (add fields, new responses)
///   without touching DB-facing types.
/// - **Testability**: Easier to unit-test route decoding/encoding independently.
///
/// Conventions:
/// - Group DTOs by resource under `HTTPDTO.<Feature>` (e.g., `HTTPDTO.Meets`).
/// - `*Body` types = **request payloads** coming from clients.
/// - `*Response` types = **responses** you return to clients.
/// - DB-facing types live elsewhere (e.g., `Proc.SystemInsertMeet.Params`) and
///   may include fields not exposed to clients (like `cognito_sub`).
enum HTTPDTO
{
    enum Meets
    {
        struct InsertBody: Content, Sendable
        {
            // Required
            let latitude        : Double
            let longitude       : Double
            let region_latitude : Double
            let region_longitude: Double
            let region_radius   : Double
            let name            : String
            let dttm_start_utc  : Date
            let dttm_end_utc    : Date
            // Optional
            let description     : String?
            let meet_category_id: Int16?
            let max_capacity    : Int32?
        }
        

        
        struct InsertUpdatedBody: Content, Sendable
        {
            // Required - must know which meet to update
            let meet_id_uuid    : UUID
            
            // ALL OPTIONAL - only send fields that are changing
            let latitude        : Double?
            let longitude       : Double?
            let region_latitude : Double?
            let region_longitude: Double?
            let region_radius   : Double?
            let meet_status_id  : Int16?
            let name            : String?
            let dttm_start_utc  : Date?
            let dttm_end_utc    : Date?
            let description     : String?
            let change_reason   : String?
            let meet_category_id: Int16?
            let max_capacity    : Int32?
        }
        
        struct InsertDeletedBody: Content, Sendable
        {
            // Required - must know which meet to update
            let meet_id_uuid    : UUID
        }
        
        struct InsertMeetResponse: Content
        {
            let num_inserted: Int32
            let meet_id_uuid: UUID?
            let validation_failed: Bool
            let validation_reason: String?
            let validation_message: String?
        }
        
        struct InsertDeleteResponse: Content, Sendable
        {
            let num_inserted: Int32
        }
        
        struct InsertUpdateResponse: Content
        {
            let num_inserted: Int32
            let validation_failed: Bool
            let validation_reason: String?
            let validation_message: String?
        }
    }
    
    
    enum MeetsWithInvites
    {
        struct InsertMeetBody: Content, Sendable
        {
            // Required
            let initial_invitee_uuids   : [UUID]
            let latitude                : Double
            let longitude               : Double
            let region_latitude         : Double
            let region_longitude        : Double
            let region_radius           : Double
            let name                    : String
            let dttm_start_utc          : Date
            let dttm_end_utc            : Date
            // Optional
            let description             : String?
            let meet_category_id        : Int16?
            let max_capacity            : Int32?
            let invitation_message      : String? 
        }

        struct InsertMeetResponse: Content
        {
            let num_inserted: Int32
            let new_meet_id_uuid: UUID?
            let validation_failed: Bool
            let validation_reason: String?
            let validation_message: String?
        }
        

        
        struct InsertDeletedBody: Content, Sendable
        {
            // Required - must know which meet to update
            let meet_id_uuid    : UUID
        }
        
        struct InsertDeleteResponse: Content, Sendable
        {
            let num_inserted: Int32
        }
        
        
        struct InsertUpdatedBody: Content, Sendable
        {
            // Required - must know which meet to update
            let meet_id_uuid    : UUID
            
            // ALL OPTIONAL - only send fields that are changing
            let latitude        : Double?
            let longitude       : Double?
            let region_latitude : Double?
            let region_longitude: Double?
            let region_radius   : Double?
            let meet_status_id  : Int16?
            let name            : String?
            let dttm_start_utc  : Date?
            let dttm_end_utc    : Date?
            let description     : String?
            let change_reason   : String?
            let meet_category_id: Int16?
            let max_capacity    : Int32?
        }
        
        struct InsertUpdateResponse: Content, Sendable
        {
            let num_inserted: Int32
        }
        
        struct InsertAdditionalParicipantsBody: Content, Sendable
        {
            // Required
            let meet_id_uuid                    : UUID
            let inviter_user_uuid               : UUID
            let additional_invitee_user_uuids    : [UUID]
            let invitation_message              : String?
        }

        struct InsertAdditionalParicipantsResponse: Content, Sendable
        {
            let user_uuid                   : UUID
            let username                    : String
            let invitation_status           : String?
            let returned_notification_id    : Int64?
        }
        
        
        struct RespondToInviteBody: Content, Sendable
        {
            let meet_id_uuid        : UUID
            let response_status_id  : Int16  // 3=Maybe, 5=Declined, 6=Accepted 8=Left 9 = removed
        }
        
        struct RespondToInviteResponse: Content, Sendable
        {
            let success      : Bool
            let message      : String
            let old_status_id: Int16?
            let new_status_id: Int16?
            // Intentionally omitting participant_id_out since client doesn't need it
        }
        // TODO: - ADD SHIT HERE FOR RESPOND TO MEET INVITES
    }
    
    enum UpdateParticipantStatus
    {
        
        struct UpdateParticipantStatusBody: Content, Sendable
        {
            let meet_id_uuid        : UUID
            let target_user_uuid    : UUID
            let new_status_id       : Int16  // 4=invited, 5=Declined, 6=Accepted, 7 = owner, 8=Left, 9 = removed
        }
        
        struct UpdateParticipantStatusResponse: Content, Sendable
        {
            let success             : Bool
            let message             : String
            let participant_id_out  : Int64?
            let old_status_id       : Int16?
            let new_status_id       : Int16?
            // Intentionally omitting participant_id_out since client doesn't need it
        }
        // TODO: - ADD SHIT HERE FOR RESPOND TO MEET INVITES
    }
    
    enum Notifications
    {
        // No SearchBody needed - just getting user's inbox
        
        struct SearchItem: Content, Sendable  // Keep this name for consistency
        {
            let notification_id                 : Int64
            let notification_type_id            : Int16
            let notification_name               : String
            let participant_status_id           : Int16
            let meet_id_uuid                    : UUID
            let creator_display_name            : String?
            let payload_json                    : Data?
            let dttm_notification_created_utc   : Date
            let dttm_received_utc               : Date
            let dttm_opened_utc                 : Date?
            let is_read                         : Bool
        }

        struct SearchResponse: Content, Sendable  // Keep this name for consistency
        {
            let results: [SearchItem]
        }
    }
    
    
    enum Users
    {
        // Client request payload (server reads cognito_sub from auth, not from body)
        struct SearchBody: Content, Sendable
        {
            let usernames: [String]?  // optional
            let emails:    [String]?  // optional
            let phones:    [String]?  // optional
        }

        struct SearchItem: Content, Sendable
        {
            let user_uuid       : UUID
            let username        : String
            let display_name    : String
            let matched_by      : [String]
            let can_invite      : Bool
        }

        struct SearchResponse: Content, Sendable
        {
            let results: [SearchItem]
        }
        
        struct ProfileBody: Content, Sendable
        {
            let user_uuid: UUID
        }

        struct ProfileResponse: Content, Sendable
        {
            let user_uuid                : UUID
            let username                 : String
            let display_name             : String
            let member_since             : Date
            let meets_created            : Int
            let meets_attended           : Int
            let friend_count             : Int
            let discoverable_by_username : Bool
            let discoverable_by_phone    : Bool
            let discoverable_by_email    : Bool
            let show_full_name           : Bool
            let allow_invites_from_anyone: Bool
        }
        
    }
}
