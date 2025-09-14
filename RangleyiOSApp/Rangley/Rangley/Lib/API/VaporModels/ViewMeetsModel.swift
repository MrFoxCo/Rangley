//
//  ViewMeetsModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//


import Foundation

public struct ViewMeetsModel: Codable, Identifiable, Sendable
{
    public let meet_id_uuid         : String
    public let meet_status_id       : Int16
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
    public let created_by_user_uuid : String
    public let display_name         : String
    public let is_owner             : Bool

    public var id: String { meet_id_uuid }
}

