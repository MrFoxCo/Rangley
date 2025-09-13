//
//  LocationManager.swift
//  Freebird
//
//  Created by Anthony Guzzardo on 7/6/25.
//

import CoreLocation
import Combine

public final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published public private(set) var userLocation: CLLocation?
    @Published public private(set) var status: CLAuthorizationStatus = .notDetermined
    @Published public private(set) var isAuthorized: Bool = false

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50

        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = type(of: manager).authorizationStatus()
        }
        handle(status)
    }

    public func requestWhenInUse() {
        guard CLLocationManager.locationServicesEnabled() else {
            print("⚠️ Location Services OFF at system level.")
            return
        }
        // Check authorization status without blocking the main thread
        let currentStatus = manager.authorizationStatus
        
        // Only request authorization if not determined
        if currentStatus == .notDetermined {
            DispatchQueue.main.async { [weak self] in
                self?.manager.requestWhenInUseAuthorization()
            }
            // The actual location request will happen in locationManagerDidChangeAuthorization
            // when the user grants permission
        } else {
            // Status is already determined, handle it immediately
            handle(currentStatus)
        }

    }


    private func handle(_ s: CLAuthorizationStatus) {
        Task { @MainActor in
            self.status = s
            switch s {
            case .authorizedAlways, .authorizedWhenInUse:
                self.isAuthorized = true
                self.manager.requestLocation()        // immediate fix
                self.manager.startUpdatingLocation()  // keep fresh
            case .notDetermined:
                self.isAuthorized = false
            case .restricted, .denied:
                self.isAuthorized = false
            @unknown default:
                self.isAuthorized = false
            }
        }
    }

    // MARK: - CLLocationManagerDelegate (non-isolated; hop to MainActor when mutating)
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
}
