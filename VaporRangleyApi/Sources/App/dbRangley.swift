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
import PostgresKit
import NIOCore // for ByteBuffer

// MARK: - Registry of fully-qualified procedure names

enum RangleyProcName: String
{
    case i_user_by_auth_register        = "rangley.rangley_i_user_by_auth_register"
    case i_meet_id                      = "rangley.rangley_i_meet_id"
    case i_meet_coordinate              = "rangley.rangley_i_meet_coordinate"
    case i_meet                         = "rangley.rangley_i_meet"
    case s_insert_meet                  = "rangley.rangley_s_insert_meet"
    case s_insert_meet_w_user_invites   = "rangley.rangley_s_insert_meet_w_user_invites"
    case s_insert_updated_meet          = "rangley.rangley_s_insert_updated_meet"
    case s_insert_deleted_meet          = "rangley.rangley_s_insert_deleted_meet"
    case i_change_stamp                 = "rangley.rangley_i_change_stamp"
    case i_updated_meet                 = "rangley.rangley_i_updated_meet"
    case m_user                         = "rangley.rangley_m_user"
    case d_user                         = "rangley.rangley_d_user_by_cognito_sub"
}

// Essentially these are views because postgres doesn't allow procedural views in an easy way
enum RangleyFunc: String
{
    // TODO: remove deprecated when update is complete
    case v_user_by_cognito_sub_dep                 = "rangley.rangley_fn_v_user_by_cognito_sub"
    case v_user_by_cognito_sub_new                 = "rangley.rangley_fn_v_user_by_cognito_sub_patch_dob"
    case v_users_by_cognito_sub                    = "rangley.rangley_fn_v_users_by_cognito_sub"
    // TODO: remove deprecated when update is complete
    case v_user_inbox_notifications_by_cognito_sub = "rangley.rangley_fn_v_user_inbox_notifications_by_cognito_sub"
    
    case v_meet_categories                         = "rangley.rangley_fn_v_meet_categories"
    case v_meets_by_cognito_sub                    = "rangley.rangley_fn_v_meets_by_cognito_sub"
    
    
    case m_respond_to_meet_invitation              = "rangley.rangley_fn_m_respond_to_meet_invitation"
    case m_update_participant_status               = "rangley.rangley_fn_m_update_participant_status"
    case i_additional_participants_to_meet         = "rangley.rangley_fn_i_additional_participants_to_meet_by_meet_id_uuid"
    case v_app_version                             = "rangley.rangley_fn_v_app_version"
    case check_username_availability               = "rangley.rgl_fn_check_username_availability"
    case validate_display_name                     = "rangley.rgl_fn_validate_display_name"
    case view_user_profile_by_uuid                 = "rangley.rgl_fn_v_user_profile_by_uuid"
    
    case send_friend_request                       = "rangley.rgl_fn_send_friend_request"
    case view_user_inbox                           = "rangley.rgl_fn_v_user_inbox"
    case respond_to_friend_request                 = "rangley.rgl_fn_respond_to_friend_request"
    case clear_user_inbox                          = "rangley.rgl_fn_clear_user_inbox"

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

        struct Result: Content, Sendable
        {
            let num_inserted        : Int32
            let meet_id_uuid        : UUID?
            let validation_failed   : Bool
            let validation_reason   : String?
            let validation_message  : String?
        }

        static func query(_ i: Params, _ o: Result) -> SQLQueryString {
            """
            CALL \(unsafeRaw: procName.rawValue)
            (
                 NULL::int4  -- OUT parameter placeholder
                ,NULL::UUID -- OUT
                ,NULL::boolean  -- OUT validation_failed
                ,NULL::text     -- OUT validation_reason
                ,NULL::text     -- OUT validation_mess
                ,\(bind: i.cognito_sub              )::text
                ,\(bind: i.latitude                 )::float8
                ,\(bind: i.longitude                )::float8
                ,\(bind: i.region_latitude          )::float8
                ,\(bind: i.region_longitude         )::float8
                ,\(bind: i.region_radius            )::float8
                ,\(bind: i.name                     )::varchar(50)
                ,\(bind: i.dttm_start_utc           )::timestamptz
                ,\(bind: i.dttm_end_utc             )::timestamptz
                ,COALESCE(\(bind: i.description     ), ''::varchar(50))::varchar(50)
                ,COALESCE(\(bind: i.meet_category_id), 1::int2)::int2
                ,COALESCE(\(bind: i.max_capacity    ), 2::int4)::int4
            );
            """
        }

        static func decode(_ row: any SQLRow) throws -> Result
        {
                try .init(
                    num_inserted: row.decode(column: "num_inserted", as: Int32.self),
                    meet_id_uuid: row.decode(column: "meet_id_uuid", as: UUID?.self),
                    validation_failed: row.decode(column: "validation_failed", as: Bool.self),
                    validation_reason: row.decode(column: "validation_reason", as: String?.self),
                    validation_message: row.decode(column: "validation_message", as: String?.self)
                )
            }
    }



    
    enum SystemInsertUpdatedMeet: PgCallableRow
    {
        static let procName: RangleyProcName = .s_insert_updated_meet  // ensure this resolves to schema-qualified "rangley.rangley_s_insert_meet" or your search_path includes 'rangley'
        
        struct Params: Content, Sendable
        {
            // Required
            let cognito_sub         : String
            let meet_id_uuid        : UUID  // This is required for updates
            
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

        struct Result: Content, Sendable
        {
             let num_inserted        : Int32
             let validation_failed   : Bool
             let validation_reason   : String?
             let validation_message  : String?
         }
        static func query(_ i: Params, _ o: Result) -> SQLQueryString {
            """
            CALL \(unsafeRaw: procName.rawValue)
            (
                 NULL::int4  -- OUT parameter placeholder
                ,NULL::boolean  -- OUT validation_failed
                ,NULL::text     -- OUT validation_reason
                ,NULL::text     -- OUT validation_message
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
            try .init(
                num_inserted: row.decode(column: "num_inserted", as: Int32.self),
                validation_failed: row.decode(column: "validation_failed", as: Bool.self),
                validation_reason: row.decode(column: "validation_reason", as: String?.self),
                validation_message: row.decode(column: "validation_message", as: String?.self)
            )
        }
    }
    
    enum SystemInsertDeletedMeet: PgCallableRow
    {
        static let procName: RangleyProcName = .s_insert_deleted_meet  // ensure this resolves to schema-qualified "rangley.rangley_s_insert_meet" or your search_path includes 'rangley'
        
        struct Params: Content, Sendable
        {
            // Required
            let cognito_sub         : String
            let meet_id_uuid        : UUID  // This is required for updates
            
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
    // MARK: - Transaction Level Meet Inserts w/ Invites
    // =========================================================
    
    enum SystemInsertMeetWithInvites: PgCallableRow
    {
        static let procName: RangleyProcName = .s_insert_meet_w_user_invites  // ensure this resolves to schema-qualified "rangley.rangley_s_insert_meet" or your search_path includes 'rangley'
        
        struct Params: Content, Sendable
        {
            // Required
            let cognito_sub             : String
            let initial_invitee_uuids   : [UUID]
            let latitude                : Double
            let longitude               : Double
            let region_latitude         : Double
            let region_longitude        : Double
            let region_radius           : Double
            let name                    : String          // p_name
            let dttm_start_utc          : Date
            let dttm_end_utc            : Date

            // Optional
            let description             : String?         // p_description
            let meet_category_id        : Int16?          // p_meet_category_id
            let max_capacity            : Int32?          // p_max_capacity
            let invitation_message      : String?         // p_description
        }

        struct Result: Content, Sendable
        {
            let num_inserted        : Int32
            let new_meet_id_uuid    : UUID?
            let validation_failed   : Bool
            let validation_reason   : String?
            let validation_message  : String?
        }

        static func query(_ i: Params, _ o: Result) -> SQLQueryString
        {
            """
            CALL \(unsafeRaw: procName.rawValue)
            (

                 NULL::int4  -- OUT parameter placeholder
                ,NULL::UUID -- OUT
                ,NULL::boolean  -- OUT validation_failed
                ,NULL::text     -- OUT validation_reason
                ,NULL::text     -- OUT validation_message
                ,\(bind: i.cognito_sub                )::text
                ,\(bind: i.initial_invitee_uuids      )::UUID[]
                ,\(bind: i.latitude                   )::float8
                ,\(bind: i.longitude                  )::float8
                ,\(bind: i.region_latitude            )::float8
                ,\(bind: i.region_longitude           )::float8
                ,\(bind: i.region_radius              )::float8
                ,\(bind: i.name                       )::varchar(50)
                ,\(bind: i.dttm_start_utc             )::timestamptz
                ,\(bind: i.dttm_end_utc               )::timestamptz
                -- OPTIONAL
                ,COALESCE(\(bind: i.description       ), ''::varchar(50))::varchar(50)
                ,COALESCE(\(bind: i.meet_category_id  ), 1::int2)::int2
                ,COALESCE(\(bind: i.max_capacity      ), 2::int4)::int4
                ,COALESCE(\(bind: i.invitation_message), ''::text)::text
            );
            """
        }

        static func decode(_ row: any SQLRow) throws -> Result
        {
            try .init(
                num_inserted: row.decode(column: "num_inserted", as: Int32.self),
                new_meet_id_uuid: row.decode(column: "new_meet_id_uuid", as: UUID?.self),
                validation_failed: row.decode(column: "validation_failed", as: Bool.self),
                validation_reason: row.decode(column: "validation_reason", as: String?.self),
                validation_message: row.decode(column: "validation_message", as: String?.self)
            )
        }
    }
    
    // =========================================================
    // MARK: - END Transaction Level Meet Inserts w/ Invites
    // =========================================================
    
    
    // MARK: - END INSERT
    

    //TODO: - FINISH DELETE USER
    enum SystemDeleteUser: PgCallableRow
    {
        static let procName: RangleyProcName = .d_user  // ensure this resolves to schema-qualified "rangley.rangley_s_insert_meet" or your search_path includes 'rangley'
        
        struct In: Content, Sendable {
            // Required
            let cognito_sub     : String
        }

        struct Out: Content, Sendable
        {
            let is_success    : Bool
        }

        static func query(_ i: In, _ o: Out) -> SQLQueryString {
            """
            CALL \(unsafeRaw: procName.rawValue)
            (
                 NULL::BOOLEAN -- OUT
                ,\(bind: i.cognito_sub)::text
            );
            """
        }

        static func decode(_ row: any SQLRow) throws -> Out {
            try .init(
                is_success: row.decode(column: "is_success", as: Bool.self)

            )
        }
    }
    
    
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


// MARK: - JSON model returned for owners
struct ParticipantDetail: Codable, Sendable
{
    let user_uuid: String
    let display_name: String
    let participant_status_id: Int16
}



private enum RowJSON
{
    static func decodeArray<T: Decodable>(_ row: any SQLRow, column: String) throws -> [T]? {
        // String -> Data -> JSON
        do {
            let sOpt = try row.decode(column: column, as: String?.self)
            if let s = sOpt {
                let data = Data(s.utf8)
                return try JSONDecoder().decode([T].self, from: data)
            }
        } catch {
            // Try next approach
        }

        // ByteBuffer -> Data -> JSON
        do {
            let bufOpt = try row.decode(column: column, as: ByteBuffer?.self)
            if var buf = bufOpt {
                let data = buf.readData(length: buf.readableBytes) ?? Data()
                if data.isEmpty { return [] }
                return try JSONDecoder().decode([T].self, from: data)
            }
        } catch {
            // Try next approach
        }

        // Data -> JSON (some drivers return jsonb as Data)
        do {
            let dataOpt = try row.decode(column: column, as: Data?.self)
            if let data = dataOpt {
                if data.isEmpty { return [] }
                return try JSONDecoder().decode([T].self, from: data)
            }
        } catch {
            // Try next approach
        }

        // NULL column
        return nil
    }
}


enum Func
{
    // =========================================================
    // MARK: - Transaction Level Meet View
    // =========================================================

    enum ViewMeets: PgFunctionRows
    {
        // Protocol associated types
        typealias Input  = In
        typealias Output = Results

        static let funcName: RangleyFunc = .v_meets_by_cognito_sub

        struct In: Sendable { let cognitoSub: String }

        struct Results: Content, Sendable {
            let meet_id_uuid         : String
            let meet_status_id       : Int16
            let change_stamp         : Int64
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
            // New columns:
            let participant_details  : [ParticipantDetail]? // nil for non-owners; [] for owners with none
            let accepted_count       : Int32
            let current_user_participant_status : Int16?
        }

        static func query(_ input: In) -> SQLQueryString {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.cognitoSub)::text);"
        }

        static func decode(_ row: any SQLRow) throws -> Results {
            let details: [ParticipantDetail]? = try RowJSON.decodeArray(row, column: "participant_details")
            return try .init(
                meet_id_uuid         : row.decode(column: "meet_id_uuid",         as: String.self),
                meet_status_id       : row.decode(column: "meet_status_id",       as: Int16.self),
                change_stamp         : row.decode(column: "change_stamp",         as: Int64.self),
                latitude             : row.decode(column: "latitude",             as: Double.self),
                longitude            : row.decode(column: "longitude",            as: Double.self),
                region_latitude      : row.decode(column: "region_latitude",      as: Double.self),
                region_longitude     : row.decode(column: "region_longitude",     as: Double.self),
                region_radius        : row.decode(column: "region_radius",        as: Double.self),
                dttm_start_utc       : row.decode(column: "dttm_start_utc",       as: Date.self),
                dttm_end_utc         : row.decode(column: "dttm_end_utc",         as: Date.self),
                name                 : row.decode(column: "name",                 as: String.self),
                category_name        : row.decode(column: "category_name",        as: String.self),
                meet_category_id     : row.decode(column: "meet_category_id",     as: Int16.self),
                description          : row.decode(column: "description",          as: String.self),
                max_capacity         : row.decode(column: "max_capacity",         as: Int32.self),
                created_by_user_uuid : row.decode(column: "created_by_user_uuid", as: String.self),
                display_name         : row.decode(column: "display_name",         as: String.self),
                is_owner             : row.decode(column: "is_owner",             as: Bool.self),
                participant_details  : details,
                accepted_count       : row.decode(column: "accepted_count",       as: Int32.self),
                current_user_participant_status       : row.decode(column: "current_user_participant_status",       as: Int16?.self)
            )
        }

        // Convenience
        static func fetchAll(on db: any SQLDatabase, sub: String) async throws -> [Results] {
            try await fetchAll(on: db, .init(cognitoSub: sub))
        }
    }
    

    // TODO: remove deprecated when update is complete
    enum ViewUserInboxNotificationsDep: PgFunctionRows
    {
        static let funcName: RangleyFunc = .v_user_inbox_notifications_by_cognito_sub

        struct In: Sendable { let cognitoSub: String }
        
        struct Results: Content, Sendable
        {
            let notification_id                 : Int64
            let notification_type_id            : Int16
            let notification_name               : String
            let participant_status_id           : Int16
            let meet_id_uuid                    : UUID
            let creator_display_name            : String?  // Can be NULL from LEFT JOIN
            let payload_json                    : Data?  // Store as raw JSON Data (Sendable)
            let dttm_notification_created_utc   : Date
            let dttm_received_utc               : Date
            let dttm_opened_utc                 : Date?  // Can be NULL (unread notifications)
            let is_read                         : Bool
        }

        static func query(_ input: In) -> SQLQueryString {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.cognitoSub)::text);"
        }

        static func decode(_ r: any SQLRow) throws -> Results {
            try .init(
                 notification_id                : r.decode(column: "notification_id", as: Int64.self)
                ,notification_type_id           : r.decode(column: "notification_type_id", as: Int16.self)
                ,notification_name              : r.decode(column: "notification_name", as: String.self)
                ,participant_status_id          : r.decode(column: "participant_status_id", as: Int16.self)
                ,meet_id_uuid                   : r.decode(column: "meet_id_uuid", as: UUID.self)
                ,creator_display_name           : r.decode(column: "creator_display_name", as: String?.self)  // Optional
                ,payload_json                   : r.decode(column: "payload_json", as: Data?.self)  // Raw JSON Data
                ,dttm_notification_created_utc  : r.decode(column: "dttm_notification_created_utc", as: Date.self)
                ,dttm_received_utc              : r.decode(column: "dttm_received_utc", as: Date.self)
                ,dttm_opened_utc                : r.decode(column: "dttm_opened_utc", as: Date?.self)  // Optional
                ,is_read                        : r.decode(column: "is_read", as: Bool.self)
            )
        }


        static func fetchAll(on db: any SQLDatabase, sub: String) async throws -> [Results] {
            try await fetchAll(on: db, .init(cognitoSub: sub))
        }
    }
    
    
    enum SystemRespondToMeetInvitation: PgFunctionRow
    {
        static let funcName: RangleyFunc = .m_respond_to_meet_invitation

        struct In: Sendable
        {
            let cognito_sub       : String
            let meet_id_uuid      : UUID
            let response_status_id: Int16
        }

        struct Results: Content, Sendable
        {
            let success             : Bool
            let message             : String
            let participant_id_out  : Int64?
            let old_status_id       : Int16?
            let new_status_id       : Int16?
        }

        static func query(_ input: In) -> SQLQueryString
        {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.cognito_sub)::text, \(bind: input.meet_id_uuid)::uuid, \(bind: input.response_status_id)::int2);"
        }

        static func decode(_ r: any SQLRow) throws -> Results
        {
            try .init(
                success           : r.decode(column: "success"           , as: Bool.self),
                message           : r.decode(column: "message"           , as: String.self),
                participant_id_out: r.decode(column: "participant_id_out", as: Int64?.self),
                old_status_id     : r.decode(column: "old_status_id"     , as: Int16?.self),
                new_status_id     : r.decode(column: "new_status_id"     , as: Int16?.self)
            )
        }


    }
    
    enum UpdateParticipantStatus: PgFunctionRow
    {
        static let funcName: RangleyFunc = .m_update_participant_status

        struct In: Sendable
        {
            let cognito_sub       : String
            let meet_id_uuid        : UUID
            let target_user_uuid    : UUID
            let new_status_id       : Int16  // 3=Maybe, 5=Declined, 6=Accepted 8=Left 9 = removed
        }

        struct Results: Content, Sendable
        {
            let success             : Bool
            let message             : String
            let participant_id_out  : Int64?
            let old_status_id       : Int16?
            let new_status_id       : Int16?
        }

        static func query(_ input: In) -> SQLQueryString
        {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.cognito_sub)::text, \(bind: input.meet_id_uuid)::uuid, \(bind: input.target_user_uuid)::uuid, \(bind: input.new_status_id)::int2);"
        }

        static func decode(_ r: any SQLRow) throws -> Results
        {
            try .init(
                success           : r.decode(column: "success"           , as: Bool.self),
                message           : r.decode(column: "message"           , as: String.self),
                participant_id_out: r.decode(column: "participant_id_out", as: Int64?.self),
                old_status_id     : r.decode(column: "old_status_id"     , as: Int16?.self),
                new_status_id     : r.decode(column: "new_status_id"     , as: Int16?.self)
            )
        }


    }
    
    enum InsertAdditionalParticipantsToMeet: PgFunctionRow
    {
        static let funcName: RangleyFunc = .i_additional_participants_to_meet

        struct In: Sendable
        {
            let cognito_sub                     : String
            let meet_id_uuid                    : UUID
            let inviter_user_uuid               : UUID
            let additional_invitee_user_uuids    : [UUID]
            let invitation_message              : String?
            
        }

        struct Results: Content, Sendable
        {
            let user_uuid                   : UUID
            let username                    : String
            let invitation_status           : String?
            let returned_notification_id    : Int64?
        }

        static func query(_ input: In) -> SQLQueryString
        {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.cognito_sub)::TEXT, \(bind: input.meet_id_uuid)::UUID, \(bind: input.inviter_user_uuid)::UUID,\(bind: input.additional_invitee_user_uuids)::UUID[], \(bind: input.invitation_message)::TEXT);"
        }

        static func decode(_ r: any SQLRow) throws -> Results
        {
            try .init(
                user_uuid                   : r.decode(column: "user_uuid"                    ,as: UUID.self),
                username                    : r.decode(column: "username"                     ,as: String.self),
                invitation_status           : r.decode(column: "invitation_status"            ,as: String?.self),
                returned_notification_id    : r.decode(column: "returned_notification_id"     ,as: Int64?.self)
            )
        }


    }

    // TODO: remove deprecated when update is complete
    enum ViewUserDeprecated: PgFunctionRows
    {
        static let funcName: RangleyFunc = .v_user_by_cognito_sub_dep  // or .v_user_clean

        struct Param: Content, Sendable
        {
            let cognito_sub: String
        }

        struct Results: Content, Sendable
        {
            let user_uuid           : UUID
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
                user_uuid           : r.decode(column: "user_uuid",         as: UUID.self),
                username            : r.decode(column: "username",          as: String.self),
                display_name        : r.decode(column: "display_name",      as: String.self),
                cellphone           : r.decode(column: "cellphone",         as: String?.self),
                email               : r.decode(column: "email",             as: String?.self),
                dob                 : r.decode(column: "dob",               as: Date.self),
                dttm_created_utc    : r.decode(column: "dttm_created_utc",  as: Date.self)
            )
        }
        static func fetchOne(on sql: any SQLDatabase, _ input: In) async throws -> Results {
            let rows = try await fetchAll(on: sql, input)
            guard let first = rows.first else { throw Abort(.notFound, reason: "User not found") }
            return first
        }
        
    }
    
    enum ViewUserNew: PgFunctionRows
    {
        static let funcName: RangleyFunc = .v_user_by_cognito_sub_new  // or .v_user_clean

        struct Param: Content, Sendable
        {
            let cognito_sub: String
        }

        struct Results: Content, Sendable
        {
            let user_uuid           : UUID
            let username            : String
            let display_name        : String
            let cellphone           : String?
            let email               : String?
            let dob                 : String
            let dttm_created_utc    : Date
        }
        
        struct In: Sendable { let cognito_sub: String }

        static func query(_ input: In) -> SQLQueryString {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.cognito_sub));"
        }

        static func decode(_ r: any SQLRow) throws -> Results
        {
            try .init(
                user_uuid           : r.decode(column: "user_uuid",         as: UUID.self),
                username            : r.decode(column: "username",          as: String.self),
                display_name        : r.decode(column: "display_name",      as: String.self),
                cellphone           : r.decode(column: "cellphone",         as: String?.self),
                email               : r.decode(column: "email",             as: String?.self),
                dob                 : r.decode(column: "dob",               as: String.self),
                dttm_created_utc    : r.decode(column: "dttm_created_utc",  as: Date.self)
            )
        }
        static func fetchOne(on sql: any SQLDatabase, _ input: In) async throws -> Results {
            let rows = try await fetchAll(on: sql, input)
            guard let first = rows.first else { throw Abort(.notFound, reason: "User not found") }
            return first
        }
    }


    
    enum ViewUsers: PgFunctionRows
    {
        static let funcName: RangleyFunc = .v_users_by_cognito_sub

        // Inputs (server injects cognito_sub; arrays are optional)
        struct In: Sendable
        {
            let cognito_sub: String
            let usernames: [String]?
            let emails: [String]?
            let phones: [String]?   // raw strings; DB side normalizes
        }

        // Row shape returned by the function
        // In ViewUsers enum
        struct Results: Content, Sendable
        {
            let user_uuid   : UUID        // Changed from String to UUID
            let username    : String
            let display_name: String
            let matched_by  : [String]
            let can_invite  : Bool
        }


        static func query(_ input: In) -> SQLQueryString
        {
            // SELECT * FROM rangley_fn_v_users_by_cognito_sub($1,$2,$3,$4)
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(" +
                "\(bind: input.cognito_sub)," +
                "\(bind: input.usernames)," +
                "\(bind: input.emails)," +
                "\(bind: input.phones)" +
            ");"
        }

        static func decode(_ r: any SQLRow) throws -> Results {
            try .init(
                user_uuid   : r.decode(column: "user_uuid",   as: UUID.self),  // Changed to UUID.self
                username    : r.decode(column: "username",    as: String.self),
                display_name: r.decode(column: "display_name",as: String.self),
                matched_by  : r.decode(column: "matched_by",  as: [String].self),
                can_invite  : r.decode(column: "can_invite",  as: Bool.self)
            )
        }
    }

    enum ViewUserProfile: PgFunctionRows
    {
        static let funcName: RangleyFunc = .view_user_profile_by_uuid

        struct In: Sendable
        {
            let user_uuid: UUID
        }

        struct Results: Content, Sendable
        {
            let user_uuid                   : UUID
            let username                    : String
            let display_name                : String
            let member_since                : Date
            let meets_created               : Int
            let meets_attended              : Int
            let friend_count                : Int
            let discoverable_by_username    : Bool
            let discoverable_by_phone       : Bool
            let discoverable_by_email       : Bool
            let show_full_name              : Bool
            let allow_invites_from_anyone   : Bool
        }

        static func query(_ input: In) -> SQLQueryString
        {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.user_uuid));"
        }

        static func decode(_ r: any SQLRow) throws -> Results
        {
            try .init(
                user_uuid:                r.decode(column: "user_uuid",                 as: UUID.self),
                username:                 r.decode(column: "username",                  as: String.self),
                display_name:             r.decode(column: "display_name",              as: String.self),
                member_since:             r.decode(column: "member_since",              as: Date.self),
                meets_created:            r.decode(column: "meets_created",             as: Int.self),
                meets_attended:           r.decode(column: "meets_attended",            as: Int.self),
                friend_count:             r.decode(column: "friend_count",              as: Int.self),
                discoverable_by_username: r.decode(column: "discoverable_by_username",  as: Bool.self),
                discoverable_by_phone:    r.decode(column: "discoverable_by_phone",     as: Bool.self),
                discoverable_by_email:    r.decode(column: "discoverable_by_email",     as: Bool.self),
                show_full_name:           r.decode(column: "show_full_name",            as: Bool.self),
                allow_invites_from_anyone:r.decode(column: "allow_invites_from_anyone", as: Bool.self)
            )
        }
    }
    
    // MARK: - Send Friend Request
    enum SendFriendRequest: PgFunctionRows
    {
        static let funcName: RangleyFunc = .send_friend_request
        
        struct In: Sendable
        {
            let cognito_sub         : String
            let recipient_user_uuid : UUID
        }
        
        struct Results: Content, Sendable
        {
            let friend_request_id   : Int64?
            let success             : Bool
            let message             : String
        }
        
        static func query(_ input: In) -> SQLQueryString
        {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.cognito_sub), \(bind: input.recipient_user_uuid));"
        }
        
        static func decode(_ r: any SQLRow) throws -> Results {
            try .init(
                friend_request_id: r.decode(column: "friend_request_id", as: Int64?.self),
                success: r.decode(column: "success", as: Bool.self),
                message: r.decode(column: "message", as: String.self)
            )
        }
    }

    // MARK: - Respond to Friend Request
    enum RespondToFriendRequest: PgFunctionRows
    {
        static let funcName: RangleyFunc = .respond_to_friend_request
        
        struct In: Sendable
        {
            let cognito_sub         : String
            let friend_request_id   : Int64
            let accept              : Bool
        }
        
        struct Results: Content, Sendable
        {
            let success: Bool
            let message: String
        }
        
        static func query(_ input: In) -> SQLQueryString
        {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.cognito_sub), \(bind: input.friend_request_id), \(bind: input.accept));"
        }
        
        static func decode(_ r: any SQLRow) throws -> Results {
            try .init(
                success: r.decode(column: "success", as: Bool.self),
                message: r.decode(column: "message", as: String.self)
            )
        }
    }

    // MARK: - Get User Inbox
    enum ViewUserInbox: PgFunctionRows
    {
        static let funcName: RangleyFunc = .view_user_inbox
        
        struct In: Sendable
        {
            let cognito_sub: String
            let limit: Int16
        }
        
        struct Results: Content, Sendable
        {
            let notification_id         : Int64
            let notification_type_id    : Int16
            let notification_type       : String
            let meet_id_uuid            : UUID?
            let created_by_user_uuid    : UUID
            let created_by_username     : String
            let created_by_display_name : String
            let payload_json            : String  // JSONB as String, decode client-side
            let dttm_created_utc        : Date
            let dttm_received_utc       : Date
            let dttm_opened_utc         : Date?
            let is_read                 : Bool
        }
        
        static func query(_ input: In) -> SQLQueryString
        {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.cognito_sub), \(bind: input.limit));"
        }
        
        static func decode(_ r: any SQLRow) throws -> Results {
            try .init(
                notification_id:        r.decode(column: "notification_id",         as: Int64.self),
                notification_type_id:   r.decode(column: "notification_type_id",    as: Int16.self),
                notification_type:      r.decode(column: "notification_type",       as: String.self),
                meet_id_uuid:           r.decode(column: "meet_id_uuid",            as: UUID?.self),
                created_by_user_uuid:   r.decode(column: "created_by_user_uuid",    as: UUID.self),
                created_by_username:    r.decode(column: "created_by_username",     as: String.self),
                created_by_display_name:r.decode(column: "created_by_display_name", as: String.self),
                payload_json:           r.decode(column: "payload_json",            as: String.self),
                dttm_created_utc:       r.decode(column: "dttm_created_utc",        as: Date.self),
                dttm_received_utc:      r.decode(column: "dttm_received_utc",       as: Date.self),
                dttm_opened_utc:        r.decode(column: "dttm_opened_utc",         as: Date?.self),
                is_read:                r.decode(column: "is_read",                 as: Bool.self)
            )
        }
    }
    
    enum ClearUserInbox: PgFunctionRows
    {
        static let funcName: RangleyFunc = .clear_user_inbox
        
        struct In: Sendable
        {
            let cognito_sub: String
        }
        
        struct Results: Content, Sendable
        {
            let success      : Bool
            let message      : String
            let cleared_count: Int32
        }
        
        static func query(_ input: In) -> SQLQueryString {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.cognito_sub));"
        }
        
        static func decode(_ r: any SQLRow) throws -> Results {
            try .init(
                success      : r.decode(column: "success",       as: Bool.self),
                message      : r.decode(column: "message",       as: String.self),
                cleared_count: r.decode(column: "cleared_count", as: Int32.self)
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
    
    enum ViewAppVersion : PgFunctionRows
    {
        
        static let funcName: RangleyFunc = .v_app_version
        
        struct In: Sendable
        {
            let app_version : Int32
        }

        struct Results: Content, Sendable
        {
            let is_supported           : Bool
            let latest_version         : Int32
            let supported_features     : [Int32]?
        }
        
        static func query(_ input: In) -> SQLQueryString
        {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.app_version)::int4);"
        }

        static func decode(_ r: any SQLRow) throws -> Results
        {
            try .init(
                is_supported      : r.decode(column: "is_supported"      , as: Bool.self),
                latest_version    : r.decode(column: "latest_version"    , as: Int32.self),
                supported_features: r.decode(column: "supported_features", as: [Int32]?.self)
            )
        }

        
    }

    
    enum CheckUsernameAvailability: PgFunctionRow
    {
        static let funcName: RangleyFunc = .check_username_availability

        struct In: Content, Sendable
        {
            let username: String
        }

        struct Results: Content, Sendable
        {
            let available: Bool
            let reason: String
            let message: String
        }

        static func query(_ input: In) -> SQLQueryString
        {
            "SELECT \(unsafeRaw: funcName.rawValue)(\(bind: input.username)::TEXT) as result;"
        }

        static func decode(_ r: any SQLRow) throws -> Results
        {
            // The function returns JSON, so we need to decode it
            let jsonData = try r.decode(column: "result", as: Data.self)
            let jsonResponse = try JSONDecoder().decode(JSONResponse.self, from: jsonData)
            
            return Results(
                available: jsonResponse.available,
                reason: jsonResponse.reason,
                message: jsonResponse.message
            )
        }
        
        // Helper struct for JSON decoding
        private struct JSONResponse: Codable
        {
            let available: Bool
            let reason: String
            let message: String
        }
        
        // Convenience method
        static func call(on db: any SQLDatabase, username: String) async throws -> Results {
            try await call(on: db, In(username: username))
        }
    }

    enum ValidateDisplayName: PgFunctionRow
    {
        static let funcName: RangleyFunc = .validate_display_name

        struct In: Content, Sendable
        {
            let display_name: String
        }

        struct Results: Content, Sendable
        {
            let valid: Bool
            let reason: String
            let message: String
        }

        static func query(_ input: In) -> SQLQueryString
        {
            "SELECT \(unsafeRaw: funcName.rawValue)(\(bind: input.display_name)::TEXT) as result;"
        }

        static func decode(_ r: any SQLRow) throws -> Results
        {
            // The function returns JSON, so we need to decode it
            let jsonData = try r.decode(column: "result", as: Data.self)
            let jsonResponse = try JSONDecoder().decode(JSONResponse.self, from: jsonData)
            
            return Results(
                valid: jsonResponse.valid,
                reason: jsonResponse.reason,
                message: jsonResponse.message
            )
        }
        
        // Helper struct for JSON decoding
        private struct JSONResponse: Codable
        {
            let valid: Bool
            let reason: String
            let message: String
        }
        
        // Convenience method
        static func call(on db: any SQLDatabase, displayName: String) async throws -> Results {
            try await call(on: db, In(display_name: displayName))
        }
    }

    // You'll also need to add these to your RangleyFunc enum:
    /*
    extension RangleyFunc {
        static let fn_check_username_availability = RangleyFunc(rawValue: "fn_check_username_availability")
        static let fn_validate_display_name = RangleyFunc(rawValue: "fn_validate_display_name")
    }
    */
    
    // =========================================================
    // MARK: - END Transaction Level Meet View
    // =========================================================
}
