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
import SotoCognitoIdentityProvider

// MARK: - Registry of fully-qualified procedure names

enum RangleyProcName: String
{
    case i_user_by_auth_register = "rangley.rangley_i_user_by_auth_register"
    case i_meet_id               = "rangley.rangley_i_meet_id"
    case i_meet_coordinate       = "rangley.rangley_i_meet_coordinate"
    case i_meet                  = "rangley.rangley_i_meet"
    case i_change_stamp          = "rangley.rangley_i_change_stamp"
    case i_updated_meet          = "rangley.rangley_i_updated_meet"
    case m_user                  = "rangley.rangley_m_user"
}

// Essentially these are views because postgres doesn't allow procedural views in an easy way
enum RangleyFunc: String
{
    case v_user_by_user_id   = "rangley.rangley_fn_v_user_by_user_id"
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

    // MARK: - INSERTS
    

    // MARK: - INSERT USER NOT TESTED
    
    /// MUST match: CREATE PROCEDURE rangley.rangley_i_user_by_auth_register(...)
    enum InsertUserByAuthRegister: PgCallableRow
    {
            static let procName: RangleyProcName = .i_user_by_auth_register

            struct Params: Sendable {
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
    
    
    // MARK: - INSERT MEET ID WORKING
    /// Meet ID needs to be created first because it is the identity row for every meet and it links the meet to the user.
    /// Second a Meet Coordinate ID needs ot be created because it goes inside of the Meets table.
    /// So whenever you want the meet coordinates you just use the Meet ID which is one of the primary keys inside of
    /// tb_meets.
    // MARK: - PROCEDURES RELATED TO MEETS DATA
    // MARK: i_meet_id (OUT new_meet_id) -> row

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
    
    // MARK: - END INSERT MEET ID WORKING

    
    // MARK: - INSERT MEET COORDINATE WORKING
    
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

    // MARK: - END INSERT MEET COORDINATE WORKING
    
    
    // MARK: - INSERT MEET WORKING
    
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

    // MARK: - END INSERT MEET WORKING
    
    
    // MARK: - INSERT CHANGE STAMP WORKING
    
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
    
    // MARK: - END INSERT CHANGE STAMP WORKING
    
    
    // MARK: INSERT UPDATED MEET WORKING
    
    /// Contains Insert Params and Results
    enum InsertUpdatedMeet: PgCallableRow
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
    
    // MARK: - END INSERT UPDATED MEET WORKING
    
    
    
    // MARK: - END PROCEDURES RELATED TO MEETS DATA
    
    
    
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
        static let funcName: RangleyFunc = .v_meets

        // vw_meet_card_data-style payload (assumes rangley_fn_v_meets() returns these columns)
        struct Results: Content, Sendable
        {
            let meet_id            : Int64
            let change_stamp       : Int64
            let meet_status_id     : Int16
            let latitude           : Double
            let longitude          : Double
            let region_latitude    : Double
            let region_longitude   : Double
            let region_radius      : Double
            let dttm_start_utc     : Date
            let dttm_end_utc       : Date
            let name               : String
            let category_name      : String
            let description        : String
            let max_capacity       : Int32
            let created_by_user_id : Int64
            let display_name       : String

        }
        
        struct In: Sendable { }  // no params

        static func query(_ input: In) -> SQLQueryString
        {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)();"
        }

        static func decode(_ r: any SQLRow) throws -> Results
        {
            try .init(
                 meet_id            : r.decode(column: "meet_id",            as: Int64.self)
                ,change_stamp       : r.decode(column: "change_stamp",       as: Int64.self)
                ,meet_status_id     : r.decode(column: "meet_status_id",     as: Int16.self)
                ,latitude           : r.decode(column: "latitude",           as: Double.self)
                ,longitude          : r.decode(column: "longitude",          as: Double.self)
                ,region_latitude    : r.decode(column: "region_latitude",    as: Double.self)
                ,region_longitude   : r.decode(column: "region_longitude",   as: Double.self)
                ,region_radius      : r.decode(column: "region_radius",      as: Double.self)
                ,dttm_start_utc     : r.decode(column: "dttm_start_utc",     as: Date.self)
                ,dttm_end_utc       : r.decode(column: "dttm_end_utc",       as: Date.self)
                ,name               : r.decode(column: "name",               as: String.self)
                ,category_name      : r.decode(column: "category_name",      as: String.self)
                ,description        : r.decode(column: "description",        as: String.self)
                ,max_capacity       : r.decode(column: "max_capacity",       as: Int32.self)
                ,created_by_user_id : r.decode(column: "created_by_user_id", as: Int64.self)
                ,display_name       : r.decode(column: "display_name",       as: String.self)
            )
        }

        // convenience
        static func fetchAll(on db: any SQLDatabase) async throws -> [Results]
        {
            try await fetchAll(on: db, In())
        }
    }


    enum ViewUser: PgFunctionRows
    {
        static let funcName: RangleyFunc = .v_user_by_user_id  // or .v_user_clean

        struct Param: Content, Sendable
        {
            let user_id: Int64
        }

        struct Results: Content, Sendable
        {
            let cognito_sub     : String?
            let username        : String?
            let display_name    : String?
            let cellphone       : String?
            let email           : String?
        }
        
        struct In: Sendable { let user_id: Int64 }

        static func query(_ input: In) -> SQLQueryString {
            "SELECT * FROM \(unsafeRaw: funcName.rawValue)(\(bind: input.user_id));"
        }

        static func decode(_ r: any SQLRow) throws -> Results
        {
            try .init(
                cognito_sub     : r.decode(column: "cognito_sub",   as: String?.self),
                username        : r.decode(column: "username",      as: String?.self),
                display_name    : r.decode(column: "display_name",  as: String?.self),
                cellphone       : r.decode(column: "cellphone",     as: String?.self),
                email           : r.decode(column: "email",         as: String?.self)
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




// TODO: Determine where this goes
enum AWS
{

    // MARK: - AUTH REGISTER

    struct RegisterBody: Content, Sendable {
        let username     : String          // app handle
        let password     : String
        let display_name : String
        let cellphone    : String?         // E.164 (+1...)
        let email        : String?         // lowercase
        let dob          : String          // "YYYY-MM-DD"
        let first_name   : String?
        let last_name    : String?

    }

    struct RegisterResponse: Content, Sendable
    {
        let token: String?
        let expires_at: Date?
        let requires_confirmation: Bool
    }

    // MARK: Helpers (all static)
    private static let reservedHandles: Set<String> = ["admin","support","rangley","mrfox","root","system"]

    @inlinable
    static func normalizeHandle(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    @inlinable
    static func validateHandle(_ h: String) -> Bool {
        h.range(of: #"^[a-z0-9_]{3,20}$"#, options: .regularExpression) != nil
        && !reservedHandles.contains(h)
    }

    @inlinable
    static func normalizeEmail(_ e: String?) -> String? {
        e?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    @inlinable
    static func normalizePhoneE164(_ p: String?) -> String? {
        guard let p else { return nil }
        let cleaned = p.replacingOccurrences(of: #"[^+\d]"#, with: "", options: .regularExpression)
        return cleaned.hasPrefix("+") && cleaned.count >= 8 ? cleaned : nil
    }

    // MARK: Business logic
    static func register(_ req: Request) async throws -> RegisterResponse {
        let body = try req.content.decode(RegisterBody.self)

        // Normalize + validate
        let handle = normalizeHandle(body.username)
        guard validateHandle(handle) else {
            throw Abort(.badRequest, reason: "Invalid or reserved username")
        }
        let emailLower = normalizeEmail(body.email)
        let phoneE164  = normalizePhoneE164(body.cellphone)

        guard emailLower != nil || phoneE164 != nil else {
            throw Abort(.badRequest, reason: "Email or cellphone are required")
        }

        // Prefer phone as Cognito username, else email
        let cognitoUsername = phoneE164 ?? emailLower!

        let idp = req.application.cognitoIDP
        let cfg = req.application.cognito

        // Sign up with preferred_username so handle can be used to sign in
        let sign: CognitoIdentityProvider.SignUpResponse
        do {
            sign = try await idp.signUp(.init(
                clientId: cfg.clientID,
                password: body.password,
                userAttributes: [
                    .init(name: "name", value: body.display_name),
                    .init(name: "preferred_username", value: handle),
                    body.first_name.map { .init(name: "given_name", value: $0) },
                    body.last_name.map  { .init(name: "family_name", value: $0) },
                    emailLower.map      { .init(name: "email", value: $0) },
                    phoneE164.map       { .init(name: "phone_number", value: $0) }
                ].compactMap { $0 },
                username: cognitoUsername
            ))
        } catch let e as CognitoIdentityProviderErrorType {
            switch e {
            case .usernameExistsException:
                throw Abort(.conflict, reason: "Account already exists for this email/phone")
            case .aliasExistsException, .invalidParameterException:
                throw Abort(.conflict, reason: "Username is taken")
            case .invalidPasswordException:
                throw Abort(.badRequest, reason: "Weak password")
            default:
                throw Abort(.badRequest, reason: "Signup failed: \(e)")
            }
        }

        let sub = sign.userSub

        // Insert app user row (keyed by cognito_sub)
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        let params = Proc.InsertUserByAuthRegister.Params(
            cognito_sub  : sub,
            username     : handle,
            display_name : body.display_name,
            cellphone    : phoneE164,
            email        : emailLower,
            dob          : body.dob,
            first_name   : body.first_name,
            last_name    : body.last_name
        )
        _ = try await Proc.InsertUserByAuthRegister.call(on: sql, params, .init(is_success: nil))

        // If confirmation required, return that state; else mint app token
        if !sign.userConfirmed {
            return .init(token: nil, expires_at: nil, requires_confirmation: true)
        } else {
            let now = Date(), exp = now.addingTimeInterval(15 * 60)
            let payload = AppPayload(
                iss: .init(value: req.application.appAuth.issuer),
                sub: .init(value: sub),
                exp: .init(value: exp),
                iat: .init(value: now),
                jti: .init(value: UUID().uuidString),
                user_id: nil,
                roles: ["user"]
            )
            let token = try await req.jwt.sign(payload, kid: "app-hs256")
            return .init(token: token, expires_at: exp, requires_confirmation: false)
        }
    }
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


