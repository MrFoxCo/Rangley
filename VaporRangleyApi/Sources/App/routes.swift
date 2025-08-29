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
    app.get("v","user",":user_id") { req async throws -> [Func.ViewUserResult] in
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        guard let id = req.parameters.get("user_id").flatMap(Int64.init)
        else { throw Abort(.badRequest, reason: "user_id must be Int64") }
        return try await Func.ViewUser.fetchAll(on: sql, .init(user_id: id))
    }


    
    // GET /v/meet-categories -> all categories
    app.get("v", "meet-categories") { req async throws -> [Func.ViewMeetCategory] in
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        return try await Func.ViewMeetCategories.fetchAll(on: sql)
    }

    // MARK: - END VIEW (fn_* ) or GET ROUTES

    
    
    
    
    // MARK: - INSERTS (i_*) or POST ROUTES

    // i/user -> (num_inserted, new_user_id)
    app.post("i","user") { req async throws -> Proc.InsertUserResult in
        let body = try req.content.decode(Proc.InsertUserParams.self)
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        return try await Proc.InsertUser.call(on: sql, body, .init(num_inserted: 0, new_user_id: 0))
    }

    // i/meet-coordinate -> (new_meet_coordinate_id)
    app.post("i","meet-coordinate") { req async throws -> Proc.InsertMeetCoordinateResult in
        let body = try req.content.decode(Proc.InsertMeetCoordinateParams.self)
        
        guard body.region_radius > 0 else { throw Abort(.badRequest, reason: "region_radius must be > 0") }
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Proc.InsertMeetCoordinate.call(on: sql, body, .init(new_meet_coordinate_id: nil))
    }

    // i/meet-id -> (new_meet_id)
    app.post("i","meet-id") { req async throws -> Proc.InsertMeetIdResult in
        let body = try req.content.decode(Proc.InsertMeetIdParams.self)
        
        guard body.meet_coordinate_id > 0, body.created_by_user_id > 0
        else { throw Abort(.badRequest, reason: "meet_coordinate_id and created_by_user_id are required") }
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Proc.InsertMeetId.call(on: sql, body, .init(new_meet_id: nil))
    }

    // i/meet -> no row (stays the same)
    app.post("i","meet") { req async throws -> OkResponse in
        let body = try req.content.decode(Proc.InsertMeetParams.self)
        
        guard body.meet_id != nil, body.name != nil, body.meet_category_id != nil
        else { throw Abort(.badRequest, reason: "meet_id, name, and meet_category_id are required") }
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        try await Proc.InsertMeet.exec(on: sql, body, .init(is_success: nil))
        
        return OkResponse(ok: true)
    }

    // i/meet-change-stamp -> (new_change_stamp)
    app.post("i","meet-change-stamp") { req async throws -> Proc.InsertMeetChangeStampResult in
        let body = try req.content.decode(Proc.InsertMeetChangeStampParams.self)
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        return try await Proc.InsertMeetChangeStamp.call(on: sql, body, .init(new_change_stamp: nil))
    }

    // i/updated-meet -> (num_inserted)
    app.post("i","updated-meet") { req async throws -> Proc.InsertUpdatedMeetResult in
        let body = try req.content.decode(Proc.InsertUpdatedMeetIn.self)
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        return try await Proc.InsertUpdatedMeet.call(on: sql, body, .init(num_inserted: nil))
    }


    
    
    // MARK: - END INSERTS (i_*) or POST ROUTES
    
    
    // MARK: - MODIFIES (m_*) or DELETE/PATCH ROUTES

    // m_user -> no OUT/INOUT (no row)
    app.post("m", "user") { req async throws -> OkResponse in
        let body = try req.content.decode(Proc.ModifyUserIn.self)
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        try await Proc.ModifyUser.exec(on: sql, body, .init(is_success: 0))
        return OkResponse(ok: true)
    }
    
    // MARK: - END MODIFIES (m_*) or DELETE/PATCH ROUTES


}

/**
 ROUTE TESTING
 
 curl -sS -X POST https://api.mrfoxco.com/i/meet-coordinate \
   -H "Content-Type: application/json" \
   -d '{
     "latitude": 41.9484,
     "longitude": -87.6553,
     "region_latitude": 41.9484,
     "region_longitude": -87.6553,
     "region_radius": 2
   }'
 curl -sS -X POST https://api.mrfoxco.com/i/meet-id \
   -H "Content-Type: application/json" \
   -d '{
     "meet_coordinate_id": 1,
     "created_by_user_id": 2
   }'
 curl -sS -X POST https://api.mrfoxco.com/i/meet \
   -H "Content-Type: application/json" \
   -d '{
     "meet_id": 1,
     "change_stamp": 0,
     "name": "Cubs Rooftop Meetup",
     "description": "Hangout and watch the game from the rooftops",
     "change_reason": "initial insert",
     "meet_category_id": 1
   }'
 
 
 */
