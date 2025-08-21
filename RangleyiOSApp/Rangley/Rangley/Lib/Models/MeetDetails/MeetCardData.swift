//
//  MeetDisplay.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/9/25.
//

import Foundation
import SQLite3

public struct MeetCardData: Identifiable, Sendable, Codable, Hashable {
    
    // MARK: - Members
    // MARK: - END Members
    
    // MARK: - Constructors

    @inlinable
    public init(
        _ meetId           : Int64,
        _ changeStamp      : Int64,
        _ meetStatusId     : Int64,
        _ coordinate       : Coordinate,
        _ epochRange       : EpochRange,
        _ name             : String,
        _ addressName      : String,
        _ categoryName     : String,
        _ description      : String,
        _ maxCapacity      : Int8,
        _ createByUserId   : Int64,
        _ firstName        : String,
        _ lastName         : String
    ) {
        self.Id                 = UUID() // we never use this just need to make compatible with Indentifiable
        self.MeetId             = meetId
        self.ChangeStamp        = changeStamp
        self.MeetStatusId       = meetStatusId
        self.Coordinate         = coordinate
        self.EpochRange         = epochRange
        self.Name               = name
        self.AddressName        = addressName
        self.CategoryName       = categoryName
        self.Description        = description
        self.MaxCapacity        = maxCapacity
        self.CreatedBy_UserId   = createByUserId
        self.FirstName          = firstName
        self.LastName           = lastName
    }
    
    // MARK: - END Constructors
    
    
    
    // MARK: - Properties
    
    public let Id: UUID
    public var id: UUID { Id }

    public var MeetId       : Int64
    public var ChangeStamp  : Int64
    public var MeetStatusId : Int64
    public var Coordinate  : Coordinate

    
    public var Latitude: Double {
        return Coordinate.latitude
    }
    public var Longitude: Double {
        return Coordinate.longitude
    }
    
    public var EpochRange       : EpochRange
    public var Name             : String
    public var AddressName      : String // (e.g., '1432 W Belmont Ave', 'Wrigley Field')
    public var CategoryName     : String
    public var Description      : String
    public var MaxCapacity      : Int8
    public var CreatedBy_UserId : Int64
    public var FirstName        : String
    public var LastName         : String

    
    // MARK: - END Properties
    

}

private func Address_String(_ address: String?) -> String {
    return address ?? ""
}
