//
//  EscapeManager.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/17/25.
//

import SwiftUI

// MARK: - Global Escape Manager
final class EscapeManager: ObservableObject
{
    struct Entry: Identifiable { let id: UUID; let handler: () -> Void }
    @Published private(set) var stack: [Entry] = []

    var isVisible: Bool { !stack.isEmpty }

    @discardableResult
    func push(_ handler: @escaping () -> Void) -> UUID {
        let id = UUID()
        stack.append(.init(id: id, handler: handler))
        return id
    }

    func remove(_ id: UUID?) {
        guard let id else { return }
        stack.removeAll { $0.id == id }
    }

    func trigger() {
        guard let last = stack.last else { return }
        last.handler()
        _ = stack.popLast()
    }

    func clear() { stack.removeAll() }
}

// MARK: - Floating X (top-right, safe-area aware)
struct FloatingCloseButton: View
{
    @EnvironmentObject private var escape: EscapeManager

    var body: some View {
        Group {
            if escape.isVisible {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        escape.trigger()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(AppPalette.Brand.neonPink.opacity(0.6), lineWidth: 1)
                        )
                        .shadow(radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(.opacity)
                .zIndex(9999)
            }
        }
        .allowsHitTesting(true)
    }
}
