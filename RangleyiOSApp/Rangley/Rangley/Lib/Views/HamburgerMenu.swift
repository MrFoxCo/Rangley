//
//  HamburgerMenu.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/11/25.
//


import SwiftUI

public struct HamburgerMenu: View {
    public var onSignOut: () -> Void
    public init(onSignOut: @escaping () -> Void) { self.onSignOut = onSignOut }

    public var body: some View {
        Menu {
            Button(role: .destructive, action: onSignOut) {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "line.horizontal.3")
                .font(.system(size: 18, weight: .semibold))
                .imageScale(.large)
                .foregroundStyle(AppPalette.Brand.neonPink)                 // solid neon lines
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppPalette.Brand.neonPink.opacity(0.14))     // slightly opaque neon bg
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.55), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12))
                // .shadow(color: AppPalette.Brand.neonPink.opacity(0.4), radius: 8) // optional neon glow
                .frame(minWidth: 44, minHeight: 44)

        }
        .tint(AppPalette.Brand.neonPink)
        .accessibilityLabel("Menu")
    }
}

