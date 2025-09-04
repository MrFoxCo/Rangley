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

public func routes(_ app: Application) throws
{
    app.get("health") { _ in "ok" }

    
    // MARK: - AUTHENTICATION

    struct LoginBody: Content, Sendable { let username: String; let password: String }
    struct LoginResp: Content, Sendable { let token: String; let expires_at: Date }

    app.post("auth","login")
    {
        req async throws -> LoginResp in
        
        let body = try req.content.decode(LoginBody.self)
        let idp  = req.application.cognitoIDP
        let cfg  = req.application.cognito

        // 1) Admin auth with username/password
        let initResp = try await idp.adminInitiateAuth(.init(
            authFlow: .adminUserPasswordAuth,
            authParameters: ["USERNAME": body.username, "PASSWORD": body.password], // <-- move up
            clientId: cfg.clientID,
            userPoolId: cfg.userPoolId
        ))

        // Handle NEW_PASSWORD_REQUIRED if you plan to support it; for now reject.
        if let ch = initResp.challengeName, ch == .newPasswordRequired {
           throw Abort(.forbidden, reason: "Password reset required")
        }

        guard let access = initResp.authenticationResult?.accessToken else {
           throw Abort(.unauthorized, reason: "Auth failed")
        }

        // could be issue with null or something
        // 2) Fetch attributes to get `sub`
        let user = try await idp.getUser(.init(accessToken: access))
        guard let sub = user.userAttributes.first(where: { $0.name == "sub" })?.value
        else { throw Abort(.unauthorized, reason: "No sub") }


        // 2) Mint your app token using Vapor JWT v5 helpers
        let now = Date()
        let exp = now.addingTimeInterval(15 * 60)

        let payload = AppPayload(
            iss: .init(value: req.application.appAuth.issuer),
            sub: .init(value: sub),
            exp: .init(value: exp),
            iat: .init(value: now),
            jti: .init(value: UUID().uuidString),
            user_id: nil,
            roles: ["user"]
        )

        // v5: Sign via req.jwt (not JWTSigner)
        let token = try await req.jwt.sign(payload, kid: "app-hs256")
        return .init(token: token, expires_at: exp)

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

    
    
    

    // routes.swift (stays tiny)
    /// register a new user through authentication system MUST BE OPEN TO THE PUBLIC
    // MARK: - AUTH: REGISTER (PUBLIC)
    struct RegisterBody: Content, Sendable {
        let username: String            // app handle (NOT Cognito username)
        let password: String
        let display_name: String
        let cellphone: String?
        let email: String?
        let dob: String                 // "YYYY-MM-DD"
        let first_name: String?
        let last_name: String?
    }
    struct RegisterResp: Content, Sendable {
        let token: String?
        let expires_at: Date?
        let requires_confirmation: Bool
    }

    app.post("auth", "register") { req async throws -> RegisterResp in
        let body = try req.content.decode(RegisterBody.self)

        // must have at least one login identifier
        guard (body.email?.isEmpty == false) || (body.cellphone?.isEmpty == false)
        else { throw Abort(.badRequest, reason: "Provide email or cellphone") }

        // Prefer cellphone as Cognito username if both are present
        let cognitoUsername: String
        if let phone = body.cellphone, !phone.isEmpty {
            cognitoUsername = phone        // E.164 expected, e.g. +13125550123
        } else {
            cognitoUsername = body.email!  // safe: guarded above
        }

        let idp = req.application.cognitoIDP
        let cfg = req.application.cognito

        // 1) Cognito signUp (password must precede username)
        let sign = try await idp.signUp(.init(
            clientId: cfg.clientID,
            password: body.password,
            userAttributes: [
                .init(name: "name", value: body.display_name),
                body.email.map { .init(name: "email", value: $0) },
                body.cellphone.map { .init(name: "phone_number", value: $0) }
            ].compactMap { $0 },
            username: cognitoUsername
        ))

        let sub = sign.userSub   // <- store as cognito_sub

        // 2) Insert your app user row via stored proc (keep app handle = body.username)
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        let params = Proc.InsertUserByAuthRegister.Params(
            cognito_sub: sub,
            username: body.username,              // your app handle
            display_name: body.display_name,
            cellphone: body.cellphone,
            email: body.email,
            dob: body.dob,
            first_name: body.first_name,
            last_name: body.last_name
        )
        _ = try await Proc.InsertUserByAuthRegister.call(on: sql, params, .init(is_success: nil))

        // 3) Return confirmation state (coalesce optional)
        let requiresConfirmation = !(sign.userConfirmed)
        if requiresConfirmation {
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

 */
