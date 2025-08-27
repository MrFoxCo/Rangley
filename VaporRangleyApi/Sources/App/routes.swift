//
//  routes.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 8/27/25.
//
import Vapor
import Fluent
import SQLKit

private struct OkResponse: Content { let ok: Bool }

public func routes(_ app: Application) throws {
    app.get("health") { _ in "ok" }

    app.get("dbdiag") { req async -> String in
        let c = req.application.config
        var lines = [
            "dbdiag:",
            "host:\(c.dbHost) port:\(c.dbPort) name:\(c.dbName) user:\(c.dbUser)"
        ]

        guard let sql = req.db as? (any SQLDatabase) else {
            lines.append("adapter:error req.db is not SQLDatabase")
            return lines.joined(separator: "\n")
        }

        do {
            _ = try await sql.raw("select 1 as one").first()
            lines.append("query:ok select 1")
        } catch {
            lines.append("query:error \(error)")
        }

        return lines.joined(separator: "\n")
    }
    
    
    // MARK: - VIEW (fn_* ) or GET ROUTES

    // GET /v/meets  -> all meet card data
    app.get("v", "meets") { req async throws -> [Func.MeetCardData] in
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        return try await Func.ViewMeets.fetchAll(on: sql)
    }

    // GET /v/user/:user_id  -> single user values
    app.get("v", "user", ":user_id") { req async throws -> Func.ViewUserOut in
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        let id = try req.parameters.get("user_id").flatMap(Int64.init)
            ?? { throw Abort(.badRequest, reason: "user_id must be Int64") }()
        return try await Func.ViewUser.call(on: sql, .init(user_id: id))
    }

    // GET /v/meet-categories -> all categories
    app.get("v", "meet-categories") { req async throws -> [Func.ViewMeetCategory] in
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        return try await Func.ViewMeetCategories.fetchAll(on: sql)
    }

    // MARK: - END VIEW (fn_* ) or GET ROUTES

    
    
    
    
    // MARK: - INSERTS (i_*) or POST ROUTES

    // i_user -> returns (num_inserted, new_user_id)
    app.post("i", "user"){ req async throws -> Proc.InsertUserOut in
        let body = try req.content.decode(Proc.InsertUserIn.self)
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Proc.InsertUser.call(on: sql, body)
    }

    // i_meet -> no OUT/INOUT (no row)
    app.post("i", "meet") { req async throws -> OkResponse in
        let body = try req.content.decode(Proc.InsertMeetIn.self)
        guard let sql = req.db as? (any SQLDatabase)
            else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        try await Proc.InsertMeet.exec(on: sql, body)
        return OkResponse(ok: true)
    }

    // i_meet_change_stamp -> returns (new_change_stamp)
    app.post("i", "meet-change-stamp") { req async throws -> Proc.InsertMeetChangeStampOut in
        let body = try req.content.decode(Proc.InsertMeetChangeStampIn.self)
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Proc.InsertMeetChangeStamp.call(on: sql, body)
    }

    // i_meet_coordinate -> returns (new_meet_coordinate_id)
    app.post("i", "meet-coordinate") { req async throws -> Proc.InsertMeetCoordinateOut in
        let body = try req.content.decode(Proc.InsertMeetCoordinateIn.self)
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Proc.InsertMeetCoordinate.call(on: sql, body)
    }

    // i_meet_id -> returns (new_meet_id)
    app.post("i", "meet-id") { req async throws -> Proc.InsertMeetIdOut in
        let body = try req.content.decode(Proc.InsertMeetIdIn.self)
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Proc.InsertMeetId.call(on: sql, body)
    }

    // i_updated_meet -> returns (num_inserted)
    app.post("i", "updated-meet") { req async throws -> Proc.InsertUpdatedMeetOut in
        let body = try req.content.decode(Proc.InsertUpdatedMeetIn.self)
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Proc.InsertUpdatedMeet.call(on: sql, body)
    }

    
    
    // MARK: - END INSERTS (i_*) or POST ROUTES
    
    
    // MARK: - MODIFIES (m_*) or DELETE/PATCH ROUTES

    // m_user -> no OUT/INOUT (no row)
    app.post("m", "user") { req async throws -> OkResponse in
        let body = try req.content.decode(Proc.ModifyUserIn.self)
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        try await Proc.ModifyUser.exec(on: sql, body)
        return OkResponse(ok: true)
    }
    
    // MARK: - END MODIFIES (m_*) or DELETE/PATCH ROUTES


}
