//
//  MeetCreationFormView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

import UIKit
import SwiftUI
import CoreLocation
import QuartzCore // for confetti supports the CA_* stuff
struct MeetCreationFormByTapView: View
{
    let locationInfo: LocationInfo
    let onConfirm: (String, Date, Date) -> Void
    let onBack: () -> Void

    @State private var meetName = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600) // Default 1 hour later

    @State private var isAnimating = false
    @State private var currentFieldStep: FieldStep = .name

    @FocusState private var isNameFieldFocused: Bool

    enum FieldStep: CaseIterable
    {
        case name, startTime, endTime, review

        var title: String {
            switch self {
            case .name: return "Name your meet"
            case .startTime: return "When does it start?"
            case .endTime: return "When does it end?"
            case .review: return "Review & Create"
            }
        }

        var stepNumber: Int {
            switch self {
            case .name: return 1
            case .startTime: return 2
            case .endTime: return 3
            case .review: return 4
            }
        }
    }

    private var totalSteps: Int { FieldStep.allCases.count }

    private var locationDisplayName: String
    {
        if let name = locationInfo.Name, !name.isEmpty { return name }
        if let thoroughfare = locationInfo.ThoroughFare { return thoroughfare }
        if let locality = locationInfo.Locality { return locality }
        return "Selected location"
    }

    private var canProceed: Bool
    {
        switch currentFieldStep {
        case .name:
            return !meetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .startTime:
            return true
        case .endTime:
            return endTime > startTime
        case .review:
            return !meetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && endTime > startTime
        }
    }

    private func nextStep() {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        switch currentFieldStep {
        case .name:
          isNameFieldFocused = false   // hide keyboard before moving on
          currentFieldStep = .startTime
        case .startTime: currentFieldStep = .endTime
        case .endTime:   currentFieldStep = .review
        case .review:
          let trimmed = meetName.trimmingCharacters(in: .whitespacesAndNewlines)
          onConfirm(String(trimmed.prefix(50)), startTime, endTime)
        }
      }
    }


    private func previousStep()
    {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            switch currentFieldStep {
            case .name:
                onBack()
            case .startTime:
                currentFieldStep = .name
            case .endTime:
                currentFieldStep = .startTime
            case .review:
                currentFieldStep = .endTime
            }
        }
    }
    struct DetailRow: View
    {
        let label: String
        let value: String
    
        var body: some View {
            HStack {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(AppPalette.Text.secondary)
    
                Spacer()
    
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppPalette.Text.primary)
            }
        }
    }
    var body: some View
    {
        VStack(spacing: 0) {
            // Header with back button and progress
            VStack(spacing: 16) {
                HStack {
                    Button(action: previousStep) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text(currentFieldStep == .name ? "Cancel" : "Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(AppPalette.Brand.neonPink)
                    }

                    Spacer()

                    // Dynamic step indicator
                    Text("Step \(currentFieldStep.stepNumber) of \(totalSteps)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppPalette.Text.secondary)
                }

                // Progress bar (dynamic)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppPalette.Surface.fieldFill)
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppPalette.Brand.neonPink)
                            .frame(
                                width: geometry.size.width * (Double(currentFieldStep.stepNumber) / Double(totalSteps)),
                                height: 4
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentFieldStep)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)

            // Location preview (always visible)
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(locationDisplayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppPalette.Text.primary)

                        if let locality = locationInfo.Locality,
                           let state = locationInfo.AdministrativeArea {
                            Text("\(locality), \(state)")
                                .font(.system(size: 12))
                                .foregroundColor(AppPalette.Text.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "location.fill")
                        .foregroundColor(AppPalette.Brand.neonPink)
                        .font(.system(size: 16))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppPalette.Surface.fieldFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Current field content
            VStack(spacing: 24) {
                Text(currentFieldStep.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppPalette.Text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                Group {
                    switch currentFieldStep {
                    case .name:
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("", text: $meetName, prompt: Text("Enter meet name").foregroundColor(AppPalette.Text.tertiary))
                                .font(.system(size: 18))
                                .foregroundColor(AppPalette.Text.primary)
                                .focused($isNameFieldFocused)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppPalette.Surface.fieldFill)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    isNameFieldFocused ? AppPalette.Surface.focusStroke : AppPalette.Surface.fieldStroke,
                                                    lineWidth: isNameFieldFocused ? 2 : 1
                                                )
                                        )
                                )
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        isNameFieldFocused = true
                                    }
                                }
                        }
                        .padding(.horizontal, 24)

                    case .startTime:
                        VStack(spacing: 16) {
                            DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .tint(AppPalette.Brand.neonPink)
                                .frame(height: 200)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppPalette.Surface.fieldFill)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                                        )
                                )
                        }
                        .padding(.horizontal, 24)

                    case .endTime:
                        VStack(spacing: 16) {
                            DatePicker("", selection: $endTime, in: startTime..., displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .tint(AppPalette.Brand.neonPink)
                                .frame(height: 200)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppPalette.Surface.fieldFill)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                                        )
                                )

                            if endTime <= startTime {
                                Text("End time must be after start time")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppPalette.Brand.neonPink)
                            }
                        }
                        .padding(.horizontal, 24)

                    case .review:
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 16) {
                                DetailRow(label: "Meet Name", value: meetName)
                                DetailRow(label: "Start", value: formatDate(startTime))
                                DetailRow(label: "End", value: formatDate(endTime))
                                DetailRow(label: "Duration", value: formatDuration(from: startTime, to: endTime))
                                // Capacity intentionally removed (feature paused)
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppPalette.Surface.fieldFill)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }

            Spacer()

            // Action button
            Button(action: nextStep) {
                Text(currentFieldStep == .review ? "Create Meet" : "Next")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(canProceed ? AppPalette.Brand.neonPink : AppPalette.Brand.neonPink.opacity(0.5))
                    )
            }
            .disabled(!canProceed)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(AppPalette.Brand.russianViolet)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: AppPalette.Brand.neonPink.opacity(0.3), radius: 20, x: 0, y: 10)
        .scaleEffect(isAnimating ? 1 : 0.95)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isAnimating = true
            }
            if endTime <= startTime { endTime = startTime.addingTimeInterval(3600) }
        }
        .onChange(of: startTime) { _, newStart in
            if endTime <= newStart { endTime = newStart.addingTimeInterval(3600) }
        }
        .onTapGesture {
            isNameFieldFocused = false
        }
    }

    private static let reviewFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
    private func formatDate(_ date: Date) -> String {
        Self.reviewFormatter.string(from: date)
    }


    private func formatDuration(from start: Date, to end: Date) -> String {
        let interval = max(0, end.timeIntervalSince(start))
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours) hour\(hours == 1 ? "" : "s")" }
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"

    }
}

struct MeetCreationOverlayByTap: View
{
    @Binding var selectedLocation: LocationInfo?
    @Binding var showPopup: Bool
    // Make this async + throws
 
    //================================================
    // MARK: - MeetCreation API Flow
    //================================================
    let onCreateMeet: (LocationInfo, String, Date, Date) async throws -> Void

    @State private var currentStep: Step = .locationConfirm
    @State private var isSubmitting = false
    @State private var submitError: String?
    
    //================================================
    // MARK: - END MeetCreation API Flow
    //================================================

    //================================================
    // MARK: - MeetCreation Effect Flow
    //================================================
    @State private var isExploding = false
    @State private var showConfetti = false
    
    private func explodeThenDismiss() // TODO: - consolidate duplicates ... not now though
    {
        guard !isExploding else { return }
        isExploding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { showConfetti = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showConfetti = false
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showPopup = false
                currentStep = .locationConfirm
                isExploding = false
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    //================================================
    // MARK: - END MeetCreation Effect Flow
    //================================================
    
    enum Step { case locationConfirm, meetDetails }

    var body: some View
    {
        ZStack
        {
            if showPopup, let location = selectedLocation {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if currentStep == .locationConfirm {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showPopup = false
                                currentStep = .locationConfirm
                            }
                        }
                    }

                Group {
                    switch currentStep
                    {
                    case .locationConfirm:
                        LocationConfirmationPopupView(
                            locationInfo: location,
                            onConfirm: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    currentStep = .meetDetails
                                }
                            },
                            onCancel: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showPopup = false
                                    currentStep = .locationConfirm
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))

                    case .meetDetails:
                        ZStack {
                            MeetCreationFormByTapView(
                                locationInfo: location,
                                onConfirm: { name, start, end in
                                    guard !isSubmitting else { return }
                                    submitError = nil
                                    isSubmitting = true
                                    Task {
                                        do {
                                            try await onCreateMeet(location, name, start, end)
                                            await MainActor.run {
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                                    explodeThenDismiss()
                                                }
                                            }
                                        } catch {
                                            await MainActor.run {
                                                submitError = error.localizedDescription
                                            }
                                        }
                                        await MainActor.run { isSubmitting = false }
                                    }
                                },
                                onBack: {
                                    guard !isExploding else { return }
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        currentStep = .locationConfirm
                                    }
                                }
                            )
                            .frame(maxWidth: 400, maxHeight: 650)
                            .allowsHitTesting(!isSubmitting && !isExploding)
                            .scaleEffect(isExploding ? 0.6 : 1.0)
                            .opacity(isExploding ? 0.0 : 1.0)
                            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExploding)
                            
                            if isSubmitting {
                                ProgressView("Creating…")
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }

                            if let submitError {
                                VStack {
                                    Spacer()
                                    Text(submitError)
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                        .padding(.bottom, 8)
                                }
                                .transition(.opacity)
                            }
                            
                            if showConfetti {
                                ConfettiBurst(color: UIColor(AppPalette.Brand.neonPink), duration: 1.0, intensity: 1.0)
                                    .allowsHitTesting(false)
                                    .transition(.opacity)
                            }
                            
                        }
                       
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPopup)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentStep)
    }
}
