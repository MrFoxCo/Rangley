//
//  OutlineCapsuleButton.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/11/25.
//

import SwiftUI

struct OutlineCapsuleButton: ButtonStyle {
    var color: Color = AppPalette.Brand.neonPink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color(AppPalette.Brand.neonPink)) // text on neon fill
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .overlay( Capsule().stroke(color, lineWidth: 2) )
            .background( Capsule().fill( color.opacity(configuration.isPressed ? 0.50 : 0.20) ) ) // <- neon @ ~0.5
            .shadow(color: .black.opacity(configuration.isPressed ? 0.25 : 0.35),
                    radius: configuration.isPressed ? 6 : 12, y: 4)
    }
}

