//
//  MeetCreationFomView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

import SwiftUI
import CoreLocation

struct MeetCreationFormView: View {
    let locationInfo: LocationInfo
    let onConfirm: (String, Date, Date, Int?) -> Void
    let onBack: () -> Void

    @State private var meetName = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600) // Default 1 hour later
    @State private var maxCapacity = ""
    @State private var isAnimating = false
    @State private var currentFieldStep: FieldStep = .name

    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isCapacityFieldFocused: Bool

    enum FieldStep: CaseIterable {
        case name, startTime, endTime, capacity, review

        var title: String {
            switch self {
            case .name: return "Name your meet"
            case .startTime: return "When does it start?"
            case .endTime: return "When does it end?"
            case .capacity: return "Set capacity (optional)"
            case .review: return "Review & Create"
            }
        }

        var stepNumber: Int {
            switch self {
            case .name: return 1
            case .startTime: return 2
            case .endTime: return 3
            case .capacity: return 4
            case .review: return 5
            }
        }
    }

    private var locationDisplayName: String {
        if let name = locationInfo.Name, !name.isEmpty { return name }
        if let thoroughfare = locationInfo.ThoroughFare { return thoroughfare }
        if let locality = locationInfo.Locality { return locality }
        return "Selected location"
    }

    private var canProceed: Bool {
        switch currentFieldStep {
        case .name:
            return !meetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .startTime:
            return true
        case .endTime:
            return endTime > startTime
        case .capacity:
            return true
        case .review:
            return !meetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endTime > startTime
        }
    }

    private func nextStep() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            switch currentFieldStep {
            case .name:
                currentFieldStep = .startTime
            case .startTime:
                currentFieldStep = .endTime
            case .endTime:
                currentFieldStep = .capacity
            case .capacity:
                currentFieldStep = .review
            case .review:
                let capacity = Int(maxCapacity)
                onConfirm(meetName, startTime, endTime, capacity)
            }
        }
    }

    private func previousStep() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            switch currentFieldStep {
            case .name:
                onBack()
            case .startTime:
                currentFieldStep = .name
            case .endTime:
                currentFieldStep = .startTime
            case .capacity:
                currentFieldStep = .endTime
            case .review:
                currentFieldStep = .capacity
            }
        }
    }

    var body: some View {
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

                    // Step indicator
                    Text("Step \(currentFieldStep.stepNumber) of 5")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppPalette.Text.secondary)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppPalette.Surface.fieldFill)
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppPalette.Brand.neonPink)
                            .frame(
                                width: geometry.size.width * (Double(currentFieldStep.stepNumber) / 5.0),
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
                                .accentColor(AppPalette.Brand.neonPink)
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
                                .accentColor(AppPalette.Brand.neonPink)
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

                    case .capacity:
                        VStack(alignment: .leading, spacing: 16) {
                            TextField("", text: $maxCapacity, prompt: Text("Leave empty for unlimited").foregroundColor(AppPalette.Text.tertiary))
                                .font(.system(size: 18))
                                .foregroundColor(AppPalette.Text.primary)
                                .keyboardType(.numberPad)
                                .focused($isCapacityFieldFocused)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppPalette.Surface.fieldFill)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    isCapacityFieldFocused ? AppPalette.Surface.focusStroke : AppPalette.Surface.fieldStroke,
                                                    lineWidth: isCapacityFieldFocused ? 2 : 1
                                                )
                                        )
                                )
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        isCapacityFieldFocused = true
                                    }
                                }
                                .onChange(of: maxCapacity) { newVal in
                                    // keep only digits
                                    let digits = newVal.filter(\.isNumber)
                                    if digits != newVal { maxCapacity = digits }
                                }

                            Button(action: {
                                maxCapacity = ""
                                nextStep()
                            }) {
                                Text("Skip this step")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppPalette.Text.secondary)
                                    .underline()
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
                                DetailRow(label: "Capacity", value: maxCapacity.isEmpty ? "Unlimited" : maxCapacity)
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
                Text(currentFieldStep == .review ? "Create Meet" : (currentFieldStep == .capacity ? "Continue" : "Next"))
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
            // keep end >= start if user scrolls start earlier
            if endTime <= startTime { endTime = startTime.addingTimeInterval(3600) }
        }
        .onChange(of: startTime) { newStart in
            if endTime <= newStart { endTime = newStart.addingTimeInterval(3600) }
        }
        .onTapGesture {
            isNameFieldFocused = false
            isCapacityFieldFocused = false
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }

    private func formatDuration(from start: Date, to end: Date) -> String {
        let interval = max(0, end.timeIntervalSince(start))
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours) hour\(hours > 1 ? "s" : "")" }
        return "\(minutes) minutes"
    }
}

struct DetailRow: View {
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

// Updated Overlay with both popups
struct MeetCreationOverlay: View {
    @Binding var selectedLocation: LocationInfo?
    @Binding var showPopup: Bool
    let onCreateMeet: (LocationInfo, String, Date, Date, Int?) -> Void

    @State private var currentStep: Step = .locationConfirm

    enum Step { case locationConfirm, meetDetails }

    var body: some View {
        ZStack {
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
                    switch currentStep {
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
                        MeetCreationFormView(
                            locationInfo: location,
                            onConfirm: { name, startTime, endTime, capacity in
                                onCreateMeet(location, name, startTime, endTime, capacity)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showPopup = false
                                    currentStep = .locationConfirm
                                }
                            },
                            onBack: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    currentStep = .locationConfirm
                                }
                            }
                        )
                        .frame(maxWidth: 400, maxHeight: 650)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPopup)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentStep)
    }
}
