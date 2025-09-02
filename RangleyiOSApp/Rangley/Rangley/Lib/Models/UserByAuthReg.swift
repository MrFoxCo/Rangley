//
//  UserByAuthReg.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/2/25.
//

import Vapor
import Fluent
import SQLKit
import JWT

enum InsertUserByAuthRegister: PgCallableRow
{
    // MUST match: CREATE PROCEDURE rangley.rangley_i_auth_register(...)
    static let procName: RangleyProcName = .i_user_by_auth_register

    struct Body: Content, Sendable
    {
        let username     : String
        let display_name : String
        let cellphone    : String?    // need this OR email
        let email        : String?    // need this OR cellphone
        let dob          : String     // "YYYY-MM-DD"
        let first_name   : String?
        let last_name    : String?
    }

    struct Params: Sendable
    {
        let cognito_sub  : String
        let username     : String
        let display_name : String
        let cellphone    : String?
        let email        : String?
        let dob          : String
        let first_name   : String?
        let last_name    : String?
    }

    // Synchronous now (no await). Uses sub provided by your middleware.
    static func fromRequest(_ req: Request) throws -> Params
    {
        let b = try req.content.decode(Body.self)
        guard let sub = req.cognitoSub
        else { throw Abort(.unauthorized, reason: "Missing Cognito sub") }

        return .init(
            cognito_sub  : sub,
            username     : b.username,
            display_name : b.display_name,
            cellphone    : b.cellphone,
            email        : b.email,
            dob          : b.dob,
            first_name   : b.first_name,
            last_name    : b.last_name
        )
    }

    struct Result: Content, Sendable
    {
        let is_success: Bool?
    }

    // Do NOT pass the OUT param; DB returns it as a row.
    static func query(_ i: Params, _ o: Result) -> SQLQueryString
    {
        """
        CALL \(unsafeRaw: procName.rawValue)
        (
             \(bind: i.cognito_sub)::text
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

    static func decode(_ row: any SQLRow) throws -> Result
    {
        try .init(is_success: row.decode(column: "is_success", as: Bool?.self))
    }
}
