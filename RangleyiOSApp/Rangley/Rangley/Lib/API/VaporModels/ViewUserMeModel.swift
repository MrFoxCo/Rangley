//
//  ViewUserMeModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

import SwiftUI

struct ViewUserMe: Codable
{
    let uuid                : String
    let username            : String
    let display_name        : String
    let cellphone           : String?
    let email               : String?
    let dob                 : Date
    let dttm_created_utc    : Date
}
