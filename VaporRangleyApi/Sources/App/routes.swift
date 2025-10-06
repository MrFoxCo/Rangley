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

extension Request
{
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

// TODO: - REMOVE ALL BUSINESS LOGIC FROM routes.swift PLACE IN dbRangley.swift
public func routes(_ app: Application) throws
{
    app.get("health") { _ in "ok" }

    // Public auth endpoints (no authentication required)
    let publicAuth = app.grouped("auth")
    
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

    // TODO: remove deprecated when update is complete
    v.get("me")
    {
        req async throws -> Func.ViewUserDeprecated.Results in
        let sub = req.cognito.sub.value
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        return try await Func.ViewUserDeprecated.fetchOne(on: sql, .init(cognito_sub: sub))
    }
    
    
    v.get("user","me")
    {
        req async throws -> Func.ViewUserNew.Results in
        let sub = req.cognito.sub.value
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        return try await Func.ViewUserNew.fetchOne(on: sql, .init(cognito_sub: sub))
    }
    
    
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
    
    v.get("users", "profile", ":user_uuid")
    {
        req async throws -> HTTPDTO.Users.ProfileResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        guard let userUUIDString = req.parameters.get("user_uuid"),
              let userUUID = UUID(uuidString: userUUIDString)
        else { throw Abort(.badRequest, reason: "Invalid user_uuid") }
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        let input = Func.ViewUserProfile.In(user_uuid: userUUID)
        
        let rs = try await sql.raw(Func.ViewUserProfile.query(input)).all()
        let rows: [Func.ViewUserProfile.Results] = try rs.map(Func.ViewUserProfile.decode)
        
        guard let profile = rows.first else {
            throw Abort(.notFound, reason: "User profile not found")
        }
        
        return .init(
            user_uuid: profile.user_uuid,
            username: profile.username,
            display_name: profile.display_name,
            member_since: profile.member_since,
            meets_created: profile.meets_created,
            meets_attended: profile.meets_attended,
            friend_count: profile.friend_count,
            discoverable_by_username: profile.discoverable_by_username,
            discoverable_by_phone: profile.discoverable_by_phone,
            discoverable_by_email: profile.discoverable_by_email,
            show_full_name: profile.show_full_name,
            allow_invites_from_anyone: profile.allow_invites_from_anyone
        )
    }
    
    // GET /v/friends/status/:user_uuid
    v.get("friends", "status", ":user_uuid") { req async throws -> HTTPDTO.Friends.StatusResponse in
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        guard let userUUIDString = req.parameters.get("user_uuid"),
              let targetUserUUID = UUID(uuidString: userUUIDString)
        else { throw Abort(.badRequest, reason: "Invalid user_uuid") }
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        let input = Func.ViewFriendshipStatus.In(
            cognito_sub: sub,
            target_user_uuid: targetUserUUID
        )
        
        let result = try await Func.ViewFriendshipStatus.fetchOne(on: sql, input)
        
        // Convert string to enum, default to .none if invalid
        let status = HTTPDTO.Friends.FriendshipStatus(rawValue: result.status) ?? .none
        
        return .init(
            status: status,
            friend_request_id: result.friend_request_id
        )
    }
    
    // GET /v/friends - List all friends
    v.get("friends") { req async throws -> [HTTPDTO.Friends.FriendItem] in
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        let input = Func.ViewFriendsList.In(cognito_sub: sub)
        let rs = try await sql.raw(Func.ViewFriendsList.query(input)).all()
        let friends: [Func.ViewFriendsList.Results] = try rs.map(Func.ViewFriendsList.decode)
        
        return friends.map { .init(
            user_uuid: $0.user_uuid,
            username: $0.username,
            display_name: $0.display_name,
            friend_since: $0.friend_since
        )}
    }
    
    
    
    v.get("notifications")
    {
        req async throws -> HTTPDTO.Notifications.SearchResponse in
        // Auth
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }

        // DB
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        // Call the function
        let rows: [Func.ViewUserInboxNotificationsDep.Results] = try await sql
            .raw(Func.ViewUserInboxNotificationsDep.query(.init(cognitoSub: sub)))
            .all(decoding: Func.ViewUserInboxNotificationsDep.Results.self)

        // Map to HTTP payload
        return .init(results: rows.map {
            HTTPDTO.Notifications.SearchItem(
                notification_id: $0.notification_id,
                notification_type_id: $0.notification_type_id,
                notification_name: $0.notification_name,
                participant_status_id: $0.participant_status_id,
                meet_id_uuid: $0.meet_id_uuid,
                creator_display_name: $0.creator_display_name,
                payload_json: $0.payload_json,
                dttm_notification_created_utc: $0.dttm_notification_created_utc,
                dttm_received_utc: $0.dttm_received_utc,
                dttm_opened_utc: $0.dttm_opened_utc,
                is_read: $0.is_read
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
    
    v.get("inbox")
    {
        req async throws -> HTTPDTO.Inbox.ViewInboxResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        let input = Func.ViewUserInbox.In(
            cognito_sub: sub,
            limit: 50
        )
        
        let rs = try await sql.raw(Func.ViewUserInbox.query(input)).all()
        let rows: [Func.ViewUserInbox.Results] = try rs.map(Func.ViewUserInbox.decode)
        
        return .init(notifications: rows.map { row in
            .init(
                notification_id: row.notification_id,
                notification_type_id: row.notification_type_id,
                notification_type: row.notification_type,
                meet_id_uuid: row.meet_id_uuid,
                created_by_user_uuid: row.created_by_user_uuid,
                created_by_username: row.created_by_username,
                created_by_display_name: row.created_by_display_name,
                payload_json: row.payload_json,
                dttm_created_utc: row.dttm_created_utc,
                dttm_received_utc: row.dttm_received_utc,
                dttm_opened_utc: row.dttm_opened_utc,
                is_read: row.is_read
            )
        })
    }
    
    // List user's meet groups
    v.get("meet-groups", "list")
    {
        req async throws -> [HTTPDTO.MeetGroups.MeetGroup] in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        do {
            let results = try await Func.SystemViewMeetGroups.fetchAll(on: sql, .init(
                cognito_sub: sub
            ))
            
            return results.map { result in
                HTTPDTO.MeetGroups.MeetGroup(
                    meet_group_id: result.meet_group_id,
                    name: result.name,
                    image_type: result.image_type,
                    image_reference: result.image_reference,
                    image_url: result.image_url,
                    member_count: result.member_count,
                    dttm_created_utc: result.dttm_created_utc,
                    dttm_modified_utc: result.dttm_modified_utc
                )
            }
            
        } catch let error as PSQLError {
            req.logger.error("Database error listing meet groups: \(error)")
            throw Abort(.internalServerError, reason: "Failed to list meet groups")
        }
    }
    
    // Get group members
    v.get("meet-groups", ":meetGroupID", "members")
    {
        req async throws -> [HTTPDTO.MeetGroups.GroupMember] in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        guard let meetGroupID = req.parameters.get("meetGroupID", as: Int64.self) else {
            throw Abort(.badRequest, reason: "Invalid meet group ID")
        }
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        do {
            let results = try await Func.SystemViewMeetGroupMembers.fetchAll(on: sql, .init(
                cognito_sub: sub,
                meet_group_id: meetGroupID
            ))
            
            return results.map { result in
                HTTPDTO.MeetGroups.GroupMember(
                    user_uuid: result.user_uuid,
                    username: result.username,
                    display_name: result.display_name,
                    dttm_added_utc: result.dttm_added_utc,
                    is_owner: result.is_owner
                )
            }
            
        } catch let error as PSQLError {
            req.logger.error("Database error getting group members: \(error)")
            throw Abort(.internalServerError, reason: "Failed to get group members")
        }
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


    // TODO: Same number might be able to beat Rater Limiter with multiple consecutive requests
    // TODO: ENHANCE for race conditions
    
    // Send verification code with rate limiting
    // Enhanced send verification route with IP protection
    publicAuth.post("send-verification")
    {
        req -> HTTPStatus in
        let body = try req.content.decode(PhoneVerificationRequest.self)
        
        guard body.phone.starts(with: "+"), body.phone.count >= 10 else {
            throw Abort(.badRequest, reason: "Invalid phone number format")
        }
        
        // Get client IP address
        let clientIP = req.headers.forwarded.first?.for ??
                       req.remoteAddress?.hostname ??
                       "unknown"
        // Normalize phone format for consistent rate limiting
        let normalizedPhone = body.phone.replacingOccurrences(of: " ", with: "")
                                         .replacingOccurrences(of: "-", with: "")
                                         .replacingOccurrences(of: "(", with: "")
                                         .replacingOccurrences(of: ")", with: "")
        // Check rate limits (both phone and IP)
        let rateCheck = await SMSRateLimiter.shared.canSend(to: normalizedPhone, from: clientIP)
        guard rateCheck.allowed else {
            if let waitInfo = await SMSRateLimiter.shared.getRemainingTime(for: normalizedPhone, from: clientIP) {
                let minutes = Int(waitInfo.timeUntilReset / 60) + 1
                let message: String
                
                switch waitInfo.reason {
                case "phone_hourly":
                    message = "Too many verification attempts for this phone. Try again in \(minutes) minutes."
                case "phone_daily":
                    let hours = Int(waitInfo.timeUntilReset / 3600) + 1
                    message = "Daily verification limit reached for this phone. Try again in \(hours) hours."
                case "ip_hourly":
                    message = "Too many verification requests from your location. Try again in \(minutes) minutes."
                case "ip_daily":
                    let hours = Int(waitInfo.timeUntilReset / 3600) + 1
                    message = "Daily verification limit reached from your location. Try again in \(hours) hours."
                default:
                    message = "Rate limit exceeded. Please try again later."
                }
                
                req.logger.warning("Rate limit hit - Phone: •••\(normalizedPhone.suffix(4)), IP: \(clientIP), Reason: \(waitInfo.reason)")
                throw Abort(.tooManyRequests, reason: message)
            } else {
                req.logger.warning("Rate limit hit - Phone: •••\(normalizedPhone.suffix(4)), IP: \(clientIP)")
                throw Abort(.tooManyRequests, reason: "Rate limit exceeded. Please try again later.")
            }
        }
        
        let code = String(format: "%06d", Int.random(in: 100000...999999))
        
        // Store code using normalized phone
        await VerificationCodeStore.shared.store(phone: normalizedPhone, code: code)
        
        // Send SMS to original phone format (preserves user's formatting)
        do {
            let message = "\(code) is your Rangley verification code. Don't share it."
            try await req.smsService.sendText(
                to: body.phone,  // Use original format for SMS delivery
                body: message
            )
            
            // Record the attempt AFTER successful send
            await SMSRateLimiter.shared.recordAttempt(for: normalizedPhone, from: clientIP)
            
            req.logger.info("Verification code sent to •••\(normalizedPhone.suffix(4)) from IP: \(clientIP)")
            return .ok
            
        } catch {
            req.logger.error("Failed to send SMS to •••\(normalizedPhone.suffix(4)) from IP: \(clientIP): \(error)")
            throw Abort(.internalServerError, reason: "Failed to send verification code")
        }
    }
    

    // Verify phone code (with attempt limiting too)
    // Verify phone code with phone normalization
    publicAuth.post("verify-phone")
    {
        req -> VerificationResponse in
        let body = try req.content.decode(VerifyCodeRequest.self)
        
        // Normalize phone format to match stored format
        let normalizedPhone = body.phone.replacingOccurrences(of: " ", with: "")
                                         .replacingOccurrences(of: "-", with: "")
                                         .replacingOccurrences(of: "(", with: "")
                                         .replacingOccurrences(of: ")", with: "")
        
        guard await VerificationCodeStore.shared.verify(phone: normalizedPhone, code: body.code) else {
            req.logger.warning("Invalid verification attempt for •••\(normalizedPhone.suffix(4))")
            throw Abort(.badRequest, reason: "Invalid or expired verification code")
        }
        
        req.logger.info("Phone •••\(normalizedPhone.suffix(4)) verified successfully")
        
        return VerificationResponse(
            verified: true,
            token: "phone_verified_\(normalizedPhone.suffix(4))",
            message: "Phone number verified successfully"
        )
    }
    
    publicAuth.get("app-version")
    {
        req async throws -> [Func.ViewAppVersion.Results] in
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        guard let appVersionString = req.query[String.self, at: "version"],
              let appVersion = Int32(appVersionString)
        else {
            throw Abort(.badRequest, reason: "Missing or invalid 'version' query parameter")
        }
        
        return try await Func.ViewAppVersion.fetchAll(on: sql, Func.ViewAppVersion.In(app_version: appVersion))
    }
    
    publicAuth.get("validate", "display-name")
    {
        req async throws -> Func.ValidateDisplayName.Results in
        
        guard let displayName = req.query[String.self, at: "display_name"] else {
            throw Abort(.badRequest, reason: "Missing display_name query parameter")
        }

        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        do {
            let result = try await Func.ValidateDisplayName.call(on: sql, displayName: displayName)
            return result
            
        } catch let error as PSQLError {
            req.logger.error("Database error validating display name: \(error)")
            throw Abort(.internalServerError, reason: "Failed to validate display name")
        }
    }

    publicAuth.get("check", "username-availability")
    {
        req async throws -> Func.CheckUsernameAvailability.Results in
        
        guard let username = req.query[String.self, at: "username"] else {
            throw Abort(.badRequest, reason: "Missing username query parameter")
        }

        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        do {
            let result = try await Func.CheckUsernameAvailability.call(on: sql, username: username)
            return result
            
        } catch let error as PSQLError {
            req.logger.error("Database error checking username availability: \(error)")
            throw Abort(.internalServerError, reason: "Failed to check username availability")
        }
    }

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
                .init(num_inserted: 0, meet_id_uuid: nil, validation_failed: false, validation_reason: nil, validation_message: nil)
            )
            
            // Return validation failure in response instead of throwing
            if dbResult.validation_failed {
                return .init(
                    num_inserted: dbResult.num_inserted,
                    meet_id_uuid: dbResult.meet_id_uuid,
                    validation_failed: true,
                    validation_reason: dbResult.validation_reason,
                    validation_message: dbResult.validation_message
                )
            }
            
            // Validate the result for successful case
            guard dbResult.num_inserted == 1,
                  let meetId = dbResult.meet_id_uuid
            else { throw Abort(.internalServerError, reason: "Failed to create meet") }

            return .init(
                num_inserted: dbResult.num_inserted,
                meet_id_uuid: meetId,
                validation_failed: false,
                validation_reason: nil,
                validation_message: nil
            )
            
        } catch let error as PSQLError {
            // Handle specific PostgreSQL errors from your procedure
            let state = error.serverInfo?[.sqlState]
            
            switch state {
            case "22023": throw Abort(.badRequest, reason: "Invalid input parameters")
            case "23505": throw Abort(.conflict, reason: "Meet already exists")
            default:
                req.logger.error("Database error creating meet: \(error)")
                throw Abort(.internalServerError, reason: "Failed to create meet")
            }
        } catch let abort as Abort {
            // Re-throw Abort errors
            throw abort
        }
    }

    s.post("meet-with-invites")
    {
        req async throws -> HTTPDTO.MeetsWithInvites.InsertMeetResponse in
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }

        let body = try req.content.decode(HTTPDTO.MeetsWithInvites.InsertMeetBody.self)

        guard !body.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw Abort(.badRequest, reason: "name is required") }
        guard body.dttm_start_utc < body.dttm_end_utc
        else { throw Abort(.badRequest, reason: "dttm_start_utc must be before dttm_end_utc") }

        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        let input = Proc.SystemInsertMeetWithInvites.Params(
            cognito_sub: sub,
            initial_invitee_uuids: body.initial_invitee_uuids,
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
            max_capacity: body.max_capacity,
            invitation_message: body.invitation_message
        )
        
        let output = Proc.SystemInsertMeetWithInvites.Result(
            num_inserted: 0,
            new_meet_id_uuid: nil,
            validation_failed: false,
            validation_reason: nil,
            validation_message: nil
        )

        do {
            let dbResult = try await Proc.SystemInsertMeetWithInvites.call(on: sql, input, output)
            
            // Return validation failure in response instead of throwing
            if dbResult.validation_failed {
                return .init(
                    num_inserted: dbResult.num_inserted,
                    new_meet_id_uuid: dbResult.new_meet_id_uuid,
                    validation_failed: true,
                    validation_reason: dbResult.validation_reason,
                    validation_message: dbResult.validation_message
                )
            }
            
            // Validate the result for successful case
            guard dbResult.num_inserted == 1,
                  let meetId = dbResult.new_meet_id_uuid
            else { throw Abort(.internalServerError, reason: "Failed to create meet") }

            return .init(
                num_inserted: dbResult.num_inserted,
                new_meet_id_uuid: meetId,
                validation_failed: false,
                validation_reason: nil,
                validation_message: nil
            )
            
        } catch let error as PSQLError {
            let state = error.serverInfo?[.sqlState]
            
            switch state {
            case "22023": throw Abort(.badRequest, reason: "Invalid input parameters")
            case "23505": throw Abort(.conflict, reason: "Meet already exists")
            default:
                req.logger.error("Database error creating meet: \(error)")
                throw Abort(.internalServerError, reason: "Failed to create meet")
            }
        } catch let abort as Abort {
            throw abort
        }
    }

    s.post("updated-meet")
    {
        req async throws -> HTTPDTO.Meets.InsertUpdateResponse in
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }

        let body = try req.content.decode(HTTPDTO.Meets.InsertUpdatedBody.self)

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
            meet_id_uuid: body.meet_id_uuid,
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
                .init(num_inserted: 0, validation_failed: false, validation_reason: nil, validation_message: nil)
            )
            
            // Return validation failure in response instead of throwing
            if dbResult.validation_failed {
                return .init(
                    num_inserted: dbResult.num_inserted,
                    validation_failed: true,
                    validation_reason: dbResult.validation_reason,
                    validation_message: dbResult.validation_message
                )
            }
            
            // Validate the result for successful case
            guard dbResult.num_inserted == 1
            else { throw Abort(.internalServerError, reason: "Failed to update meet") }

            return .init(
                num_inserted: dbResult.num_inserted,
                validation_failed: false,
                validation_reason: nil,
                validation_message: nil
            )
                        
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
        } catch let abort as Abort {
            throw abort
        }
    }
    
    
    
    s.post("meets", "invitations", "respond")
    {
        req async throws -> HTTPDTO.MeetsWithInvites.RespondToInviteResponse in
        
        // Auth validation
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        let body = try req.content.decode(HTTPDTO.MeetsWithInvites.RespondToInviteBody.self)
        
        // Database check
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        do {
            let result = try await Func.SystemRespondToMeetInvitation.call(on: sql, .init(
                cognito_sub: sub,
                meet_id_uuid: body.meet_id_uuid,
                response_status_id: body.response_status_id
            ))
            
            return .init(
                success: result.success,
                message: result.message,
                old_status_id: result.old_status_id,
                new_status_id: result.new_status_id
            )
            
        } catch let error as PSQLError {
            req.logger.error("Database error responding to invitation: \(error)")
            throw Abort(.internalServerError, reason: "Failed to respond to invitation")
        }
    }
    
    s.post("meets", "leave")
    {
        req async throws -> HTTPDTO.MeetsWithInvites.LeaveMeetResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        let body = try req.content.decode(HTTPDTO.MeetsWithInvites.LeaveMeetBody.self)
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        do {
            let result = try await Func.SystemLeaveMeet.call(on: sql, .init(
                cognito_sub: sub,
                meet_id_uuid: body.meet_id_uuid
            ))
            
            return .init(
                success: result.success,
                message: result.message,
                old_status_id: result.old_status_id
            )
            
        } catch let error as PSQLError {
            req.logger.error("Database error leaving meet: \(error)")
            throw Abort(.internalServerError, reason: "Failed to leave meet")
        }
    }
    
    s.post("update-participant-status")
    {
        req async throws -> HTTPDTO.UpdateParticipantStatus.UpdateParticipantStatusResponse in
        
        // Auth validation
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        let body = try req.content.decode(HTTPDTO.UpdateParticipantStatus.UpdateParticipantStatusBody.self)
        
        // Database check
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        do {
            let result = try await Func.UpdateParticipantStatus.call(on: sql, .init(
                cognito_sub: sub,
                meet_id_uuid: body.meet_id_uuid,
                target_user_uuid: body.target_user_uuid,
                new_status_id: body.new_status_id
            ))
            
            return .init(
                success: result.success,
                message: result.message,
                participant_id_out: result.participant_id_out,
                old_status_id: result.old_status_id,
                new_status_id: result.new_status_id
            )
            
        } catch let error as PSQLError {
            req.logger.error("Database error responding to invitation: \(error)")
            throw Abort(.internalServerError, reason: "Failed to respond to invitation")
        }
    }
    
    s.post("insert-additional-participants-to-meet") // Fixed typo: "invitess" -> "invites"
    {
        req async throws -> HTTPDTO.MeetsWithInvites.InsertAdditionalParicipantsResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }

        let body = try req.content.decode(HTTPDTO.MeetsWithInvites.InsertAdditionalParicipantsBody.self)

        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        do {
            let result = try await Func.InsertAdditionalParticipantsToMeet.call(on: sql, .init(
                cognito_sub                     : sub,
                meet_id_uuid                    : body.meet_id_uuid,
                inviter_user_uuid               : body.inviter_user_uuid,
                additional_invitee_user_uuids    : body.additional_invitee_user_uuids,
                invitation_message              : body.invitation_message
            ))
            
            return .init(
                user_uuid: result.user_uuid,
                username: result.username,
                invitation_status: result.invitation_status,
                returned_notification_id: result.returned_notification_id
            )
            
        } catch let error as PSQLError {
            req.logger.error("Database error responding to invitation: \(error)")
            throw Abort(.internalServerError, reason: "Failed to respond to invitation")
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
    
    // TODO: consider pluralizign eveyr route
    s.post("user", "delete")
    {
        req async throws -> Proc.SystemDeleteUser.Out in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }

        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }

        let params = Proc.SystemDeleteUser.In(cognito_sub: sub)
        let outputPlaceholder = Proc.SystemDeleteUser.Out(is_success: false)
        
        return try await Proc.SystemDeleteUser.call(on: sql, params, outputPlaceholder)
    }
    
    // Friend request routes
    s.post("friends", "request")
    {
        req async throws -> HTTPDTO.Friends.SendRequestResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        let body = try req.content.decode(HTTPDTO.Friends.SendRequestBody.self)
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        let input = Func.SendFriendRequest.In(
            cognito_sub: sub,
            recipient_user_uuid: body.recipient_user_uuid
        )
        
        let rs = try await sql.raw(Func.SendFriendRequest.query(input)).all()
        let rows: [Func.SendFriendRequest.Results] = try rs.map(Func.SendFriendRequest.decode)
        
        guard let result = rows.first else {
            throw Abort(.internalServerError, reason: "No result from friend request")
        }
        
        return .init(
            friend_request_id: result.friend_request_id,
            success: result.success,
            message: result.message
        )
    }

    s.post("friends", "respond")
    {
        req async throws -> HTTPDTO.Friends.RespondToRequestResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        let body = try req.content.decode(HTTPDTO.Friends.RespondToRequestBody.self)
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        let input = Func.RespondToFriendRequest.In(
            cognito_sub: sub,
            friend_request_id: body.friend_request_id,
            accept: body.accept
        )
        
        let rs = try await sql.raw(Func.RespondToFriendRequest.query(input)).all()
        let rows: [Func.RespondToFriendRequest.Results] = try rs.map(Func.RespondToFriendRequest.decode)
        
        guard let result = rows.first else {
            throw Abort(.internalServerError, reason: "No result from respond")
        }
        
        return .init(
            success: result.success,
            message: result.message
        )
    }
    
    s.post("inbox", "clear")
    {
        req async throws -> HTTPDTO.Inbox.ClearInboxResponse in
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        let input = Func.ClearUserInbox.In(cognito_sub: sub)
        let rs = try await sql.raw(Func.ClearUserInbox.query(input)).all()
        
        guard let result = try rs.map(Func.ClearUserInbox.decode).first else {
            throw Abort(.internalServerError, reason: "No result returned")
        }
        
        return .init(
            success: result.success,
            message: result.message,
            cleared_count: result.cleared_count
        )
    }
    
    s.delete("inbox", "notification")
    {
        req async throws -> HTTPDTO.Inbox.DeleteNotificationResponse in
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        let body = try req.content.decode(HTTPDTO.Inbox.DeleteNotificationBody.self)
        
        let input = Func.DeleteInboxNotification.In(
            cognito_sub: sub,
            notification_id: body.notification_id
        )
        
        let rs = try await sql.raw(Func.DeleteInboxNotification.query(input)).all()
        
        guard let result = try rs.map(Func.DeleteInboxNotification.decode).first else {
            throw Abort(.internalServerError, reason: "No result returned")
        }
        
        return .init(success: result.success, message: result.message)
    }
    
    // DELETE /s/friends/:user_uuid - Remove friend
    s.delete("friends", ":user_uuid")
    {
        req async throws -> HTTPDTO.Friends.UnfriendResponse in
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        guard let userUUIDString = req.parameters.get("user_uuid"),
              let targetUserUUID = UUID(uuidString: userUUIDString)
        else { throw Abort(.badRequest, reason: "Invalid user_uuid") }
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        let input = Func.DeleteFriend.In(
            cognito_sub: sub,
            target_user_uuid: targetUserUUID
        )
        
        let result = try await Func.DeleteFriend.fetchOne(on: sql, input)
        
        return .init(success: result.success, message: result.message)
    }
    
    // =========================================================
    // MARK: - Friend GRoup Stuff
    // =========================================================
    // Create friend group
    // =========================================================
    // MARK: - Meet Group Routes
    // =========================================================

    ///Create meet group
    s.post("meet-groups", "insert")
    {
        req async throws -> HTTPDTO.MeetGroups.InsertGroupResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        let body = try req.content.decode(HTTPDTO.MeetGroups.InsertGroupBody.self)
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        do {
            let result = try await Func.SystemInsertMeetGroup.call(on: sql, .init(
                cognito_sub: sub,
                group_name: body.group_name,
                image_reference: body.image_reference ?? "person.3.fill"
            ))
            
            return .init(
                success: result.success,
                message: result.message,
                meet_group_id: result.meet_group_id,
                validation_failed: result.validation_failed,
                validation_reason: result.validation_reason,
                validation_message: result.validation_message
            )
            
        } catch let error as PSQLError {
            req.logger.error("Database error creating meet group: \(error)")
            throw Abort(.internalServerError, reason: "Failed to create meet group")
        }
    }

    // Invite members to group
    s.post("meet-groups", "invite")
    {
        req async throws -> HTTPDTO.MeetGroups.InviteMembersResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        let body = try req.content.decode(HTTPDTO.MeetGroups.InviteMembersBody.self)
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        do {
            let result = try await Func.SystemInviteToMeetGroup.call(on: sql, .init(
                cognito_sub: sub,
                meet_group_id: body.meet_group_id,
                user_uuids: body.user_uuids
            ))
            
            return .init(
                success: result.success,
                message: result.message,
                invited_count: result.invited_count,
                skipped_count: result.skipped_count
            )
            
        } catch let error as PSQLError {
            req.logger.error("Database error inviting to meet group: \(error)")
            throw Abort(.internalServerError, reason: "Failed to invite members")
        }
    }

    // Respond to invitation
    s.post("meet-groups", "respond")
    {
        req async throws -> HTTPDTO.MeetGroups.RespondInvitationResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        let body = try req.content.decode(HTTPDTO.MeetGroups.RespondInvitationBody.self)
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        do {
            let result = try await Func.SystemRespondMeetGroupInvitation.call(on: sql, .init(
                cognito_sub: sub,
                invitation_id: body.invitation_id,
                accept: body.accept
            ))
            
            return .init(
                success: result.success,
                message: result.message
            )
            
        } catch let error as PSQLError {
            req.logger.error("Database error responding to invitation: \(error)")
            throw Abort(.internalServerError, reason: "Failed to respond to invitation")
        }
    }

    // Remove members from group
    s.post("meet-groups", "delete-members")
    {
        req async throws -> HTTPDTO.MeetGroups.RemoveMembersResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        let body = try req.content.decode(HTTPDTO.MeetGroups.RemoveMembersBody.self)
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        do {
            let result = try await Func.SystemDeleteMembersFromMeetGroup.call(on: sql, .init(
                cognito_sub: sub,
                meet_group_id: body.meet_group_id,
                user_uuids: body.user_uuids
            ))
            
            return .init(
                success: result.success,
                message: result.message,
                removed_count: result.removed_count
            )
            
        } catch let error as PSQLError {
            req.logger.error("Database error removing members from group: \(error)")
            throw Abort(.internalServerError, reason: "Failed to remove members")
        }
    }

    // Delete meet group
    s.post("meet-groups", "delete")
    {
        req async throws -> HTTPDTO.MeetGroups.DeleteGroupResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        let body = try req.content.decode(HTTPDTO.MeetGroups.DeleteGroupBody.self)
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        do {
            let result = try await Func.SystemDeleteMeetGroup.call(on: sql, .init(
                cognito_sub: sub,
                meet_group_id: body.meet_group_id
            ))
            
            return .init(
                success: result.success,
                message: result.message
            )
            
        } catch let error as PSQLError {
            req.logger.error("Database error deleting meet group: \(error)")
            throw Abort(.internalServerError, reason: "Failed to delete meet group")
        }
    }

    // Leave meet group
    s.post("meet-groups", "leave")
    {
        req async throws -> HTTPDTO.MeetGroups.LeaveMeetGroupResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        let body = try req.content.decode(HTTPDTO.MeetGroups.LeaveMeetGroupBody.self)
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        do {
            let result = try await Func.SystemLeaveMeetGroup.call(on: sql, .init(
                cognito_sub: sub,
                meet_group_id: body.meet_group_id
            ))
            
            return .init(
                success: result.success,
                message: result.message
            )
            
        } catch let error as PSQLError {
            req.logger.error("Database error leaving meet group: \(error)")
            throw Abort(.internalServerError, reason: "Failed to leave meet group")
        }
    }
    
    // Update group image
    s.post("meet-groups", "modify-image")
    {
        req async throws -> HTTPDTO.MeetGroups.ModifyImageResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        let body = try req.content.decode(HTTPDTO.MeetGroups.ModifyImageBody.self)
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        do {
            let result = try await Func.SystemModifyMeetGroupImage.call(on: sql, .init(
                cognito_sub: sub,
                meet_group_id: body.meet_group_id,
                image_reference: body.image_reference
            ))
            
            return .init(
                success: result.success,
                message: result.message
            )
            
        } catch let error as PSQLError {
            req.logger.error("Database error updating group image: \(error)")
            throw Abort(.internalServerError, reason: "Failed to update group image")
        }
    }
    
    
    s.post("meet-groups", "insert-members")
    {
        req async throws -> HTTPDTO.MeetGroups.InsertMembersResponse in
        
        let sub = req.cognito.sub.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sub.isEmpty else { throw Abort(.unauthorized, reason: "Invalid auth sub") }
        
        let body = try req.content.decode(HTTPDTO.MeetGroups.InsertMembersBody.self)
        
        guard let sql = req.db as? any SQLDatabase
        else { throw Abort(.failedDependency, reason: "Database is not SQLDatabase") }
        
        do {
            let result = try await Func.SystemInsertMembersToMeetGroup.call(on: sql, .init(
                cognito_sub: sub,
                meet_group_id: body.meet_group_id,
                user_uuids: body.user_uuids
            ))
            
            return .init(
                success: result.success,
                message: result.message,
                added_count: result.added_count,
                skipped_count: result.skipped_count
            )
            
        } catch let error as PSQLError {
            req.logger.error("Database error adding members to meet group: \(error)")
            throw Abort(.internalServerError, reason: "Failed to add members")
        }
    }
    

    // =========================================================
    // MARK: - END Friend GRoup Stuff
    // =========================================================
    
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

/*

 
 
 In PostgreSQL you must supply an argument for every parameter without a default, including OUT.
 The OUT placeholders aren’t evaluated (typical is NULL), and the procedure returns a single row containing the OUT/INOUT values.
 
 
 
*/
