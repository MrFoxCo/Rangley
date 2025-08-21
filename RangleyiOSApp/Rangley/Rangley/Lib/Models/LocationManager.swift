//
//  LocationManager.swift
//  Freebird
//
//  Created by Anthony Guzzardo on 7/6/25.
//
/**
 
 Check Availability of services your app uses
 - Always verify that location services are available.
 1. device is in airplane mode
 2. device doesn't have location servies hardware
 3. devices doesn't support a specific service
 4. app doesn't have auth to use the serivce
 
 TIP
 BEGIN REQUESTING LOCATION UPDATES WHEN IT IS RELEVANT IN APP
 DO NOT REQUEST LOCATION SERVICES BEFORE THEY ARE REQUIRED. THIS MAY
 CONFUSED TO USER.
 
 ACCESS LEVEL
 1. when in use
 2. always
 In iOS, an app is in use when it’s in the foreground and for a short time when it transitions from the foreground to the background.
 If you enable background location updates, an app with When in Use authorization continues to run in the background when
 location services are active; if location services aren’t running, the normal suspension rules apply. If the system terminates
 the app or the app isn’t running, the system doesn’t launch an app with When in Use authorization to deliver new updates;
 it does launch an app with Always authorization for some types of location updates.
 
 The first time you make an authorization request, the system displays an alert asking the person to grant or deny the request.
 The alert includes a usage description string that explains why you want access to location data.
 You provide this string in your app’s Info.plist file and use it to inform people about how your app uses location data.
 */
import CoreLocation
import Foundation

public class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    @Published public var userLocation: CLLocation?
    @Published public var isAuthorized: Bool = false

    // MARK: Constructor
    
    public override init() {
        super.init()
        manager.delegate = self
        handleAuthorizationStatus(manager.authorizationStatus)
    }

    // MARK: Utility Services
    
    private func handleAuthorizationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            isAuthorized = true
            manager.startUpdatingLocation()
        case .notDetermined:
            isAuthorized = false
            manager.requestWhenInUseAuthorization()
        case .restricted:
            isAuthorized = false
            print("Location access restricted. Update settings to enable.")
        case .denied:
            isAuthorized = false
            print("Location access denied. Cannot use location services.")
        @unknown default:
            isAuthorized = false
            print("Unknown authorization status.")
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handleAuthorizationStatus(manager.authorizationStatus)
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
