//
//  MeetFormViewModel.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/14/25.
//

import SwiftUI
import Foundation
import CoreLocation

enum MeetFormMode {
    case create(location: LocationInfo)
    case update(existing: ViewMeetsModel) // whatever you already use for the list/detail
}

final class MeetFormViewModel: ObservableObject {
    // Inputs (originals for update)
    private let mode: MeetFormMode
    private let meetIDUUID: String? // present in update mode

    // Editable fields (bind these to your view)
    @Published var name: String
    @Published var start: Date
    @Published var end: Date
    @Published var descriptionText: String?
    @Published var meetCategoryID: Int16?
    @Published var maxCapacity: Int32?

    // Coordinates (nil = unchanged; non-nil = edited)
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var regionLatitude: Double?
    @Published var regionLongitude: Double?
    @Published var regionRadius: Double?

    // Originals (only for update mode)
    private var origName: String?
    private var origStart: Date?
    private var origEnd: Date?
    private var origDescription: String?
    private var origCategoryID: Int16?
    private var origMaxCapacity: Int32?
    private var origLat: Double?
    private var origLon: Double?
    private var origRegLat: Double?
    private var origRegLon: Double?
    private var origRegRad: Double?

    init(mode: MeetFormMode) {
        self.mode = mode
        switch mode {
        case .create(let loc):
            self.meetIDUUID = nil
            self.name = ""
            let now = Date()
            self.start = now
            self.end = now.addingTimeInterval(3600)
            self.descriptionText = nil
            self.meetCategoryID = nil
            self.maxCapacity = nil
            // Prefill coords from creation location (user may keep as is)
            self.latitude = loc.Coordinate.latitude
            self.longitude = loc.Coordinate.longitude
            self.regionLatitude = loc.RegionCoordinate.latitude
            self.regionLongitude = loc.RegionCoordinate.longitude
            self.regionRadius = loc.RegionRadius
        case .update(let existing):
            self.meetIDUUID = existing.meet_id_uuid
            // Prefill editable fields
            self.name = existing.name
            self.start = existing.dttm_start_utc
            self.end   = existing.dttm_end_utc
            self.descriptionText = existing.description
            self.meetCategoryID  = existing.meet_category_id
            self.maxCapacity     = existing.max_capacity
            // Coords start as unchanged (nil) until user taps Change Location
            self.latitude = nil; self.longitude = nil
            self.regionLatitude = nil; self.regionLongitude = nil; self.regionRadius = nil
            // Save originals for diffing
            self.origName = existing.name
            self.origStart = existing.dttm_start_utc
            self.origEnd   = existing.dttm_end_utc
            self.origDescription = existing.description
            self.origCategoryID  = existing.meet_category_id
            self.origMaxCapacity = existing.max_capacity
            self.origLat   = existing.latitude
            self.origLon   = existing.longitude
            self.origRegLat = existing.region_latitude
            self.origRegLon = existing.region_longitude
            self.origRegRad = existing.region_radius
        }
    }

    // Validation
    func validate() -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Name is required." }
        guard trimmed.count <= 50 else { return "Name must be 50 characters or fewer." }
        guard start < end else { return "Start time must be before end time." }

        // Option B: if any coord changed, all must be present
        let coords = [latitude, longitude, regionLatitude, regionLongitude, regionRadius]
        let provided = coords.compactMap{$0}.count
        guard provided == 0 || provided == 5 else {
            return "Provide all 5 coordinate fields or none."
        }
        if let mc = maxCapacity, mc < 2 { return "Capacity must be at least 2." }
        return nil
    }

    // Build create body
    func makeCreateBody(locationFallback: LocationInfo) -> MeetInsertBody? {
        guard case .create = mode else { return nil }
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50))

        // If user didn’t alter the prefilled coords, ensure they’re present from the location
        let lat = latitude ?? locationFallback.Coordinate.latitude
        let lon = longitude ?? locationFallback.Coordinate.longitude
        let rlat = regionLatitude ?? locationFallback.RegionCoordinate.latitude
        let rlon = regionLongitude ?? locationFallback.RegionCoordinate.longitude
        let rrad = regionRadius ?? locationFallback.RegionRadius

        return .init(
            latitude: lat,
            longitude: lon,
            region_latitude: rlat,
            region_longitude: rlon,
            region_radius: rrad,
            name: trimmed,
            dttm_start_utc: start,
            dttm_end_utc: end,
            description: descriptionText,
            meet_category_id: meetCategoryID,
            max_capacity: maxCapacity
        )
    }
    
    @inline(__always)
    private func diff<T: Equatable>(_ new: T?, _ old: T?) -> T? {
        guard let new = new else { return nil }     // only send if client set a value
        return (old == nil || new != old) ? new : nil
    }

    // Example usage:


    // Build update body (send only diffs; return nil if no changes)
    func makeUpdateBody() -> UpdatedMeetInsertBody? {
        guard case .update = mode, let id = meetIDUUID else { return nil }

        // Simple diffs
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50))
        let nameOpt: String? = (trimmed != (origName ?? "")) ? trimmed : nil
        let startOpt: Date?  = (origStart.map { $0 != start } ?? true) ? start : nil
        let endOpt: Date?    = (origEnd.map   { $0 != end   } ?? true) ? end   : nil
        let descOpt: String? = diff(descriptionText, origDescription)
        let catOpt : Int16?  = diff(meetCategoryID,  origCategoryID)
        let capOpt : Int32?  = diff(maxCapacity,     origMaxCapacity)

        // Coords: all-or-none
        let coordProvided = [latitude, longitude, regionLatitude, regionLongitude, regionRadius]
            .compactMap { $0 }.count

        var latOpt: Double? = nil
        var lonOpt: Double? = nil
        var rLatOpt: Double? = nil
        var rLonOpt: Double? = nil
        var rRadOpt: Double? = nil

        if coordProvided == 5 {
            guard
                let lat  = latitude,
                let lon  = longitude,
                let rLat = regionLatitude,
                let rLon = regionLongitude,
                let rRad = regionRadius
            else {
                return nil // inconsistent; fail-fast is fine
            }

            let eps  = 1e-7
            let epsR = 1e-3
            let sameAsOrig =
                abs(lat  - (origLat    ?? lat )) < eps  &&
                abs(lon  - (origLon    ?? lon )) < eps  &&
                abs(rLat - (origRegLat ?? rLat)) < eps  &&
                abs(rLon - (origRegLon ?? rLon)) < eps  &&
                abs(rRad - (origRegRad ?? rRad)) < epsR

            if !sameAsOrig {
                latOpt  = lat
                lonOpt  = lon
                rLatOpt = rLat
                rLonOpt = rLon
                rRadOpt = rRad
            }
        } // else: send none

        // No-op guard
        let nothingChanged = ![
            nameOpt as Any?, startOpt as Any?, endOpt as Any?, descOpt as Any?,
            catOpt as Any?,  capOpt as Any?,
            latOpt as Any?,  lonOpt as Any?, rLatOpt as Any?, rLonOpt as Any?, rRadOpt as Any?
        ].contains { $0 != nil }

        if nothingChanged { return nil }


        return UpdatedMeetInsertBody(
            meet_id_uuid: id,
            latitude:        latOpt,
            longitude:       lonOpt,
            region_latitude: rLatOpt,
            region_longitude:rLonOpt,
            region_radius:   rRadOpt,
            meet_status_id:  nil,             // add if you expose in UI
            name:            nameOpt,
            dttm_start_utc:  startOpt,
            dttm_end_utc:    endOpt,
            description:     descOpt,
            change_reason:   nil,             // wire up if you add a field
            meet_category_id:catOpt,
            max_capacity:    capOpt
        )
    }

}
