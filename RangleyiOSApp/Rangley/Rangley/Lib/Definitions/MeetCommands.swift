//
//  MeetCommands.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/12/25.
//

// MeetCommands.swift
enum MeetCommands {
    @discardableResult
    static func delete(meetCardData: MeetCardData, db: OpaquePointer?) -> (Bool, Error?) {
        let batch = ModifyMeetBatch(MeetCardData: meetCardData, MeetStatusId: .Deleted, ChangeReason: nil)
        return DbRangle.tryProcDeleteMeet(db, modifyMeetBatch: batch)
    }
}
