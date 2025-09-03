//
//  UserByAuthReg.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/2/25.
//
// AuthRegisterModels.swift

import Foundation

// Match server snake_case exactly to avoid CodingKeys noise.
public struct AuthRegisterRequest: Codable, Sendable
{
    public let username: String
    public let display_name: String
    public let cellphone: String?
    public let email: String?
    public let dob: String          // "YYYY-MM-DD"
    public let first_name: String?
    public let last_name: String?
    
    public init(username: String,
                display_name: String,
                cellphone: String?,
                email: String?,
                dob: String,
                first_name: String?,
                last_name: String?) {
        self.username = username
        self.display_name = display_name
        self.cellphone = cellphone
        self.email = email
        self.dob = dob
        self.first_name = first_name
        self.last_name = last_name
    }
}

public struct AuthRegisterResult: Codable, Sendable
{
    public let is_success: Bool?
}

