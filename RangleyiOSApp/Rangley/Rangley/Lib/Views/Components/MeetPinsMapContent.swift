//
//  PopulateMapWithMeets.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/9/25.
//

import SwiftUI
import MapKit

struct MeetPinsMapContent: MapContent {
    let Meets    : [MeetCardData]
    let OnSelect : (MeetCardData) -> Void

    private let pinSize: CGFloat = 40   // keep this in sync with PopupMetrics.pinHeight

    var body: some MapContent {
        ForEach(Meets) { m in
            Annotation(
                m.Name,
                coordinate: .init(latitude: m.Latitude, longitude: m.Longitude),
                anchor: .center                        // 👈 coordinate is the visual center
            ) {
                Button { OnSelect(m) } label: {
                    Image(systemName: "mappin.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40) // match PopupMetrics.pinHeight
                        //.background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .highPriorityGesture(TapGesture().onEnded { OnSelect(m) })
                .contentShape(Rectangle())
                .accessibilityLabel(m.Name)
            }
        }
    }
}
