//
//  procedures.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 8/27/25.
//

import Vapor
import Fluent
import SQLKit

// MARK: - Registry of fully-qualified procedure names

enum RangleyProcName: String
{
    case i_user              = "rangley.rangley_i_user"
    case i_meet              = "rangley.rangley_i_meet"
    case i_meet_change_stamp = "rangley.rangley_i_meet_change_stamp"
    case i_meet_coordinate   = "rangley.rangley_i_meet_coordinate"
    case i_meet_id           = "rangley.rangley_i_meet_id"
    case i_updated_meet      = "rangley.rangley_i_updated_meet"
    case m_user              = "rangley.rangley_m_user"
}

enum RangleyFunc: String
{
    case v_user              = "rangley.rangley_fn_v_user"
    case v_meets             = "rangley.rangley_fn_v_meets"
    case v_meet_categories   = "rangley.rangley_fn_v_meet_categories"
}

// MARK: - Generic call shapes

protocol PgCallableRow
{
    associatedtype Input: Sendable
    associatedtype Output: Content & Sendable
    static var procName: RangleyProcName { get }
    static func query(_ input: Input) -> SQLQueryString
    static func decode(_ row: any SQLRow) throws -> Output
}

extension PgCallableRow
{
    @discardableResult
    static func call(on db: any SQLDatabase, _ input: Input) async throws -> Output {
        let rows = try await db.raw(query(input)).all()
        guard let row = rows.first else {
            throw Abort(.internalServerError, reason: "\(procName.rawValue) returned no row")
        }
        return try decode(row)
    }
}

protocol PgCallableNoRow
{
    associatedtype Input: Sendable
    static var procName: RangleyProcName { get }
    static func query(_ input: Input) -> SQLQueryString
}

extension PgCallableNoRow
{
    static func exec(on db: any SQLDatabase, _ input: Input) async throws {
        _ = try await db.raw(query(input)).all()  // CALL without OUT returns no row; ignore result
    }
}

// MARK: - Procs

enum Proc
{


    // MARK: - INSERT
    
    // MARK: i_user (INOUT num_inserted, INOUT new_user_id) -> row
    struct InsertUserIn: Content, Sendable
    {
        let username   : String
        let first_name : String
        let last_name  : String
        let cellphone  : String
        let email      : String
    }
    
    struct InsertUserOut: Content, Sendable
    {
        let num_inserted: Int
        let new_user_id : Int
    }
    
    enum InsertUser: PgCallableRow
    {
        static let procName: RangleyProcName = .i_user
        static func query(_ i: InsertUserIn) -> SQLQueryString {
            """
            CALL \(unsafeRaw: procName.rawValue)(
                \(bind: i.username),
                \(bind: i.first_name),
                \(bind: i.last_name),
                \(bind: i.cellphone),
                \(bind: i.email),
                NULL,  -- INOUT num_inserted
                NULL   -- INOUT new_user_id
            );
            """
        }
        static func decode(_ row: any SQLRow) throws -> InsertUserOut {
            try .init(
                num_inserted: row.decode(column: "num_inserted", as: Int.self),
                new_user_id : row.decode(column: "new_user_id",  as: Int.self)
            )
        }
    }
    
    // MARK: i_meet (no OUT) -> no row
    struct InsertMeetIn: Content, Sendable
    {
        let meet_id         : Int64?   // p_meet_id
        let change_stamp    : Int64    // p_change_stamp (DEFAULT 0 on PG side, but pass explicit)
        let name            : String?   // p_name
        let description     : String?   // p_description
        let change_reason   : String?   // p_change_reason
        let meet_category_id: Int32?    // p_meet_category_id
    }
    
    enum InsertMeet: PgCallableNoRow
    {
        static let procName: RangleyProcName = .i_meet
        static func query(_ i: InsertMeetIn) -> SQLQueryString {
            """
            CALL \(unsafeRaw: procName.rawValue)(
                \(bind: i.meet_id),
                \(bind: i.change_stamp),
                \(bind: i.name),
                \(bind: i.description),
                \(bind: i.change_reason),
                \(bind: i.meet_category_id)
            );
            """
        }
    }

    // MARK: i_meet_change_stamp (OUT new_change_stamp) -> row
    struct InsertMeetChangeStampIn: Content, Sendable
    {
        let meet_id      : Int64
        let meet_status_id: Int32
    }
    
    struct InsertMeetChangeStampOut: Content, Sendable
    {
        let new_change_stamp: Int64
    }
    
    enum InsertMeetChangeStamp: PgCallableRow
    {
        static let procName: RangleyProcName = .i_meet_change_stamp
        static func query(_ i: InsertMeetChangeStampIn) -> SQLQueryString {
            // OUT params are NOT passed
            """
            CALL \(unsafeRaw: procName.rawValue)(
                \(bind: i.meet_id),
                \(bind: i.meet_status_id)
            );
            """
        }
        static func decode(_ row: any SQLRow) throws -> InsertMeetChangeStampOut {
            try .init(
                new_change_stamp: row.decode(column: "new_change_stamp", as: Int64.self)
            )
        }
    }

    // MARK: i_meet_coordinate (OUT new_meet_coordinate_id) -> row
    struct InsertMeetCoordinateIn: Content, Sendable
    {
        let latitude        : Double
        let longitude       : Double
        let region_latitude : Double
        let region_longitude: Double
        let region_radius   : Double
    }
    
    struct InsertMeetCoordinateOut: Content, Sendable
    {
        let new_meet_coordinate_id: Int64
    }
    
    enum InsertMeetCoordinate: PgCallableRow
    {
        static let procName: RangleyProcName = .i_meet_coordinate
        static func query(_ i: InsertMeetCoordinateIn) -> SQLQueryString {
            """
            CALL \(unsafeRaw: procName.rawValue)(
                \(bind: i.latitude),
                \(bind: i.longitude),
                \(bind: i.region_latitude),
                \(bind: i.region_longitude),
                \(bind: i.region_radius)
            );
            """
        }
        static func decode(_ row: any SQLRow) throws -> InsertMeetCoordinateOut {
            try .init(
                new_meet_coordinate_id: row.decode(column: "new_meet_coordinate_id", as: Int64.self)
            )
        }
    }

    // MARK: i_meet_id (OUT new_meet_id) -> row
    struct InsertMeetIdIn: Content, Sendable
    {
        let meet_address_id  : Int64
        let created_by_user_id: Int64
    }
    
    struct InsertMeetIdOut: Content, Sendable
    {
        let new_meet_id: Int64
    }
    
    enum InsertMeetId: PgCallableRow
    {
        static let procName: RangleyProcName = .i_meet_id
        static func query(_ i: InsertMeetIdIn) -> SQLQueryString {
            """
            CALL \(unsafeRaw: procName.rawValue)(
                \(bind: i.meet_address_id),
                \(bind: i.created_by_user_id)
            );
            """
        }
        static func decode(_ row: any SQLRow) throws -> InsertMeetIdOut {
            try .init(
                new_meet_id: row.decode(column: "new_meet_id", as: Int64.self)
            )
        }
    }

    // MARK: i_updated_meet (INOUT num_inserted) -> row
    struct InsertUpdatedMeetIn: Content, Sendable
    {
        let meet_id        : Int64?
        let change_stamp   : Int64?
        let meet_status_id : Int32?
        let name           : String?
        let description    : String?
        let change_reason  : String?
        let meet_category_id: Int32?
        let max_capacity   : Int32? // PG default 2 if nil
    }
    
    struct InsertUpdatedMeetOut: Content, Sendable
    {
        let num_inserted: Int
    }
    
    enum InsertUpdatedMeet: PgCallableRow
    {
        static let procName: RangleyProcName = .i_updated_meet
        static func query(_ i: InsertUpdatedMeetIn) -> SQLQueryString {
            """
            CALL \(unsafeRaw: procName.rawValue)(
                \(bind: i.meet_id),
                \(bind: i.change_stamp),
                \(bind: i.meet_status_id),
                \(bind: i.name),
                \(bind: i.description),
                \(bind: i.change_reason),
                \(bind: i.meet_category_id),
                \(bind: i.max_capacity),
                NULL  -- INOUT num_inserted
            );
            """
        }
        static func decode(_ row: any SQLRow) throws -> InsertUpdatedMeetOut {
            try .init(
                num_inserted: row.decode(column: "num_inserted", as: Int.self)
            )
        }
    }
    
    // MARK: - END INSERT
    

    
    
    
    // MARK: - MODIFY
    
    // MARK: m_user (no OUT) -> no row
    struct ModifyUserIn: Content, Sendable
    {
        let user_id   : Int64
        let username  : String?
        let first_name: String?
        let last_name : String?
        let cellphone : String?
        let email     : String?
    }
    
    enum ModifyUser: PgCallableNoRow
    {
        static let procName: RangleyProcName = .m_user
        static func query(_ i: ModifyUserIn) -> SQLQueryString {
            """
            CALL \(unsafeRaw: procName.rawValue)(
                \(bind: i.user_id),
                \(bind: i.username),
                \(bind: i.first_name),
                \(bind: i.last_name),
                \(bind: i.cellphone),
                \(bind: i.email)
            );
            """
        }
    }
    
    // MARK: - END MODIFY


}


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

enum Func
{
    // MARK: - VIEWS

    // vw_meet_card_data-style payload (assumes rangley_fn_v_meets() returns these columns)
    struct MeetCardData: Content, Sendable
    {
        let meet_id            : Int32
        let change_stamp       : Int32
        let meet_status_id     : Int32
        let latitude           : Double
        let longitude          : Double
        let region_latitude    : Double
        let region_longitude   : Double
        let dttm_start_utc     : Date
        let dttm_end_utc       : Date
        let name               : String
        let category_name      : String
        let description        : String
        let max_capacity       : Int32
        let created_by_user_id : Int32
        let first_name         : String
        let last_name          : String
    }

    enum ViewMeets: PgFunctionRows
    {
        static let funcName: RangleyFunc = .v_meets

        struct In: Sendable { }  // no params

        static func query(_ input: In) -> SQLQueryString {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)();"
        }

        static func decode(_ r: any SQLRow) throws -> MeetCardData {
            try .init(
                meet_id           : r.decode(column: "meet_id",            as: Int32.self),
                change_stamp      : r.decode(column: "change_stamp",       as: Int32.self),
                meet_status_id    : r.decode(column: "meet_status_id",     as: Int32.self),
                latitude          : r.decode(column: "latitude",           as: Double.self),
                longitude         : r.decode(column: "longitude",          as: Double.self),
                region_latitude   : r.decode(column: "region_latitude",    as: Double.self),
                region_longitude  : r.decode(column: "region_longitude",   as: Double.self),
                dttm_start_utc    : r.decode(column: "dttm_start_utc",     as: Date.self),
                dttm_end_utc      : r.decode(column: "dttm_end_utc",       as: Date.self),
                name              : r.decode(column: "name",               as: String.self),
                category_name     : r.decode(column: "category_name",      as: String.self),
                description       : r.decode(column: "description",        as: String.self),
                max_capacity      : r.decode(column: "max_capacity",       as: Int32.self),
                created_by_user_id: r.decode(column: "created_by_user_id", as: Int32.self),
                first_name        : r.decode(column: "first_name",         as: String.self),
                last_name         : r.decode(column: "last_name",          as: String.self)
            )
        }

        // convenience
        static func fetchAll(on db: any SQLDatabase) async throws -> [MeetCardData] {
            try await fetchAll(on: db, In())
        }
    }

    struct ViewUserIn: Content, Sendable
    {
        let user_id: Int64
    }

    struct ViewUserOut: Content, Sendable
    {
        let username  : String?
        let first_name: String?
        let last_name : String?
        let cellphone : String?
        let email     : String?
    }

    enum ViewUser: PgFunctionRow
    {
        static let funcName: RangleyFunc = .v_user

        static func query(_ i: ViewUserIn) -> SQLQueryString {
            """
            SELECT *
            FROM \(unsafeRaw: funcName.rawValue)(\(bind: i.user_id));
            """
        }

        static func decode(_ r: any SQLRow) throws -> ViewUserOut {
            try .init(
                username  : r.decode(column: "username",   as: String?.self),
                first_name: r.decode(column: "first_name", as: String?.self),
                last_name : r.decode(column: "last_name",  as: String?.self),
                cellphone : r.decode(column: "cellphone",  as: String?.self),
                email     : r.decode(column: "email",      as: String?.self)
            )
        }
    }

    struct ViewMeetCategory: Content, Sendable
    {
        let meet_category_id: Int32
        let name            : String
    }

    enum ViewMeetCategories: PgFunctionRows
    {
        static let funcName: RangleyFunc = .v_meet_categories

        struct In: Sendable { }  // no params

        static func query(_ input: In) -> SQLQueryString {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)();"
        }

        static func decode(_ r: any SQLRow) throws -> ViewMeetCategory {
            try .init(
                meet_category_id: r.decode(column: "meet_category_id", as: Int32.self),
                name            : r.decode(column: "name",             as: String.self)
            )
        }

        // convenience
        static func fetchAll(on db: any SQLDatabase) async throws -> [ViewMeetCategory] {
            try await fetchAll(on: db, In())
        }
    }

    // MARK: - END VIEWS
}

