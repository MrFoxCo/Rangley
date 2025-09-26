import SwiftUI

public struct HamburgerMenu: View {
    public var onSignOut: () -> Void
    @State private var showAccount = false
    @State private var showMenu = false

    public init(onSignOut: @escaping () -> Void) { self.onSignOut = onSignOut }

    public var body: some View {
        Button {
            showMenu = true
        } label: {
            Image(systemName: "line.horizontal.3")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppPalette.Brand.neonPink)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppPalette.Brand.neonPink.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.55), lineWidth: 1)
                )
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
            // Header (solid colors only)
            VStack(spacing: 16) {
                Text("Rangley")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppPalette.Brand.neonPink)

                Text("Your social compass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppPalette.Text.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 32)

            // Menu items
            VStack(spacing: 16) {
                MenuItemButton(
                    icon: "person.crop.circle.fill",
                    title: "Account Settings",
                    subtitle: "Manage your profile",
                    isDestructive: false,
                    action: onAccount
                )

                MenuItemButton(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign Out",
                    subtitle: "See you next time",
                    isDestructive: true,
                    action: onSignOut
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(AppPalette.Brand.japDarkerPurple.ignoresSafeArea())
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
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon badge (no gradients)
                ZStack {
                    Circle()
                        .fill(AppPalette.Brand.japPurple)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(AppPalette.Brand.neonPink.opacity(0.6), lineWidth: 1.5)
                        )

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppPalette.Brand.neonPink)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppPalette.Brand.neonPink) // neon pink for titles

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppPalette.Text.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppPalette.Brand.neonPink.opacity(0.85))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppPalette.Brand.japPurple) // textbox surface
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
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
