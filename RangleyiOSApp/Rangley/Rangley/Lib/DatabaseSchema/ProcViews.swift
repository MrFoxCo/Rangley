//
//  StoredProcedures.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/13/25.
//

/// Viewing type stored procedures
public struct ProcViews {

    
    // Simple passthroughs to the actual views (use view NAMES, not the CREATE SQL)
    static let rgl_v_MeetCardData =
    """
    SELECT
         MeetID
        ,ChangeStamp
        ,MeetStatusID
        ,Latitude
        ,Longitude
        ,DttmStartUtc
        ,DttmEndUtc
        ,Name
        ,AddressName
        ,CategoryName
        ,Description
        ,MaxCapacity
        ,CreatedBy_UserID
        ,FirstName
        ,LastName
    FROM vwMeetCardData
    WHERE MeetStatusID <> 7
        AND DttmEndUtc > strftime('%s','now');
    """


    // Renamed to match the fixed view: vwMeetChangeStampVersions
    // Usage when you need a specific mapping:
    //   SELECT Version FROM vwMeetChangeStampVersions WHERE MeetID=? AND ChangeStamp=?;
    static let rgl_v_MeetByChangeStamps_WhereNotDeleted =
    """
    SELECT *
        FROM vwMeetChangeStampVersions
        WHERE MeetStatusID <>7;
    """

    static let rgl_v_MeetCategoryID_ByName =
    """
    SELECT MeetCategoryID
    FROM vwMeetCategoryIDAndName
    WHERE TRIM(Name) = TRIM(?) COLLATE NOCASE;
    """
    static let rgl_v_MeetCategory_ById =
    """
    SELECT MeetCategoryID
    FROM vwMeetCategoryIDAndName
    WHERE MeetCategoryID = ?;
    """
    static let rgl_v_MeetCategoryIDAndName =
    """
    SELECT
        MeetCategoryID, Name
    FROM vwMeetCategoryIDAndName
    WHERE MeetCategoryID <> 0
    ORDER BY Name;
    """

    static let rgl_v_Users_ByUserID =
    """
    SELECT UserID, FirstName, LastName, CellPhone, Email, UID
    FROM vwUsers
    WHERE UserID = ?;
    """

    // Recommended (window functions)
    // Note: join tbMeetChangeStamps on BOTH MeetID and ChangeStamp for correctness.
    static let rgl_v_Meets =
    """
    SELECT m.*
    FROM (
        SELECT  m.*,
                mcs.MeetStatusID,
                ROW_NUMBER() OVER (PARTITION BY m.MeetID ORDER BY m.ChangeStamp DESC) AS rn
        FROM \(Tables.tbMeets) m
        JOIN \(Tables.tbMeetIDs) mi
          ON m.MeetID = mi.MeetID
        JOIN \(Tables.tbMeetChangeStamps) mcs
          ON mcs.MeetID = m.MeetID
         AND mcs.ChangeStamp = m.ChangeStamp
        WHERE m.MeetID <> 0
          AND mcs.MeetStatusID <> 7
          AND datetime(m.DttmEndUtc) >= datetime('now')
    ) ranked
    WHERE rn = 1
    ORDER BY DttmStartUtc;
    """

    // Fallback for older SQLite (no window functions)
    static let rgl_v_Meets_OlderSQLite =
    """
    SELECT m.*
    FROM \(Views.vwMeets) m
    JOIN \(Views.vwMeetIDs) mi
      ON m.MeetID = mi.MeetID
    JOIN \(Views.vwMeetChangeStamps) mcs
      ON mcs.MeetID = m.MeetID
     AND mcs.ChangeStamp = m.ChangeStamp
    WHERE m.MeetID <> 0
      AND mcs.MeetStatusID <> 7
      AND datetime(m.DttmEndUtc) >= datetime('now')
      AND m.ChangeStamp = (
          SELECT MAX(m2.ChangeStamp)
          FROM \(Tables.tbMeets) m2
          WHERE m2.MeetID = m.MeetID
      )
    ORDER BY m.DttmStartUtc;
    """
}
