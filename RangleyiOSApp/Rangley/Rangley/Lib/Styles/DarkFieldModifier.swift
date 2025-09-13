//
//  DarkFieldModifier.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/10/25.
//

import SwiftUI

struct DarkFieldModifier: ViewModifier {
    var focused: Bool
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(AppPalette.Surface.fieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(focused ? AppPalette.Surface.focusStroke : AppPalette.Surface.fieldStroke,
                            lineWidth: focused ? 1.5 : 1)
            )
            .tint(AppPalette.Brand.neonPink) // cursor, selection
            .foregroundStyle(AppPalette.Text.primary)
    }
}
extension View {
    func darkField(focused: Bool) -> some View { modifier(DarkFieldModifier(focused: focused)) }
}
