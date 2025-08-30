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
    case v_user              = "rangley.rangley_fn_v_user_by_user_id"
    case v_meets             = "rangley.rangley_fn_v_meets"
    case v_meet_categories   = "rangley.rangley_fn_v_meet_categories"
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


    // MARK: - INSERT
    
    // MARK: i_user (INOUT num_inserted, INOUT new_user_id) -> row
    struct InsertUserParams: Content, Sendable
    {
        let username   : String
        let first_name : String
        let last_name  : String
        let cellphone  : String
        let email      : String
    }
    
    struct InsertUserResult: Content, Sendable
    {
        let num_inserted: Int
        let new_user_id : Int64
    }
    
    // i_user (OUT num_inserted, OUT new_user_id)
    enum InsertUser: PgCallableRow
    {
        static let procName: RangleyProcName = .i_user
        static func query(_ i: InsertUserParams, _ o: InsertUserResult) -> SQLQueryString
        {
            """
            CALL \(unsafeRaw: procName.rawValue)(
                \(bind: i.username),
                \(bind: i.first_name),
                \(bind: i.last_name),
                \(bind: i.cellphone),
                \(bind: i.email),
                \(bind: o.num_inserted),
                \(bind: o.new_user_id)
            );
            """
        }
        static func decode(_ row: any SQLRow) throws -> InsertUserResult
        {
            try .init(
                num_inserted: row.decode(column: "num_inserted", as: Int.self),
                new_user_id : row.decode(column: "new_user_id",  as: Int64.self)
            )
        }
    }
    


    // MARK: i_meet_coordinate (OUT new_meet_coordinate_id) -> row
    struct InsertMeetCoordinateParams: Content, Sendable
    {
        let latitude            : Double
        let longitude           : Double
        let region_latitude     : Double
        let region_longitude    : Double
        let region_radius       : Double
    }
    
    struct InsertMeetCoordinateResult: Content, Sendable
    {
        let new_meet_coordinate_id: Int64?
    }
    
    enum InsertMeetCoordinate: PgCallableRow
    {
        static let procName: RangleyProcName = .i_meet_coordinate
        static func query(_ i: InsertMeetCoordinateParams, _ o : InsertMeetCoordinateResult) -> SQLQueryString
        {
            """
            CALL \(unsafeRaw: procName.rawValue)(
                \(bind: i.latitude),
                \(bind: i.longitude),
                \(bind: i.region_latitude),
                \(bind: i.region_longitude),
                \(bind: i.region_radius),
                \(bind: o.new_meet_coordinate_id)
            );
            """
        }
        static func decode(_ row: any SQLRow) throws -> InsertMeetCoordinateResult
        {
            try .init(
                new_meet_coordinate_id: row.decode(column: "new_meet_coordinate_id", as: Int64?.self)
            )
        }
    }

    // MARK: i_meet_id (OUT new_meet_id) -> row
    struct InsertMeetIdParams: Content, Sendable
    {
        let meet_coordinate_id  : Int64
        let created_by_user_id  : Int64
    }
    
    struct InsertMeetIdResult: Content, Sendable
    {
        let new_meet_id: Int64?
    }
    
    enum InsertMeetId: PgCallableRow
    {
        static let procName: RangleyProcName = .i_meet_id
        
        static func query(_ i: InsertMeetIdParams, _ o : InsertMeetIdResult) -> SQLQueryString
        {
            """
            CALL \(unsafeRaw: procName.rawValue)(
                \(bind: i.meet_coordinate_id),
                \(bind: i.created_by_user_id),
                \(bind: o.new_meet_id)
            );
            """
        }
        
        static func decode(_ row: any SQLRow) throws -> InsertMeetIdResult {
            try .init(
                new_meet_id: row.decode(column: "new_meet_id", as: Int64?.self)
            )
        }
    }

    
    // MARK: i_meet (no OUT) -> no row
    struct InsertMeetParams: Content, Sendable
    {
        // required
        let meet_id             : Int64   // p_meet_id
        let name                : String   // p_name
        let dttm_start_utc      : Date
        let dttm_end_utc        : Date
        
        // optional
        let description         : String?   // p_description
        let change_reason       : String?   // p_change_reason
        let meet_category_id    : Int16?    // p_meet_category_id
        let max_capacity        : Int32?

    }
    struct InsertMeetResult: Content, Sendable
    {
        let num_inserted: Int32?
    }
    
    enum InsertMeet: PgCallableRow
    {
        static let procName: RangleyProcName = .i_meet

        static func query(_ i: InsertMeetParams, _ o: InsertMeetResult) -> SQLQueryString {
            """
            CALL \(unsafeRaw: procName.rawValue)
            (
                 \(bind: o.num_inserted)::int4
                ,\(bind: i.meet_id)::int8
                ,\(bind: i.name)::varchar(50)
                ,\(bind: i.dttm_start_utc)::timestamptz
                ,\(bind: i.dttm_end_utc)::timestamptz
                ,COALESCE(\(bind: i.description)::varchar(50), ''::varchar(50))
                ,COALESCE(\(bind: i.change_reason)::varchar(50), ''::varchar(50))
                ,COALESCE(\(bind: i.meet_category_id)::int2, 1::int2)   -- <- avoids NULL + matches int2
                ,COALESCE(\(bind: i.max_capacity)::int4, 2::int4)
            );
            """
        }

        static func decode(_ row: any SQLRow) throws -> InsertMeetResult {
            try .init(num_inserted: row.decode(column: "num_inserted", as: Int32?.self))
        }
    }

    
    // MARK: i_meet_change_stamp (OUT new_change_stamp) -> row
    struct InsertMeetChangeStampParams: Content, Sendable
    {
        let meet_id         : Int64
        let meet_status_id  : Int16? // optional
    }
    
    struct InsertMeetChangeStampResult: Content, Sendable
    {
        let new_change_stamp: Int64?
    }
    
    enum InsertMeetChangeStamp: PgCallableRow
    {
        static let procName: RangleyProcName = .i_meet_change_stamp
        static func query(_ i: InsertMeetChangeStampParams, _ o : InsertMeetChangeStampResult) -> SQLQueryString {
            // OUT params are NOT passed
            """
            CALL \(unsafeRaw: procName.rawValue)
            (
                 \(bind: o.new_change_stamp)
                ,\(bind: i.meet_id)
                ,COALESCE(\(bind: i.meet_status_id)::int2, 0::int2)   -- <- avoids NULL + matches int2
            );
            """
        }
        static func decode(_ row: any SQLRow) throws -> InsertMeetChangeStampResult {
            try .init(
                new_change_stamp: row.decode(column: "new_change_stamp", as: Int64?.self)
            )
        }
    }
    
    
    // MARK: i_updated_meet (INOUT num_inserted) -> row
    struct InsertUpdatedMeetParams: Content, Sendable
    {
        // required
        let meet_id             : Int64
        let change_stamp        : Int64
        let name                : String
        let dttm_start_utc      : Date
        let dttm_end_utc        : Date

        // optional
        let description         : String?
        let change_reason       : String?
        let meet_category_id    : Int16?
        let max_capacity        : Int32? // PG default 2 if nil

    }
    
    struct InsertUpdatedMeetResult: Content, Sendable
    {
        let num_inserted: Int32?
    }
    
    enum InsertUpdatedMeet: PgCallableRow
    {
        static let procName: RangleyProcName = .i_updated_meet
        
        static func query(_ i: InsertUpdatedMeetParams, _ o : InsertUpdatedMeetResult ) -> SQLQueryString
        {
            """
            CALL \(unsafeRaw: procName.rawValue)
            (
                 \(bind: o.num_inserted)::int4
                ,\(bind: i.meet_id)::int8
                ,\(bind: i.change_stamp)::int8
                ,\(bind: i.name)::varchar(50)
                ,\(bind: i.dttm_start_utc)::timestamptz
                ,\(bind: i.dttm_end_utc)::timestamptz
                ,COALESCE(\(bind: i.description)::varchar(50), ''::varchar(50))
                ,COALESCE(\(bind: i.change_reason)::varchar(50), ''::varchar(50))
                ,COALESCE(\(bind: i.meet_category_id)::int2, 1::int2)   -- <- avoids NULL + matches int2
                ,COALESCE(\(bind: i.max_capacity)::int4, 2::int4)
            );
            """
        }
        static func decode(_ row: any SQLRow) throws -> InsertUpdatedMeetResult {
            try .init(num_inserted: row.decode(column: "num_inserted", as: Int32?.self))
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
    
    struct ModifyUserResult: Content, Sendable
    {
        let num_affected : Int?
    }
    
    
    enum ModifyUser: PgCallableNoRow
    {
        static let procName: RangleyProcName = .m_user
        static func query(_ i: ModifyUserIn, _ o : ModifyUserResult) -> SQLQueryString {
            """
            CALL \(unsafeRaw: procName.rawValue)(
                \(bind: i.user_id),
                \(bind: i.username),
                \(bind: i.first_name),
                \(bind: i.last_name),
                \(bind: i.cellphone),
                \(bind: i.email),
                \(bind: o.num_affected)
            );
            """
        }
        static func decode(_ row: any SQLRow) throws -> ModifyUserResult
        {
            try .init(
                num_affected: row.decode(column: "num_affected", as: Int?.self)
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

        static func query(_ input: In) -> SQLQueryString
        {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)();"
        }

        static func decode(_ r: any SQLRow) throws -> MeetCardData
        {
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

    struct ViewUserParam: Content, Sendable
    {
        let user_id: Int64
    }

    struct ViewUserResult: Content, Sendable
    {
        let username  : String?
        let first_name: String?
        let last_name : String?
        let cellphone : String?
        let email     : String?
    }

    enum ViewUser: PgFunctionRows
    {
        static let funcName: RangleyFunc = .v_user  // or .v_user_clean

        struct In: Sendable { let user_id: Int64 }

        static func query(_ input: In) -> SQLQueryString {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.user_id));"
        }

        static func decode(_ r: any SQLRow) throws -> ViewUserResult {
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


// for ios repo i believe??
//enum API
//{
//    static let base = URL(string: "https://api.mrfoxco.com")!
//
//    static func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
//        var req = URLRequest(url: base.appendingPathComponent(path))
//        req.httpMethod = "POST"
//        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        // req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//        req.httpBody = try JSONEncoder().encode(body)
//
//        let (data, resp) = try await URLSession.shared.data(for: req)
//        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
//            let text = String(data: data, encoding: .utf8) ?? ""
//            throw NSError(domain: "API", code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
//                          userInfo: [NSLocalizedDescriptionKey: "Bad response: \(text)"])
//        }
//        let dec = JSONDecoder() // if you use camelCase models, set: dec.keyDecodingStrategy = .convertFromSnakeCase
//        return try dec.decode(T.self, from: data)
//    }
//}


