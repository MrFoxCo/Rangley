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
    let i    = api.grouped("i")            // protected inserts
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
    v.get("meets")
    {
        req async throws -> [Func.ViewMeets.Results] in
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Func.ViewMeets.fetchAll(on: sql)
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


//    v.put("user","me")
//    { req async throws -> HTTPStatus in
//        struct Body: Content, Sendable {
//            let username: String?
//            let display_name: String?
//            let cellphone: String?
//            let email: String?
//            let dob: Date? // ensure ISO8601 decoding or customize decoder
//            let first_name: String?
//            let last_name: String?
//        }
//
//        let sub = try req.jwt.verify(as: CognitoPayload.self).sub.value
//        let body = try req.content.decode(Body.self)
//        guard let sql = req.db as? any SQLDatabase else { throw Abort(.failedDependency) }
//
//        let id: Int64? = try await sql.raw("""
//            SELECT user_id::bigint FROM rangley.tb_users WHERE cognito_sub = \(bind: sub)
//        """).first(decoding: Int64?.self)
//        guard let userId = id else { throw Abort(.notFound) }
//
//        // Call your stored proc to modify (preferred):
//        // CALL rangley.rangley_m_user(OUT num_affected, IN p_user_id, IN p_cognito_sub, IN p_username, ...);
//        try await sql.raw("""
//            CALL rangley.rangley_m_user(
//                NULL,
//                \(bind: userId),
//                DEFAULT,                          -- keep cognito_sub
//                \(bind: body.username ?? .none),
//                \(bind: body.display_name ?? .none),
//                \(bind: body.first_name ?? .none),
//                \(bind: body.last_name  ?? .none),
//                \(bind: body.cellphone  ?? .none),
//                \(bind: body.email      ?? .none),
//                \(bind: body.dob        ?? .none)
//            );
//        """).run()
//
//        return .noContent
//    }

    
    
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
    /**
     
     curl -X POST https://api.mrfoxco.com/register \
       -H "Content-Type: application/json" \
       -d '{
         "cognito_sub": "123e4567-e89b-12d3-a456-426614174000",
         "username": "rangleytest",
         "display_name": "Rangley Test User",
         "cellphone": "+13125551234",
         "email": "rangleytest@example.com",
         "dob": "2000-05-21",
         "first_name": "Rangley",
         "last_name": "Tester"
       }'
     */
    
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

    // i/meet-coordinate -> (new_meet_coordinate_id)
    i.post("meet-coordinate")
    {
        req async throws -> Proc.InsertMeetCoordinate.Result in
        
        let body = try req.content.decode(Proc.InsertMeetCoordinate.Params.self)
        
        guard body.region_radius > 0 else { throw Abort(.badRequest, reason: "region_radius must be > 0") }
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Proc.InsertMeetCoordinate.call(on: sql, body, .init(new_meet_coordinate_id: nil))
    }

    // i/meet-id -> (new_meet_id)
    i.post("meet-id") { req async throws -> Proc.InsertMeetId.Result in
        let userId = try await req.userIdOrFail()

        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        let params = Proc.InsertMeetId.Params(created_by_user_id: userId)
        return try await Proc.InsertMeetId.call(on: sql, params, .init(new_meet_id: nil))
    }

    // i/meet -> returns (num_inserted)
    i.post("meet")
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
    i.post("meet-change-stamp")
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
    i.post("updated-meet")
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
    
    
    
    
    // MARK: - System INSERTS (s*) or POST ROUTES

    // TODO: - CONSIDER DOING THIS WITH EVERYTHING
    // TODO: - SWAPOUT NUM_INSERTED for is_success or something
    s.post("meet")
    {
        req async throws -> HTTPDTO.Meets.InsertResponse in
        
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
            change_reason: body.change_reason,
            meet_category_id: body.meet_category_id,
            max_capacity: body.max_capacity
        )

        do {
            let dbResult = try await Proc.SystemInsertMeet.call(
                on: sql,
                params,
                .init(new_meet_id: -1, new_meet_coordinate_id: -1, num_inserted: 0)  // Sentinel values to match your procedure
            )
            
            // Validate the result
            guard dbResult.new_meet_id > 0, dbResult.new_meet_coordinate_id > 0, dbResult.num_inserted == 1
            else { throw Abort(.internalServerError, reason: "Failed to create meet") }

            return .init(meet_id: dbResult.new_meet_id,
                        meet_coordinate_id: dbResult.new_meet_coordinate_id)
                        
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
