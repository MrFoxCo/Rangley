//
//  MeetBatch.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/8/25.
//

public class MeetBatch{
    // MARK: Members
    // MARK: END Members

    // MARK: Constructors
    public init(User: User) {
        self.User = User
    }
    // MARK: END Constructors

    // MARK: Properties
    
    public var User             : User
    public var Meet             : Meet?
    public var LocationInfo     : LocationInfo?
    public var MeetAddressId    : Int64?
    public var MeetId           : Int64?
    public var MeetStatusID     : Int64 = 0
    
    // MARK: END Properties
    

}
