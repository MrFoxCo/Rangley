//
//  MeetUpdateFormView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/14/25.
//

import SwiftUI
import CoreLocation
import QuartzCore

struct MeetUpdateFormView: View
{
    // MARK: Inputs
    let mode: MeetFormMode
    let onUpdate: (UpdatedMeetInsertBody) async throws -> Void
    let onClose: () -> Void
    let onPickLocation: (() async -> LocationInfo?)?
    let onLoadMeets: (() async -> Void)?
    
    // MARK: VM
    @StateObject private var vm: MeetFormModel
    
    // MARK: UI State
    @State private var isAnimating = false
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var currentStep: UpdateStep = .name
    @State private var showLocationPicker = false
    @FocusState private var isNameFieldFocused: Bool
    
    // Location display states
    @State private var displayLocationName: String = "Loading location..."
    @State private var displayLocationSubtitle: String = ""
    @State private var geocodingTask: Task<Void, Never>?
    
    init(
        mode: MeetFormMode,
        onUpdate: @escaping (UpdatedMeetInsertBody) async throws -> Void,
        onClose: @escaping () -> Void,
        onPickLocation: (() async -> LocationInfo?)? = nil,
        onLoadMeets: (() async -> Void)? = nil
    ) {
        self.mode = mode
        self.onUpdate = onUpdate
        self.onClose = onClose
        self.onPickLocation = onPickLocation
        self.onLoadMeets = onLoadMeets
        _vm = StateObject(wrappedValue: MeetFormModel(mode: mode))
    }
    
    // MARK: Steps
    enum UpdateStep: CaseIterable
    {
        case name
        case startTime
        case endTime
        case review
        
        var title: String {
            switch self {
            case .name: return "Update meet name"
            case .startTime: return "Change start time"
            case .endTime: return "Change end time"
            case .review: return "Review Changes"
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
    
    private var totalSteps: Int { UpdateStep.allCases.count }
    
    // MARK: Progress enablement
    private var canProceed: Bool
    {
        switch currentStep {
        case .name:
            return !vm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .startTime:
            return true
        case .endTime:
            return vm.end > vm.start
        case .review:
            return vm.validate() == nil && vm.makeUpdateBody() != nil
        }
    }
    
    // Seed from the existing meet (so the picker opens where the meet is now)
    private var seedLocation: LocationInfo
    {
        switch mode {
        case .update(let e):
            return LocationInfo(
                Coordinate: .init(e.latitude, e.longitude),
                RegionCoordinate: .init(e.region_latitude, e.region_longitude),
                RegionRadius: e.region_radius,
                Name: e.display_name,
                ThoroughFare: nil, SubThoroughFare: nil,
                Locality: nil, SubLocality: nil,
                AdministrativeArea: nil, SubAdministrativeArea: nil,
                PostalCode: nil,
                Country: nil, IsoCountryCode: nil,
                TimeZone: nil, InlandWater: nil, Ocean: nil
            )
        case .create(let location):
            if let location = location {
                return location
            } else {
                return LocationInfo(
                    Coordinate: .init(37.7749, -122.4194),
                    RegionCoordinate: .init(37.7749, -122.4194),
                    RegionRadius: 1000.0,
                    Name: "Default Location",
                    ThoroughFare: nil, SubThoroughFare: nil,
                    Locality: nil, SubLocality: nil,
                    AdministrativeArea: nil, SubAdministrativeArea: nil,
                    PostalCode: nil,
                    Country: nil, IsoCountryCode: nil,
                    TimeZone: nil, InlandWater: nil, Ocean: nil
                )
            }
        }
    }
    
    // MARK: View Body
    var body: some View
    {
        VStack(spacing: 0)
        {
            // Header
            header
            
            // Progress bar
            progressBar
            
            // Location card
            locationCard
            
            // Current step content - FIXED: Add ScrollView for review step
            if currentStep == .review {
                ScrollView {
                    stepContent
                        .padding(.bottom, 20) // Extra padding for scroll content
                }
            } else {
                stepContent
                Spacer(minLength: 0)
            }
            
            // Action button
            actionButton
        }
        .frame(maxWidth: 420, maxHeight: 590)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(AppPalette.Brand.formBlack)
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
            setupInitialState()
        }
        .onChange(of: vm.start, initial: false) { _, newStart in
            if vm.end <= newStart { vm.end = newStart.addingTimeInterval(3600) }
        }
        .onTapGesture { isNameFieldFocused = false }
        .onDisappear { geocodingTask?.cancel() }
        .fullScreenCover(isPresented: $showLocationPicker) {
            LocationPickerSheet(
                initial: seedLocation,
                onPick: { picked in
                    vm.latitude = picked.Coordinate.latitude
                    vm.longitude = picked.Coordinate.longitude
                    vm.regionLatitude = picked.RegionCoordinate.latitude
                    vm.regionLongitude = picked.RegionCoordinate.longitude
                    vm.regionRadius = picked.RegionRadius
                    
                    displayLocationName = "Loading new location..."
                    displayLocationSubtitle = ""
                    loadNewLocationAddress(picked)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showLocationPicker = false
                    }
                },
                onCancel: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showLocationPicker = false
                    }
                }
            )
        }
    }
    
    // MARK: Components
    private var header: some View
    {
        VStack(spacing: 16) {
            HStack {
                Button(action: previousStep) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text(isFirstStep ? "Cancel" : "Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(AppPalette.Brand.neonPink)
                }
                
                Spacer()
                
                Text("Step \(currentStep.stepNumber) of \(totalSteps)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppPalette.Text.secondary)
                    .accessibilityValue("Step \(currentStep.stepNumber) of \(totalSteps)")
                
                Spacer()
                
                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppPalette.Brand.neonPink)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(AppPalette.Brand.neonPink.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        .padding(.bottom, 12)
    }
    
    private var progressBar: some View
    {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppPalette.Surface.fieldFill)
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppPalette.Brand.neonPink)
                    .frame(
                        width: geometry.size.width * (Double(currentStep.stepNumber) / Double(totalSteps)),
                        height: 4
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentStep)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
    
    // MARK: Location Card - Cleaned up version
    private var locationCard: some View
    {
        VStack(alignment: .leading, spacing: 8)
        {
            Button(action: { showLocationPicker = true }) {
                HStack(spacing: 12) {
                    // Location icon
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        // Primary location name
                        Text(displayLocationName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppPalette.Text.primary)
                            .lineLimit(1)
                        
                        // Condensed address line
                        if !displayLocationSubtitle.isEmpty {
                            Text(displayLocationSubtitle)
                                .font(.system(size: 13))
                                .foregroundStyle(AppPalette.Text.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Subtle navigation hint
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.6))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppPalette.Surface.fieldFill.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppPalette.Surface.fieldStroke.opacity(0.8), lineWidth: 1)
                        )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
    
    // MARK: Step Content
    private var stepContent: some View
    {
        VStack(spacing: 24) {
            Text(currentStep.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppPalette.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
            
            Group
            {
                switch currentStep
                {
                case .name:
                    nameStepContent
                case .startTime:
                    startTimeStepContent
                case .endTime:
                    endTimeStepContent
                case .review:
                    reviewStepContent
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
    }
        
    // MARK: Step Contents
    private var nameStepContent: some View
    {
        VStack(alignment: .leading, spacing: 8)
        {
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
            
            Text("\(vm.name.count)/50")
                .font(.footnote)
                .foregroundColor(AppPalette.Text.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
    }
    
    private var startTimeStepContent: some View
    {
        VStack(spacing: 16)
        {
            DatePicker("", selection: $vm.start, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.wheel)
                .labelsHidden()
                .tint(AppPalette.Brand.neonPink)
                .colorScheme(.dark)
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
    }
    
    private var endTimeStepContent: some View
    {
        VStack(spacing: 16)
        {
            DatePicker("", selection: $vm.end, in: vm.start..., displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.wheel)
                .labelsHidden()
                .tint(AppPalette.Brand.neonPink)
                .colorScheme(.dark)
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
    }
    
    private var reviewStepContent: some View
    {
        VStack(spacing: 24)
        {
            VStack(alignment: .leading, spacing: 16)
            {
                DetailRow(label: "Location", value: displayLocationName)
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
            
            // Changes Made section - SEPARATED for better spacing
            if let updateBody = vm.makeUpdateBody() {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Changes Made:")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppPalette.Brand.neonPink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if updateBody.name != nil {
                            ChangeRow(text: "Name updated")
                        }
                        if updateBody.dttm_start_utc != nil {
                            ChangeRow(text: "Start time changed")
                        }
                        if updateBody.dttm_end_utc != nil {
                            ChangeRow(text: "End time changed")
                        }
                        if updateBody.latitude != nil || updateBody.longitude != nil {
                            ChangeRow(text: "Location updated")
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppPalette.Brand.neonPink.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 24)
    }

    
    private var actionButton: some View
    {
        Button(action: nextStep) {
            Text(currentStep == .review ? "Save Changes" : "Next")
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
            if let submitError, currentStep == .review {
                Text(submitError)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.bottom, 4)
            }
        }
    }
    
    // MARK: Navigation
    private var isFirstStep: Bool { currentStep == UpdateStep.allCases.first }
    
    private func nextStep()
    {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8))
        {
            switch currentStep {
            case .name:
                isNameFieldFocused = false
                currentStep = .startTime
            case .startTime:
                currentStep = .endTime
            case .endTime:
                currentStep = .review
            case .review:
                submit()
            }
        }
    }
    
    private func previousStep()
    {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            switch currentStep {
            case .name:
                onClose()
            case .startTime:
                currentStep = .name
            case .endTime:
                currentStep = .startTime
            case .review:
                currentStep = .endTime
            }
        }
    }
    
    // MARK: Submit
    // MARK: Submit - FIXED
    private func submit()
    {
        guard !isSubmitting else { return }
        
        // Clear any previous error
        submitError = nil
        
        // Validate first
        if let validationError = vm.validate() {
            submitError = validationError
            return
        }
        
        // Check if there are changes to save
        guard let updateBody = vm.makeUpdateBody() else {
            submitError = "No changes to save."
            return
        }
        
        isSubmitting = true
        Task {
            defer {
                Task { @MainActor in
                    isSubmitting = false
                }
            }
            
            do {
                try await onUpdate(updateBody)
                // Don't call onLoadMeets here - let the overlay handle it
                // The overlay will trigger the success animation
            } catch {
                await MainActor.run {
                    submitError = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: Location Address Loading
    private func setupInitialState()
    {
        if vm.end <= vm.start {
            vm.end = vm.start.addingTimeInterval(3600)
        }
        loadCurrentLocationAddress()
    }
    
    private func loadCurrentLocationAddress()
    {
        geocodingTask?.cancel()
        
        switch mode {
        case .update(let e):
            geocodingTask = Task {
                let geocoder = CLGeocoder()
                let location = CLLocation(latitude: e.latitude, longitude: e.longitude)
                
                do {
                    let placemarks = try await geocoder.reverseGeocodeLocation(location)
                    guard let p = placemarks.first else {
                        await MainActor.run {
                            displayLocationName = "Unknown location"
                            displayLocationSubtitle = "Lat: \(String(format: "%.4f", e.latitude)), Lng: \(String(format: "%.4f", e.longitude))"
                        }
                        return
                    }
                    
                    let name = p.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let street = p.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let number = p.subThoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let city = p.locality?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let state = p.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    await MainActor.run {
                        displayLocationName = name ?? street ?? "Current Location"
                        
                        let addressParts = [
                            [number, street].compactMap { $0 }.joined(separator: " "),
                            [city, state].compactMap { $0 }.joined(separator: ", ")
                        ].filter { !$0.isEmpty }
                        
                        displayLocationSubtitle = addressParts.joined(separator: " • ")
                    }
                } catch {
                    await MainActor.run {
                        displayLocationName = "Current location"
                        displayLocationSubtitle = "Lat: \(String(format: "%.4f", e.latitude)), Lng: \(String(format: "%.4f", e.longitude))"
                    }
                }
            }
            
        case .create(let location):
            if let location = location {
                loadNewLocationAddress(location)
            } else {
                displayLocationName = "Choose a location"
                displayLocationSubtitle = "Tap location card to select"
            }
        }
    }
        
    private func loadNewLocationAddress(_ locationInfo: LocationInfo)
    {
        geocodingTask?.cancel()
        
        geocodingTask = Task {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: locationInfo.Coordinate.latitude, longitude: locationInfo.Coordinate.longitude)
            
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                guard let p = placemarks.first else {
                    await MainActor.run {
                        displayLocationName = "New location selected"
                        displayLocationSubtitle = "Lat: \(String(format: "%.4f", locationInfo.Coordinate.latitude)), Lng: \(String(format: "%.4f", locationInfo.Coordinate.longitude))"
                    }
                    return
                }
                
                let name = p.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                let street = p.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines)
                let number = p.subThoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines)
                let city = p.locality?.trimmingCharacters(in: .whitespacesAndNewlines)
                let state = p.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines)
                
                await MainActor.run {
                    displayLocationName = name ?? street ?? "New Location"
                    
                    let addressParts = [
                        [number, street].compactMap { $0 }.joined(separator: " "),
                        [city, state].compactMap { $0 }.joined(separator: ", ")
                    ].filter { !$0.isEmpty }
                    
                    displayLocationSubtitle = addressParts.joined(separator: " • ")
                }
            } catch {
                await MainActor.run {
                    displayLocationName = "New location selected"
                    displayLocationSubtitle = "Lat: \(String(format: "%.4f", locationInfo.Coordinate.latitude)), Lng: \(String(format: "%.4f", locationInfo.Coordinate.longitude))"
                }
            }
        }
    }
    
    // MARK: Helpers
    private struct DetailRow: View
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
    
    private func formatDuration(from start: Date, to end: Date) -> String
    {
        let interval = max(0, end.timeIntervalSince(start))
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours) hour\(hours == 1 ? "" : "s")" }
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }
}


// MARK: - Meet Update Unified Overlay (similar to creation overlay)
struct MeetUpdateUnifiedOverlay: View
{
    // MARK: Configuration
    @Binding var showOverlay: Bool
    @Binding var meetToEdit: ViewMeetsModel?
    let onUpdate: (UpdatedMeetInsertBody) async throws -> Void
    let onLoadMeets: (() async -> Void)?
    
    // MARK: State
    @State private var isAnimating = false
    @State private var isExploding = false
    @State private var showConfetti = false
    @State private var isSoftDismissing = false
    
    // MARK: Body
    var body: some View {
        ZStack {
            if showOverlay, let meet = meetToEdit {
                // Dark backdrop
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Allow backdrop dismiss
                        dismiss()
                    }
                
                // Content
                ZStack {
                    MeetUpdateFormView(
                        mode: .update(existing: meet),
                        onUpdate: { body in
                            try await handleUpdate(body: body)
                        },
                        onClose: { softDismiss() },
                        onPickLocation: nil,
                        onLoadMeets: onLoadMeets
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
    
    // MARK: Handlers
    private func handleUpdate(body: UpdatedMeetInsertBody) async throws {
        try await onUpdate(body)
        await onLoadMeets?()
        await MainActor.run { explodeThenDismiss() }
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
