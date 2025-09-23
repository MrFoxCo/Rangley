//
//  HamburgerMenu.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/11/25.
//

import SwiftUI

public struct HamburgerMenu: View
{
    public var onSignOut: () -> Void
    @State private var showAccount = false
    @State private var showMenu = false

    public init(onSignOut: @escaping () -> Void) {
        self.onSignOut = onSignOut
    }

    public var body: some View
    {
        Button {
            showMenu = true
        } label: {
            Image(systemName: "line.horizontal.3")
                .font(.system(size: 18, weight: .semibold))
                .imageScale(.large)
                .foregroundStyle(AppPalette.Brand.neonPink)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppPalette.Brand.neonPink.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.55), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityLabel("Menu")
        .sheet(isPresented: $showMenu) {
            CustomMenuView(
                onAccount: {
                    showMenu = false
                    showAccount = true
                },
                onSignOut: {
                    showMenu = false
                    onSignOut()
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAccount) {
            AccountView()
                .preferredColorScheme(.dark)
        }
    }
}

struct CustomMenuView: View {
    let onAccount: () -> Void
    let onSignOut: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient
            VStack(spacing: 16) {
                // Rangley title with gradient
                Text("Rangley")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppPalette.Brand.neonPink,
                                AppPalette.Brand.electricViolet,
                                AppPalette.Brand.brightTeal
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // Subtitle
                Text("Your social compass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppPalette.Text.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 32)
            
            // Menu items
            VStack(spacing: 16) {
                // Account button
                MenuItemButton(
                    icon: "person.crop.circle.fill",
                    title: "Account Settings",
                    subtitle: "Manage your profile",
                    colors: [AppPalette.Brand.neonPink, AppPalette.Brand.electricViolet],
                    action: onAccount
                )
                
                // Sign out button
                MenuItemButton(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign Out",
                    subtitle: "See you next time",
                    colors: [AppPalette.Brand.brightTeal, AppPalette.Brand.neonPurple],
                    isDestructive: true,
                    action: onSignOut
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .background(
            LinearGradient(
                colors: [
                    AppPalette.Brand.russianViolet,
                    AppPalette.Brand.violetMid,
                    AppPalette.Brand.nearBlack
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
    }
}

struct MenuItemButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let colors: [Color]
    var isDestructive: Bool = false
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: colors.map { $0.opacity(0.2) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: colors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isDestructive ? AppPalette.Brand.neonPink : AppPalette.Text.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppPalette.Text.secondary)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppPalette.Text.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppPalette.Surface.fieldFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: colors.map { $0.opacity(0.3) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
