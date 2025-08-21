//
//  TapDetectingMap.swift
//  Freebird
//
//  Created by Anthony Guzzardo on 7/9/25.
//

import SwiftUI
import MapKit

public struct TapDetectingMap: UIViewRepresentable {
    @Binding var tappedCoordinate: CLLocationCoordinate2D?
    @Binding var tappedPoint: CGPoint?
    @Binding var region: MKCoordinateRegion

    public class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TapDetectingMap

        init(parent: TapDetectingMap) {
            self.parent = parent
        }

        @objc func handleTap(gestureRecognizer: UITapGestureRecognizer) {
            let mapView = gestureRecognizer.view as! MKMapView
            let point = gestureRecognizer.location(in: mapView)
            let coord = mapView.convert(point, toCoordinateFrom: mapView)

            // Update SwiftUI state
            parent.tappedCoordinate = coord
            parent.tappedPoint = point

            // Center region
            parent.region.center = coord
        }

    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // Add the tap gesture
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(gestureRecognizer:))
        )
        mapView.addGestureRecognizer(tapGesture)

        // Set initial region
        mapView.setRegion(region, animated: false)

        return mapView
    }

    public func updateUIView(_ uiView: MKMapView, context: Context) {
        // Keep the MKMapView in sync with SwiftUI region
        uiView.setRegion(region, animated: true)
    }
}
