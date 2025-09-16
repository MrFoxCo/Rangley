//
//  DockView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/15/25.
//

import SwiftUI

public struct DockView: View {
    public var onSignOut: () -> Void
    public var onSearch: () -> Void
    public var onCreateMeet: () -> Void
    
    @State private var isAnimating = false
    
    public init(
        onSignOut: @escaping () -> Void,
        onSearch: @escaping () -> Void,
        onCreateMeet: @escaping () -> Void
    ) {
        self.onSignOut = onSignOut
        self.onSearch = onSearch
        self.onCreateMeet = onCreateMeet
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            // Search button
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .imageScale(.large)
                    .foregroundStyle(AppPalette.Brand.neonPink)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppPalette.Brand.neonPink.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppPalette.Brand.neonPink.opacity(0.55), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 16))
                    .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Search")
            
            // Create meet button with migraine aura effect
            Button(action: onCreateMeet) {
                ZStack {
                    // Migraine aura effect layers
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        AppPalette.Brand.neonPink.opacity(0.8),
                                        Color.purple.opacity(0.6),
                                        Color.cyan.opacity(0.4),
                                        AppPalette.Brand.neonPink.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .scaleEffect(1.0 + (Double(index) * 0.1))
                            .opacity(isAnimating ? 0.2 : 0.6)
                            .animation(
                                .easeInOut(duration: 2.0 + Double(index) * 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.3),
                                value: isAnimating
                            )
                    }
                    
                    // Background with shimmer
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    AppPalette.Brand.neonPink.opacity(0.2),
                                    Color.purple.opacity(0.15),
                                    Color.cyan.opacity(0.1)
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 30
                            )
                        )
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    // Plus icon
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .imageScale(.large)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    AppPalette.Brand.neonPink,
                                    Color.purple,
                                    Color.cyan
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(isAnimating ? 90 : 0))
                        .animation(
                            .easeInOut(duration: 3.0)
                            .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Create Meet")
            .onAppear {
                isAnimating = true
            }
            
            // Hamburger menu (your existing component)
            HamburgerMenu(onSignOut: onSignOut)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppPalette.Brand.russianViolet.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: AppPalette.Brand.neonPink.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
