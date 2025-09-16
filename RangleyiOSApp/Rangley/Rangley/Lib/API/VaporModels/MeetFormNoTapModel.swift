// =========================================================
// MARK: - MeetFormNoTapModel
// =========================================================

import Foundation
import CoreLocation

enum MeetFormNoTapMode
{
    case create(location: LocationInfo? = nil)
}

final class MeetFormNoTapModel: ObservableObject
{
    // Inputs (originals for update — unused in create mode)
    private let mode: MeetFormNoTapMode
    private let meetIDUUID: String? // present in update mode

    // Editable fields
    @Published var name: String
    @Published var start: Date
    @Published var end: Date
    @Published var descriptionText: String?
    @Published var meetCategoryID: Int16?
    @Published var maxCapacity: Int32?

    // Coordinates (nil = not set)
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var regionLatitude: Double?
    @Published var regionLongitude: Double?
    @Published var regionRadius: Double?

    init(mode: MeetFormNoTapMode)
    {
        self.mode = mode
        switch mode {
        case .create(let location):
            self.meetIDUUID = nil
            // Defaults
            self.name = ""
            self.start = Date().addingTimeInterval(3600)
            self.end = Date().addingTimeInterval(7200)
            self.descriptionText = ""
            self.meetCategoryID = 1
            self.maxCapacity = 8

            if let loc = location {
                self.latitude = loc.Coordinate.latitude
                self.longitude = loc.Coordinate.longitude
                self.regionLatitude = loc.RegionCoordinate.latitude
                self.regionLongitude = loc.RegionCoordinate.longitude
                self.regionRadius = loc.RegionRadius
            } else {
                self.latitude = nil
                self.longitude = nil
                self.regionLatitude = nil
                self.regionLongitude = nil
                self.regionRadius = nil
            }
        }
    }

    // Validation
    func validate() -> String?
    {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Name is required." }
        guard trimmed.count <= 50 else { return "Name must be 50 characters or fewer." }
        guard start < end else { return "Start time must be before end time." }

        // For create mode, coordinates are required
        switch mode {
        case .create:
            guard latitude != nil,
                  longitude != nil,
                  regionLatitude != nil,
                  regionLongitude != nil,
                  regionRadius != nil else {
                return "Location is required for new meets."
            }
        }
        if let mc = maxCapacity, mc < 2 { return "Capacity must be at least 2." }
        return nil
    }
    
    // Build create body
    func makeCreateBody() -> MeetInsertBody?
    {
        guard case .create = mode else { return nil }
        guard let lat = latitude, let lon = longitude,
              let rLat = regionLatitude, let rLon = regionLongitude,
              let rRad = regionRadius else {
            return nil
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        return MeetInsertBody(
            latitude: lat,
            longitude: lon,
            region_latitude: rLat,
            region_longitude: rLon,
            region_radius: rRad,
            name: String(trimmed.prefix(50)),
            dttm_start_utc: start,
            dttm_end_utc: end,
            description: descriptionText ?? "",
            meet_category_id: meetCategoryID ?? 1,
            max_capacity: maxCapacity ?? 8
        )
    }
}
