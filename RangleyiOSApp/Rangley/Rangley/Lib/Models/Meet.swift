//
//  Destination.swift
//  Freebird
//
//  Created by Anthony Guzzardo on 7/7/25.
//

import Foundation

public struct Meet: Sendable, Codable, Hashable, Identifiable {
    // If you truly don’t track MeetId yet, synthesize one from content for Identifiable.
    public let Id: UUID
    public var id: UUID { Id }

    public let ChangeStamp      : Int?
    public let Name             : String
    public let Description      : String?
    public let ChangeReason     : String?
    public let MeetCategoryId   : Int64?
    public let MaxCapacity      : Int64?
    public let EpochRange       : EpochRange?

    public init(
        ChangeStamp:     Int? = nil,
        Name            : String,
        Description     : String? = nil,
        ChangeReason    : String? = nil,
        MeetCategoryId  : Int64? = nil,
        MaxCapacity     : Int64?,
        EpochRange      : EpochRange
    ) {
        self.Id            = UUID()
        self.ChangeStamp    = ChangeStamp
        self.Name           = Name
        self.Description    = Description
        self.ChangeReason   = ChangeReason
        self.MeetCategoryId = MeetCategoryId
        self.MaxCapacity    = MaxCapacity
        self.EpochRange     = EpochRange
    }
}
