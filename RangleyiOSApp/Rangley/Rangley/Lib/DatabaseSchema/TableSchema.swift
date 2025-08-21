//
//  LookupTableCreation.swift
//  MeetMate
//
//  Created by Anthony Guzzardo on 7/23/25.
//
/**
table prefixes
tb = normal table
te = enum table
td = dictionary table
th = history table

DateTime rules
- ensure you use ISO 8601 Datetimes and "TEXT data for SQL Lite" when writing
- always store in UTC e.g when you use "2025-07-24T23:15:00Z"
- Sql lite has NO want to enforce utc or specific dates thus the writer must
  always use same format.
*/
// MARK: - Table Creation SQL
public struct TableSchema {
    
    static let lookupTables = [
        """
        CREATE TABLE IF NOT EXISTS teVersionFeatures
        (
             Version    INTEGER NOT NULL
            ,FeatureID  INTEGER NOT NULL
            ,PRIMARY KEY(Version, FeatureID)
                
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS tdParticpantStatus
        (
             ParticipantStatusID    INTEGER PRIMARY KEY
            ,Name                   TEXT    NOT NULL UNIQUE
            ,DttmCreatedUtc         INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS tdMeetStatus
        (
             MeetStatusID    INTEGER PRIMARY KEY
            ,Name            TEXT NOT NULL
            ,DttmCreatedUtc  INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS tdFeatures
        (
             FeatureID  INTEGER PRIMARY KEY
            ,Name       TEXT NOT NULL
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS tdMeetCategory
        (
            MeetCategoryID  INTEGER PRIMARY KEY
           ,Name            TEXT NOT NULL UNIQUE
           ,DttmCreatedUtc  INTEGER NOT NULL DEFAULT (strftime('%s','now'))
           ,CreatedBy       TEXT NOT NULL DEFAULT ''
           ,DttmModifiedUtc TEXT NULL
           ,ModifiedBy      TEXT NOT NULL DEFAULT ''
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS tdSubCategory
        (
             SubCategoryID      INTEGER NOT NULL
            ,MeetCategoryID     INTEGER NOT NULL
            ,Name               TEXT NOT NULL DEFAULT ''
            ,CreatedBy          TEXT NOT NULL DEFAULT ''
            ,DttmModifiedUtc    TEXT NULL
            ,ModifiedBy         TEXT NOT NULL DEFAULT ''
        
            ,PRIMARY KEY(SubCategoryID, MeetCategoryID)
        );
        """,
        
        """
        CREATE TABLE IF NOT EXISTS tdNotificationType
        (
             NotificationTypeID INTEGER PRIMARY KEY NOT NULL
            ,Name               TEXT NOT NULL DEFAULT ''--'invitation', 'reminder', 'cancellation' , default ios
            ,DttmCreatedUtc     INTEGER NOT NULL DEFAULT (strftime('%s','now'))
            ,CreatedBy          TEXT NOT NULL DEFAULT ''
            ,DttmModifiedUtc    INTEGER NOT NULL DEFAULT (strftime('%s','now'))
            ,ModifiedBy         TEXT NOT NULL DEFAULT ''
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS tdMeetIcon
        (
             MeetIconID      INTEGER NOT NULL
            ,Name            TEXT    NOT NULL
            ,FileType        TEXT    NOT NULL
            ,DttmCreatedUtc  INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
        """
    ]
    
    static let normalTables = [
        /**
         --Notes:
         -- Always include DttmCreatedUtc (or DttmModifiedUtc) for debugging if nothing else
         -- IS there a way for a user to RSVP? so they would pre-exist in this table?
           Then you could have some report like Rsvp'd, declined, ghosted, will be late but there, cameo, attended, left early, was late, etc (or whatever status)
         -- I would include UID in this table
         */
        """
        CREATE TABLE IF NOT EXISTS tbMeetParticipants
        (
             ParticipantID       INTEGER PRIMARY KEY AUTOINCREMENT
            ,MeetID              INTEGER NOT NULL
            ,UserID              INTEGER NOT NULL
            ,ParticipantStatusID INTEGER NOT NULL
            ,DttmJoinedUtc       INTEGER NOT NULL DEFAULT (strftime('%s','now'))
            ,DttmLeftUtc         INTEGER NULL
            ,DttmCreatedUtc      INTEGER NOT NULL DEFAULT (strftime('%s','now'))
            ,DttmModifiedUtc     INTEGER NULL
            ,UID                 TEXT NOT NULL DEFAULT '' 
            
            ,UNIQUE(MeetID , UserID)
        );
        """,
        //        -- what else belongs herea???
        """
        CREATE TABLE IF NOT EXISTS tbNotifications
        (
             NotificationID     INTEGER PRIMARY KEY AUTOINCREMENT
            ,NotificationTypeID INTEGER NOT NULL
            ,MeetID             INTEGER NULL -- may not be attached to meet (e.g., system message)
            ,UserID             INTEGER NOT NULL
            ,DttmSentUtc        INTEGER NOT NULL DEFAULT (strftime('%s','now'))
            ,DttmOpenedUtc      INTEGER NULL
            ,UID                TEXT NOT NULL DEFAULT ''
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS tbMeets 
        (
             MeetID            INTEGER NOT NULL
            ,ChangeStamp       INTEGER NOT NULL DEFAULT 0  -- See notes below
            ,Name              TEXT    NOT NULL CHECK(length(Name) <= 40)
            ,Description       TEXT    NOT NULL CHECK(length(Description) <= 100)
            ,ChangeReason      TEXT    NOT NULL DEFAULT '' -- if version <> 0 you can have a reason
            ,MeetCategoryID    INTEGER NOT NULL DEFAULT 0
            ,MaxCapacity       INTEGER NOT NULL DEFAULT 2  -- cannot have less than 0
            ,DttmStartUtc      INTEGER NOT NULL DEFAULT (strftime('%s','now')) -- epoch time
            ,DttmEndUtc        INTEGER NOT NULL DEFAULT (strftime('%s','now')) -- epoch time

            ,PRIMARY KEY       (MeetID, ChangeStamp)
        );
        
        -- If you sort upcoming feeds: ORDER BY DttmStartUtc
        CREATE INDEX IF NOT EXISTS idx_meets_dttmstart
          ON tbMeets(DttmStartUtc);

        -- If you often filter by category + time (e.g., “Food starting this week”)
        CREATE INDEX IF NOT EXISTS idx_meets_category_start
          ON tbMeets(MeetCategoryID, DttmStartUtc);
        """,
        /// -- not all meets have physical locations -- worry about this in Version 2
        ///-- RegionID Used for GeoFencing -- when a device enters or exits the boundaries of said location
        ///HOW DO WE Distinguish Primary Keys from tbMeetAddresses and tbMeets
        ///they can't have the same compound primary key for this reason
        ///1. everytime the address changes that genereates a new changestamp... however every time the meet
        ///changes that will not always change the meetaddress. for example the description of the meeting changes
        ///and nothing else
        """
        CREATE TABLE IF NOT EXISTS tbMeetAddresses -- physical addresses
        (   
             MeetAddressID          INTEGER PRIMARY KEY AUTOINCREMENT
            ,Latitude               REAL    NOT NULL DEFAULT 0.0 -- REAL is SQLite floating point type
            ,Longitude              REAL    NOT NULL DEFAULT 0.0
            ,RegionLatitude         REAL    NOT NULL DEFAULT 0.0
            ,RegionLongitude        REAL    NOT NULL DEFAULT 0.0
            ,RegionRadius           REAL    NOT NULL DEFAULT 0.0
            ,Name                   TEXT    NOT NULL DEFAULT ''
            ,ThoroughFare           TEXT    NOT NULL DEFAULT ''
            ,SubThoroughFare        TEXT    NOT NULL DEFAULT ''
            ,SubLocality            TEXT    NOT NULL DEFAULT ''
            ,Locality               TEXT    NOT NULL DEFAULT ''
            ,SubAdministrativeArea  TEXT    NOT NULL DEFAULT ''
            ,AdministrativeArea     TEXT    NOT NULL DEFAULT ''
            ,PostalCode             TEXT    NOT NULL DEFAULT ''
            ,Country                TEXT    NOT NULL DEFAULT ''
            ,IsoCountryCode         TEXT    NOT NULL DEFAULT ''
            ,TimeZone               TEXT    NOT NULL DEFAULT ''
            ,InlandWater            TEXT    NOT NULL DEFAULT ''
            ,Ocean                  TEXT    NOT NULL DEFAULT ''
        );
        
        -- Good for: WHERE Latitude BETWEEN ? AND ? AND Longitude BETWEEN ? AND ?
        CREATE INDEX IF NOT EXISTS idx_meetaddr_lat_long
          ON tbMeetAddresses(Latitude, Longitude);
        """,
        
        ///MeetStatusID only exists in tbMeetChangeStamps because we only document
        ///canceled and postponed. Active and Compeleted we can get by the dates, Full MaxCacpacity and draft by who knows.
        """
        CREATE TABLE IF NOT EXISTS tbMeetChangeStamps -- <-- inser this table to Stamps?
        (
             ChangeStamp       INTEGER PRIMARY KEY AUTOINCREMENT
            ,MeetID            INTEGER NOT NULL
            ,MeetStatusID      INTEGER NOT NULL DEFAULT 0
            ,DttmModifiedUtc   INTEGER NOT NULL DEFAULT (strftime('%s','now'))
            ,DttmModifiedUtc   INTEGER NOT NULL DEFAULT (strftime('%s','now'))
            ,ModifiedBy_UserID INTEGER NOT NULL DEFAULT 0
        );
        
        -- PK(ChangeStamp) already exists. Add these:
        CREATE INDEX IF NOT EXISTS idx_mcs_meetid_changestamp
          ON tbMeetChangeStamps(MeetID, ChangeStamp);

        -- Optional: if you often ask "show recent changes for MeetID X"
        CREATE INDEX IF NOT EXISTS idx_mcs_meetid_modified_desc
          ON tbMeetChangeStamps(MeetID, DttmModifiedUtc DESC);

        -- Optional: if you sometimes filter by status per meet
        CREATE INDEX IF NOT EXISTS idx_mcs_meetid_status
          ON tbMeetChangeStamps(MeetID, MeetStatusID);

        """,
        
        """
        CREATE TABLE IF NOT EXISTS tbMeetIDs  -- <-- insert into this table to create MeetID
        (
             MeetID            INTEGER PRIMARY KEY AUTOINCREMENT
            ,MeetAddressID     INTEGER NOT NULL DEFAULT 0
            ,CreatedBy_UserID  INTEGER NOT NULL DEFAULT 0
            ,DttmCreatedUtc    INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
        
        -- PK(MeetID) already exists.
        CREATE INDEX IF NOT EXISTS idx_meetids_meetaddressid
          ON tbMeetIDs(MeetAddressID);

        CREATE INDEX IF NOT EXISTS idx_meetids_createdby
          ON tbMeetIDs(CreatedBy_UserID);

        """,
        """
        CREATE TABLE IF NOT EXISTS tbUsers
        (
            UserID          INTEGER PRIMARY KEY AUTOINCREMENT
           ,FirstName       TEXT NOT NULL DEFAULT ''
           ,LastName        TEXT NOT NULL DEFAULT ''
           ,CellPhone       TEXT NOT NULL DEFAULT ''
           ,Email           TEXT NOT NULL DEFAULT ''
           ,DttmCreatedUtc  INTEGER NOT NULL DEFAULT (strftime('%s','now'))
           ,DttmModifiedUtc INTEGER NULL
           ,UID             TEXT NOT NULL DEFAULT ''
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS tbUserInboxes
        (   
             MeetNotificationID     INTEGER NOT NULL
            ,DttmRecievedUtc        INTEGER NOT NULL DEFAULT (strftime('%s','now'))
            ,DttmOpenedUtc          TEXT NULL
            ,UID                    TEXT NOT NULL DEFAULT ''
        ); 
        """
    ]
}
/**
 Why?

 Previous + 1 is bad idea:
 - you can end up inserting the same version twice
 - have to trace yourself what verion it is
 - Locks read/write to avoid issue same version being inserted
 - Update version counters or rely on ordering
 MAX + 1 is bad idea:
 - Requires additional SELECT and INSERT logic
 - Requires locking (or a version counter table) to be safe
 - Duplicate versions under concurrent inserts without transactions

 My methodology (which I have used on many databases from SMALL TO HUGE (hundreds of billions of inserts)
 - works on any modern Modern ACID compliant database (when/if you outgrow SqlLite....dont have to rethink)
 - No version maintenance
 - Immutable and audit-friendly
 - No risk of collision
 - no locking required
 - Can recovery from Data gaps (e.g error on insert and increment gaps)
 - You can always recompute Version from scratch by running the ROW_NUMBER() query and it will ALWAYS be the same and you have a full audit log build it. (also useful if you need to recovery)
 - Future proof (I can tell you that as I have done in experience from SqlLite migration to SQL Server/Postgre/Oracle as performance needs require more) - nothing has to change method works without modification.


 Now if you REALLY want versions to go from 0-n PER meeting I have you covered.
 - ChangeStamp is guaranted to be unique and searlized without locking or explicit transactions needed and ROW_NUMBER() just works — no state to manage. So to get the version (if you really want this) you do this

 1. Insert into tbMeetChangeStamps and capture the ID inserted
 2. Call this select statement to get the autoincrementing version

 SELECT tb.rn as Version
 FROM (
   SELECT ChangeStamp, ROW_NUMBER() OVER (PARTITION BY MeetID ORDER BY ChangeStamp) AS rn
   FROM tbMeetChangeStamps where MeetID = <my meet ID>);
 ) tb
 Where tb.ChangeStamp = <the auto id u got from the insert into tbMeetChangeStamps>

 3. Insert the Meeting with this version into the tbMeets table
 
 
 */
