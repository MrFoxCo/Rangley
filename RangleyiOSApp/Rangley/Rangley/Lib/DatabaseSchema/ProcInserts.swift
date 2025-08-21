//
//  Inserts.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/9/25.
//

public struct ProcInserts {
    static let rgl_i_Meet =
    """
        INSERT INTO \(Tables.tbMeets)
        (
            MeetID,         ChangeStamp, Name,
            Description,    ChangeReason,
            MeetCategoryID, MaxCapacity,
            DttmStartUtc,   DttmEndUtc
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
    
    """
    static let rgl_i_MeetAddress =
    """
        INSERT INTO \(Tables.tbMeetAddresses)
        (
              Latitude              ,Longitude
             ,RegionLatitude        ,RegionLongitude        ,RegionRadius
             ,Name                  ,ThoroughFare           ,SubThoroughFare
             ,Locality              ,SubLocality
             ,AdministrativeArea    ,SubAdministrativeArea
             ,PostalCode            ,Country                ,IsoCountryCode ,TimeZone
             ,InlandWater           ,Ocean
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """
    static let rgl_i_MeetId =
    """
        INSERT INTO \(Tables.tbMeetIDs)
        (
            MeetAddressID, CreatedBy_UserId
        )
        VALUES (?, ?);
    """
    static let rgl_i_User =
    """
        INSERT INTO \(Tables.tbUsers)
        (
             FirstName
            ,LastName
            ,CellPhone
            ,Email
            ,UUID
        )
        VALUES (?, ?, ?, ?, ?);
    """
    static let rgl_i_MeetChangeStamp =
    """
        INSERT INTO \(Tables.tbMeetChangeStamps)
        (
             MeetID
            ,MeetStatusID
            ,ModifiedBy_UserID
        )
        VALUES (?, ?, ?);
    """
    
    static let rgl_i_DeletedMeet =
    """
        INSERT INTO tbMeets
          (MeetID, ChangeStamp, Name, Description, ChangeReason, MeetCategoryID, MaxCapacity, DttmStartUtc, DttmEndUtc)
        SELECT
           MeetID       ,? -- ChangeStampID     
          ,Name
          ,Description
          ,COALESCE(?, ChangeReason)
          ,MeetCategoryID
          ,MaxCapacity
          ,DttmStartUtc ,DttmEndUtc
        FROM tbMeets
        WHERE MeetID = ?
          AND ChangeStamp = (SELECT MAX(ChangeStamp) FROM tbMeets WHERE MeetID = ?);
    """
    
}
