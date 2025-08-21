//
//  DbRangle.swift
//  
//
//  Created by Anthony Guzzardo on 7/30/25.
//

import SQLite3
import Foundation

// TODO: why the inlining is helpful??

@inline(__always)
func bindTextNN(_ stmt: OpaquePointer?, _ idx: Int32, _ s: String?) {
    let T = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(stmt, idx, (s ?? ""), -1, T) // "" if nil
}
@inline(__always)
func bindDoubleNN(_ stmt: OpaquePointer?, _ idx: Int32, _ d: Double?) {
    sqlite3_bind_double(stmt, idx, d ?? 0.0)       // 0.0 if nil
}
@inline(__always)
func bindIntNN(_ stmt: OpaquePointer?, _ idx: Int32, _ i: Int?) {
    sqlite3_bind_int(stmt, idx, Int32(i ?? 0))     // 0 if nil
}
@inline(__always)
func bindInt64NN(_ stmt: OpaquePointer?, _ idx: Int32, _ i: Int64?) {
    sqlite3_bind_int64(stmt, idx, i ?? 0)          // 0 if nil
}


/// Handles any database operation for Rangle
public class DbRangle
{
    
    
    // MARK: - "Stored Procedures"
    
    
    /// "Stored Procedure" that inserts meet into tbMeets
    /// - Parameters:
    ///   - db: connects to database
    ///   - meetBatch: contains User class object contains UserID,  Meet class object contains meet details, and LocationInfo class object contains GeoLocation details ** MOST IMPORTANT PARAM **
    /// - Returns: <#Description of the return value, or remove if Void#>
    /// - Throws: <#Description of the error conditions, or remove if not throwing#>
    public static func tryProcInsertMeet(_ db : OpaquePointer?, meetBatch : MeetBatch) -> (Bool, Error?)
    {
        // TODO: REMOVE PRINT STATEMENT
        print("Executing procInsertMeet...")
        
        // MARK: - STEP 1 Insert Address
        /// MeetAddressID needs to be created before MeetID because it is a column inside of tbMeetIDs
        let (meetAddressId , insertAddresError) = tryInsertAddress(db, meetBatch : meetBatch)
        
        if let error = insertAddresError {
            return (false, error)
        }
        
        meetBatch.MeetAddressId = meetAddressId

        // MARK: - STEP 2 Insert MeetID
        
        let (meetId, insertMeetIdError) = tryInsertMeetId(db, meetBatch : meetBatch)
        
        if let error = insertMeetIdError {
            return (false, error)
        }
        
        meetBatch.MeetId = meetId
        
        // MARK: - STEP 3 Insert Meet
        let (_ , insertMeetError) = tryInsertMeet(db, meetBatch : meetBatch)
        
        if let error = insertMeetError {
            return (false, error)
        }
        
        return (true, nil)
    }
    
    /// Procedure inserts changestampID and then inserts row into tbMets with the updated row (MeetID, ChangeStampID)
    /// - Parameters:
    ///   - db: connects to database
    ///   - modifyMeetBatch: contains all necessary objects
    /// - Returns: rerturns bool or error
    /// - Throws: <#Description of the error conditions, or remove if not throwing#>
    public static func tryProcDeleteMeet(_ db: OpaquePointer?, modifyMeetBatch: ModifyMeetBatch) -> (Bool, Error?)
    {
        guard let db = db else {
            return (false, NSError(domain: "SQLite", code: 0,
                                   userInfo: [NSLocalizedDescriptionKey: "Database connection is nil."]))
        }
        guard let meet = modifyMeetBatch.MeetCardData else {
            return (false, NSError(domain: "DeleteMeet", code: 1,
                                   userInfo: [NSLocalizedDescriptionKey: "MeetDisplay is nil."]))
        }

        // BEGIN TRANSACTION
        if sqlite3_exec(db, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil) != SQLITE_OK {
            let err = String(cString: sqlite3_errmsg(db))
            return (false, NSError(domain: "SQLite", code: 2,
                                   userInfo: [NSLocalizedDescriptionKey: "BEGIN failed: \(err)"]))
        }

        // 1) Insert ChangeStamp with Deleted status
        var batch = modifyMeetBatch
        batch.MeetStatusId = .Deleted

        let (changeStampIdOpt, csErr) = tryInsertChangeStamp(db, batch)
        if let csErr {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return (false, csErr)
        }
        guard let changeStampId = changeStampIdOpt else {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return (false, NSError(domain: "DeleteMeet", code: 3,
                                   userInfo: [NSLocalizedDescriptionKey: "Missing ChangeStamp id from tryInsertChangeStamp."]))
        }

        // 2) Clone latest tbMeets row with the NEW ChangeStamp
        let sql = ProcInserts.rgl_i_DeletedMeet  // INSERT … SELECT (MeetID, ChangeStamp, Name, …)
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            let err = String(cString: sqlite3_errmsg(db))
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return (false, NSError(domain: "SQLite", code: 4,
                                   userInfo: [NSLocalizedDescriptionKey: "prepare INSERT…SELECT failed: \(err)"]))
        }

        // Bind: new ChangeStamp, optional reason, meetId, meetId   (using your helpers)
        bindInt64NN(stmt, 1, changeStampId)                         // :1  ChangeStamp
        bindTextNN( stmt, 2, batch.ChangeReason ?? "Deleted")      // :2  ChangeReason (override or keep)
        bindInt64NN(stmt, 3, Int64(meet.MeetId))                    // :3  MeetID
        bindInt64NN(stmt, 4, Int64(meet.MeetId))                    // :4  MeetID again in subquery

        if sqlite3_step(stmt) != SQLITE_DONE {
            let err = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(stmt)
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return (false, NSError(domain: "SQLite", code: 5,
                                   userInfo: [NSLocalizedDescriptionKey: "INSERT…SELECT step failed: \(err)"]))
        }
        sqlite3_finalize(stmt)

        // Ensure one row inserted (SELECT matched)
        if sqlite3_changes(db) == 0 {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return (false, NSError(domain: "DeleteMeet", code: 6,
                                   userInfo: [NSLocalizedDescriptionKey: "No prior version to clone for MeetID \(meet.MeetId)."]))
        }

        // COMMIT
        if sqlite3_exec(db, "COMMIT;", nil, nil, nil) != SQLITE_OK {
            let err = String(cString: sqlite3_errmsg(db))
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            return (false, NSError(domain: "SQLite", code: 7,
                                   userInfo: [NSLocalizedDescriptionKey: "COMMIT failed: \(err)"]))
        }

        return (true, nil)
    }


    // MARK: - END "Stored Procedures"
    
    
    
    
    // MARK: - Insert Functions
    
    /// Inserts GeoLocation information into the database, including GeoFencing and general address information.
    /// - Parameters:
    ///   - db: Reference to the database.
    ///   - locationInfo: Object that stores pertinent address information. See `LocationInfo` for more details.
    public static func tryInsertAddress(_ db: OpaquePointer?, meetBatch: MeetBatch) -> (Int64?, Error?)
    {
        guard let db, let info = meetBatch.LocationInfo else { return (nil, nil) }

        let sql = ProcInserts.rgl_i_MeetAddress
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db)); return (nil, NSError(domain: "SQLite", code: 2, userInfo: [NSLocalizedDescriptionKey: err]))
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, info.Coordinate.latitude)
        sqlite3_bind_double(stmt, 2, info.Coordinate.longitude)
        bindDoubleNN(stmt, 3, info.RegionCoordinate?.latitude)
        bindDoubleNN(stmt, 4, info.RegionCoordinate?.longitude)
        bindDoubleNN(stmt, 5, info.RegionRadius)

        bindTextNN(stmt,  6, info.Name)
        bindTextNN(stmt,  7, info.ThoroughFare)
        bindTextNN(stmt,  8, info.SubThoroughFare)
        bindTextNN(stmt,  9, info.Locality)
        bindTextNN(stmt, 10, info.SubLocality)
        bindTextNN(stmt, 11, info.AdministrativeArea)
        bindTextNN(stmt, 12, info.SubAdministrativeArea)
        bindTextNN(stmt, 13, info.PostalCode)
        bindTextNN(stmt, 14, info.Country)
        bindTextNN(stmt, 15, info.IsoCountryCode)
        bindTextNN(stmt, 16, info.TimeZone)
        bindTextNN(stmt, 17, info.InlandWater) // "" if nil → respects NOT NULL
        bindTextNN(stmt, 18, info.Ocean)

        if sqlite3_step(stmt) == SQLITE_DONE { return (sqlite3_last_insert_rowid(db), nil) }
        let err = String(cString: sqlite3_errmsg(db)); return (nil, NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: err]))
    }


    
    // TODO: figure out better ID input
    
    /// Inserts ID into database for a new meet or a modified one.
    /// - Parameters:
    ///   - db: reference to databse
    ///   - meetBatch: contains User class object contains user specific properties and MeetAddressID to insert into tbMeetIds
    /// - Returns: returns ID value inserted into tbMeetIds. Primary key needed in tbMeets
    /// - Throws: todo: decscribe what the error is
    public static func tryInsertMeetId(_ db: OpaquePointer?, meetBatch : MeetBatch) -> (Int64?, Error?)
    {
        
        let user = meetBatch.User
        
        guard let meetAddressId = meetBatch.MeetAddressId else {
            return (nil, NSError(
                domain: "MeetInsertError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "MeetAddressId null or invalid"]
            ))
        }
        
        let sql = ProcInserts.rgl_i_MeetId
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            
            sqlite3_bind_int64(statement, 1, meetAddressId)
            print("this is the meet id  [\(meetAddressId)]")
            print("This is the user ID: [\(user.UserId)]")
            sqlite3_bind_int64(statement, 2, user.UserId)

            
            if sqlite3_step(statement) == SQLITE_DONE {
                let rowID = sqlite3_last_insert_rowid(db)  // This IS the auto-generated MeetID!
                sqlite3_finalize(statement)
                return (rowID, nil)
            } else {
                let err = String(cString: sqlite3_errmsg(db))
                sqlite3_finalize(statement)
                return (nil, NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: err]))
            }
        } else {
            let err = String(cString: sqlite3_errmsg(db))
            return (nil, NSError(domain: "SQLite", code: 2, userInfo: [NSLocalizedDescriptionKey: err]))
        }
    }
    
    // TODO: figure out better ID input
    
    /// Inserts meet into tbMeets containing meet details  date, name, description, etc.
    /// - Parameters:
    ///   - meetBatch: Contains Meet object containing meet properties necessary to reference that table
    /// - Returns: TODO: FIX.. returns int64 for some reason
    /// - Throws: todo:... fix
    public static func tryInsertMeet(_ db: OpaquePointer?, meetBatch: MeetBatch) -> (Int64?, Error?)
    {
        // Validate inputs
        guard let db = db,
              let meet = meetBatch.Meet,
              let meetId = meetBatch.MeetId else {
            return (nil, NSError(domain: "MeetInsertError", code: 1,
                                 userInfo: [NSLocalizedDescriptionKey: "Error with meet / MeetId"]))
        }

        guard let meetCategoryId = meet.MeetCategoryId else {
            return (nil, NSError(domain: "MeetInsertError", code: 1,
                                 userInfo: [NSLocalizedDescriptionKey: "Error with MeetCategoryID"]))
        }
        
        // MaxCapacity: optional -> Int32 for SQLite
        let meetMaxI32: Int32 = {
            // If MaxCapacity is optional Int?/Int8?
            if let v = meet.MaxCapacity {
                // clamp to a sane range (1...100) and upcast to Int32
                let clamped = max(1, min(Int(v), 100))
                return Int32(clamped)
            } else {
                // or fail fast instead of defaulting:
                // return -1 to trigger guard below if you prefer
                return 0
            }
        }()

        guard meetMaxI32 > 0 else {
            return (nil, NSError(domain: "MeetInsertError", code: 1,
                                 userInfo: [NSLocalizedDescriptionKey: "Error with MaxCapacity"]))
        }

        
        // --- Compute UTC epoch seconds (preferred from EpochRange; fallback to Date) ---
        let startEpoch  : Int64
        let endEpoch    : Int64
        if let r = meet.EpochRange {
            startEpoch = r.startEpoch
            endEpoch   = r.endEpoch
        } else {
            return (nil, NSError(domain: "MeetInsertError", code: 1,
                                 userInfo: [NSLocalizedDescriptionKey: "Missing start/end datetime"]))
        }

        // Guard ordering (don’t insert inverted ranges)
        guard endEpoch >= startEpoch else {
            return (nil, NSError(domain: "MeetInsertError", code: 1,
                                 userInfo: [NSLocalizedDescriptionKey: "End must be >= Start"]))
        }

        // Prepare
        let sql = ProcInserts.rgl_i_Meet
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db))
            return (nil, NSError(domain: "SQLite", code: 2, userInfo: [NSLocalizedDescriptionKey: err]))
        }
        defer { sqlite3_finalize(stmt) }

        // Bind (ensure indices match your INSERT)
        sqlite3_bind_int64( stmt, 1, meetId)
        bindIntNN(          stmt, 2, meet.ChangeStamp)
        bindTextNN(         stmt, 3, meet.Name)
        bindTextNN(         stmt, 4, meet.Description)
        bindTextNN(         stmt, 5, meet.ChangeReason)
        sqlite3_bind_int(   stmt, 6, Int32(meetCategoryId))
        sqlite3_bind_int(   stmt, 7, meetMaxI32)
        sqlite3_bind_int64( stmt, 8, startEpoch)   // INTEGER epoch seconds (UTC)
        sqlite3_bind_int64( stmt, 9, endEpoch)     // INTEGER epoch seconds (UTC)

        if sqlite3_step(stmt) == SQLITE_DONE {
            return (meetId, nil)
        } else {
            let err = String(cString: sqlite3_errmsg(db))
            return (nil, NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: err]))
        }
    }


    /// Inserts ID into database for a new meet or a modified one.
    /// - Parameters:
    ///   - db: reference to databse
    ///   - meetBatch: contains User class object contains user specific properties and MeetAddressID to insert into tbMeetIds
    /// - Returns: returns ID value inserted into tbMeetIds. Primary key needed in tbMeets
    /// - Throws: todo: decscribe what the error is
    public static func tryInsertChangeStamp(_ db: OpaquePointer?, _ modifyMeetBatch: ModifyMeetBatch) -> (Int64?, Error?)
    {
        guard let meetDisplay = modifyMeetBatch.MeetCardData else {
            return (nil, NSError(domain: "View Meet Card Error on ChangeStamp",
                                 code: 1,
                                 userInfo: [NSLocalizedDescriptionKey: "Meet Card Null or Empty"]))
        }

        let meetId         = meetDisplay.MeetId
        let createdByUser  = meetDisplay.CreatedBy_UserId
        // TODO: Losing speed casting here??
        let meetStatusId   = Int64(modifyMeetBatch.MeetStatusId.rawValue)   // <— use enum rawValue (Int64)

        let sql = ProcInserts.rgl_i_MeetChangeStamp
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, meetId)
            sqlite3_bind_int64(stmt, 2, meetStatusId)
            sqlite3_bind_int64(stmt, 3, createdByUser)

            if sqlite3_step(stmt) == SQLITE_DONE {
                let rowID = sqlite3_last_insert_rowid(db)
                sqlite3_finalize(stmt)
                return (rowID, nil)
            } else {
                let err = String(cString: sqlite3_errmsg(db))
                sqlite3_finalize(stmt)
                return (nil, NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: err]))
            }
        } else {
            let err = String(cString: sqlite3_errmsg(db))
            return (nil, NSError(domain: "SQLite", code: 2, userInfo: [NSLocalizedDescriptionKey: err]))
        }
    }

    
    // TODO: Implement w/ Version 2
    /// incomplete
    /// - Parameters:
    ///   - <#paramName#>: <#Description of the parameter#>
    ///   - <#paramName#>: <#Description of the parameter#>
    /// - Returns: <#Description of the return value, or remove if Void#>
    /// - Throws: <#Description of the error conditions, or remove if not throwing#>
    public static func tryInsertUser(_ db: OpaquePointer?, user: User) -> (Int64?, Error?)
    {
        guard let db else { return (nil, nil) }
    
        let sql = ProcInserts.rgl_i_User
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db)); return (nil, NSError(domain: "SQLite", code: 2, userInfo: [NSLocalizedDescriptionKey: err]))
        }
        defer { sqlite3_finalize(stmt) }

        bindTextNN(stmt, 1, user.FirstName)
        bindTextNN(stmt, 2, user.LastName)
        bindTextNN(stmt, 3, user.CellPhone)
        bindTextNN(stmt, 4, user.Email)
        bindTextNN(stmt, 5, user.UID)

        if sqlite3_step(stmt) == SQLITE_DONE { return (sqlite3_last_insert_rowid(db), nil) }
        let err = String(cString: sqlite3_errmsg(db)); return (nil, NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: err]))
    }

    
    // MARK: - END Insert Functions
    
    
    
    
    
    // MARK: - View Functions
    

    /// View user details... TODO: consider allowing less properties to be stored
    /// - Parameters:
    ///   - db: connects to database
    ///   - userId: necessary to get correct user information
    /// - Returns: returns a User object with all properties stored
    /// - Throws: TODO: fix... add decsrption
    public static func tryViewUser(_ db: OpaquePointer?, userId: Int64) -> (User?, Error?)
    {
        let sql = ProcViews.rgl_v_Users_ByUserID
        var statement: OpaquePointer?
        
        // Prepare the SQL statement
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            
            // Bind the userId parameter to the ? placeholder
            sqlite3_bind_int64(statement, 1, userId)
            
            // Execute the query and check if we got a row
            if sqlite3_step(statement) == SQLITE_ROW {
                // Extract values from each column
                let userIdResult = sqlite3_column_int64(statement, 0)
                
                var firstName = ""
                if let firstNamePtr = sqlite3_column_text(statement, 1) {
                    firstName = String(cString: firstNamePtr)
                }
                
                var lastName = ""
                if let lastNamePtr = sqlite3_column_text(statement, 2) {
                    lastName = String(cString: lastNamePtr)
                }
                
                var cellPhone = ""
                if let cellPhonePtr = sqlite3_column_text(statement, 3) {
                    cellPhone = String(cString: cellPhonePtr)
                }
                
                var email = ""
                if let emailPtr = sqlite3_column_text(statement, 4) {
                    email = String(cString: emailPtr)
                }
                
                var uid = ""
                if let uidPtr = sqlite3_column_text(statement, 5) {
                    uid = String(cString: uidPtr)
                }
                
                // Create and return the User object
                let user = User(
                    UserId: userIdResult,
                    FirstName: firstName,
                    LastName: lastName,
                    CellPhone: cellPhone,
                    Email: email,
                    UID: uid
                )
                
                sqlite3_finalize(statement)
                return (user, nil)
                
            } else {
                // No user found with that ID
                sqlite3_finalize(statement)
                return (nil, nil)
            }
            
        } else {
            // SQL preparation failed
            let err = String(cString: sqlite3_errmsg(db))
            return (nil, NSError(domain: "SQLite", code: 3, userInfo: [NSLocalizedDescriptionKey: err]))
        }
    }
    
    /// View to access categories that define a meet
    /// - Parameters:
    ///   - db: connects to database
    /// - Returns: returns list of categories or an error
    /// - Throws: TODO: fix description
    public static func tryViewMeetCategories(_ db: OpaquePointer?) -> ([MeetCategory], Error?)
    {
        guard let db = db else { return ([], nil) }

        let sql = ProcViews.rgl_v_MeetCategoryIDAndName   // expects: SELECT MeetCategoryID, Name FROM ...
        var stmt: OpaquePointer?
        var categories: [MeetCategory] = []

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let err = String(cString: sqlite3_errmsg(db))
            return ([], NSError(domain: "SQLite", code: 3, userInfo: [NSLocalizedDescriptionKey: err]))
        }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id    = sqlite3_column_int64(stmt, 0)                           // MeetCategoryID
            let nameC = sqlite3_column_text(stmt, 1)                            // Name
            let name  = nameC != nil ? String(cString: nameC!) : ""

            categories.append(MeetCategory(MeetCategoryId: id, Name: name))
        }

        return (categories, nil)
    }

    
    /// View to access categories that define a meet
    /// - Parameters:
    ///   - db: connects to database
    /// - Returns: ([Name], Error?)
    /// - Throws: TODO: fix description
    public static func tryViewMeetCardData(_ db: OpaquePointer?) -> ([MeetCardData], Error?)
    {
        guard let db else { return ([], nil) }

        let sql = ProcViews.rgl_v_MeetCardData
        var stmt: OpaquePointer?

        // PREPARE
        let prep = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard prep == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(db))
            return ([], NSError(domain: "SQLite", code: Int(prep),
                                userInfo: [NSLocalizedDescriptionKey: "prepare failed: \(msg)"]))
        }
        defer { sqlite3_finalize(stmt) }

        var rows: [MeetCardData] = []

        // STEP loop
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW {
                if let md = mapMeetCardData(stmt) {
                    rows.append(md)
                }
                continue
            }
            if rc == SQLITE_DONE {
                return (rows, nil)
            }
            let msg = String(cString: sqlite3_errmsg(db))
            return ([], NSError(domain: "SQLite", code: Int(rc),
                                userInfo: [NSLocalizedDescriptionKey: "step failed: \(msg)"]))
        }
    }


    // MARK: - END View Functions
    
    
    // MARK: - Utility Functions
    /// Auxillary method that calls tryViewMeetCategegories returning a string of Category names... TODO: determine efficacy of method
    /// - Parameters:
    ///   - db: connects to database
    /// - Returns: returns array of database names
    /// - Throws: TODO: fix.. add description

    public static func loadCategories(_ db: OpaquePointer?) -> [MeetCategory]
    {
        let (loadedCategories, err) = tryViewMeetCategories(db)
        if let err = err { print("loadCategories error: \(err.localizedDescription)") }
        return loadedCategories
    }
    
    // MARK: - END Utility Functions

    


}
// MARK: - Private mapping/helpers (kept inside DbRangle.swift)
private extension DbRangle {
    
    static func mapMeetCardData(_ stmt: OpaquePointer!) -> MeetCardData? {
        // Matches: MeetID(0), ChangeStamp(1), MeetStatusID(2),
        //          Latitude(3), Longitude(4),
        //          DttmStartUtc(5), DttmEndUtc(6),
        //          Name(7), Description(8), MaxCapacity(9),
        //          UserID(10), FirstName(11), LastName(12),
        //          AddressName(13), CategoryName(14)   <-- ensure your SELECT returns these!

        let meetId       = sqlite3_column_int64( stmt, 0)
        let changeStamp  = sqlite3_column_int64( stmt, 1)
        let meetStatusId = sqlite3_column_int64( stmt, 2)
        let lat          = sqlite3_column_double(stmt, 3)
        let lon          = sqlite3_column_double(stmt, 4)
        let startEpoch   = sqlite3_column_int64( stmt, 5)
        let endEpoch     = sqlite3_column_int64( stmt, 6)
        
        guard endEpoch >= startEpoch else { return nil }
        
        let name         = sqliteText(           stmt, 7)  ?? ""
        let addressName  = sqliteText(           stmt, 8)  ?? ""
        let categoryName = sqliteText(           stmt, 9)  ?? ""
        let description  = sqliteText(           stmt, 10) ?? ""
        let maxCap       = sqlite3_column_int(   stmt, 11)
        let createdBy    = sqlite3_column_int64( stmt, 12)
        let firstName    = sqliteText(           stmt, 13) ?? ""
        let lastName     = sqliteText(           stmt, 14) ?? ""



        // Int64 -> Int8 with clamping to avoid overflow
        let maxCapacity  = Int8(clamping: Int(maxCap))

        return MeetCardData(
            meetId,
            changeStamp,
            meetStatusId,
            Coordinate(lat, lon),
            EpochRange(startEpoch, endEpoch),// Int64 epoch seconds
            name,
            addressName,             // <- now provided
            categoryName,            // <- now provided
            description,
            maxCapacity,             // Int8
            createdBy,
            firstName,
            lastName
        )
    }



    @inline(__always)
    static func sqliteText(_ stmt: OpaquePointer!, _ idx: Int32) -> String? {
        guard sqlite3_column_type(stmt, idx) != SQLITE_NULL,
              let cstr = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: cstr)
    }

    // Accept common UTC shapes you’re likely to store.
    @inline(__always)
    static func parseUtcDate(_ s: String) -> Date? {
        if let d = ISO8601Z.date(from: s) { return d }
        if let d = YMD_HMS.date(from: s) { return d }
        if let d = YMD.date(from: s) { return d }
        return nil
    }

    // Cached formatters (UTC)
    static let ISO8601Z: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    static let YMD_HMS: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static let YMD: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
