//
//  AppVersionModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/26/25.
//

import Foundation

struct AppVersionModelBody: Codable
{
    let app_version : Int32
}

struct AppVersionModelResponse: Codable
{
    let is_supported           : Bool
    let latest_version         : Int32
    let supported_features     : [Int32]
}
