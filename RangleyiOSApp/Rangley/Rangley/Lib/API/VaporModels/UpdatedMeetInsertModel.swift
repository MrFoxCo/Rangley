//
//  UpdatedMeetInsertModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/14/25.
//

import SwiftUI
import Foundation

struct UpdatedMeetInsertBody: Codable {
    // Required
    let meet_id_uuid: String

    // Optional: send only what changed
    let latitude: Double?
    let longitude: Double?
    let region_latitude: Double?
    let region_longitude: Double?
    let region_radius: Double?

    let meet_status_id: Int16?
    let name: String?
    let dttm_start_utc: Date?
    let dttm_end_utc: Date?
    let description: String?
    let change_reason: String?
    let meet_category_id: Int16?
    let max_capacity: Int32?
}

struct UpdatedMeetInsertResponse: Codable {
    let num_inserted: Int32
}

extension UpdatedMeetInsertBody {
    var isCoordinateSetValid: Bool {
        let coords = [latitude, longitude, region_latitude, region_longitude, region_radius]
        let provided = coords.compactMap { $0 }.count
        return provided == 0 || provided == 5
    }
}
