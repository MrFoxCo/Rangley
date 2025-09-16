//
//  MeetFormView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/14/25.
//

import SwiftUI
import CoreLocation
import QuartzCore

struct MeetFormView: View
{
    @State private var showLocationPicker = false
    
    // Location display states
    @State private var displayLocationName: String = "Loading location..."
    @State private var displayLocationSubtitle: String = ""
    @State private var geocodingTask: Task<Void, Never>?
    
    private func pickLocation() async -> LocationInfo? {
        // Your location picking logic here
        // This could open a location picker, use current location, etc.
        // For now, just return nil
        return nil
    }
    
    // Seed from the existing meet (so the picker opens where the meet is now)
    private var seedLocation: LocationInfo
    {
        switch mode {
        case .update(let e):
            return LocationInfo(
                Coordinate:        .init(e.latitude, e.longitude),
                RegionCoordinate:  .init(e.region_latitude, e.region_longitude),
                RegionRadius:      e.region_radius, // meters
                Name: e.display_name,               // or e.name; whatever you prefer
                ThoroughFare: nil, SubThoroughFare: nil,
                Locality: nil, SubLocality: nil,
                AdministrativeArea: nil, SubAdministrativeArea: nil,
                PostalCode: nil,
                Country: nil, IsoCountryCode: nil,
                TimeZone: nil, InlandWater: nil, Ocean: nil
            )
        }
    }

    // MARK: Inputs
    let mode: MeetFormMode                     // .update(existing: ...)
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
        onUpdate: @escaping (UpdatedMeetInsertBody) async throws -> Void,
        onClose: @escaping () -> Void,
        onPickLocation: (() async -> LocationInfo?)? = nil
    ) {
        self.mode = mode
        self.onUpdate = onUpdate
        self.onClose = onClose
        self.onPickLocation = onPickLocation
        _vm = StateObject(wrappedValue: MeetFormViewModel(mode: mode))
    }

    // MARK: Steps
    enum FieldStep: CaseIterable
    {
        case name, startTime, endTime, review

        func title() -> String {
            switch self {
            case .name:      return "Name your meet"
            case .startTime: return "When does it start?"
            case .endTime:   return "When does it end?"
            case .review:    return "Review & Save"
            }
        }
    }

    private var totalSteps: Int { FieldStep.allCases.count }

    // MARK: Progress enablement
    private var canProceed: Bool
    {
        switch currentFieldStep {
        case .name:
            return !vm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .startTime:
            return true
        case .endTime:
            return vm.end > vm.start
        case .review:
            if let err = vm.validate() { submitError = err; return false }
            // Require an actual change on review
            return vm.makeUpdateBody() != nil
        }
    }

    // MARK: View Body
    var body: some View
    {
        VStack(spacing: 0)
        {
            header
            progressBar

            // Location card + change button
            locationCard

            // Current step content
            contentForCurrentStep

            Spacer(minLength: 0)

            // Action button
            Button(action: nextStep)
            {
                Text(currentFieldStep == .review ? "Save Changes" : "Next")
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
            // Load the current location address
            loadCurrentLocationAddress()
        }
        .onChange(of: vm.start, initial: false) { _, newStart in
            if vm.end <= newStart { vm.end = newStart.addingTimeInterval(3600) }
        }
        .onTapGesture { isNameFieldFocused = false }
        .onDisappear { geocodingTask?.cancel() }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerSheet(
                initial: seedLocation,
                onPick: { picked in
                    vm.latitude        = picked.Coordinate.latitude
                    vm.longitude       = picked.Coordinate.longitude
                    vm.regionLatitude  = picked.RegionCoordinate.latitude
                    vm.regionLongitude = picked.RegionCoordinate.longitude
                    vm.regionRadius    = picked.RegionRadius
                    
                    // Show temporary state while loading new address
                    displayLocationName = "Loading new location..."
                    displayLocationSubtitle = ""
                    
                    // Update display with new location info
                    loadNewLocationAddress(picked)
                    
                    // Add small delay before dismissing to avoid Metal texture error
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

    // MARK: Location Address Loading
    private func loadCurrentLocationAddress() {
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
                        displayLocationName = name ?? street ?? "Dropped Pin"
                        displayLocationSubtitle = [
                            [number, street].compactMap { $0 }.joined(separator: " "),
                            [city, state].compactMap { $0 }.joined(separator: ", ")
                        ].filter { !$0.isEmpty }.joined(separator: " • ")
                    }
                } catch {
                    await MainActor.run {
                        displayLocationName = "Unknown location"
                        displayLocationSubtitle = "Lat: \(String(format: "%.4f", e.latitude)), Lng: \(String(format: "%.4f", e.longitude))"
                    }
                }
            }
        }
    }
    
    private func loadNewLocationAddress(_ locationInfo: LocationInfo) {
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
                    displayLocationSubtitle = [
                        [number, street].compactMap { $0 }.joined(separator: " "),
                        [city, state].compactMap { $0 }.joined(separator: ", ")
                    ].filter { !$0.isEmpty }.joined(separator: " • ")
                }
            } catch {
                await MainActor.run {
                    displayLocationName = "New location selected"
                    displayLocationSubtitle = "Lat: \(String(format: "%.4f", locationInfo.Coordinate.latitude)), Lng: \(String(format: "%.4f", locationInfo.Coordinate.longitude))"
                }
            }
        }
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
        .padding(.bottom, 12) // ⬅️ increase this number for more space
    }

    private func stepNumber(for step: FieldStep) -> Int
    {
        switch step {
        case .name: return 1
        case .startTime: return 2
        case .endTime: return 3
        case .review: return 4
        }
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
    private var locationCard: some View
    {
        VStack(alignment: .leading, spacing: 8)
        {
            Label {
                VStack(alignment: .leading, spacing: 4)
                {
                    Text(displayLocationName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppPalette.Text.primary)

                    Text(displayLocationSubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppPalette.Text.secondary)
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

            HStack
            {
                Button {
                    showLocationPicker = true
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

    private var coordProvidedCount: Int
    {
        [vm.latitude, vm.longitude, vm.regionLatitude, vm.regionLongitude, vm.regionRadius]
            .compactMap { $0 }.count
    }

    // MARK: Step Content
    private var contentForCurrentStep: some View
    {
        VStack(spacing: 24) {
            Text(currentFieldStep.title())
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppPalette.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            Group
            {
                switch currentFieldStep
                {
                case .name:
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

                case .startTime:
                    VStack(spacing: 16)
                    {
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
                    VStack(spacing: 16)
                    {
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
                    VStack(spacing: 20)
                    {
                        VStack(alignment: .leading, spacing: 16)
                        {
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
                            DetailRow(label: "Changes", value: vm.makeUpdateBody() != nil ? "Yes" : "No")
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
    private func nextStep()
    {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8))
        {
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

    private func previousStep()
    {
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

    private func submit()
    {
        if isSubmitting { return }
        submitError = vm.validate()
        guard submitError == nil else { return }

        isSubmitting = true
        Task {
            defer { Task { @MainActor in isSubmitting = false } } // no await here
            do {
                if let body = vm.makeUpdateBody() {
                    try await onUpdate(body)
                    await MainActor.run { onClose() }
                } else {
                    await MainActor.run { submitError = "No changes to save." }
                }
            } catch {
                await MainActor.run { submitError = error.localizedDescription }
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

// MARK: - LocationPickerSheet
struct LocationPickerSheet: View {
    let initial: LocationInfo
    let onPick: (LocationInfo) -> Void
    let onCancel: () -> Void
    
    @State private var selectedMethod: LocationMethod = .map
    @State private var isAnimating = false
    
    enum LocationMethod: String, CaseIterable {
        case map = "Pick on Map"
        case address = "Enter Address"
        
        var icon: String {
            switch self {
            case .map: return "map"
            case .address: return "magnifyingglass"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header matching MeetFormView style
            HStack {
                Button(action: onCancel) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(AppPalette.Brand.neonPink)
                }
                
                Spacer()
                
                Text("Choose Location")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppPalette.Text.primary)
                
                Spacer()
                
                // Invisible button for symmetry
                Button("") {}
                    .opacity(0)
                    .disabled(true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Method selector with matching style
            VStack(spacing: 16) {
                Text("How would you like to pick your location?")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppPalette.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Picker("Location Method", selection: $selectedMethod) {
                    ForEach(LocationMethod.allCases, id: \.self) { method in
                        Text(method.rawValue)
                            .tag(method)
                    }
                }
                .pickerStyle(.segmented)
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
            
            // Content based on selected method
            Group {
                switch selectedMethod {
                case .map:
                    MapLocationPicker(
                        initial: initial,
                        onPick: onPick,
                        onCancel: onCancel
                    )
                case .address:
                    AddressSearchPicker(
                        initialRadiusMeters: initial.RegionRadius,
                        onPick: onPick,
                        onCancel: onCancel
                    )
                }
            }
            .transition(.opacity.combined(with: .slide))
            .animation(.easeInOut(duration: 0.3), value: selectedMethod)
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
        }
        .presentationDetents([.large])
    }
}
