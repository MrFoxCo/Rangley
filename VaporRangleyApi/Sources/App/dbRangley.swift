//
//  procedures.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 8/27/25.
//


import Vapor
import Fluent
import SQLKit
import JWT


// MARK: - Registry of fully-qualified procedure names

enum RangleyProcName: String
{
    case i_user_by_auth_register = "rangley.rangley_i_user_by_auth_register"
    case i_meet_id               = "rangley.rangley_i_meet_id"
    case i_meet_coordinate       = "rangley.rangley_i_meet_coordinate"
    case i_meet                  = "rangley.rangley_i_meet"
    case s_insert_meet           = "rangley.rangley_s_insert_meet"
    case s_insert_updated_meet   = "rangley.rangley_s_insert_updated_meet"
    case i_change_stamp          = "rangley.rangley_i_change_stamp"
    case i_updated_meet          = "rangley.rangley_i_updated_meet"
    case m_user                  = "rangley.rangley_m_user"
}

// Essentially these are views because postgres doesn't allow procedural views in an easy way
enum RangleyFunc: String
{
    case v_user_by_cognito_sub  = "rangley.rangley_fn_v_user_by_cognito_sub"
    case v_meets_by_cognito_sub = "rangley.rangley_fn_v_meets_by_cognito_sub"
    case v_meet_categories      = "rangley.rangley_fn_v_meet_categories"
}

// MARK: - Generic call shapes

protocol PgCallableRow
{
    associatedtype Input: Sendable
    associatedtype Output: Content & Sendable
    
    static var procName: RangleyProcName { get }
    static func query(_ input: Input, _ output : Output) -> SQLQueryString
    static func decode(_ row: any SQLRow) throws -> Output
}

extension PgCallableRow
{
    @discardableResult
    static func call(on db: any SQLDatabase, _ input: Input, _ output : Output) async throws -> Output
    {
        let rows = try await db.raw(query(input, output)).all()
        guard let row = rows.first else {
            throw Abort(.internalServerError, reason: "\(procName.rawValue) returned no row")
        }
        return try decode(row)
    }
}

protocol PgCallableNoRow
{
    associatedtype Input: Sendable
    associatedtype Output: Content & Sendable
    static var procName: RangleyProcName { get }
    static func query(_ input: Input, _ output : Output) -> SQLQueryString
}

extension PgCallableNoRow
{
    static func exec(on db: any SQLDatabase, _ input: Input, _ output : Output) async throws
    {
        _ = try await db.raw(query(input, output)).all()  // CALL without OUT returns no row; ignore result
    }
}

// MARK: - END Generic call shapes

// MARK: - Procs

enum Proc
{

    // MARK: - INSERTS
    

    // MARK: - INSERT USER NOT TESTED
    
    /// MUST match: CREATE PROCEDURE rangley.rangley_i_user_by_auth_register(...)
    enum InsertUserByAuthRegister: PgCallableRow
    {
        static let procName: RangleyProcName = .i_user_by_auth_register

        struct RegisterBody: Content, Sendable {
            let username    : String
            let display_name: String
            let cellphone   : String?
            let email       : String?
            let dob         : String
            let first_name  : String?
            let last_name   : String?
        }
        
        struct Params: Content, Sendable {
            let cognito_sub  : String
            let username     : String
            let display_name : String
            let cellphone    : String?
            let email        : String?
            let dob          : String          // "YYYY-MM-DD"
            let first_name   : String?
            let last_name    : String?
        }

        struct Result: Content, Sendable {
            let is_success: Bool?
        }

        // OUT goes first (your convention)
        static func query(_ i: Params, _ o: Result) -> SQLQueryString {
            """
            CALL \(unsafeRaw: procName.rawValue)
            (
                 \(bind: o.is_success)::boolean
                ,\(bind: i.cognito_sub)::text
                ,\(bind: i.username)::varchar(50)
                ,\(bind: i.display_name)::varchar(50)
                ,\(bind: i.cellphone)::varchar(16)
                ,\(bind: i.email)::varchar(256)
                ,\(bind: i.dob)::date
                ,COALESCE(\(bind: i.first_name)::varchar(50), ''::varchar(50))
                ,COALESCE(\(bind: i.last_name)::varchar(50),  ''::varchar(50))
            );
            """
        }

        static func decode(_ row: any SQLRow) throws -> Result {
            try .init(is_success: row.decode(column: "is_success", as: Bool?.self))
        }
    }

    
    // MARK: - END INSERT USER NOT TESTED
    
    
    // =========================================================
    // MARK: - Transaction Level Meet Inserts
    // =========================================================

    enum SystemInsertMeet: PgCallableRow
    {
        static let procName: RangleyProcName = .s_insert_meet  // ensure this resolves to schema-qualified "rangley.rangley_s_insert_meet" or your search_path includes 'rangley'
        
        struct Params: Content, Sendable {
            // Required
            let cognito_sub     : String
            let latitude        : Double
            let longitude       : Double
            let region_latitude : Double
            let region_longitude: Double
            let region_radius   : Double
            let name            : String          // p_name
            let dttm_start_utc  : Date
            let dttm_end_utc    : Date

            // Optional
            let description     : String?         // p_description
            let meet_category_id: Int16?          // p_meet_category_id
            let max_capacity    : Int32?          // p_max_capacity
        }

        struct Result: Content, Sendable {
            let num_inserted: Int32
        }

        static func query(_ i: Params, _ o: Result) -> SQLQueryString {
            """
            CALL \(unsafeRaw: procName.rawValue)
            (
                 NULL::int4  -- OUT parameter placeholder
                ,\(bind: i.cognito_sub              )::text
                ,\(bind: i.latitude                 )::float8
                ,\(bind: i.longitude                )::float8
                ,\(bind: i.region_latitude          )::float8
                ,\(bind: i.region_longitude         )::float8
                ,\(bind: i.region_radius            )::float8
                ,\(bind: i.name                     )::varchar(50)
                ,\(bind: i.dttm_start_utc           )::timestamptz
                ,\(bind: i.dttm_end_utc             )::timestamptz
                ,COALESCE(\(bind: i.description     )::varchar(50), ''::varchar(50))
                ,COALESCE(\(bind: i.meet_category_id)::int2, 1::int2)
                ,COALESCE(\(bind: i.max_capacity    )::int4, 2::int4)
            );
            """
        }

        static func decode(_ row: any SQLRow) throws -> Result
        {
            try .init(num_inserted: row.decode(column: "num_inserted", as: Int32.self))
        }
    }

    enum SystemInsertUpdatedMeet: PgCallableRow
    {
        static let procName: RangleyProcName = .s_insert_updated_meet  // ensure this resolves to schema-qualified "rangley.rangley_s_insert_meet" or your search_path includes 'rangley'
        
        struct Params: Content, Sendable
        {
            // Required
            let cognito_sub         : String
            let meet_id_uuid        : String  // This is required for updates
            
            // Optional fields - only pass what's changing
            let latitude            : Double?
            let longitude           : Double?
            let region_latitude     : Double?
            let region_longitude    : Double?
            let region_radius       : Double?
            let meet_status_id      : Int16?
            let name                : String?
            let dttm_start_utc      : Date?
            let dttm_end_utc        : Date?
            let description         : String?
            let change_reason       : String?
            let meet_category_id    : Int16?
            let max_capacity        : Int32?
        }

        struct Result: Content, Sendable {
            let num_inserted: Int32
        }

        static func query(_ i: Params, _ o: Result) -> SQLQueryString {
            """
            CALL \(unsafeRaw: procName.rawValue)
            (
                 NULL::int4  -- OUT parameter placeholder
                -- REQUIRED
                ,\(bind: i.cognito_sub      )::text
                ,\(bind: i.meet_id_uuid     )::uuid  -- FIX: was cognito_sub
                --OPTIONAL
                ,\(bind: i.latitude         )::float8
                ,\(bind: i.longitude        )::float8
                ,\(bind: i.region_latitude  )::float8
                ,\(bind: i.region_longitude )::float8
                ,\(bind: i.region_radius    )::float8
                ,\(bind: i.meet_status_id   )::int2  -- ADD: was missing
                ,\(bind: i.name             )::varchar(50)
                ,\(bind: i.dttm_start_utc   )::timestamptz
                ,\(bind: i.dttm_end_utc     )::timestamptz
                ,\(bind: i.description      )::varchar(50)
                ,\(bind: i.change_reason    )::varchar(50)
                ,\(bind: i.meet_category_id )::int2
                ,\(bind: i.max_capacity     )::int4
            );
            """
        }
        static func decode(_ row: any SQLRow) throws -> Result
        {
            try .init(num_inserted: row.decode(column: "num_inserted", as: Int32.self))
        }
    }
    
    // =========================================================
    // MARK: - END Transaction Level Meet Inserts
    // =========================================================

    
    // =========================================================
    // MARK: - Deprecated or not Integrated into UI
    // =========================================================
    /// Contains Insert Params and Results
    enum InsertMeetId: PgCallableRow
    {
        static let procName: RangleyProcName = .i_meet_id
        
        struct Params: Content, Sendable // WORKING
        {
            let created_by_user_id  : Int64
        }
        
        struct Result: Content, Sendable
        {
            let new_meet_id: Int64?
        }
        
        static func query(_ i: Params, _ o : Result) -> SQLQueryString
        {
            """
            CALL \(unsafeRaw: procName.rawValue)(
                 \(bind: o.new_meet_id)
                ,\(bind: i.created_by_user_id)

            );
            """
        }
        
        static func decode(_ row: any SQLRow) throws -> Result {
            try .init(
                new_meet_id: row.decode(column: "new_meet_id", as: Int64?.self)
            )
        }
    }
    
    /// Contains Insert Params and Results
    enum InsertMeetCoordinate: PgCallableRow
    {
        static let procName: RangleyProcName = .i_meet_coordinate
        
        struct Params: Content, Sendable
        {
            let latitude            : Double
            let longitude           : Double
            let region_latitude     : Double
            let region_longitude    : Double
            let region_radius       : Double
        }
        
        struct Result: Content, Sendable
        {
            let new_meet_coordinate_id: Int64?
        }
        
        static func query(_ i: Params, _ o : Result) -> SQLQueryString
        {
            """
            CALL \(unsafeRaw: procName.rawValue)
            (
                -- OUT
                 \(bind: o.new_meet_coordinate_id)
            
                -- REQUIRED
                ,\(bind: i.latitude)
                ,\(bind: i.longitude)
                ,\(bind: i.region_latitude)
                ,\(bind: i.region_longitude)
                ,\(bind: i.region_radius)

            );
            """
        }
        
        static func decode(_ row: any SQLRow) throws -> Result
        {
            try .init(
                new_meet_coordinate_id: row.decode(column: "new_meet_coordinate_id", as: Int64?.self)
            )
        }
    }
    
    /// Contains Insert Params and Results
    enum InsertMeet: PgCallableRow
    {
        static let procName: RangleyProcName = .i_meet

        struct Params: Content, Sendable
        {
            // required
            let meet_id             : Int64   // p_meet_id
            let meet_coordinate_id  : Int64
            let name                : String   // p_name
            let dttm_start_utc      : Date
            let dttm_end_utc        : Date
            
            // optional
            let description         : String?   // p_description
            let change_reason       : String?   // p_change_reason
            let meet_category_id    : Int16?    // p_meet_category_id
            let max_capacity        : Int32?

        }
        
        struct Result: Content, Sendable
        {
            let num_inserted: Int32?
        }
        
        static func query(_ i: Params, _ o: Result) -> SQLQueryString
        {
            """
            CALL \(unsafeRaw: procName.rawValue)
            (
                 \(bind: o.num_inserted)::int4
            
                -- Required
                ,\(bind: i.meet_id)::int8
                ,\(bind: i.meet_coordinate_id)::int8
                ,\(bind: i.name)::varchar(50)
                ,\(bind: i.dttm_start_utc)::timestamptz
                ,\(bind: i.dttm_end_utc)::timestamptz
                
                -- Optional Params Must Coalesce because they are included in parameter
                ,COALESCE(\(bind: i.description)::varchar(50), ''::varchar(50))
                ,COALESCE(\(bind: i.change_reason)::varchar(50), ''::varchar(50))
                ,COALESCE(\(bind: i.meet_category_id)::int2, 1::int2)   -- <- avoids NULL + matches int2
                ,COALESCE(\(bind: i.max_capacity)::int4, 2::int4)
            );
            """
        }

        static func decode(_ row: any SQLRow) throws -> Result {
            try .init(num_inserted: row.decode(column: "num_inserted", as: Int32?.self))
        }
    }
    /// Contains Insert Params and Results
    enum InsertChangeStamp: PgCallableRow
    {
        struct Params: Content, Sendable
        {
            let meet_id         : Int64
        }
        
        struct Result: Content, Sendable
        {
            let new_change_stamp: Int64?
        }
        
        static let procName: RangleyProcName = .i_change_stamp
        
        static func query(_ i: Params, _ o : Result) -> SQLQueryString
        {
            // OUT params are NOT passed
            """
            CALL \(unsafeRaw: procName.rawValue)
            (
                -- OUT
                 \(bind: o.new_change_stamp)
            
                -- REQUIRED
                ,\(bind: i.meet_id)
            );
            """
        }
        
        static func decode(_ row: any SQLRow) throws -> Result
        {
            try .init(
                new_change_stamp: row.decode(column: "new_change_stamp", as: Int64?.self)
            )
        }
    }
    
    /// Contains Insert Params and Results
    enum InsertUpdatedMeet: PgCallableRow // deprecated
    {
        static let procName: RangleyProcName = .i_updated_meet
        
        struct Params: Content, Sendable
        {
            // required
            let meet_id             : Int64
            let change_stamp        : Int64
            let meet_coordinate_id  : Int64
            let name                : String
            let dttm_start_utc      : Date
            let dttm_end_utc        : Date

            // optional
            let meet_status_id      : Int16?
            let description         : String?
            let change_reason       : String?
            let meet_category_id    : Int16?
            let max_capacity        : Int32? // PG default 2 if nil

        }
        
        struct Result: Content, Sendable
        {
            let num_inserted: Int32?
        }
        
        static func query(_ i: Params, _ o : Result ) -> SQLQueryString
        {
            """
            CALL \(unsafeRaw: procName.rawValue)
            (
                -- Out
                 \(bind: o.num_inserted)::int4
            
                -- Required
                ,\(bind: i.meet_id)::int8
                ,\(bind: i.change_stamp)::int8
                ,\(bind: i.meet_coordinate_id)::int8
                ,\(bind: i.name)::varchar(50)
                ,\(bind: i.dttm_start_utc)::timestamptz
                ,\(bind: i.dttm_end_utc)::timestamptz

                -- Optional Params Must Coalesce because they are included in parameter
                ,COALESCE(\(bind: i.meet_status_id)::int2, 0::int2)
                ,COALESCE(\(bind: i.description)::varchar(50), ''::varchar(50))
                ,COALESCE(\(bind: i.change_reason)::varchar(50), ''::varchar(50))
                ,COALESCE(\(bind: i.meet_category_id)::int2, 1::int2)   -- <- avoids NULL + matches int2
                ,COALESCE(\(bind: i.max_capacity)::int4, 2::int4)
            );
            """
        }
        static func decode(_ row: any SQLRow) throws -> Result
        {
            try .init(num_inserted: row.decode(column: "num_inserted", as: Int32?.self))
        }
    }
    
    // =========================================================
    // MARK: - END Deprecated or not Integrated into UI
    // =========================================================
    
    
    
    // MARK: - END INSERT
    

    
    
    
    // MARK: - MODIFY
    

    // TODO: FIX THIS
    /// Contains Insert Params and Results
    enum ModifyUser: PgCallableNoRow
    {
        static let procName: RangleyProcName = .m_user
        
        struct Params: Content, Sendable
        {
            // REQUIRED
            let user_id      : Int64
            
            //OPTIONAL
            let cognito_sub  : String?
            let username     : String?
            let display_name : String?
            let first_name   : String? // need this or email
            let last_name    : String? // need this or cellphone
            let cellphone    : String?
            let email        : String?
            let dob          : String?
        }
        
        struct Result: Content, Sendable
        {
            let num_affected : Int32?
        }
        
        static func query(_ i: Params, _ o: Result) -> SQLQueryString
        {
            """
            CALL \(unsafeRaw: procName.rawValue)
            (
                -- OUT num_affected OMITTED
                 \(bind: o.num_affected)::int4
                -- REQUIRED
                ,\(bind: i.user_id)::int8
                -- Optional fields (pass NULLs as-is)
                ,\(bind: i.cognito_sub)::text
                ,\(bind: i.username)::varchar(50)
                ,\(bind: i.display_name)::varchar(50)
                ,\(bind: i.first_name)::varchar(50)
                ,\(bind: i.last_name)::varchar(50)
                ,\(bind: i.cellphone)::varchar(16)
                ,\(bind: i.email)::varchar(256)
                ,\(bind: i.dob)::date
            );
            """
        }
        
        static func decode(_ row: any SQLRow) throws -> Result
        {
            try .init(
                num_affected : row.decode(column: "num_affected",  as: Int32.self)
            )
        }
    }
    
    // MARK: - END MODIFY


}

// MARK: - END Procs




// MARK: - Generic call shapes for FUNCTIONS

/// MULTIPLE ROWS
protocol PgFunctionRows
{
    associatedtype Input    : Sendable
    associatedtype Output   : Content & Sendable
    static var funcName     : RangleyFunc { get }
    
    static func query(_ input: Input) -> SQLQueryString
    static func decode(_ row: any SQLRow) throws -> Output
}

/// MULTIPLE ROWS
extension PgFunctionRows
{
    static func fetchAll(on db: any SQLDatabase, _ input: Input) async throws -> [Output] {
        let rows = try await db.raw(query(input)).all()
        return try rows.map { try decode($0) }
    }
}

/// SINGLE ROW
protocol PgFunctionRow
{
    associatedtype Input    : Sendable
    associatedtype Output   : Content & Sendable
    static var funcName     : RangleyFunc { get }
    
    static func query(_ input: Input) -> SQLQueryString
    static func decode(_ row: any SQLRow) throws -> Output
}

/// MULTIPLE ROWS
extension PgFunctionRow
{
    static func call(on db: any SQLDatabase, _ input: Input) async throws -> Output {
        let rows = try await db.raw(query(input)).all()
        guard let row = rows.first else {
            throw Abort(.notFound, reason: "\(funcName.rawValue) returned no rows")
        }
        return try decode(row)
    }
}

// MARK: - END Generic call shapes for FUNCTIONS



enum Func
{
    // MARK: - VIEWS

    enum ViewMeets: PgFunctionRows
    {
        static let funcName: RangleyFunc = .v_meets_by_cognito_sub

        struct In: Sendable { let cognitoSub: String }

        struct Results: Content, Sendable {
            let meet_id_uuid         : String
            let meet_status_id       : Int16
            let latitude             : Double
            let longitude            : Double
            let region_latitude      : Double
            let region_longitude     : Double
            let region_radius        : Double
            let dttm_start_utc       : Date
            let dttm_end_utc         : Date
            let name                 : String
            let category_name        : String
            let meet_category_id     : Int16
            let description          : String
            let max_capacity         : Int32
            let created_by_user_uuid : String
            let display_name         : String
            let is_owner             : Bool
            // add change_stamp if you want it
            // let change_stamp       : Int64
        }

        static func query(_ input: In) -> SQLQueryString {
            // if funcName.rawValue already includes schema, this is fine
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.cognitoSub)::text);"
        }

        static func decode(_ r: any SQLRow) throws -> Results {
            try .init(
                 meet_id_uuid         : r.decode(column: "meet_id_uuid",         as: String.self)
                ,meet_status_id       : r.decode(column: "meet_status_id",       as: Int16.self)
                ,latitude             : r.decode(column: "latitude",             as: Double.self)
                ,longitude            : r.decode(column: "longitude",            as: Double.self)
                ,region_latitude      : r.decode(column: "region_latitude",      as: Double.self)
                ,region_longitude     : r.decode(column: "region_longitude",     as: Double.self)
                ,region_radius        : r.decode(column: "region_radius",        as: Double.self)
                ,dttm_start_utc       : r.decode(column: "dttm_start_utc",       as: Date.self)
                ,dttm_end_utc         : r.decode(column: "dttm_end_utc",         as: Date.self)
                ,name                 : r.decode(column: "name",                 as: String.self)
                ,category_name        : r.decode(column: "category_name",        as: String.self)
                ,meet_category_id     : r.decode(column: "meet_category_id",     as: Int16.self)
                ,description          : r.decode(column: "description",          as: String.self)
                ,max_capacity         : r.decode(column: "max_capacity",         as: Int32.self)
                ,created_by_user_uuid : r.decode(column: "created_by_user_uuid", as: String.self)
                ,display_name         : r.decode(column: "display_name",         as: String.self)
                ,is_owner             : r.decode(column: "is_owner",             as: Bool.self)
                // ,change_stamp       : r.decode(column: "change_stamp",         as: Int64.self)
            )
        }

        static func fetchAll(on db: any SQLDatabase, sub: String) async throws -> [Results] {
            try await fetchAll(on: db, .init(cognitoSub: sub))
        }
    }


    enum ViewUser: PgFunctionRows
    {
        static let funcName: RangleyFunc = .v_user_by_cognito_sub  // or .v_user_clean

        struct Param: Content, Sendable
        {
            let cognito_sub: String
        }

        struct Results: Content, Sendable
        {
            let user_uuid           : String
            let username            : String
            let display_name        : String
            let cellphone           : String?
            let email               : String?
            let dob                 : Date
            let dttm_created_utc    : Date
        }
        
        struct In: Sendable { let cognito_sub: String }

        static func query(_ input: In) -> SQLQueryString {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.cognito_sub));"
        }

        static func decode(_ r: any SQLRow) throws -> Results
        {
            try .init(
                user_uuid           : r.decode(column: "user_uuid",         as: String.self),
                username            : r.decode(column: "username",          as: String.self),
                display_name        : r.decode(column: "display_name",      as: String.self),
                cellphone           : r.decode(column: "cellphone",         as: String?.self),
                email               : r.decode(column: "email",             as: String?.self),
                dob                 : r.decode(column: "dob",               as: Date.self),
                dttm_created_utc    : r.decode(column: "dttm_created_utc",  as: Date.self)
            )
        }
    }


    enum ViewMeetCategories: PgFunctionRows
    {
        static let funcName: RangleyFunc = .v_meet_categories

        struct Results: Content, Sendable
        {
            let meet_category_id: Int32
            let name            : String
        }

        
        struct In: Sendable { }  // no params

        static func query(_ input: In) -> SQLQueryString {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)();"
        }

        static func decode(_ r: any SQLRow) throws -> Results
        {
            try .init(
                meet_category_id: r.decode(column: "meet_category_id", as: Int32.self),
                name            : r.decode(column: "name",             as: String.self)
            )
        }

        // convenience
        static func fetchAll(on db: any SQLDatabase) async throws -> [Results] {
            try await fetchAll(on: db, In())
        }
    }

    // Inside: enum Func

    
    // MARK: - END VIEWS
}




// TODO: CONSIDER UN-NESTING ALL THIS SHIT
//
//enum AWS
//{
//    // MARK: Helpers (all static)
//    private static let reservedHandles: Set<String> = ["admin","support","rangley","mrfox","root","system"]
//
//    @inlinable
//    static func normalizeHandle(_ s: String) -> String {
//        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
//    }
//
//    @inlinable
//    static func validateHandle(_ h: String) -> Bool {
//        h.range(of: #"^[a-z0-9_]{3,20}$"#, options: .regularExpression) != nil
//        && !reservedHandles.contains(h)
//    }
//
//    @inlinable
//    static func normalizeEmail(_ e: String?) -> String? {
//        e?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
//    }
//
//    @inlinable
//    static func normalizePhoneE164(_ p: String?) -> String? {
//        guard let p else { return nil }
//        let cleaned = p.replacingOccurrences(of: #"[^+\d]"#, with: "", options: .regularExpression)
//        return cleaned.hasPrefix("+") && cleaned.count >= 8 ? cleaned : nil
//    }
//    /// Turn whatever the user typed into a Cognito-friendly username:
//    /// - phone -> E.164
//    /// - email -> lowercase
//    /// - else  -> normalized handle (lowercased)
//    @inlinable
//    static func normalizeLoginUsername(_ raw: String) -> String {
//        if let p = normalizePhoneE164(raw) { return p }
//        if let e = normalizeEmail(raw), raw.contains("@") { return e }
//        return normalizeHandle(raw)
//    }
//
//    // MARK: - END Helpers (all static)
