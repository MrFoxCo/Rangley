//
//  ViewUsersModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

import SwiftUI

public struct ViewUsersModel: Codable, Identifiable, Hashable, Sendable
{
    public let user_uuid    : UUID
    public let username     : String
    public let display_name : String
    public let matched_by   : [String]
    public let can_invite   : Bool

    public var id: UUID { user_uuid }

    // Convenience flags for UI badges/toggles
    public var matchedByUsername: Bool { matched_by.contains("username") }
    public var matchedByEmail:    Bool { matched_by.contains("email") }
    public var matchedByPhone:    Bool { matched_by.contains("phone") }
}

// If your endpoint returns { "results": [...] }
public struct ViewUsersResponse: Codable, Sendable {
    public let results: [ViewUsersModel]
}
