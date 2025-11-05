//
//  ViewUserMeModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

import SwiftUI

struct ViewUserMeModel: Codable, Identifiable
{
    let user_uuid           : UUID
    let username            : String
    let display_name        : String
    let cellphone           : String?
    let email               : String?
    let dob                 : String
    let dttm_created_utc    : Date
    
    var id: UUID { user_uuid }
    
    var firstName: String {
        let components = display_name.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if let first = components.first {
            return String(first)
        }
        return display_name
    }
}
