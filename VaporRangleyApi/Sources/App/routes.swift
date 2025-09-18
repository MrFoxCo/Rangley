//
//  routes.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 8/27/25.
//
import Vapor
import Fluent
import SQLKit
import JWT
import PostgresNIO


private struct OkResponse: Content { let ok: Bool }

extension Request {
    /// Look up the app's user_id by Cognito sub; throws if not provisioned.
    func userIdOrFail() async throws -> Int64 {
        let sub = self.cognito.sub.value
        guard let sql = self.db as? any SQLDatabase else {
            throw Abort(.failedDependency, reason: "Database is not SQLDatabase")
        }
        if let id: Int64 = try await sql.raw("""
            SELECT user_id::bigint
            FROM rangley.vw_users
            WHERE cognito_sub = \(bind: sub)
        """).first(decoding: Int64.self) {
            return id
        }
        throw Abort(.notFound, reason: "User not provisioned in DB (sub=\(sub)).")
    }
}

extension Func.ViewUser {
    static func fetchOne(on sql: any SQLDatabase, _ input: In) async throws -> Results {
        let rows = try await fetchAll(on: sql, input)
        guard let first = rows.first else { throw Abort(.notFound, reason: "User not found") }
        return first
    }
}


// TODO: - REMOVE ALL BUSINESS LOGIC FROM routes.swift PLACE IN dbRangley.swift
public func routes(_ app: Application) throws
{
    app.get("health") { _ in "ok" }

    
    
    // ===== Routing groups =====
    // MARK: - ROUTING GROUPS
    
    // ===== Routing groups =====

    let api = app.grouped(CognitoIDMiddleware())
    
    api.get("auth", "whoami") { req async throws -> [String:String] in
        let p = req.cognito
        return [
            "cognito_sub": p.sub.value,
            "email": p.email ?? "",
            "cellphone": p.phone_number ?? "",
            "username": p.cognito_username ?? ""
        ]
    }

    
    let auth = api.grouped("auth")
    let v    = api.grouped("v")                  // protected reads
    let m    = api.grouped("m")            // protected modifies
    let s    = api.grouped("s")           // transactional inserts contain multiple proc calls
    //let p = api.grouped("p")            // protected modifies
    
    // MARK: - VIEW (fn_* ) or GET ROUTES


    v.get("me")
    {
        req async throws -> Func.ViewUser.Results in
        let sub = req.cognito.sub.value
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        return try await Func.ViewUser.fetchOne(on: sql, .init(cognito_sub: sub))
    }
    
    // GET /v/meets  -> all meet card data
    // GET /v/meets  -> all meet card data
    v.get("meets")
    {
        req async throws -> [Func.ViewMeets.Results] in
       
        let sub = req.cognito.sub.value
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        return try await Func.ViewMeets.fetchAll(on: sql, sub: sub)
    }

    
    v.get("users")
    {
        req async throws -> HTTPDTO.Users.SearchResponse in
        // Auth
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }

        // Decode from query (?usernames=a&usernames=b&emails=x@…)
        let q = (try? req.query.decode(HTTPDTO.Users.SearchBody.self))
            ?? .init(usernames: nil, emails: nil, phones: nil)

        // Sanitize; treat empty arrays as nil
        func clean(_ xs: [String]?) -> [String]? {
            let r = xs?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                       .filter { !$0.isEmpty }
            return (r?.isEmpty == false) ? r : nil
        }
        let usernames = clean(q.usernames)
        let emails    = clean(q.emails)
        let phones    = clean(q.phones)

        guard usernames != nil || emails != nil || phones != nil
        else { throw Abort(.badRequest, reason: "Provide at least one of usernames, emails, or phones.") }

        // DB
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        // Call the set-returning function
        let rows: [Func.ViewUsers.Results] = try await sql
            .raw(Func.ViewUsers.query(.init(
                cognito_sub: sub,
                usernames: usernames,
                emails: emails,
                phones: phones
            )))
            .all(decoding: Func.ViewUsers.Results.self)

        // Map to HTTP payload
        return .init(results: rows.map {
            HTTPDTO.Users.SearchItem(
                user_uuid:   $0.user_uuid,
                username:    $0.username,
                display_name:$0.display_name,
                matched_by:  $0.matched_by,
                can_invite:  $0.can_invite
            )
        })
    }

    // GET /v/meet-categories -> all categories
    v.get("meet-categories")
    {
        req async throws -> [Func.ViewMeetCategories.Results] in
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Func.ViewMeetCategories.fetchAll(on: sql)
    }
    
    

    // MARK: - END VIEW (fn_* ) or GET ROUTES

    
    
    
    
    // MARK: - INSERTS (i_*) or POST ROUTES
    
    
    auth.post("register")
    {
        req async throws -> Proc.InsertUserByAuthRegister.Result in
        
        let body = try req.content.decode(Proc.InsertUserByAuthRegister.RegisterBody.self)
        
        let sub = req.cognito.sub.value
        
        let p = Proc.InsertUserByAuthRegister.Params(
                cognito_sub:  sub,
                username:     body.username,
                display_name: body.display_name,
                cellphone:    body.cellphone,
                email:        body.email,
                dob:          body.dob,
                first_name:   body.first_name,
                last_name:    body.last_name
            )
        
        guard let sql = req.db as? (any SQLDatabase)
            else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

            return try await Proc.InsertUserByAuthRegister.call(on: sql, p, .init(is_success: nil))
    }
    
//    auth.post("forgot-password")
//    {
//
//    }
//
//    auth.post("forgot-email")
//    {
//
//    }
//    
//    auth.post("forgot-phone")
//    {
//        
//    }

    

    // MARK: - END INSERTS (i_*) or POST ROUTES
    
    
    
    
    // MARK: - System INSERTS (s*) or POST ROUTES

    s.post("meet")
    {
        req async throws -> HTTPDTO.Meets.InsertMeetResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }

        let body = try req.content.decode(HTTPDTO.Meets.InsertBody.self)

        guard !body.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw Abort(.badRequest, reason: "name is required") }
        guard body.dttm_start_utc < body.dttm_end_utc
        else { throw Abort(.badRequest, reason: "dttm_start_utc must be before dttm_end_utc") }

        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        let params = Proc.SystemInsertMeet.Params(
            cognito_sub: sub,
            latitude: body.latitude,
            longitude: body.longitude,
            region_latitude: body.region_latitude,
            region_longitude: body.region_longitude,
            region_radius: body.region_radius,
            name: body.name,
            dttm_start_utc: body.dttm_start_utc,
            dttm_end_utc: body.dttm_end_utc,
            description: body.description,
            meet_category_id: body.meet_category_id,
            max_capacity: body.max_capacity
        )

        do {
            let dbResult = try await Proc.SystemInsertMeet.call(
                on: sql,
                params,
                .init(meet_id_uuid: nil, num_inserted: 0)
            )
            
            // Validate the result
            guard dbResult.num_inserted == 1,
                  let meetId = dbResult.meet_id_uuid
            else { throw Abort(.internalServerError, reason: "Failed to create meet") }

            return .init(meet_id_uuid: meetId, num_inserted: dbResult.num_inserted)
            
        } catch let error as PSQLError {
            // Handle specific PostgreSQL errors from your procedure
            if error.serverInfo?[.sqlState] == "22023" {  // Invalid parameter value
                throw Abort(.badRequest, reason: "Invalid input parameters")
            } else if error.serverInfo?[.sqlState] == "23505" {  // Unique violation
                throw Abort(.conflict, reason: "Meet already exists")
            } else {
                req.logger.error("Database error creating meet: \(error)")
                throw Abort(.internalServerError, reason: "Failed to create meet")
            }
        }
    }
    
    s.post("updated-meet")
    {
        req async throws -> HTTPDTO.Meets.InsertUpdateResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }

        let body = try req.content.decode(HTTPDTO.Meets.InsertUpdatedBody.self)  // Use InsertUpdatedBody

        // Only validate fields that are provided
        if let name = body.name {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw Abort(.badRequest, reason: "name cannot be empty if provided") }
        }
        
        if let startTime = body.dttm_start_utc, let endTime = body.dttm_end_utc {
            guard startTime < endTime
            else { throw Abort(.badRequest, reason: "dttm_start_utc must be before dttm_end_utc") }
        }

        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        let params = Proc.SystemInsertUpdatedMeet.Params(
            cognito_sub: sub,
            meet_id_uuid: body.meet_id_uuid,  // Now available from body
            latitude: body.latitude,
            longitude: body.longitude,
            region_latitude: body.region_latitude,
            region_longitude: body.region_longitude,
            region_radius: body.region_radius,
            meet_status_id: body.meet_status_id,
            name: body.name,
            dttm_start_utc: body.dttm_start_utc,
            dttm_end_utc: body.dttm_end_utc,
            description: body.description,
            change_reason: body.change_reason,
            meet_category_id: body.meet_category_id,
            max_capacity: body.max_capacity
        )

        do {
            let dbResult = try await Proc.SystemInsertUpdatedMeet.call(
                on: sql,
                params,
                .init(num_inserted: 0)
            )
            
            guard dbResult.num_inserted == 1
            else { throw Abort(.internalServerError, reason: "Failed to update meet") }

            return .init(num_inserted: dbResult.num_inserted)
                        
        } catch let error as PSQLError {
            let state = error.serverInfo?[.sqlState]
            switch state {
            case "22023": throw Abort(.badRequest, reason: "Invalid input parameters")
            case "P0002": throw Abort(.notFound,    reason: "Meet not found")
            case "42501": throw Abort(.forbidden,   reason: "Not authorized to update this meet")
            default:
                req.logger.error("sqlstate=\(state ?? "nil") error=\(String(reflecting: error))")
                throw Abort(.internalServerError, reason: "Failed to update meet")
            }
        }
    }
    
    s.post("deleted-meet")
    {
        req async throws -> HTTPDTO.Meets.InsertDeleteResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }

        let body = try req.content.decode(HTTPDTO.Meets.InsertDeletedBody.self)  // Use InsertDeletedBody


        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        let params = Proc.SystemInsertDeletedMeet.Params(
            cognito_sub: sub,
            meet_id_uuid: body.meet_id_uuid  // Now available from body
        )

        do {
            let dbResult = try await Proc.SystemInsertDeletedMeet.call(
                on: sql,
                params,
                .init(num_inserted: 0)
            )
            
            guard dbResult.num_inserted == 1
            else { throw Abort(.internalServerError, reason: "Failed to delete meet") }

            return .init(num_inserted: dbResult.num_inserted)
                        
        } catch let error as PSQLError {
            let state = error.serverInfo?[.sqlState]
            switch state {
            case "22023": throw Abort(.badRequest, reason: "Invalid input parameters")
            case "P0002": throw Abort(.notFound,    reason: "Meet not found")
            case "42501": throw Abort(.forbidden,   reason: "Not authorized to delete this meet")
            default:
                req.logger.error("sqlstate=\(state ?? "nil") error=\(String(reflecting: error))")
                throw Abort(.internalServerError, reason: "Failed to update meet")
            }
        }
    }
    
    s.post("users", "search")
    {
        req async throws -> HTTPDTO.Users.SearchResponse in
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }

        let body = try req.content.decode(HTTPDTO.Users.SearchBody.self)

        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        let input = Func.ViewUsers.In(
            cognito_sub: sub,
            usernames: body.usernames,
            emails: body.emails,
            phones: body.phones
        )

        let rs = try await sql.raw(Func.ViewUsers.query(input)).all()
        let rows: [Func.ViewUsers.Results] = try rs.map(Func.ViewUsers.decode)

        return .init(results: rows.map {
            .init(user_uuid: $0.user_uuid,
                  username: $0.username,
                  display_name: $0.display_name,
                  matched_by: $0.matched_by,
                  can_invite: $0.can_invite)
        })
    }
    
    

    // MARK: - END System INSERTS (s*) or POST ROUTES
    
    
    // ===== MODIFIES (protected) =====
    
    // MARK: - MODIFIES (m_*) or DELETE/PATCH ROUTES

    // m_user -> no OUT/INOUT (no row)
    m.post("user",":user_id")
    {
        req async throws -> OkResponse in
        
        let body = try req.content.decode(Proc.ModifyUser.Params.self)
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        try await Proc.ModifyUser.exec(on: sql, body, .init(num_affected: nil))
        
        return OkResponse(ok: true)
    }
    
    // MARK: - END MODIFIES (m_*) or DELETE/PATCH ROUTES

    
    
    
    // MARK: - END ROUTING GROUPS

}

/**
 ROUTE TESTING
 curl -sS -X POST "{$BASE}/i/meet-id" \
   -H "Content-Type: application/json" \
   -H "Authorization: Bearer $AUTH_TOKEN" \
   -d '{
     "created_by_user_id": 2
   }'
 
 curl -sS -X POST "{$BASE}/i/meet-coordinate" \
   -H "Content-Type: application/json" \
   -H "Authorization: Bearer $AUTH_TOKEN" \
    -d '{
     "latitude": 40.9484,
     "longitude": -86.6553,
     "region_latitude": 40.9484,
     "region_longitude": -86.6553,
     "region_radius": 2
   }'

 
 curl -sS -X POST "{$BASE}/i/meet" \
  -H "Content-Type: application/json" \
 -H "Authorization: Bearer $AUTH_TOKEN" \
  -d '{
     "meet_id": 6,
     "meet_coordinate_id": 2,
     "name": "Other Cubs Rooftop Meetup",
     "dttm_start_utc": "2025-09-29T18:00:00Z",
     "dttm_end_utc": "2025-09-29T21:00:00Z"
     }'
 
 // with legal meet_status_id
 curl -sS -X POST "{$BASE}/i/meet-change-stamp" \
   -H "Content-Type: application/json" \
 -H "Authorization: Bearer $AUTH_TOKEN" \
   -d '{
     "meet_id": 2,
   }'
 curl -sS -X POST "{$BASE}/meet-coordinate" \
   -H "Content-Type: application/json" \
 -H "Authorization: Bearer $AUTH_TOKEN" \
   -d '{
     "latitude": 41.830017,
     "longitude": -87.634598,
     "region_latitude": 41.830017,
     "region_longitude": -87.634598,
     "region_radius": 2
   }'
 
 
 curl -sS -X POST "{$BASE}/i/updated-meet" \
   -H "Content-Type: application/json" \
 -H "Authorization: Bearer $AUTH_TOKEN" \
   -d '{
     "meet_id": 5,
     "change_stamp": 3,
     "meet_coordinate_id": 6,
     "name": "Anthony'\''s Rooftop Party",
     "dttm_start_utc": "2025-09-05T09:00:00Z",
     "dttm_end_utc": "2025-09-05T12:00:00Z"
   }'


 
 // with legal meet_status_id
 curl -sS -X POST "{$BASE}/i/meet-change-stamp" \
   -H "Content-Type: application/json" \
 -H "Authorization: Bearer $AUTH_TOKEN" \
   -d '{
     "meet_id": 1
   }'
 
 
 
 curl -sS -X POST "{$BASE}/i/meet" \
   -H "Content-Type: application/json" \
   -H "Authorization: Bearer $AUTH_TOKEN" \
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

 curl -sS -X POST "{$BASE}/i/user" \
   -H "Content-Type: application/json" \
   -H "Authorization: Bearer $AUTH_TOKEN" \
   -d '{
     "cognito_sub": "us-east-2_abc123:deadbeef-dead-beef-dead-beefdeadbeef",
     "username": "xcoder",
     "display_name": "X Code",
     "cellphone": "+13125550123",
     "email": "x@code.com",
     "dob": "1993-05-14",
     "first_name": "X",
     "last_name": "Code"
   }'

 In PostgreSQL you must supply an argument for every parameter without a default, including OUT.
 The OUT placeholders aren’t evaluated (typical is NULL), and the procedure returns a single row containing the OUT/INOUT values.

 # single user
 
curl -sS -X GET "{$BASE}/v/user/4" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Accept: application/json"

curl -sS -X GET "{$BASE}/v/meets" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Accept: application/json"

curl -sS -X GET "{$BASE}/v/meet-categories" \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Accept: application/json"
 
 
 curl -sS -X POST "{$BASE}/m/user/4" \
   -H "Content-Type: application/json" \
   -H "Authorization: Bearer $AUTH_TOKEN" \
   -d '{
     "user_id": 4,
     "display_name": "Jonathan"
   }'
 
 curl -sS -X POST "{$BASE}/i/auth-register" \
   -H "Authorization: Bearer $AUTH_TOKEN" \
   -H "Content-Type: application/json" \
   -d '{
     "username": "elvis",
     "display_name": "elvis p",
     "cellphone": "+17731232222",
     "email": "",
     "dob": "1999-01-01",
     "first_name": "",
     "last_name": ""
   }'
 curl -sS -X POST "{$BASE}/i/auth-register-test" \
   -H "Authorization: Bearer $AUTH_TOKEN" \
   -H "Content-Type: application/json" \
   -d '{
     "username": "ricksanchez",
     "display_name": "rick s",
     "cellphone": "+13121238888",
     "email": "rick@g.com",
     "dob": "1999-01-01",
     "first_name": "",
     "last_name": ""
   }'
 
 
 curl -sS -X POST "{$BASE}/i/user" \
   -H "Authorization: Bearer $AUTH_TOKEN" \
   -H "Content-Type: application/json" \
   -d '{
     "username": "stevek",
     "display_name": "Steve K",
     "cellphone": "+14321902222",
     "email": null,
     "dob": "1999-01-01",
     "first_name": null,
     "last_name": null
    }'
     
 curl -sS -X POST "{$BASE}/i/user" \
   -H "Authorization: Bearer $AUTH_TOKEN" \
   -H "Content-Type: application/json" \
   -d '{
     "username": "[upiyouyt]",
     "display_name": "p[iouiyuty",
     "cellphone": "+10011112222",
     "email": "",
     "dob": "1999-01-01",
     "first_name": "",
     "last_name": ""
   }'
 
 curl -sS -X POST "$BASE/user" \
   -H "Content-Type: application/json" \
   -d '{
     "username": "sdfgsdfg",
     "display_name": "ffsdfgs ",
     "cellphone": "+1888999220",
     "email": "asd@f.com",
     "dob": "1999-01-01",
     "first_name": "",
     "last_name": ""
   }'
 
 
 curl -sS -X POST "$BASE/auth/register" -H "Content-Type: application/json" -d '{
   "username":"elvis",
   "password":"StrongPw123!",
   "display_name":"Elvis P",
   "cellphone":"+16865550123",
   "email":"elvis@example.com",
   "dob":"1999-01-01",
   "first_name":"Elvis",
   "last_name":"Presley"
 }'
 curl -sS -X POST "https://api.mrfoxco.com/auth/register" -H "Content-Type: application/json" -d '{
   "username":"",
   "password":"!",
   "display_name":"",
   "cellphone":"+",
   "email":"",
   "dob":"",
   "first_name":"",
   "last_name":""
 }'
 // WINDOWS
 curl.exe -sS -X POST "https://api.mrfoxco.com/auth/register" `
   -H "Content-Type: application/json" `
   -d '{"username":"",
        "password":"!",
        "display_name":"",
        "cellphone":"+",
        "email":"",
        "dob":"yyyy-mm-dd",
        "first_name":"",
        "last_name":""
 }'

 curl -sS -X POST POST "$BASE/auth/login" `
 -H "Content-Type: application/json" `
 -d
 '{
 "username":"mrman",
 "password":"14PincheTuMadre!"
 }'
 
 curl -sS -X POST "$BASE/auth/login" \
   -H "Content-Type: application/json" \
   -d '{"username":"21abe5c0-d071-70b3-e3c1-876a9457ea6c","password":"d!DNF9AKJ"}'
 
 curl -sS -X POST "$BASE/auth/login" \
   -H "Content-Type: application/json" \
   -d '{"username":"<email-or-+1phone>","password":"<password>"}'
 
 
 Password minimum length
 8 character(s)
 Password requirements
 Contains at least 1 number
 Contains at least 1 special character
 Contains at least 1 uppercase letter
 Contains at least 1 lowercase letter
 // password  must satisfy regular expression pattern: ^[\S]+.*[\S]+$
 
 curl -sS -X POST "$BASE/auth/register" \
 -H "Content-Type: application/json"\
 -d '{
   "username":"testu",
   "password":"d!DNF9AKJ",
   "display_name":"testd",
   "cellphone":"+17731110101",
   "email":"1@gmail.com",
   "dob":"1988-01-01",
   "first_name":"not",
   "last_name":"important"
 }'
 
 
 DNF9AKJ#
 
 
 
 
 
 
 
 
 */
