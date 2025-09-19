//
//  DeletedMeetInsertModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/14/25.
//

import SwiftUI
import Foundation

struct DeletedMeetInsertBody: Codable {
    // Required
    let meet_id_uuid: UUID
}

struct DeletedMeetInsertResponse: Codable {
    let num_inserted: Int32
}
