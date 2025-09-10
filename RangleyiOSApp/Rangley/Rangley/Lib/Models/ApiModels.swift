//
//  ApiModels.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/1/25.
//

import Foundation

// MARK: - Shared

enum APIModels {}


// MARK: - i/meet-coordinate

extension APIModels
{
    struct InsertMeetCoordinateRequest: Codable
    {
        let latitude: Double
        let longitude: Double
        let regionLatitude: Double
        let regionLongitude: Double
        let regionRadius: Double

        enum CodingKeys: String, CodingKey
        {
            case latitude, longitude
            case regionLatitude  = "region_latitude"
            case regionLongitude = "region_longitude"
            case regionRadius    = "region_radius"
        }
    }

    struct InsertMeetCoordinateResponse: Codable
    {
        let newMeetCoordinateId: Int64?
        enum CodingKeys: String, CodingKey { case newMeetCoordinateId = "new_meet_coordinate_id" }
    }
}

// MARK: - i/meet-id

extension APIModels {
    struct InsertMeetIdRequest: Codable
    {
        let createdByUserId: Int64
        enum CodingKeys: String, CodingKey { case createdByUserId = "created_by_user_id" }
    }

    struct InsertMeetIdResponse: Codable
    {
        let newMeetId: Int64?
        enum CodingKeys: String, CodingKey { case newMeetId = "new_meet_id" }
    }
}

// MARK: - i/meet

extension APIModels
{
    struct InsertMeetRequest: Codable
    {
        // required
        let meetId: Int64
        let meetCoordinateId: Int64
        let name: String
        let dttmStartUtc: Date
        let dttmEndUtc: Date
        // optional
        let description: String?
        let changeReason: String?
        let meetCategoryId: Int16?
        let maxCapacity: Int32?

        enum CodingKeys: String, CodingKey
        {
            case meetId            = "meet_id"
            case meetCoordinateId  = "meet_coordinate_id"
            case name
            case dttmStartUtc      = "dttm_start_utc"
            case dttmEndUtc        = "dttm_end_utc"
            case description
            case changeReason      = "change_reason"
            case meetCategoryId    = "meet_category_id"
            case maxCapacity       = "max_capacity"
        }
    }

    struct InsertMeetResponse: Codable
    {
        let numInserted: Int32?
        enum CodingKeys: String, CodingKey { case numInserted = "num_inserted" }
    }
}

// MARK: - i/meet-change-stamp

extension APIModels
{
    struct InsertChangeStampRequest: Codable
    {
        let meetId: Int64
        enum CodingKeys: String, CodingKey { case meetId = "meet_id" }
    }

    struct InsertChangeStampResponse: Codable
    {
        let newChangeStamp: Int64?
        enum CodingKeys: String, CodingKey { case newChangeStamp = "new_change_stamp" }
    }
}

// MARK: - i/updated-meet

extension APIModels
{
    struct InsertUpdatedMeetRequest: Codable
    {
        // required
        let meetId: Int64
        let changeStamp: Int64
        let meetCoordinateId: Int64
        let name: String
        let dttmStartUtc: Date
        let dttmEndUtc: Date
        // optional
        let meetStatusId: Int16?
        let description: String?
        let changeReason: String?
        let meetCategoryId: Int16?
        let maxCapacity: Int32?

        enum CodingKeys: String, CodingKey
        {
            case meetId            = "meet_id"
            case changeStamp       = "change_stamp"
            case meetCoordinateId  = "meet_coordinate_id"
            case name
            case dttmStartUtc      = "dttm_start_utc"
            case dttmEndUtc        = "dttm_end_utc"
            case meetStatusId      = "meet_status_id"
            case description
            case changeReason      = "change_reason"
            case meetCategoryId    = "meet_category_id"
            case maxCapacity       = "max_capacity"
        }
    }

    struct InsertUpdatedMeetResponse: Codable
    {
        let numInserted: Int32?
        enum CodingKeys: String, CodingKey { case numInserted = "num_inserted" }
    }
}

// MARK: - v/meets

extension APIModels
{
    struct ViewMeetsItem: Codable, Identifiable
    {
        var id: Int64 { meetId }

        let meetId: Int64
        let changeStamp: Int64
        let meetStatusId: Int16
        let latitude: Double
        let longitude: Double
        let regionLatitude: Double
        let regionLongitude: Double
        let regionRadius: Double
        let dttmStartUtc: Date
        let dttmEndUtc: Date
        let name: String
        let categoryName: String
        let description: String
        let maxCapacity: Int32
        let createdByUserId: Int64
        let displayName: String

        enum CodingKeys: String, CodingKey
        {
            case meetId            = "meet_id"
            case changeStamp       = "change_stamp"
            case meetStatusId      = "meet_status_id"
            case latitude, longitude
            case regionLatitude    = "region_latitude"
            case regionLongitude   = "region_longitude"
            case regionRadius      = "region_radius"
            case dttmStartUtc      = "dttm_start_utc"
            case dttmEndUtc        = "dttm_end_utc"
            case name
            case categoryName      = "category_name"
            case description
            case maxCapacity       = "max_capacity"
            case createdByUserId   = "created_by_user_id"
            case displayName       = "display_name"
        }
    }
}

// MARK: - v/user/:user_id

extension APIModels
{
    struct ViewUserItem: Codable
    {
        let cognitoSub: String?
        let username: String?
        let displayName: String?
        let cellphone: String?
        let email: String?

        enum CodingKeys: String, CodingKey
        {
            case cognitoSub = "cognito_sub"
            case username
            case displayName = "display_name"
            case cellphone
            case email
        }
    }
}

// MARK: - v/meet-categories

extension APIModels
{
    struct ViewMeetCategoryItem: Codable, Identifiable
    {
        var id: Int32 { meetCategoryId }
        let meetCategoryId: Int32
        let name: String

        enum CodingKeys: String, CodingKey
        {
            case meetCategoryId = "meet_category_id"
            case name
        }
    }
}

// MARK: - Lightweight API Client

final class APIClient
{
    let baseURL: URL
    let authToken: String

    init(baseURL: URL, authToken: String)
    {
        self.baseURL = baseURL
        self.authToken = authToken
    }

    private func makeRequest(path: String, method: String, body: Data? = nil) -> URLRequest
    {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = body
        
        return req
    }

    private static let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601 // for dttm_* fields
        return enc
    }()

    private static let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601 // for dttm_* fields
        return dec
    }()

    func post<Req: Encodable, Res: Decodable>(_ path: String, body: Req) async throws -> Res
    {
        let data                = try Self.encoder.encode(body)
        let req                 = makeRequest(path: path, method: "POST", body: data)
        let (respData, resp)    = try await URLSession.shared.data(for: req)
        
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode)
        else
        {
            let text = String(data: respData, encoding: .utf8) ?? ""
            throw NSError(domain: "API", code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: "Bad response: \(text)"])
        }
        
        return try Self.decoder.decode(Res.self, from: respData)
    }

    func get<Res: Decodable>(_ path: String) async throws -> Res
    {
        let req                 = makeRequest(path: path, method: "GET")
        let (respData, resp)    = try await URLSession.shared.data(for: req)
        
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let text = String(data: respData, encoding: .utf8) ?? ""
            throw NSError(domain: "API", code: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: "Bad response: \(text)"])
        }
        return try APIClient.decoder.decode(Res.self, from: respData)
    }
}

// MARK: - Convenience calls

extension APIClient
{
    // MARK: - Inserts

    func insertMeetCoordinate(_ body: APIModels.InsertMeetCoordinateRequest) async throws -> APIModels.InsertMeetCoordinateResponse {
        try await post("/i/meet-coordinate", body: body)
    }

    func insertMeetId(_ body: APIModels.InsertMeetIdRequest) async throws -> APIModels.InsertMeetIdResponse
    {
        try await post("/i/meet-id", body: body)
    }

    func insertMeet(_ body: APIModels.InsertMeetRequest) async throws -> APIModels.InsertMeetResponse
    {
        try await post("/i/meet", body: body)
    }

    func insertChangeStamp(_ body: APIModels.InsertChangeStampRequest) async throws -> APIModels.InsertChangeStampResponse {
        try await post("/i/meet-change-stamp", body: body)
    }

    func insertUpdatedMeet(_ body: APIModels.InsertUpdatedMeetRequest) async throws -> APIModels.InsertUpdatedMeetResponse {
        try await post("/i/updated-meet", body: body)
    }

    // Views
    func viewMeets() async throws -> [APIModels.ViewMeetsItem]
    {
        try await get("/v/meets")
    }

    func viewUser(userId: Int64) async throws -> [APIModels.ViewUserItem]
    {
        try await get("/v/user/\(userId)")
    }

    func viewMeetCategories() async throws -> [APIModels.ViewMeetCategoryItem]
    {
        try await get("/v/meet-categories")
    }
}

// MARK: - Helpers

extension DateFormatter
{
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
