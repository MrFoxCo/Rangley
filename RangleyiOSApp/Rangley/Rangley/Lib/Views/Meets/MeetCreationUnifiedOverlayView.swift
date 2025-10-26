//
//  MeetCreationUnifiedOverlayView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/23/25.
//

import SwiftUI
import UIKit
import CoreLocation

struct MeetCreationUnifiedOverlay: View
{
    // MARK: Configuration
    @Binding var showOverlay: Bool
    @Binding var entryMode  : MeetCreationEntryMode?
    let baseURL             : URL
    let token               : String
    let onCreate            : (MeetInsertBody) async throws -> Void
    let onCreateWithInvites : (MeetWithInvitesInsertBody) async throws -> Void
    let onContentViolation  : (ContentViolation) -> Void

    
    // MARK: State
    @State private var isAnimating      = false
    @State private var isExploding      = false
    @State private var showConfetti     = false
    @State private var showCreateForm   = false
    @State private var showAiChat       = false  // NEW
    @State private var isSoftDismissing = false
    
    // MARK: Body
    var body: some View
    {
        ZStack {
            if showOverlay, let mode = entryMode {
                // Dark backdrop
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Allow backdrop dismiss only when showing confirmation
                        if !showCreateForm && !showAiChat {
                            dismiss()
                        }
                    }
                
                // Content
                ZStack {
                    // Initial confirmation popup (for both flows)
                    if !showCreateForm && !showAiChat {
                        CreateMeetConfirmationPopup(
                            entryMode: mode,
                            onConfirm: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showCreateForm = true
                                }
                            },
                            onConfirmWithAI: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showAiChat = true
                                }
                            },
                            onCancel: dismiss
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                    }
                    
                    // AI Chat interface
                    if showAiChat {
                        AiChatInterfaceView(
                          entryMode     : mode,
                          baseURL       : baseURL,
                          token         : token,
                          onClose       : { softDismiss() },
                          onCreate: { body in
                              do {
                                  try await onCreate(body)
                                  await MainActor.run { explodeThenDismiss() }
                              } catch {
                                  if let v = parseContentViolation(from: error) { await MainActor.run { onContentViolation(v) } }
                                  throw error
                              }
                          },
                          onCreateWithInvites: { body in
                              do {
                                  try await onCreateWithInvites(body)
                                  await MainActor.run { explodeThenDismiss() }
                              } catch {
                                  if let v = parseContentViolation(from: error) { await MainActor.run { onContentViolation(v) } }
                                  throw error
                              }
                          },
                        )
                        .allowsHitTesting(!isExploding)
                        .scaleEffect(isExploding ? 0.6 : (isSoftDismissing ? 0.95 : 1.0))
                        .opacity(isExploding ? 0.0 : (isSoftDismissing ? 0.0 : 1.0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExploding)
                        .animation(.easeOut(duration: 0.25), value: isSoftDismissing)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                    
                    // Manual form (after confirmation)
                    if showCreateForm {
                        MeetCreationUnifiedFormView(
                          entryMode: mode,
                          baseURL: baseURL,
                          token: token,
                          onCreate: { body in
                              do {
                                  try await onCreate(body)
                                  await MainActor.run { explodeThenDismiss() }
                              } catch {
                                  if let v = parseContentViolation(from: error) { await MainActor.run { onContentViolation(v) } }
                                  throw error
                              }
                          },
                          onCreateWithInvites: { body in
                              do {
                                  try await onCreateWithInvites(body)
                                  await MainActor.run { explodeThenDismiss() }
                              } catch {
                                  if let v = parseContentViolation(from: error) { await MainActor.run { onContentViolation(v) } }
                                  throw error
                              }
                          },
                          onClose: { softDismiss() }
                        )
                        .allowsHitTesting(!isExploding)
                        .scaleEffect(isExploding ? 0.6 : (isSoftDismissing ? 0.95 : 1.0))
                        .opacity(isExploding ? 0.0 : (isSoftDismissing ? 0.0 : 1.0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExploding)
                        .animation(.easeOut(duration: 0.25), value: isSoftDismissing)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                    
                    // Confetti overlay
                    if showConfetti {
                        ConfettiBurst(
                            color: UIColor(AppPalette.Brand.neonPink),
                            duration: 1.0,
                            intensity: 1.0
                        )
                        .allowsHitTesting(false)
                        .transition(.opacity)
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showOverlay)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showCreateForm)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showAiChat)
    }
    
    // MARK: ^^ HELPER FUNCTION
    private func parseContentViolation(from error: Error) -> ContentViolation?
    {
        if let contentError = error as? ContentViolationError {
            return contentError.violation
        }
        return nil
    }
    
    // MARK: Actions
    private func dismiss()
    {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8))
        {
            showOverlay = false
            entryMode = nil
            showCreateForm = false
            showAiChat = false
        }
    }
    
    private func softDismiss()
    {
        guard !isExploding else { return }
        isSoftDismissing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            showOverlay = false
            entryMode = nil
            showCreateForm = false
            showAiChat = false
            isSoftDismissing = false
        }
    }
    
    private func explodeThenDismiss()
    {
        guard !isExploding else { return }
        isExploding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            showConfetti = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showConfetti = false
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showOverlay = false
                entryMode = nil
                showCreateForm = false
                showAiChat = false
                isExploding = false
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}


// MARK: - form to ask if users actually want to create a meet
struct CreateMeetConfirmationPopup: View
{
    let entryMode       : MeetCreationEntryMode
    let onConfirm       : () -> Void
    let onConfirmWithAI : () -> Void
    let onCancel        : () -> Void
    
    @State private var isAnimating = false
    @State private var locationName: String = "Loading location..."
    
    private var title: String {
        switch entryMode {
        // TBD if i use location here
        case .tapOnMap(let location): return "Create Meet Here?"
        case .createButton: return "Create New Meet?"
        case .createWithGroup(let group, _): return "Create Meet with \(group.name)?"
        case .update: return "Update This Meet?"
        }
    }

    private var subtitle: String {
        switch entryMode {
        case .tapOnMap: return locationName
        case .createButton: return "Start planning your meetup"
        case .createWithGroup(_, let members):
            return "Inviting \(members.count) member\(members.count == 1 ? "" : "s")"
        case .update(let meet):
            return "Make changes to \(meet.name)"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(AppPalette.Brand.neonPink)
            
            // Title
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppPalette.Text.primary)
                .multilineTextAlignment(.center)

            // Subtitle/Location
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppPalette.Text.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            // Buttons
            VStack(spacing: 10)
            {
                // AI Assistant Button
                Button(action: onConfirmWithAI)
                {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Use AI Assistant")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppPalette.Brand.neonPink,
                                        AppPalette.Brand.neonPink.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                
                // Manual Entry Button
                Button(action: onConfirm)
                {
                    Text("Manual Entry")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppPalette.Text.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Cancel Button
                Button(action: onCancel)
                {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppPalette.Text.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppPalette.Brand.japDarkerPurple)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: 280)
        .shadow(color: AppPalette.Brand.neonPink.opacity(0.3), radius: 15, x: 0, y: 8)
        .scaleEffect(isAnimating ? 1 : 0.5)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isAnimating = true
            }
            loadLocationNameIfExists()
        }
    }
    
    private func loadLocationNameIfExists()
    {
        guard case .tapOnMap(let location) = entryMode else { return }
        
        let clLocation = CLLocation(
            latitude    : location.Coordinate.latitude,
            longitude   : location.Coordinate.longitude
        )
        
        CLGeocoder().reverseGeocodeLocation(clLocation) { placemarks, error in
            DispatchQueue.main.async {
                if error != nil {
                    locationName = "Selected location"
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    locationName = "Selected location"
                    return
                }
                
                // Build location name similar to other components
                var components: [String] = []
                
                if let name = placemark.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                    components.append(name)
                } else if let street = placemark.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines), !street.isEmpty {
                    if let number = placemark.subThoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines), !number.isEmpty {
                        components.append("\(number) \(street)")
                    } else {
                        components.append(street)
                    }
                }
                
                if let city = placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty {
                    components.append(city)
                }
                
                locationName = components.isEmpty ? "Selected location" : components.joined(separator: ", ")
            }
        }
    }
}
