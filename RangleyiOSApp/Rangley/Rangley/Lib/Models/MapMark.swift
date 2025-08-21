//
//  FreebirdMapMarker.swift
//  Freebird
//
//  Created by Anthony Guzzardo on 7/7/25.
//
import MapKit

/// Mark on a map inside a broader 'Event' i.e. Landmark or Pin
/// Need Coordinates(latitude, longitude) , address, name, and option Destination object

public class MapMark{
    public var id           : String = UUID().uuidString
    public var coordinate   : Coordinate
    public var address      : String
    public var name         : String
    public var meetup       : Meet?

    public init(name: String, coordinate: Coordinate, address: String) {
        self.name = name
        self.coordinate = coordinate
        self.address = address
    }
    
}


