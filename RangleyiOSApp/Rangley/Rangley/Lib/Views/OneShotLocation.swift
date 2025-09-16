//
//  OneShotLocation.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/16/25.
//

import CoreLocation



final class OneShotLocation: NSObject, CLLocationManagerDelegate
{
    enum LocError: Error { case denied, restricted, unavailable }
    private let manager = CLLocationManager()
    private var cont: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.delegate = self
    }

    func request() async throws -> CLLocation {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            throw LocError.denied
        default: break
        }
        manager.requestLocation()
        return try await withCheckedThrowingContinuation { cont in
            self.cont = cont
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        cont?.resume(returning: loc)
        cont = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        cont?.resume(throwing: error)
        cont = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            cont?.resume(throwing: LocError.denied)
            cont = nil
        }
    }
}
