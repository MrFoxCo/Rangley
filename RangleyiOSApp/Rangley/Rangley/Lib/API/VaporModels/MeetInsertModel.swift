//
//  MeetInsertModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

// MARK: - s/meet models (client-side)

import SwiftUI
import Foundation

struct MeetInsertBody: Codable {
    // Required
    let latitude: Double
    let longitude: Double
    let region_latitude: Double
    let region_longitude: Double
    let region_radius: Double
    let name: String
    let dttm_start_utc: Date
    let dttm_end_utc: Date
    // Optional
    let description: String?
    let meet_category_id: Int16?
    let max_capacity: Int32?
}

struct MeetInsertResponse: Codable {
    let num_inserted: Int32
}
