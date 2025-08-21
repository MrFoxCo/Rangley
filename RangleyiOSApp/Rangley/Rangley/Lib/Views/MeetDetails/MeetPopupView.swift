//
//  MeetPopup.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/10/25.
//

import SwiftUI
import MapKit

// MARK: - Popup Container (centered over map, tap-to-dismiss)
// MeetPopup (just add yOffset)
struct MeetPopupView: View {
    
    // MARK: - Properties
    let meetCardData: MeetCardData
    
    var yOffset     : CGFloat = 110
    var onDismiss   : () -> Void = {}

    // two separate callbacks
    var onCloseMeetCard: (MeetCardData) -> Void = { _ in }
    var onDeleteMeet: (MeetCardData) -> Void = { _ in }

    // MARK: - END Properties
    
    
    var body: some View {
        ZStack {
            UkiyoPalette.Semantic.backdropDim.ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { onDismiss() }
                }

            MeetCardView(
                meetCardData: meetCardData,
                // EITHER pass through directly (cleanest):
                onCloseMeetCard: onCloseMeetCard,
                onDeleteMeet: onDeleteMeet

                // OR, if you want the explicit closure form:
                // onCloseMeetDisplayCard: { m in onCloseMeetDisplayCard(m) },
                // onDeleteMeet: { m in onDeleteMeet(m) }
            )
            .padding(.horizontal, 20)
            .frame(maxWidth: 360)
            .offset(y: yOffset)
            .transition(.scale.combined(with: .opacity))
            .shadow(radius: 20, y: 10)
        }
    }
}

