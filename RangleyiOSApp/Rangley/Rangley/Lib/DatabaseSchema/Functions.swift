//
//  Functions.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/13/25.
//

public struct Functions {
    
    /// must input meetiD
    static let rgl_fx_GetLatestMeetID_ByChangeStamp =
    """
        SELECT MeetID, ChangeStamp
        FROM tbMeets
        WHERE MeetID = ?
        ORDER BY ChangeStamp DESC
        LIMIT 1;
    """
}
