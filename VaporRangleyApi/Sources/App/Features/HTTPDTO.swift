//
//  HTTPDTO.swift
//  VaporRangleyApi
//
//  Created by Anthony Guzzardo on 9/12/25.
//

import Vapor

/// HTTPDTO
/// =======
/// A lightweight namespace for **HTTP-layer data transfer objects** (DTOs).
/// These types model the JSON your API **receives** from clients and **returns**
/// to clients. They are intentionally decoupled from database/procedure models.
///
/// Why use `HTTPDTO`?
/// - **Separation of concerns**: HTTP contract stays stable even if DB schema or
///   stored procedures change. Route code translates between HTTPDTO ↔︎ DB params.
/// - **Security**: Client-facing DTOs omit sensitive/server-controlled fields
///   (e.g., `cognito_sub`). The server injects identity from the verified token.
/// - **Versioning**: You can evolve HTTP payloads (add fields, new responses)
///   without touching DB-facing types.
/// - **Testability**: Easier to unit-test route decoding/encoding independently.
///
/// Conventions:
/// - Group DTOs by resource under `HTTPDTO.<Feature>` (e.g., `HTTPDTO.Meets`).
/// - `*Body` types = **request payloads** coming from clients.
/// - `*Response` types = **responses** you return to clients.
/// - DB-facing types live elsewhere (e.g., `Proc.SystemInsertMeet.Params`) and
///   may include fields not exposed to clients (like `cognito_sub`).
enum HTTPDTO {
    enum Meets {
        struct InsertBody: Content, Sendable {
            // Required
            let latitude        : Double
            let longitude       : Double
            let region_latitude : Double
            let region_longitude: Double
            let region_radius   : Double
            let name            : String
            let dttm_start_utc  : Date
            let dttm_end_utc    : Date
            // Optional
            let description     : String?
            let meet_category_id: Int16?
            let max_capacity    : Int32?
        }
        

        
        struct InsertUpdatedBody: Content, Sendable {
            // Required - must know which meet to update
            let meet_id_uuid    : String
            
            // ALL OPTIONAL - only send fields that are changing
            let latitude        : Double?
            let longitude       : Double?
            let region_latitude : Double?
            let region_longitude: Double?
            let region_radius   : Double?
            let meet_status_id  : Int16?
            let name            : String?
            let dttm_start_utc  : Date?
            let dttm_end_utc    : Date?
            let description     : String?
            let change_reason   : String?
            let meet_category_id: Int16?
            let max_capacity    : Int32?
        }
        
        struct InsertDeletedBody: Content, Sendable {
            // Required - must know which meet to update
            let meet_id_uuid    : String
        }
        
        struct InsertResponse: Content, Sendable {
            let num_inserted: Int32
        }
    }
}
