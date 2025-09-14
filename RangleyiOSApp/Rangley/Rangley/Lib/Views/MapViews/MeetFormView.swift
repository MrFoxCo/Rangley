//
//  MeetFormView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/14/25.
//


import SwiftUI
import CoreLocation
import QuartzCore

struct MeetFormView: View {
    // MARK: Inputs
    let mode: MeetFormMode
    let onCreate: (MeetInsertBody) async throws -> Void
    let onUpdate: (UpdatedMeetInsertBody) async throws -> Void
    let onClose: () -> Void
    /// Optional async location picker; return a full LocationInfo (all 5 fields).
    let onPickLocation: (() async -> LocationInfo?)?

    // MARK: VM
    @StateObject private var vm: MeetFormViewModel

    // MARK: UI State
    @State private var isAnimating = false
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var currentFieldStep: FieldStep = .name
    @FocusState private var isNameFieldFocused: Bool

    init(
        mode: MeetFormMode,
        onCreate: @escaping (MeetInsertBody) async throws -> Void,
        onUpdate: @escaping (UpdatedMeetInsertBody) async throws -> Void,
        onClose: @escaping () -> Void,
        onPickLocation: (() async -> LocationInfo?)? = nil
    ) {
        self.mode = mode
        self.onCreate = onCreate
        self.onUpdate = onUpdate
        self.onClose = onClose
        self.onPickLocation = onPickLocation
        _vm = StateObject(wrappedValue: MeetFormViewModel(mode: mode))
    }

    // MARK: Steps
    enum FieldStep: CaseIterable {
        case name, startTime, endTime, review

        func title(isUpdate: Bool) -> String {
            switch self {
            case .name:      return "Name your meet"
            case .startTime: return "When does it start?"
            case .endTime:   return "When does it end?"
            case .review:    return isUpdate ? "Review & Save" : "Review & Create"
            }
        }
    }


    private var totalSteps: Int { FieldStep.allCases.count }
    private var isUpdateMode: Bool { if case .update = mode { return true } else { return false } }
    private var createLocation: LocationInfo? { if case .create(let loc) = mode { return loc } else { return nil } }

    // MARK: Location display
    private var locationDisplayName: String {
        if let loc = createLocation {
            if let n = loc.Name, !n.isEmpty { return n }
            if let t = loc.ThoroughFare { return t }
            if let l = loc.Locality { return l }
            return "Selected location"
        } else {
            return "Current location"
        }
    }

    // MARK: Progress enablement
    private var canProceed: Bool {
        switch currentFieldStep {
        case .name:
            return !vm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .startTime:
            return true
        case .endTime:
            return vm.end > vm.start
        case .review:
            if let err = vm.validate() { submitError = err; return false }
            // In update mode, also require that something actually changed
            if isUpdateMode {
                return vm.makeUpdateBody() != nil
            }
            // Create mode is valid if validate() passed
            return true
        }
    }

    // MARK: View Body
    var body: some View {
        VStack(spacing: 0) {
            header
            progressBar

            // Location card + change button
            locationCard

            // Current step content
            contentForCurrentStep

            Spacer(minLength: 0)

            // Action button
            Button(action: nextStep) {
                Text(currentFieldStep == .review ? (isUpdateMode ? "Save Changes" : "Create Meet") : "Next")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(canProceed ? AppPalette.Brand.neonPink : AppPalette.Brand.neonPink.opacity(0.5))
                    )
            }
            .disabled(!canProceed || isSubmitting)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .overlay(alignment: .bottom) {
                if let submitError, currentFieldStep == .review {
                    Text(submitError)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.bottom, 4)
                }
            }
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
            // Ensure end > start on entry
            if vm.end <= vm.start { vm.end = vm.start.addingTimeInterval(3600) }
        }
        .onChange(of: vm.start, initial: false) { _, newStart in
            if vm.end <= newStart { vm.end = newStart.addingTimeInterval(3600) }
        }

        .onTapGesture { isNameFieldFocused = false }
    }

    // MARK: Header & Progress
    private var header: some View {
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

                Text("Step \(stepNumber(for: currentFieldStep)) of \(totalSteps)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppPalette.Text.secondary)
                    .accessibilityValue("Step \(stepNumber(for: currentFieldStep)) of \(totalSteps)")
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
    }

    private func stepNumber(for step: FieldStep) -> Int {
        switch step {
        case .name: return 1
        case .startTime: return 2
        case .endTime: return 3
        case .review: return 4
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppPalette.Surface.fieldFill)
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(AppPalette.Brand.neonPink)
                    .frame(
                        width: geometry.size.width * (Double(stepNumber(for: currentFieldStep)) / Double(totalSteps)),
                        height: 4
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentFieldStep)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: Location Card
    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(locationDisplayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppPalette.Text.primary)

                    if let loc = createLocation,
                       let city = loc.Locality, let state = loc.AdministrativeArea {
                        Text("\(city), \(state)")
                            .font(.system(size: 12))
                            .foregroundColor(AppPalette.Text.secondary)
                    } else if isUpdateMode {
                        // Show a hint if a new location has been selected during update
                        if coordProvidedCount > 0 {
                            Text("New location selected")
                                .font(.system(size: 12))
                                .foregroundColor(AppPalette.Text.secondary)
                        } else {
                            Text("Tap to change location")
                                .font(.system(size: 12))
                                .foregroundColor(AppPalette.Text.tertiary)
                        }
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

            HStack {
                Button {
                    Task {
                        guard let onPick = onPickLocation else { return }
                        if let newLoc = await onPick() {
                            // Set all five to respect all-or-none policy
                            vm.latitude        = newLoc.Coordinate.latitude
                            vm.longitude       = newLoc.Coordinate.longitude
                            vm.regionLatitude  = newLoc.RegionCoordinate.latitude
                            vm.regionLongitude = newLoc.RegionCoordinate.longitude
                            vm.regionRadius    = newLoc.RegionRadius
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("Change Location")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppPalette.Brand.neonPink)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppPalette.Brand.neonPink.opacity(0.6), lineWidth: 1)
                    )
                }

                if coordProvidedCount > 0 && coordProvidedCount != 5 {
                    Text("Provide all 5 fields or none")
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.leading, 8)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var coordProvidedCount: Int {
        [vm.latitude, vm.longitude, vm.regionLatitude, vm.regionLongitude, vm.regionRadius]
            .compactMap { $0 }.count
    }

    // MARK: Step Content
    private var contentForCurrentStep: some View {
        VStack(spacing: 24) {
            Text(currentFieldStep.title(isUpdate: isUpdateMode)) //Text(currentFieldStep.title(isUpdate: isUpdateMode))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppPalette.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            Group {
                switch currentFieldStep {
                case .name:
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("", text: $vm.name, prompt: Text("Enter meet name").foregroundColor(AppPalette.Text.tertiary))
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
                            .onChange(of: vm.start, initial: false) { _, newStart in
                                if vm.end <= newStart { vm.end = newStart.addingTimeInterval(3600) }
                            }


                        Text("\(vm.name.count)/50")
                            .font(.footnote)
                            .foregroundColor(AppPalette.Text.tertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal, 24)

                case .startTime:
                    VStack(spacing: 16) {
                        DatePicker("", selection: $vm.start, displayedComponents: [.date, .hourAndMinute])
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
                        DatePicker("", selection: $vm.end, in: vm.start..., displayedComponents: [.date, .hourAndMinute])
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

                        if vm.end <= vm.start {
                            Text("End time must be after start time")
                                .font(.system(size: 12))
                                .foregroundColor(AppPalette.Brand.neonPink)
                        }
                    }
                    .padding(.horizontal, 24)

                case .review:
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 16) {
                            DetailRow(label: "Meet Name", value: vm.name)
                            DetailRow(label: "Start", value: formatDate(vm.start))
                            DetailRow(label: "End", value: formatDate(vm.end))
                            DetailRow(label: "Duration", value: formatDuration(from: vm.start, to: vm.end))

                            if let desc = vm.descriptionText, !desc.isEmpty {
                                DetailRow(label: "Description", value: desc)
                            }
                            if let cap = vm.maxCapacity {
                                DetailRow(label: "Capacity", value: "\(cap)")
                            }
                            if isUpdateMode {
                                DetailRow(label: "Changes", value: vm.makeUpdateBody() != nil ? "Yes" : "No")
                            }
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
    }

    // MARK: Actions
    private func nextStep() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            switch currentFieldStep {
            case .name:
                isNameFieldFocused = false
                currentFieldStep = .startTime
            case .startTime:
                currentFieldStep = .endTime
            case .endTime:
                currentFieldStep = .review
            case .review:
                submit()
            }
        }
    }

    private func previousStep() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            switch currentFieldStep {
            case .name:
                onClose()
            case .startTime:
                currentFieldStep = .name
            case .endTime:
                currentFieldStep = .startTime
            case .review:
                currentFieldStep = .endTime
            }
        }
    }

    private func submit() {
        submitError = vm.validate()
        guard submitError == nil else { return }

        isSubmitting = true
        Task {
            do {
                if isUpdateMode {
                    if let body = vm.makeUpdateBody() {
                        try await onUpdate(body)
                    } else {
                        submitError = "No changes to save."
                    }
                } else {
                    guard let loc = createLocation, let body = vm.makeCreateBody(locationFallback: loc) else {
                        submitError = "Missing location."
                        return
                    }
                    try await onCreate(body)
                }
                await MainActor.run { onClose() }
            } catch {
                await MainActor.run { submitError = error.localizedDescription }
            }
            await MainActor.run { isSubmitting = false }
        }
    }

    // MARK: Helpers
    private struct DetailRow: View {
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
                    .multilineTextAlignment(.trailing)
            }
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
