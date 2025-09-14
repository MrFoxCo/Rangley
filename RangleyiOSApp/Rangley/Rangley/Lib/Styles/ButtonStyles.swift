//
//  OutlineCapsuleButton.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/11/25.
//

import SwiftUI

struct OutlineCapsuleButton: ButtonStyle {
    var font: Font = FontStyles.buttonSecondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(Color.white.opacity(0.96))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background( Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.07)) )
            .overlay( Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1) )
            .shadow(color: .black.opacity(0.15),
                    radius: configuration.isPressed ? 6 : 10, y: 4)
    }
}


struct CreateNewAccountCapsuleButton: ButtonStyle {
    var font: Font = FontStyles.buttonPrimary

    // warmer off-whites (less glare than pure white)
    private let top    = Color(red: 0.98, green: 0.97, blue: 0.99) // ~#FBF8FD
    private let bottom = Color(red: 0.94, green: 0.93, blue: 0.96) // ~#F0EEF5

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        return configuration.label
            .font(font)
            .kerning(0.2)
            .foregroundStyle(AppPalette.Brand.russianViolet.opacity(0.98))
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [
                            top.opacity(pressed ? 0.96 : 1.0),
                            bottom.opacity(pressed ? 0.94 : 0.98)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            // subtle hairline (no neon rim)
            .overlay( Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1) )
            // faint top sheen only
            .overlay(
                Capsule().fill(
                    LinearGradient(colors: [Color.white.opacity(0.08), .clear],
                                   startPoint: .top, endPoint: .center)
                )
            )
            // single soft drop shadow (removed bright white glow)
            .shadow(color: .black.opacity(0.22),
                    radius: pressed ? 6 : 10,
                    y: pressed ? 2 : 5)
            .scaleEffect(pressed ? 0.985 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: pressed)
    }
}


struct PrimaryCapsuleButton: ButtonStyle {
    var font: Font = FontStyles.buttonPrimary
    private let fill = AppPalette.Brand.pigNeonPink   // solid

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        return configuration.label
            .font(font).kerning(0.2)
            .foregroundStyle(.white.opacity(0.98))
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background( Capsule().fill(fill.opacity(pressed ? 0.92 : 1.0)) )
            // optional: keep or remove hairline; it’s neutral (not neon)
            .overlay( Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1) )
            .shadow(color: .black.opacity(0.22),
                    radius: pressed ? 6 : 10,
                    y: pressed ? 2 : 5)
            .scaleEffect(pressed ? 0.985 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: pressed)
    }
}

