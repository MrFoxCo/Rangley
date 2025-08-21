import MapKit

/// Semantic type, wrapping CLLocationCoordinate2D in own Coordinates
/// Params are latitude, longitude
public struct Coordinate:  Sendable, Codable, Equatable, Hashable{
    public let latitude: Double
    public let longitude: Double

    public init(_ latitude: Double, _ longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    ///accesser to latitude and longitude
    public var cl : CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }
}
