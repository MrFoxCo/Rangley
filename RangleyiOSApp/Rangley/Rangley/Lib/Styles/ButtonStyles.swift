//
//  OutlineCapsuleButton.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/11/25.
//

import SwiftUI

struct OutlineCapsuleButton: ButtonStyle {
    var color: Color = AppPalette.Brand.neonPink
    var font: Font = FontStyles.buttonSecondary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .overlay( Capsule().stroke(color, lineWidth: 4) )
            .background( Capsule().fill( color.opacity(configuration.isPressed ? 0.8 : 0.5) ) )
            .shadow(color: color.opacity(0.6), radius: configuration.isPressed ? 10 : 18, y: 4)
            .shadow(color: .black.opacity(0.3), radius: configuration.isPressed ? 6 : 12, y: 4)
    }
}

struct CreateNewAccountCapsuleButton: ButtonStyle {
    var isPressed: Bool = false
    var font: Font = FontStyles.buttonPrimary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .kerning(0.2)
            .foregroundStyle(AppPalette.Brand.russianViolet)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(
                Capsule().stroke(
                    Color.white.opacity(0.3),
                    lineWidth: 1
                )
            )
            .shadow(
                color: Color.white.opacity(configuration.isPressed ? 0.4 : 0.6),
                radius: configuration.isPressed ? 8 : 12,
                y: configuration.isPressed ? 3 : 6
            )
            .shadow(
                color: .black.opacity(0.15),
                radius: 2,
                y: 1
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PrimaryCapsuleButton: ButtonStyle {
    var isPressed: Bool = false
    var font: Font = FontStyles.buttonPrimary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .kerning(0.2)
            .foregroundStyle(.white.opacity(0.98))
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [
                            AppPalette.Brand.neonPink.opacity(0.95),
                            AppPalette.Brand.neonPink.opacity(0.75)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(
                Capsule().stroke(
                    AppPalette.Brand.neonPink.opacity(0.4),
                    lineWidth: 1
                )
            )
            .shadow(
                color: AppPalette.Brand.neonPink.opacity(configuration.isPressed ? 0.4 : 0.6),
                radius: configuration.isPressed ? 8 : 12,
                y: configuration.isPressed ? 3 : 6
            )
            .shadow(
                color: .black.opacity(0.15),
                radius: 2,
                y: 1
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
