//
//  MeetCategory.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/13/25.
//
import Foundation

public struct MeetCategory :  Identifiable, Sendable, Codable, Hashable {
    
    // MARK: - Members
    // MARK: - END Members

    // MARK: - Constructors
    
    @inlinable
    public init(MeetCategoryId: Int64, Name: String)
    {
        self.Id = UUID()
        self.MeetCategoryId = MeetCategoryId
        self.Name = Name
    }
    
    // MARK: - END Constructors

    // MARK: - Properties
    public let Id: UUID
    public var id: UUID { Id }
    public var MeetCategoryId   : Int64
    public var Name             : String
    
    // MARK: - END Properties


}
