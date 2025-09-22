//
//  LocationManager.swift
//  Freebird
//
//  Created by Anthony Guzzardo on 7/6/25.
//

import CoreLocation
import Combine

public struct GeocodeDisplay: Equatable {
    public let name: String
    public let subtitle: String
}

public final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    private var geocodingTask: Task<GeocodeDisplay, Never>?

    @Published public private(set) var userLocation: CLLocation?
    @Published public private(set) var status: CLAuthorizationStatus = .notDetermined
    @Published public private(set) var isAuthorized: Bool = false

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
        if #available(iOS 14.0, *) { status = manager.authorizationStatus }
        else { status = type(of: manager).authorizationStatus() }
        handle(status)
    }

    public func requestWhenInUse() {
        guard CLLocationManager.locationServicesEnabled() else {
            print("Location Services OFF at system level.")
            return
        }
        let currentStatus = manager.authorizationStatus
        if currentStatus == .notDetermined {
            DispatchQueue.main.async { [weak self] in
                self?.manager.requestWhenInUseAuthorization()
            }
        } else {
            handle(currentStatus)
        }
    }

    private func handle(_ s: CLAuthorizationStatus) {
        Task { @MainActor in
            self.status = s
            switch s {
            case .authorizedAlways, .authorizedWhenInUse:
                self.isAuthorized = true
                self.manager.requestLocation()
                self.manager.startUpdatingLocation()
            case .notDetermined:
                self.isAuthorized = false
            case .restricted, .denied:
                self.isAuthorized = false
            @unknown default:
                self.isAuthorized = false
            }
        }
    }

    // MARK: CLLocationManagerDelegate
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handle(manager.authorizationStatus)
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in self.userLocation = loc }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }

    // MARK: Reverse-geocode (returns strings for the View to display)
    public func reverseGeocodeDisplay(for info: LocationInfo) async -> GeocodeDisplay {
        geocodingTask?.cancel()

        let lat = info.Coordinate.latitude
        let lon = info.Coordinate.longitude
        let fallback = GeocodeDisplay(
            name: "New location selected",
            subtitle: "Lat: \(String(format: "%.4f", lat)), Lng: \(String(format: "%.4f", lon))"
        )

        let task = Task<GeocodeDisplay, Never> {
            let geocoder = CLGeocoder()
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lon))
                guard let p = placemarks.first else { return fallback }

                let name   = p.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                let street = p.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines)
                let number = p.subThoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines)
                let city   = p.locality?.trimmingCharacters(in: .whitespacesAndNewlines)
                let state  = p.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines)

                let subtitle = [
                    [number, street].compactMap { $0 }.joined(separator: " "),
                    [city, state].compactMap { $0 }.joined(separator: ", ")
                ].filter { !$0.isEmpty }.joined(separator: " • ")

                return GeocodeDisplay(
                    name: (name ?? street ?? "New Location"),
                    subtitle: subtitle.isEmpty ? fallback.subtitle : subtitle
                )
            } catch {
                return fallback
            }
        }

        geocodingTask = task
        return await task.value
    }
}
