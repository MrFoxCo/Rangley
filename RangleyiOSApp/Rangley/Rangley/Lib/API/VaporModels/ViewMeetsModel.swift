//
//  ViewMeetsModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//


import Foundation
/// they are snake case only because it's what they look like in PGSQL ... we should
/// probably fix that
public struct ViewMeetsModel: Codable, Identifiable, Sendable
{
    public let meet_id_uuid         : UUID
    public let meet_status_id       : Int16
    public let change_stamp         : Int64?
    public let latitude             : Double
    public let longitude            : Double
    public let region_latitude      : Double
    public let region_longitude     : Double
    public let region_radius        : Double
    public let dttm_start_utc       : Date
    public let dttm_end_utc         : Date
    public let name                 : String
    public let category_name        : String
    public let meet_category_id     : Int16 // might not need this?
    public let description          : String
    public let max_capacity         : Int32
    public let created_by_user_uuid : UUID
    public let display_name         : String
    public let is_owner             : Bool
    public let participant_details  : [ParticipantDetail]? // nil for non-owners; [] for owners with none
    public let accepted_count       : Int32

    public var id: UUID { meet_id_uuid }
    
    public var remaining_capacity: Int32 { max(0, max_capacity - accepted_count) }
    public var owner_participants: [ParticipantDetail] { participant_details ?? [] }

}

public struct ParticipantDetail: Codable, Sendable, Equatable
{
    public let user_uuid            : UUID
    public let display_name         : String
    public let participant_status_id: Int16
}

extension ViewMeetsModel: Equatable {
    public static func == (lhs: ViewMeetsModel, rhs: ViewMeetsModel) -> Bool {
        lhs.id == rhs.id
    }
}
