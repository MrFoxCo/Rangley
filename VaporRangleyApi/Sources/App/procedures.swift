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

enum RangleyProcName: String {
    case i_user              = "rangley.rangley_i_user"
    case i_meet              = "rangley.rangley_i_meet"
    case i_meet_change_stamp = "rangley.rangley_i_meet_change_stamp"
    case i_meet_coordinate   = "rangley.rangley_i_meet_coordinate"
    case i_meet_id           = "rangley.rangley_i_meet_id"
    case i_updated_meet      = "rangley.rangley_i_updated_meet"
    case m_user              = "rangley.rangley_m_user"
}

// MARK: - Generic callable

protocol PgCallable {
    associatedtype Input: Sendable
    associatedtype Output: Content & Sendable
    static var name: RangleyProcName { get }
    static func query(_ input: Input) -> SQLQueryString
    static func decode(_ row: any SQLRow) throws -> Output
}

extension PgCallable {
    static func call(on db: any SQLDatabase, _ input: Input) async throws -> Output {
        let rows = try await db.raw(query(input)).all()
        guard let row = rows.first else {
            throw Abort(.internalServerError, reason: "\(name.rawValue) returned no row")
        }
        return try decode(row)
    }
}

// MARK: - i_user

struct IUserReq: Content, Sendable {
    let username: String
    let first_name: String
    let last_name: String
    let cellphone: String
    let email: String
}

struct IUserRes: Content, Sendable {
    let num_inserted: Int
    let new_user_id: Int
}

enum Proc {
    enum IUser: PgCallable {
        static let name: RangleyProcName = .i_user

        static func query(_ i: IUserReq) -> SQLQueryString {
            // IN args first; pass NULL for each INOUT to receive as columns
            """
            CALL \(unsafeRaw: name.rawValue)(
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

        static func decode(_ row: any SQLRow) throws -> IUserRes {
            try .init(
                num_inserted: row.decode(column: "num_inserted", as: Int.self),
                new_user_id:  row.decode(column: "new_user_id",  as: Int.self)
            )
        }
    }

    // MARK: - i_meet (example)

    // Signature you showed: rangley_i_meet(int8, int8, text, text, text, int4)
    // Assuming proc also returns INOUT num_inserted, INOUT new_meet_id.
    struct IMeetReq: Content, Sendable {
        let host_user_id: Int64
        let category_id: Int64
        let title: String
        let details: String
        let location_hint: String
        let tz_offset_minutes: Int32
    }

    struct IMeetRes: Content, Sendable {
        let num_inserted: Int
        let new_meet_id: Int64
    }

    enum IMeet: PgCallable {
        static let name: RangleyProcName = .i_meet

        static func query(_ i: IMeetReq) -> SQLQueryString {
            """
            CALL \(unsafeRaw: name.rawValue)(
                \(bind: i.host_user_id),
                \(bind: i.category_id),
                \(bind: i.title),
                \(bind: i.details),
                \(bind: i.location_hint),
                \(bind: i.tz_offset_minutes),
                NULL,  -- INOUT num_inserted
                NULL   -- INOUT new_meet_id
            );
            """
        }

        static func decode(_ row: any SQLRow) throws -> IMeetRes {
            try .init(
                num_inserted: row.decode(column: "num_inserted", as: Int.self),
                new_meet_id:  row.decode(column: "new_meet_id",  as: Int64.self)
            )
        }
    }

    // Add more procs below using the same pattern:
    // enum IMeetChangeStamp: PgCallable { ... }
    // enum IMeetCoordinate: PgCallable { ... }
    // enum IMeetId: PgCallable { ... }
    // enum IUpdatedMeet: PgCallable { ... }
    // enum MUser: PgCallable { ... }
}
