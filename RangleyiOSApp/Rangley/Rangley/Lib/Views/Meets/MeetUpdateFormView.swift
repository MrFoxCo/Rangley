//
//  MeetUpdateFormView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/14/25.
//

import SwiftUI
import CoreLocation
import QuartzCore

struct MeetUpdateUnifiedOverlay: View
{
    // MARK: Configuration
    @Binding var showOverlay: Bool
    @Binding var meetToEdit: ViewMeetsModel?
    let onUpdate: (UpdatedMeetInsertBody) async throws -> Void
    let onLoadMeets: (() async -> Void)?
    let onContentViolation: (ContentViolation) -> Void
    
    // Get auth token from environment or pass it in
    @EnvironmentObject private var authState: AuthStateStore
    
    // MARK: State
    @State private var isAnimating = false
    @State private var isExploding = false
    @State private var showConfetti = false
    @State private var isSoftDismissing = false
    
    // MARK: Body
    var body: some View
    {
        ZStack {
            if showOverlay, let meet = meetToEdit {
                // Dark backdrop
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }
                
                // Content
                ZStack {
                    MeetCreationUnifiedFormView(
                        entryMode: .update(meet: meet),
                        baseURL: Env.apiBaseURL,
                        token: authState.currentToken,
                        onCreate: { _ in },
                        onCreateWithInvites: { _ in },
                        onUpdate: { body in
                            try await handleUpdate(body: body)
                        },
                        onClose: { softDismiss() }
                    )
                    .allowsHitTesting(!isExploding)
                    .scaleEffect(isExploding ? 0.6 : (isSoftDismissing ? 0.95 : 1.0))
                    .opacity(isExploding ? 0.0 : (isSoftDismissing ? 0.0 : 1.0))
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExploding)
                    .animation(.easeOut(duration: 0.25), value: isSoftDismissing)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                    
                    // Confetti overlay
                    if showConfetti {
                        ConfettiBurst(
                            color: UIColor(AppPalette.Brand.neonPink),
                            duration: 1.0,
                            intensity: 0.8
                        )
                        .allowsHitTesting(false)
                        .transition(.opacity)
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showOverlay)
    }
    
    private func handleUpdate(body: UpdatedMeetInsertBody) async throws
    {
        do {
            try await onUpdate(body)
            await onLoadMeets?()
            await MainActor.run { explodeThenDismiss() }
        } catch {
            if let violation = parseContentViolation(from: error) {
                await MainActor.run {
                    onContentViolation(violation)
                }
                throw error
            } else {
                throw error
            }
        }
    }
    
    private func parseContentViolation(from error: Error) -> ContentViolation? {
        if let contentError = error as? ContentViolationError {
            return contentError.violation
        }
        return nil
    }
    
    // MARK: Actions
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showOverlay = false
            meetToEdit = nil
        }
    }
    
    private func softDismiss() {
        guard !isExploding else { return }
        isSoftDismissing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            showOverlay = false
            meetToEdit = nil
            isSoftDismissing = false
        }
    }
    
    private func explodeThenDismiss() {
        guard !isExploding else { return }
        isExploding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            showConfetti = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showConfetti = false
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showOverlay = false
                meetToEdit = nil
                isExploding = false
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}


// MARK: New helper view for change items
private struct ChangeRow: View
{
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(AppPalette.Brand.neonPink)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(AppPalette.Text.primary)
            
            Spacer()
        }
    }
}

