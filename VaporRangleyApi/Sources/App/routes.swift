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

public func routes(_ app: Application) throws
{
    app.get("health") { _ in "ok" }

    
  
//    app.get("dbdiag")
//    {
//        req async -> String in
//        
//        let c = req.application.config
//        
//        var lines = [
//            "dbdiag:",
//            "host:\(c.dbHost) port:\(c.dbPort) name:\(c.dbName) user:\(c.dbUser)"
//        ]
//
//        guard let sql = req.db as? (any SQLDatabase) else {
//            lines.append("adapter:error req.db is not SQLDatabase")
//            return lines.joined(separator: "\n")
//        }
//
//        do {
//            _ = try await sql.raw("select 1 as one").first()
//            lines.append("query:ok select 1")
//        } catch {
//            lines.append("query:error \(error)")
//        }
//
//        return lines.joined(separator: "\n")
//    }
    
    
    // --- Cognito-protected group ---
    let issuer   = app.cognito.issuer          // from configure.swift storage
    let clientID = app.cognito.clientID

    // AWS Cognito JWKS endpoint is under /.well-known/jwks.json
    let jwksURL = URI(string: "\(issuer)/.well-known/jwks.json")

    let auth = CognitoJWTMiddleware(
        jwksURL: jwksURL,
        issuer: issuer,
        audience: clientID
    )

    let api = app.grouped(auth)
    
    let v = api.grouped("v")                  // public reads
    let i = api.grouped("i")            // protected inserts
    let m = api.grouped("m")            // protected modifies
    
    // MARK: - VIEW (fn_* ) or GET ROUTES

    // GET /v/meets  -> all meet card data
    v.get("v", "meets")
    {
        req async throws -> [Func.ViewMeets.Results] in
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Func.ViewMeets.fetchAll(on: sql)
    }

    // GET /v/user/:user_id  -> single user values
    v.get("v","user",":user_id")
    {
        req async throws -> [Func.ViewUser.Results] in
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        guard let id = req.parameters.get("user_id").flatMap(Int64.init)
        else { throw Abort(.badRequest, reason: "user_id must be Int64") }
        
        return try await Func.ViewUser.fetchAll(on: sql, .init(user_id: id))
    }
    
    // GET /v/meet-categories -> all categories
    v.get("v", "meet-categories")
    {
        req async throws -> [Func.ViewMeetCategories.Results] in
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Func.ViewMeetCategories.fetchAll(on: sql)
    }

    // MARK: - END VIEW (fn_* ) or GET ROUTES

    
    
    
    
    // MARK: - INSERTS (i_*) or POST ROUTES

    // i/user -> (num_inserted, new_user_id)
    i.post("i","user")
    {
        req async throws -> Proc.InsertUser.Result in
        
        let body = try req.content.decode(Proc.InsertUser.Params.self)
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Proc.InsertUser.call(on: sql, body, .init(num_inserted: 0, new_user_id: 0))
    }

    // i/meet-coordinate -> (new_meet_coordinate_id)
    i.post("i","meet-coordinate")
    {
        req async throws -> Proc.InsertMeetCoordinate.Result in
        
        let body = try req.content.decode(Proc.InsertMeetCoordinate.Params.self)
        
        guard body.region_radius > 0 else { throw Abort(.badRequest, reason: "region_radius must be > 0") }
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Proc.InsertMeetCoordinate.call(on: sql, body, .init(new_meet_coordinate_id: nil))
    }

    // i/meet-id -> (new_meet_id)
    i.post("i","meet-id")
    {
        req async throws -> Proc.InsertMeetId.Result in
        let body = try req.content.decode(Proc.InsertMeetId.Params.self)
        
        guard body.created_by_user_id > 0
        else { throw Abort(.badRequest, reason: "meet_coordinate_id and created_by_user_id are required") }
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Proc.InsertMeetId.call(on: sql, body, .init(new_meet_id: nil))
    }

    // i/meet -> returns (num_inserted)
    i.post("i","meet")
    {
        req async throws -> Proc.InsertMeet.Result in
        
        let body = try req.content.decode(Proc.InsertMeet.Params.self)
        guard !body.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "name is required")
        }
        guard body.meet_id > 0
        else { throw Abort(.badRequest, reason: "meet id invalid or null") }
        
        guard body.dttm_start_utc <= body.dttm_end_utc else {
            throw Abort(.badRequest, reason: "dttm_start_utc must be before dttm_end_utc")
        }
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Proc.InsertMeet.call(on: sql, body, .init(num_inserted: nil))
    }
    
    // WORKS BUT SAYS PERMISSION DENIED FOR SOME REASON???
    // i/meet-change-stamp -> (new_change_stamp)
    i.post("i","meet-change-stamp")
    {
        req async throws -> Proc.InsertChangeStamp.Result in
        
        let body = try req.content.decode(Proc.InsertChangeStamp.Params.self)
        
        guard body.meet_id > 0
        else { throw Abort(.badRequest, reason: "Meet ID is invalid or not provided") }
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Proc.InsertChangeStamp.call(on: sql, body, .init(new_change_stamp: nil))
    }

    // i/meet -> returns (num_inserted)
    i.post("i","updated-meet")
    {
        req async throws -> Proc.InsertUpdatedMeet.Result in
        
        let body = try req.content.decode(Proc.InsertUpdatedMeet.Params.self)
        guard !body.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "name is required")
        }
        guard body.meet_id > 0
        else { throw Abort(.badRequest, reason: "meet id invalid or null") }
        
        guard body.dttm_start_utc < body.dttm_end_utc else {
            throw Abort(.badRequest, reason: "dttm_start_utc must be before dttm_end_utc")
        }
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Proc.InsertUpdatedMeet.call(on: sql, body, .init(num_inserted: nil))
    }

    
    // MARK: - END INSERTS (i_*) or POST ROUTES
    
    
    
    
    
    // MARK: - MODIFIES (m_*) or DELETE/PATCH ROUTES

    // m_user -> no OUT/INOUT (no row)
    m.post("m", "user")
    {
        req async throws -> OkResponse in
        
        let body = try req.content.decode(Proc.ModifyUser.Params.self)
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        try await Proc.ModifyUser.exec(on: sql, body, .init(num_affected: nil))
        
        return OkResponse(ok: true)
    }
    
    // MARK: - END MODIFIES (m_*) or DELETE/PATCH ROUTES


}

/**
 ROUTE TESTING
 curl -sS -X POST https://api.mrfoxco.com/i/meet-id \
   -H "Content-Type: application/json" \
   -d '{
     "created_by_user_id": 2
   }'
 
 curl -sS -X POST https://api.mrfoxco.com/i/meet-coordinate \
   -H "Content-Type: application/json" \
   -d '{
     "latitude": 40.9484,
     "longitude": -86.6553,
     "region_latitude": 40.9484,
     "region_longitude": -86.6553,
     "region_radius": 2
   }'

 
 curl -sS -X POST https://api.mrfoxco.com/i/meet \
  -H "Content-Type: application/json" \
  -d '{
     "meet_id": 5,
     "meet_coordinate_id": 6,
     "name": "Other Cubs Rooftop Meetup",
     "dttm_start_utc": "2025-09-29T18:00:00Z",
     "dttm_end_utc": "2025-09-29T21:00:00Z"
     }'
 
 // with legal meet_status_id
 curl -sS -X POST https://api.mrfoxco.com/i/meet-change-stamp \
   -H "Content-Type: application/json" \
   -d '{
     "meet_id": 2,
   }'
 curl -sS -X POST https://api.mrfoxco.com/i/meet-coordinate \
   -H "Content-Type: application/json" \
   -d '{
     "latitude": 41.830017,
     "longitude": -87.634598,
     "region_latitude": 41.830017,
     "region_longitude": -87.634598,
     "region_radius": 2
   }'
 
 
 curl -sS -X POST https://api.mrfoxco.com/i/updated-meet \
   -H "Content-Type: application/json" \
   -d '{
     "meet_id": 5,
     "change_stamp": 3,
     "meet_coordinate_id": 6,
     "name": "Anthony'\''s Rooftop Party",
     "dttm_start_utc": "2025-09-05T09:00:00Z",
     "dttm_end_utc": "2025-09-05T12:00:00Z"
   }'


 
 // with legal meet_status_id
 curl -sS -X POST https://api.mrfoxco.com/i/meet-change-stamp \
   -H "Content-Type: application/json" \
   -d '{
     "meet_id": 1
   }'
 
 
 
 curl -sS -X POST https://api.mrfoxco.com/i/meet \
   -H "Content-Type: application/json" \
   -d '{
     "meet_id": 1,
     "name": "Cubs Rooftop Meetup",
    "dttm_start_utc": "2025-09-29T18:00:00Z",
    "dttm_end_utc": "2025-09-29T21:00:00Z",
     "description": "Hangout and watch the game from the rooftops",
     "change_reason": "initial insert",
     "meet_category_id": 1,
     "max_capacity" : 2
   }'
 
 // no defaults


 In PostgreSQL you must supply an argument for every parameter without a default, including OUT.
 The OUT placeholders aren’t evaluated (typical is NULL), and the procedure returns a single row containing the OUT/INOUT values.

 
 */

