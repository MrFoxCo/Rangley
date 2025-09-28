//
//  ContentViolation.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/28/25.
//


import SwiftUI

struct ContentViolationAlert: View
{
    let violation: ContentViolation
    let onDismiss: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Dark backdrop
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            
            VStack(spacing: 20) {
                // Warning icon
                Image(systemName: violation.iconName)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(violation.color)
                
                // Title
                Text(violation.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppPalette.Text.primary)
                    .multilineTextAlignment(.center)
                
                // Message
                Text(violation.message)
                    .font(.system(size: 16))
                    .foregroundColor(AppPalette.Text.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                
                // Escalation warning for severe violations
                if violation.showEscalationWarning {
                    VStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.orange.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("Severe violations may be reported to our Trust & Safety team for review.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                }
                
                // Dismiss button
                Button(action: onDismiss) {
                    Text("I Understand")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppPalette.Brand.neonPink)
                        )
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppPalette.Brand.japDarkerPurple)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(violation.color.opacity(0.5), lineWidth: 2)
                    )
            )
            .frame(maxWidth: 320)
            .scaleEffect(isAnimating ? 1 : 0.8)
            .opacity(isAnimating ? 1 : 0)
            .shadow(color: violation.color.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
}

struct ContentViolation {
    let reason: String
    let message: String
    
    var title: String {
        switch reason.lowercased() {
        case let r where r.contains("hate_speech") || r.contains("hate speech"):
            return "Content Not Allowed"
        case let r where r.contains("inappropriate") || r.contains("content_violation"):
            return "Inappropriate Content"
        case let r where r.contains("spam"):
            return "Spam Detected"
        default:
            return "Content Violation"
        }
    }
    
    var iconName: String {
        switch reason.lowercased() {
        case let r where r.contains("hate_speech") || r.contains("hate speech"):
            return "exclamationmark.triangle.fill"
        case let r where r.contains("inappropriate") || r.contains("content_violation"):
            return "hand.raised.fill"
        case let r where r.contains("spam"):
            return "trash.fill"
        default:
            return "exclamationmark.circle.fill"
        }
    }
    
    var color: Color {
        switch reason.lowercased() {
        case let r where r.contains("hate_speech") || r.contains("hate speech"):
            return .red
        case let r where r.contains("inappropriate") || r.contains("content_violation"):
            return .orange
        case let r where r.contains("spam"):
            return .yellow
        default:
            return .red
        }
    }
    
    var showEscalationWarning: Bool {
        return reason.lowercased().contains("hate_speech") || reason.lowercased().contains("hate speech")
    }
}

struct ContentViolationError: Error {
    let violation: ContentViolation
}

// Updated error parsing function for overlays:
func parseContentViolation(from error: Error) -> ContentViolation?
{
    if let contentError = error as? ContentViolationError {
        return contentError.violation
    }
    
    let errorString = error.localizedDescription.lowercased()
    
    if errorString.contains("hate speech") ||
       errorString.contains("content_hate_speech") ||
       errorString.contains("content contains hate speech") {
        return ContentViolation(reason: "hate_speech", message: "Content contains hate speech or offensive language that violates our community guidelines.")
    }
    
    if errorString.contains("inappropriate") ||
       errorString.contains("violates") ||
       errorString.contains("community guidelines") ||
       errorString.contains("content not allowed") ||
       errorString.contains("validation failed") {
        return ContentViolation(reason: "content_violation", message: "Content violates our community guidelines. Please revise and try again.")
    }
    
    return nil // Not a content violation
}
