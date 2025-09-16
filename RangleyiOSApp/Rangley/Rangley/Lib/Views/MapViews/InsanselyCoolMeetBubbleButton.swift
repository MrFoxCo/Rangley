////
////  InsanselyCoolMeetBubbleButton.swift
////  Rangley
////
////  Created by Anthony Guzzardo on 9/15/25.
////


import SwiftUI

// MARK: - Bubble (the little circle)
struct InsanelyCoolMeetBubbleButton: View
{
    let meet: ViewMeetsModel
    let ns: Namespace.ID
    let onTap: () -> Void
    
    @State private var isAnimating = false
    @State private var pulsePhase = 0.0

    private var initials: String {
        let n = meet.display_name.trimmingCharacters(in: .whitespaces)
        let parts = n.split(separator: " ")
        let chars = parts.prefix(2).compactMap { $0.first }
        return String(chars).uppercased()
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { onTap() }
        } label: {
            ZStack {
                // Outer migraine aura rings
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    AppPalette.Brand.neonPink.opacity(0.8),
                                    AppPalette.Brand.electricViolet.opacity(0.6),
                                    AppPalette.Brand.brightTeal.opacity(0.7),
                                    AppPalette.Brand.neonPurple.opacity(0.5),
                                    AppPalette.Brand.vibrantBlue.opacity(0.6),
                                    AppPalette.Brand.brightCyan.opacity(0.4),
                                    AppPalette.Brand.hotPurple.opacity(0.5),
                                    AppPalette.Brand.neonPink.opacity(0.8)
                                ],
                                center: .center,
                                startAngle: .degrees(pulsePhase + Double(index * 72)),
                                endAngle: .degrees(pulsePhase + 360 + Double(index * 72))
                            ),
                            lineWidth: 3 - (Double(index) * 0.4)
                        )
                        .scaleEffect(1.0 + (Double(index + 1) * 0.15) + (isAnimating ? 0.1 : 0))
                        .opacity(isAnimating ? 0.3 + (Double(index) * 0.1) : 0.6 - (Double(index) * 0.1))
                        .animation(
                            .easeInOut(duration: 2.5 + Double(index) * 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
                
                // Swirling inner aura
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppPalette.Brand.neonPink.opacity(0.3),
                                AppPalette.Brand.electricViolet.opacity(0.2),
                                AppPalette.Brand.brightTeal.opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .opacity(isAnimating ? 0.6 : 0.3)
                    .animation(
                        .easeInOut(duration: 3.0)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                // Prismatic shimmer overlay
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                AppPalette.Brand.brightCyan.opacity(0.4),
                                AppPalette.Brand.neonPurple.opacity(0.3),
                                AppPalette.Brand.vibrantBlue.opacity(0.4),
                                AppPalette.Brand.brightTeal.opacity(0.2),
                                AppPalette.Brand.electricViolet.opacity(0.3),
                                AppPalette.Brand.brightCyan.opacity(0.4)
                            ],
                            center: .center,
                            startAngle: .degrees(pulsePhase * 1.5),
                            endAngle: .degrees(pulsePhase * 1.5 + 360)
                        )
                    )
                    .frame(width: 85, height: 85)
                    .opacity(0.4)
                    .scaleEffect(isAnimating ? 1.05 : 0.95)
                    .animation(
                        .easeInOut(duration: 4.0)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                // The actual sticker image
                Image("RangleySticker")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1.02 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
        }
        .buttonStyle(.plain)
        .frame(width: 120, height: 120) // Larger hit area for the aura
        .contentShape(Circle()) // Circular hit area
        .onAppear {
            isAnimating = true
            // Continuous rotation for the angular gradients
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                pulsePhase = 360
            }
        }
    }
}
