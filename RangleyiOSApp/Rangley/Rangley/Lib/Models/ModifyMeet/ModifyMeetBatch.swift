//
//  EditMeetBatch.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/12/25.
//

// TODO: This will be the flags for updating the meet
//[Flags]
//enum MeetDetails {
//    case
//    
//}

public struct ModifyMeetBatch {
    // MARK: - Members
    // MARK: - END Members
    
    // MARK: - Constructors
    // MARK: - END Constructors
    
    // MARK: - Properties
    
    public var MeetCardData  : MeetCardData?      // keep optional if you want, but see note below
    public var MeetStatusId : MeetStatusId = .Deleted
    public var ChangeReason : String?
    
    // MARK: - END Properties
}
