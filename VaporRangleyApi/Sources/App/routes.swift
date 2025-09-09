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
import SotoCognitoIdentityProvider

private struct OkResponse: Content { let ok: Bool }

// TODO: - REMOVE ALL BUSINESS LOGIC FROM routes.swift PLACE IN dbRangley.swift
public func routes(_ app: Application) throws
{
    app.get("health") { _ in "ok" }

    
    // MARK: - AUTHENTICATION (Sign Up, Log In, Log Out, Password Reset, Forgot Password, Admin Reset Password)
    
    // TODO: - RELOCATE ALL STRUCTS TO DIFFERENT FILE
    
    
    /// register a new user through authentication system MUST BE OPEN TO THE PUBLIC
    // MARK: - AUTH REGISTER (PUBLIC)

    // ---------- Route ----------
    app.post("auth", "register")
    {
        req async throws -> AWS.AuthRegister.RegisterResponse in
        try await AWS.AuthRegister.register(req)
    }

    // MARK: - END AUTH REGISTER (PUBLIC)

    // MARK: - AUTH LOGIN

    app.post("auth", "login")
    {
        req async throws -> AWS.AuthLogin.LoginResponse in
        try await AWS.AuthLogin.login(req)
    }
    // MARK: - END AUTH LOGIN
    
    struct ForgotBody: Content, Sendable { let username: String } // email or phone (per your pool)

    app.post("auth","forgot") { req async throws -> HTTPStatus in
        let b = try req.content.decode(ForgotBody.self)
        
        let idp = req.application.cognitoIDP, cfg = req.application.cognito
        
        try await idp.forgotPassword(.init(clientId: cfg.clientID, username: b.username))
        
        return .noContent
    }

    struct ConfirmResetBody: Content, Sendable { let username: String; let code: String; let new_password: String }
    
    app.post("auth","confirm-forgot"){ req async throws -> HTTPStatus in
        let b = try req.content.decode(ConfirmResetBody.self)
        let idp = req.application.cognitoIDP, cfg = req.application.cognito
//        try await idp.confirmForgotPassword(.init(
//            clientId: cfg.clientID, username: b.username,
//            confirmationCode: b.code, password: b.new_password
//        ))
        return .noContent
    }
    
    struct ChangePwBody: Content, Sendable { let old_password: String; let new_password: String }
    app.post("auth","change-password") { req async throws -> HTTPStatus in
        // get Cognito access token first (your login already retrieved it; include it in the app token or fetch again)
        // if you don’t have it handy, call adminInitiateAuth again and get AccessToken
//        let access = /* your way to obtain the current Cognito access token */
//        let b = try req.content.decode(ChangePwBody.self)
//        let idp = req.application.cognitoIDP
//        try await idp.changePassword(.init(previousPassword: b.old_password, proposedPassword: b.new_password, accessToken: access))
        return .noContent
    }

    struct AdminSetPwBody: Content, Sendable { let username: String; let new_password: String; let permanent: Bool }
    app.post("admin","set-password") { req async throws -> HTTPStatus in
        let b = try req.content.decode(AdminSetPwBody.self)
        let idp = req.application.cognitoIDP, cfg = req.application.cognito
//        try await idp.adminSetUserPassword(.init(
//            userPoolId: cfg.userPoolId, username: b.username,
//            password: b.new_password, permanent: b.permanent
//        ))
        return .noContent
    }


    // MARK: - END AUTHENTICATION
    
    // ===== Routing groups =====
    // MARK: - ROUTING GROUPS
    // ===== Routing groups =====

    let api = app.grouped(AppJWTMiddleware())

    let v = api.grouped("v")                  // protected reads
    let i = api.grouped("i")            // protected inserts
    let m = api.grouped("m")            // protected modifies
    //let p = api.grouped("p")            // protected modifies
    
    // MARK: - VIEW (fn_* ) or GET ROUTES

    // GET /v/meets  -> all meet card data
    v.get("meets")
    {
        req async throws -> [Func.ViewMeets.Results] in
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        return try await Func.ViewMeets.fetchAll(on: sql)
    }

    // GET /v/user/:user_id  -> single user values
    v.get("user",":user_id")
    {
        req async throws -> [Func.ViewUser.Results] in
        
        guard let sql = req.db as? (any SQLDatabase)
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        guard let id = req.parameters.get("user_id").flatMap(Int64.init)
        else { throw Abort(.badRequest, reason: "user_id must be Int64") }
        
        return try await Func.ViewUser.fetchAll(on: sql, .init(user_id: id))
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
    i.post("meet-id")
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
 
 
 
 
 
 
 
 
 
 
 
 
 */
