//
//  MeetCardOverlayView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

import SwiftUI

// MARK: - Bubble (the little circle)
struct MeetBubbleButton: View
{
    let meet: ViewMeetsModel
    let ns: Namespace.ID
    let onTap: () -> Void

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
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(AppPalette.bgGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .stroke(AppPalette.Brand.neonPink.opacity(0.85), lineWidth: 2)
                    )
                    .matchedGeometryEffect(id: "meet-bg-\(meet.meet_id)", in: ns)

                VStack(spacing: 2) {
                    Text(initials.isEmpty ? "•" : initials)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppPalette.Text.primary)
                    Image(systemName: "mappin.and.ellipse")
                        .imageScale(.small)
                        .foregroundStyle(AppPalette.Text.tertiary)
                }
                .padding(.vertical, 6)
            }
            .frame(width: 52, height: 52)
            .shadow(radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Overlay (expanded card)
struct MeetCardOverlay: View
{
    @Binding var selectedMeet: ViewMeetsModel?
    @Binding var isPresented: Bool
    let ns: Namespace.ID

    var body: some View {
        ZStack {
            if isPresented, let meet = selectedMeet {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { close() }

                MeetCardView(meet: meet, onClose: close)
                    .frame(maxWidth: 420, maxHeight: 600)
                    .background(
                        // Morph from the circular bubble to this rounded rect
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(AppPalette.bgGradient)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "meet-bg-\(meet.meet_id)", in: ns)
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                    .padding(.horizontal, 20)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: isPresented)
    }

    private func close() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) { isPresented = false }
    }
}

// MARK: - Card content (no background; background is provided by overlay for the morph)
private struct MeetCardView: View
{
    let meet: ViewMeetsModel
    let onClose: () -> Void

    private var dateRangeText: String {
        let f = DateIntervalFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: meet.dttm_start_utc, to: meet.dttm_end_utc)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Creator
            HStack(alignment: .firstTextBaseline) {
                Text(meet.display_name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppPalette.Text.primary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .padding(8)
                        .background(AppPalette.Surface.fieldFill, in: Circle())
                        .overlay(Circle().stroke(AppPalette.Surface.fieldStroke, lineWidth: 1))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                }
                .buttonStyle(.plain)
            }

            Text(meet.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppPalette.Text.primary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Chip(text: meet.category_name, systemImage: "tag")
                Chip(text: "Cap \(meet.max_capacity)", systemImage: "person.3")
            }

            Divider().overlay(AppPalette.Surface.fieldStroke)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundStyle(AppPalette.Brand.neonPink)
                Text(dateRangeText)
                    .foregroundStyle(AppPalette.Text.secondary)
                    .font(.subheadline)
            }

            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(AppPalette.Brand.neonPink)
                Text("\(meet.latitude, specifier: "%.5f"), \(meet.longitude, specifier: "%.5f")")
                    .foregroundStyle(AppPalette.Text.tertiary)
                    .font(.footnote)
            }

            if !meet.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("About")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.Text.primary)
                    Text(meet.description)
                        .foregroundStyle(AppPalette.Text.secondary)
                        .font(.callout)
                        .lineLimit(6)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .shadow(radius: 24, y: 8)
    }
}

private struct Chip: View
{
    let text: String
    let systemImage: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(AppPalette.Text.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppPalette.Surface.fieldFill, in: Capsule())
        .overlay(Capsule().stroke(AppPalette.Surface.fieldStroke, lineWidth: 1))
    }
}
