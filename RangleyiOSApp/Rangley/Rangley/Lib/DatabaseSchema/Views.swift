//
//  TableViews.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/8/25.
//

/**
 What do we need?
 Coordinates, Date, Category, Event Name, Description, MaxCapacity, CreatedBy??
 
 */

public struct Views {
    
    // MARK: - Normal Views

    static let vwMeets =
    """
    CREATE VIEW IF NOT EXISTS vwMeets AS 
    SELECT
         MeetID          
        ,ChangeStamp     
        ,Name            
        ,Description     
        ,ChangeReason    
        ,MeetCategoryID  
        ,MaxCapacity     
        ,DttmStartUtc    
        ,DttmEndUtc      
    FROM tbMeets;
    """
    
    static let vwMeetAddresses =
    """
    CREATE VIEW IF NOT EXISTS vwMeetAddresses AS
    SELECT
         MeetAddressID         
        ,Latitude              
        ,Longitude             
        ,RegionLatitude        
        ,RegionLongitude       
        ,RegionRadius          
        ,Name                  
        ,ThoroughFare          
        ,SubThoroughFare       
        ,SubLocality           
        ,Locality              
        ,SubAdministrativeArea 
        ,AdministrativeArea    
        ,PostalCode            
        ,Country               
        ,IsoCountryCode        
        ,TimeZone              
        ,InlandWater           
        ,Ocean                 
    FROM tbMeetAddresses;
    """
    
    static let vwMeetChangeStamps =
    """
    CREATE VIEW IF NOT EXISTS vwMeetChangeStamps AS -- 
    SELECT
         ChangeStamp      
        ,MeetID           
        ,MeetStatusID     
        ,DttmModifiedUtc  
        ,ModifiedBy_UserID
    FROM tbMeetChangeStamps;
    """
    
    static let vwMeetIDs =
    """
    CREATE VIEW IF NOT EXISTS vwMeetIDs AS
    SELECT
         MeetID           
        ,MeetAddressID    
        ,CreatedBy_UserID 
        ,DttmCreatedUtc   
    FROM tbMeetIDs;
    """
    
    static let vwUsers =
    """
    CREATE VIEW IF NOT EXISTS vwUsers AS
    SELECT
        UserID          
       ,FirstName       
       ,LastName        
       ,CellPhone       
       ,Email           
       ,DttmCreatedUtc  
       ,DttmModifiedUtc 
       ,UID             
    FROM tbUsers;
    """
    
    static let vwNotifications =
    """
    CREATE VIEW IF NOT EXISTS vwNotifications AS
    SELECT
         NotificationID     
        ,NotificationTypeID 
        ,MeetID             
        ,UserID             
        ,DttmSentUtc        
        ,DttmOpenedUtc      
        ,UID                
    FROM tbNotifications;
    """
    static let vwUserInboxes =
    """
    CREATE VIEW IF NOT EXISTS vwUserInboxes AS
    SELECT
         MeetNotificationID 
        ,DttmRecievedUtc    
        ,DttmOpenedUtc      
        ,UID                
    FROM tbUserInboxes;
    """
    
    
    static let vwMeetParticipants =
    """
    CREATE VIEW IF NOT EXISTS vwMeetParticipants AS
    SELECT
         ParticipantID      
        ,MeetID             
        ,UserID             
        ,ParticipantStatusID
        ,DttmJoinedUtc      
        ,DttmLeftUtc        
        ,DttmCreatedUtc     
        ,DttmModifiedUtc    
        ,UID                
    FROM tbMeetParticipants;
    """
    
    static let vwMeetIcon =
    """
        CREATE VIEW IF NOT EXISTS vwMeetIcon AS
        SELECT 
             MeetIconID
            ,Name
            ,FileType
            ,DttmCreatedUtc
        FROM tdMeetIcon;
    """
    
    static let vwNotificationType =
    """
        CREATE VIEW IF NOT EXISTS vwNotificationType AS
        SELECT 
             NotificationTypeID
            ,Name
            ,DttmCreatedUtc
            ,CreatedBy
            ,DttmModifiedUtc
            ,ModifiedBy
        FROM tdNotificationType;
    """
    
    static let vwSubCategory =
    """
        CREATE VIEW IF NOT EXISTS vwSubCategory AS
        SELECT 
             SubCategoryID
            ,MeetCategoryID
            ,Name
            ,CreatedBy
            ,DttmModifiedUtc
            ,ModifiedBy
        FROM tdSubCategory;
    """
    
    static let vwMeetCategory =
    """
        CREATE VIEW IF NOT EXISTS vwMeetCategory AS
        SELECT 
             MeetCategoryID
            ,Name
            ,DttmCreatedUtc
            ,CreatedBy
            ,DttmModifiedUtc
            ,ModifiedBy
        FROM tdMeetCategory;
    """
    
    static let vwFeatures =
    """
        CREATE VIEW IF NOT EXISTS vwFeatures AS
        SELECT FeatureID, Name
        FROM tdFeatures;
    """
    
    static let vwMeetStatus =
    """
        CREATE VIEW IF NOT EXISTS vwMeetStatus AS
        SELECT 
             MeetStatusID
            ,Name
            ,DttmCreatedUtc
        FROM tdMeetStatus;
    """
    
    static let vwParticpantStatus =
    """
        CREATE VIEW IF NOT EXISTS vwParticpantStatus AS
        SELECT 
             ParticipantStatusID
            ,Name
            ,DttmCreatedUtc
        FROM tdParticpantStatus;
    """
    
    static let vwVersionFeatures =
    """
        CREATE VIEW IF NOT EXISTS vwVersionFeatures AS
        SELECT Version, FeatureID
        FROM teVersionFeatures;
    """
    
    // MARK: - END Normal Views
    
    
    
    
    
    
    // MARK: - Sub Views
    
    static let vwLatestMeetVersions =
    """
        CREATE VIEW IF NOT EXISTS vwLatestMeetVersions AS
        WITH latest AS (
          SELECT MeetID, MAX(ChangeStamp) AS ChangeStamp
          FROM vwMeets
          GROUP BY MeetID
        )
        SELECT l.MeetID, l.ChangeStamp
        FROM latest l;
    """

    static let vwMeetCardData =
    """
    CREATE VIEW IF NOT EXISTS vwMeetCardData AS
    SELECT
         m.MeetID
        ,m.ChangeStamp  
        ,COALESCE(mcs.MeetStatusID, 0) AS MeetStatusID -- 0 = no explicit status yet
        ,ma.Latitude
        ,ma.Longitude
        ,m.DttmStartUtc
        ,m.DttmEndUtc
        ,m.Name                 
        ,ma.Name                AS 'AddressName'
        ,mc.Name                AS 'CategoryName'
        ,m.Description
        ,m.MaxCapacity
        ,mi.CreatedBy_UserID
        ,u.FirstName
        ,u.LastName
    FROM vwLatestMeetVersions l
    JOIN vwMeets m
        ON m.MeetID = l.MeetID
        AND m.ChangeStamp = l.ChangeStamp
    LEFT JOIN tbMeetChangeStamps mcs           -- keep brand-new meets
        ON mcs.MeetID = l.MeetID
        AND mcs.ChangeStamp = l.ChangeStamp
    JOIN vwMeetIDs mi
        ON mi.MeetID = l.MeetID
    JOIN vwMeetAddresses ma
        ON ma.MeetAddressID = mi.MeetAddressID
    JOIN vwUsers u
        ON u.UserID = mi.CreatedBy_UserID
    JOIN vwMeetCategory mc
        ON mc.MeetCategoryID = m.MeetCategoryID;
    """
    
    static let vwMeetCategoryIDAndName =
    """
    CREATE VIEW IF NOT EXISTS vwMeetCategoryIDAndName AS
    SELECT MeetCategoryID, Name
    FROM vwMeetCategory;
    """

//    /// Latest non-deleted meet version that hasn’t ended yet.
//    static let vwLatestVisibleMeets =
//    """
//    CREATE VIEW IF NOT EXISTS vwLatestVisibleMeets AS
//    WITH last AS (
//        SELECT MeetID, MAX(ChangeStamp) AS ChangeStamp
//        FROM tbMeets
//        GROUP BY MeetID
//    )
//    SELECT m.*
//    FROM last l
//    JOIN vwMeets m
//      ON m.MeetID = l.MeetID
//     AND m.ChangeStamp = l.ChangeStamp
//    JOIN vwMeetChangeStamps cs
//      ON cs.MeetID = l.MeetID
//     AND cs.ChangeStamp = l.ChangeStamp
//    WHERE cs.MeetStatusID <> 7
//      AND datetime(m.DttmEndUtc) >= datetime('now');
//    """

    
//    static let vwMeetCardData2 =
//    """
//        CREATE VIEW IF NOT EXISTS vwMeetCardData AS
//        WITH latest AS (
//            SELECT MeetID, MAX(ChangeStamp) AS ChangeStamp
//            FROM tbMeets
//            GROUP BY MeetID
//        )
//        SELECT
//             m.MeetID
//            ,m.ChangeStamp              -- real ChangeStamp
//            ,mcs.MeetStatusID
//            ,ma.Latitude
//            ,ma.Longitude
//            ,m.DttmStartUtc
//            ,m.DttmEndUtc
//            ,m.Name
//            ,ma.Name AS 'AddressName'
//            ,mc.Name AS 'CategoryName'
//            ,m.Description
//            ,m.MaxCapacity
//            ,u.UserID
//            ,u.FirstName
//            ,u.LastName
//        FROM latest l
//        JOIN vwMeets m
//          ON m.MeetID = l.MeetID
//         AND m.ChangeStamp = l.ChangeStamp
//        JOIN wMeetChangeStamps mcs
//          ON mcs.MeetID = l.MeetID
//         AND mcs.ChangeStamp = l.ChangeStamp
//        JOIN vwMeetIDs mi
//          ON mi.MeetID = l.MeetID
//        JOIN vwMeetAddresses ma
//          ON ma.MeetAddressID = mi.MeetAddressID
//        JOIN vwUsers u
//          ON u.UserID = mi.CreatedBy_UserID;
//        """
    
//    static let vwMeetCardDataPartitioned =
//    """
//    CREATE VIEW IF NOT EXISTS vwMeetCardDataPartitioned AS
//    WITH versioned AS (
//        SELECT
//             m.MeetID
//            ,mcs.MeetStatusID
//            ,ROW_NUMBER() OVER (
//                PARTITION BY m.MeetID
//                ORDER BY m.ChangeStamp ASC
//            ) AS ChangeStampVersion
//            ,ROW_NUMBER() OVER (
//                PARTITION BY m.MeetID
//                ORDER BY m.ChangeStamp DESC
//            ) AS rn_latest
//            ,ma.Latitude
//            ,ma.Longitude
//            ,m.DttmStartUtc
//            ,m.DttmEndUtc
//            ,m.Name
//            ,m.Description
//            ,m.MaxCapacity
//            ,u.UserID
//            ,u.FirstName
//            ,u.LastName
//        FROM vwMeets m
//        JOIN vwMeetChangeStamps) mcs
//          ON mcs.MeetID = m.MeetID
//         AND mcs.ChangeStamp = m.ChangeStamp
//        JOIN vwMeetIDs mi
//          ON mi.MeetID = m.MeetID
//        JOIN vwMeetAddresses ma
//          ON ma.MeetAddressID = mi.MeetAddressID
//        JOIN vwUsers u
//          ON u.UserID = mi.CreatedBy_UserID
//    )
//    SELECT *
//    FROM versioned
//    WHERE rn_latest = 1;
//    """

//    /// ChangeStamp -> Version mapping for all meets.
//    /// Usage:
//    ///   SELECT Version
//    ///   FROM vwMeetChangeStampVersions
//    ///   WHERE MeetID = ? AND ChangeStamp = ?;
//    static let vwMeetChangeStampsPartitioned =
//    """
//    CREATE VIEW IF NOT EXISTS vwMeetChangeStamps AS
//    SELECT
//         MeetID
//        ,ChangeStamp
//        ,ROW_NUMBER() OVER (
//            PARTITION BY MeetID
//            ORDER BY ChangeStamp ASC
//        ) AS Version
//        ,MeetStatusID
//    FROM vwMeetChangeStamps;
//    """


}


/**
 
 
 SELECT
      m.Name AS "Meet Name"
     ,ma.Thoroughfare
     ,u.FirstName AS "Created By"
 FROM tbMeetIDs mi
 JOIN tbMeets m
     ON m.MeetID = mi.MeetID
 JOIN tbMeetAddresses ma
     ON ma.MeetAddressID = mi.MeetAddressID
 JOIN tbUsers u
     ON u.UserID = mi.CreatedBy_UserID;

 
 */
