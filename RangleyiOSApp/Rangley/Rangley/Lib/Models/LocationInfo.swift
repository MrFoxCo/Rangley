//
//  MeetLocationInfo.swift
//  MeetMate
//
//  Created by Anthony Guzzardo on 7/31/25.
//
import MapKit

public struct LocationInfo: Sendable, Codable, Hashable {
    public let Coordinate           : Coordinate              // required
    public let RegionCoordinate     : Coordinate             // geofencing center (optional)
    public let RegionRadius         : Double                 // meters (optional)
    public let Name                 : String?
    public let ThoroughFare         : String?
    public let SubThoroughFare      : String?
    public let Locality             : String?
    public let SubLocality          : String?
    public let AdministrativeArea   : String?
    public let SubAdministrativeArea: String?
    public let PostalCode           : String?
    public let Country              : String?
    public let IsoCountryCode       : String?
    public let TimeZone             : String?
    public let InlandWater          : String?
    public let Ocean                : String?

    public init(
        Coordinate: Coordinate,
        RegionCoordinate: Coordinate,
        RegionRadius: Double,
        Name: String? = nil,
        ThoroughFare: String? = nil,
        SubThoroughFare: String? = nil,
        Locality: String? = nil,
        SubLocality: String? = nil,
        AdministrativeArea: String? = nil,
        SubAdministrativeArea: String? = nil,
        PostalCode: String? = nil,
        Country: String? = nil,
        IsoCountryCode: String? = nil,
        TimeZone: String? = nil,
        InlandWater: String? = nil,
        Ocean: String? = nil
    ) {
        self.Coordinate            = Coordinate
        self.RegionCoordinate      = RegionCoordinate
        self.RegionRadius          = RegionRadius
        self.Name                  = Name
        self.ThoroughFare          = ThoroughFare
        self.SubThoroughFare       = SubThoroughFare
        self.Locality              = Locality
        self.SubLocality           = SubLocality
        self.AdministrativeArea    = AdministrativeArea
        self.SubAdministrativeArea = SubAdministrativeArea
        self.PostalCode            = PostalCode
        self.Country               = Country
        self.IsoCountryCode        = IsoCountryCode
        self.TimeZone              = TimeZone
        self.InlandWater           = InlandWater
        self.Ocean                 = Ocean
    }

    public var address: String {
        [Name, ThoroughFare, SubThoroughFare, Locality, AdministrativeArea, PostalCode, Country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    // A generic ~10 mi span; tweak as needed or derive from RegionRadius.
    public var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: Coordinate.latitude,
                                           longitude: Coordinate.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }
}
