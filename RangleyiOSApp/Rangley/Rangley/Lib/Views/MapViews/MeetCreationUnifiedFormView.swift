//
//  MeetCreationUnifiedFormView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/23/25.
//

import SwiftUI
import CoreLocation
import QuartzCore

// MARK: - Entry Mode
enum MeetCreationEntryMode
{
    case tapOnMap(location: LocationInfo)  // Location pre-selected
    case createButton                       // Need to pick location
}

// MARK: - Unified Form View
struct MeetCreationUnifiedFormView: View
{
    // MARK: Configuration
    let entryMode: MeetCreationEntryMode
    let baseURL: URL
    let token: String
    let onCreate: (MeetInsertBody) async throws -> Void
    let onCreateWithInvites: (MeetWithInvitesInsertBody) async throws -> Void
    let onClose: () -> Void
    
    // MARK: State
    @StateObject private var vm: MeetFormUnifiedModel
    @State private var currentStep: UnifiedStep = .location
    @State private var invitedUsers: [ViewUsersModel] = []
    @State private var isAnimating = false
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var showLocationPicker = false
    @State private var displayLocationName = "Choose a location"
    @State private var displayLocationSubtitle = ""
    @State private var geocodingTask: Task<Void, Never>?
    @FocusState private var isNameFieldFocused: Bool
    
    init(
        entryMode: MeetCreationEntryMode,
        baseURL: URL,
        token: String,
        onCreate: @escaping (MeetInsertBody) async throws -> Void,
        onCreateWithInvites: @escaping (MeetWithInvitesInsertBody) async throws -> Void,
        onClose: @escaping () -> Void
    ) {
        self.entryMode = entryMode
        self.baseURL = baseURL
        self.token = token
        self.onCreate = onCreate
        self.onCreateWithInvites = onCreateWithInvites
        self.onClose = onClose
        
        // Initialize VM with location if available
        let initialLocation: LocationInfo? = {
            switch entryMode {
            case .tapOnMap(let loc): return loc
            case .createButton: return nil
            }
        }()
        
        _vm = StateObject(wrappedValue: MeetFormUnifiedModel(location: initialLocation))
        
        // Skip location step if coming from tap
        switch entryMode {
        case .tapOnMap:
            _currentStep = State(initialValue: .name)
        case .createButton:
            _currentStep = State(initialValue: .location)
        }
    }
    
    // MARK: Steps
    enum UnifiedStep: CaseIterable
    {
        case location    // Only for createButton flow
        case name
        case startTime
        case endTime
        case inviteFriends
        case review
        
        var title: String {
            switch self {
            case .location: return "Choose your location"
            case .name: return "Name your meet"
            case .startTime: return "When does it start?"
            case .endTime: return "When does it end?"
            case .inviteFriends: return "Invite Friends"
            case .review: return "Review & Create"
            }
        }
        
        var stepNumber: Int {
            // Adjust numbering based on entry mode
            switch self {
            case .location: return 1
            case .name: return 2
            case .startTime: return 3
            case .endTime: return 4
            case .inviteFriends: return 5
            case .review: return 6
            }
        }
    }
    
    // Get active steps based on entry mode
    private var activeSteps: [UnifiedStep]
    {
        switch entryMode {
        case .tapOnMap:
            // Skip location step
            return UnifiedStep.allCases.filter { $0 != .location }
        case .createButton:
            // Include all steps
            return UnifiedStep.allCases
        }
    }
    
    private var totalSteps: Int { activeSteps.count }
    
    private var currentStepNumber: Int
    {
        guard let index = activeSteps.firstIndex(of: currentStep) else { return 1 }
        return index + 1
    }
    
    // MARK: Progress validation
    private var canProceed: Bool
    {
        switch currentStep {
        case .location:
            return vm.hasValidLocation
        case .name:
            return !vm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .startTime:
            return true
        case .endTime:
            return vm.end > vm.start
        case .inviteFriends:
            return true // Optional step
        case .review:
            return vm.validate() == nil
        }
    }
    
    // MARK: Body
    var body: some View
    {
        VStack(spacing: 0) {
            // Header
            header
            
            // Progress bar
            progressBar
            
            // Location card (always visible except during location step)
            if currentStep != .location {
                locationCard
            }
            
            // Current step content
            stepContent
            
            Spacer(minLength: 0)
            
            // Action button
            actionButton
        }
        .frame(maxWidth: 400, maxHeight: 650)
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
            setupInitialState()
        }
        .onChange(of: vm.start, initial: false) { _, newStart in
            if vm.end <= newStart {
                vm.end = newStart.addingTimeInterval(3600)
            }
        }
        .onTapGesture { isNameFieldFocused = false }
        .onDisappear { geocodingTask?.cancel() }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerSheet(
                initial: vm.currentLocationInfo,
                onPick: { picked in
                    vm.applyLocation(picked)
                    displayLocationName = "Loading new location..."
                    displayLocationSubtitle = ""
                    loadLocationAddress(picked)
                    showLocationPicker = false
                },
                onCancel: { showLocationPicker = false }
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
                
                Text("Step \(currentStepNumber) of \(totalSteps)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppPalette.Text.secondary)
                
                Spacer()
                
                // Add X button on the right
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
                        width: geometry.size.width * (Double(currentStepNumber) / Double(totalSteps)),
                        height: 4
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentStep)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
    
    private var locationCard: some View
    {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayLocationName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppPalette.Text.primary)
                    
                    if !displayLocationSubtitle.isEmpty {
                        Text(displayLocationSubtitle)
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
            
            // Change location button (optional based on flow)
            if case .createButton = entryMode {
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
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
    
    private var stepContent: some View
    {
        VStack(spacing: 24) {
            Text(currentStep.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppPalette.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
            
            Group {
                switch currentStep {
                case .location:
                    locationStepContent
                case .name:
                    nameStepContent
                case .startTime:
                    startTimeStepContent
                case .endTime:
                    endTimeStepContent
                case .inviteFriends:
                    inviteFriendsStepContent
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
    private var locationStepContent: some View
    {
        VStack(spacing: 12) {
            Text("Pick a spot for your meet")
                .font(.system(size: 14))
                .foregroundColor(AppPalette.Text.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button {
                showLocationPicker = true
            } label: {
                HStack {
                    Image(systemName: "map")
                    Text("Open Location Picker")
                }
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppPalette.Brand.neonPink, lineWidth: 1)
                )
            }
            .padding(.top, 4)
            
            if vm.hasValidLocation {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayLocationName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppPalette.Text.primary)
                            
                            Text(displayLocationSubtitle)
                                .font(.system(size: 12))
                                .foregroundColor(AppPalette.Text.secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppPalette.Brand.neonPink)
                            .font(.system(size: 16))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppPalette.Brand.neonPink.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var nameStepContent: some View
    {
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
            
            Text("\(vm.name.count)/50")
                .font(.footnote)
                .foregroundColor(AppPalette.Text.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 24)
    }
    
    private var startTimeStepContent: some View
    {
        VStack(spacing: 16) {
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
        VStack(spacing: 16) {
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
    
    private var inviteFriendsStepContent: some View
    {
        InviteFriendsEmbedded(
            baseURL: baseURL,
            token: token,
            selectedUsers: $invitedUsers
        )
    }
    
    private var reviewStepContent: some View
    {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                DetailRow(label: "Location", value: displayLocationName)
                DetailRow(label: "Meet Name", value: vm.name)
                DetailRow(label: "Start", value: formatDate(vm.start))
                DetailRow(label: "End", value: formatDate(vm.end))
                DetailRow(label: "Duration", value: formatDuration(from: vm.start, to: vm.end))
                
                if !invitedUsers.isEmpty {
                    DetailRow(label: "Invites", value: "\(invitedUsers.count) friend\(invitedUsers.count == 1 ? "" : "s")")
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
    
    private var actionButton: some View
    {
        Button(action: nextStep) {
            Text(buttonTitle)
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
    
    private var buttonTitle: String
    {
        switch currentStep {
        case .review: return "Create Meet"
        case .inviteFriends: return invitedUsers.isEmpty ? "Skip" : "Continue"
        default: return "Next"
        }
    }
    
    // MARK: Navigation
    private var isFirstStep: Bool
    {
        currentStep == activeSteps.first
    }
    
    private func nextStep()
    {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if currentStep == .name {
                isNameFieldFocused = false
            }
            
            if currentStep == .review {
                submit()
            } else if let currentIndex = activeSteps.firstIndex(of: currentStep),
                      currentIndex < activeSteps.count - 1 {
                currentStep = activeSteps[currentIndex + 1]
            }
        }
    }
    
    private func previousStep()
    {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if isFirstStep {
                onClose()
            } else if let currentIndex = activeSteps.firstIndex(of: currentStep),
                      currentIndex > 0 {
                currentStep = activeSteps[currentIndex - 1]
            }
        }
    }
    
    // MARK: Submit
    private func submit()
    {
        guard !isSubmitting else { return }
        submitError = vm.validate()
        guard submitError == nil else { return }
        
        isSubmitting = true
        Task {
            defer { Task { @MainActor in isSubmitting = false } }
            do {
                if invitedUsers.isEmpty {
                    // No invites - use simple insert
                    if let body = vm.makeCreateBody() {
                        try await onCreate(body)
                        await MainActor.run { onClose() }
                    } else {
                        await MainActor.run { submitError = "Missing required fields" }
                    }
                } else {
                    // Has invites - use invite insert
                    if let body = vm.makeCreateBodyWithInvites(invitedUserUUIDs: invitedUsers.map { $0.user_uuid }) {
                        try await onCreateWithInvites(body)
                        await MainActor.run { onClose() }
                    } else {
                        await MainActor.run { submitError = "Missing required fields" }
                    }
                }
            } catch {
                await MainActor.run { submitError = error.localizedDescription }
            }
        }
    }
    
    // MARK: Helpers
    private func setupInitialState()
    {
        if vm.end <= vm.start {
            vm.end = vm.start.addingTimeInterval(3600)
        }
        
        switch entryMode {
        case .tapOnMap(let location):
            loadLocationAddress(location)
        case .createButton:
            displayLocationName = "Choose a location"
            displayLocationSubtitle = "Tap 'Open Location Picker' to select"
        }
    }
    
    private func loadLocationAddress(_ location: LocationInfo)
    {
        geocodingTask?.cancel()
        geocodingTask = Task {
            let geocoder = CLGeocoder()
            let clLocation = CLLocation(
                latitude: location.Coordinate.latitude,
                longitude: location.Coordinate.longitude
            )
            
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(clLocation)
                guard let p = placemarks.first else {
                    await MainActor.run {
                        displayLocationName = "Selected location"
                        displayLocationSubtitle = formatCoordinates(location)
                    }
                    return
                }
                
                let name = p.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                let street = p.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines)
                let number = p.subThoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines)
                let city = p.locality?.trimmingCharacters(in: .whitespacesAndNewlines)
                let state = p.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines)
                
                await MainActor.run {
                    displayLocationName = name ?? street ?? "Selected Location"
                    displayLocationSubtitle = [
                        [number, street].compactMap { $0 }.joined(separator: " "),
                        [city, state].compactMap { $0 }.joined(separator: ", ")
                    ].filter { !$0.isEmpty }.joined(separator: " • ")
                }
            } catch {
                await MainActor.run {
                    displayLocationName = "Selected location"
                    displayLocationSubtitle = formatCoordinates(location)
                }
            }
        }
    }
    
    private func formatCoordinates(_ location: LocationInfo) -> String
    {
        "Lat: \(String(format: "%.4f", location.Coordinate.latitude)), Lng: \(String(format: "%.4f", location.Coordinate.longitude))"
    }
    
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
    
    private func formatDate(_ date: Date) -> String
    {
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

// MARK: - Unified View Model
final class MeetFormUnifiedModel: ObservableObject
{
    // Location
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var regionLatitude: Double?
    @Published var regionLongitude: Double?
    @Published var regionRadius: Double?
    
    // Meet details
    @Published var name = ""
    @Published var start = Date().addingTimeInterval(3600)
    @Published var end = Date().addingTimeInterval(7200)
    @Published var descriptionText = ""
    @Published var meetCategoryID: Int16 = 1
    @Published var maxCapacity: Int32 = 8
    
    init(location: LocationInfo? = nil) {
        if let loc = location {
            applyLocation(loc)
        }
    }
    
    var hasValidLocation: Bool {
        latitude != nil &&
        longitude != nil &&
        regionLatitude != nil &&
        regionLongitude != nil &&
        regionRadius != nil
    }
    
    var currentLocationInfo: LocationInfo {
        LocationInfo(
            Coordinate: .init(
                latitude ?? 37.7749,
                longitude ?? -122.4194
            ),
            RegionCoordinate: .init(
                regionLatitude ?? 37.7749,
                regionLongitude ?? -122.4194
            ),
            RegionRadius: regionRadius ?? 1000.0,
            Name: "Current Location",
            ThoroughFare: nil,
            SubThoroughFare: nil,
            Locality: nil,
            SubLocality: nil,
            AdministrativeArea: nil,
            SubAdministrativeArea: nil,
            PostalCode: nil,
            Country: nil,
            IsoCountryCode: nil,
            TimeZone: nil,
            InlandWater: nil,
            Ocean: nil
        )
    }
    
    func applyLocation(_ location: LocationInfo) {
        latitude = location.Coordinate.latitude
        longitude = location.Coordinate.longitude
        regionLatitude = location.RegionCoordinate.latitude
        regionLongitude = location.RegionCoordinate.longitude
        regionRadius = location.RegionRadius
    }
    
    func validate() -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Name is required" }
        guard trimmed.count <= 50 else { return "Name must be 50 characters or fewer" }
        guard start < end else { return "Start time must be before end time" }
        guard hasValidLocation else { return "Location is required" }
        if maxCapacity < 2 { return "Capacity must be at least 2" }
        return nil
    }
    
    func makeCreateBody() -> MeetInsertBody? {
        guard hasValidLocation,
              let lat = latitude,
              let lon = longitude,
              let rLat = regionLatitude,
              let rLon = regionLongitude,
              let rRad = regionRadius else {
            return nil
        }
        
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        return MeetInsertBody(
            latitude: lat,
            longitude: lon,
            region_latitude: rLat,
            region_longitude: rLon,
            region_radius: rRad,
            name: String(trimmed.prefix(50)),
            dttm_start_utc: start,
            dttm_end_utc: end,
            description: descriptionText.isEmpty ? nil : descriptionText,
            meet_category_id: meetCategoryID,
            max_capacity: maxCapacity
        )
    }
    
    func makeCreateBodyWithInvites(invitedUserUUIDs: [UUID]) -> MeetWithInvitesInsertBody? {
        guard hasValidLocation,
              let lat = latitude,
              let lon = longitude,
              let rLat = regionLatitude,
              let rLon = regionLongitude,
              let rRad = regionRadius else {
            return nil
        }
        
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        return MeetWithInvitesInsertBody(
            initial_invitee_uuids: invitedUserUUIDs,
            latitude: lat,
            longitude: lon,
            region_latitude: rLat,
            region_longitude: rLon,
            region_radius: rRad,
            name: String(trimmed.prefix(50)),
            dttm_start_utc: start,
            dttm_end_utc: end,
            description: descriptionText.isEmpty ? nil : descriptionText,
            meet_category_id: meetCategoryID,
            max_capacity: maxCapacity,
            invitation_message: nil
        )
    }
}
