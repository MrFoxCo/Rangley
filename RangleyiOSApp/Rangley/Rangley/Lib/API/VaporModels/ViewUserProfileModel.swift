//
//  ViewUserProfileModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/3/25.
//

import SwiftUI

struct ViewUserProfileModelBody: Codable, Sendable
{
    let user_uuid: UUID
}

struct ViewUserProfileModelResponse: Codable, Sendable
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
