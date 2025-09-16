////
////  MeetCreationFormWoutTapView.swift
////  Rangley
////
////  Created by Anthony Guzzardo on 9/16/25.
////
//
//import SwiftUI
//import CoreLocation
//import QuartzCore
//
//struct MeetCreationFormWoutTapView: View
//{
//    // for best guess initial locaiton
//    @State private var initialForSheet: LocationInfo?
//    let seedLocation: LocationInfo?
//    let onCreateMeet: (MeetInsertBody) async throws -> Void
//    let onClose: () -> Void
//    
//    
//    
//    // MARK: State
//    @State private var currentStep: CreationStep = .location
//    @State private var isAnimating = false
//    @State private var isSubmitting = false
//    @State private var submitError: String?
//    
//    // Location state
//    @State private var selectedLocation: LocationInfo?
//    @State private var showLocationPicker = false
//    @State private var displayLocationName: String = "No location selected"
//    @State private var displayLocationSubtitle: String = "Tap 'Select Location' to choose"
//    @State private var geocodingTask: Task<Void, Never>?
//    
//    // Meet details state
//    @State private var meetName = ""
//    @State private var startTime = Date().addingTimeInterval(3600) // 1 hour from now
//    @State private var endTime = Date().addingTimeInterval(7200)   // 2 hours from now
//    @State private var descriptionText = ""
//    @State private var meetCategoryID: Int16 = 1
//    @State private var maxCapacity: Int32 = 8
//    
//    @FocusState private var isNameFieldFocused: Bool
//    
//    // Success animation state
//    @State private var isExploding = false
//    @State private var showConfetti = false
//    
//    // MARK: Steps
//    enum CreationStep: CaseIterable
//    {
//        case location, name, startTime, endTime, review
//        
//        func title() -> String {
//            switch self {
//            case .location: return "Pick a location"
//            case .name: return "Name your meet"
//            case .startTime: return "When does it start?"
//            case .endTime: return "When does it end?"
//            case .review: return "Review & Create"
//            }
//        }
//    }
//    
//    private var totalSteps: Int { CreationStep.allCases.count }
//    
//    private func stepNumber(for step: CreationStep) -> Int
//    {
//        switch step {
//        case .location: return 1
//        case .name: return 2
//        case .startTime: return 3
//        case .endTime: return 4
//        case .review: return 5
//        }
//    }
//    
//    // MARK: Progress enablement
//    private var canProceed: Bool
//    {
//        switch currentStep {
//        case .location:
//            return selectedLocation != nil
//        case .name:
//            return !meetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
//        case .startTime:
//            return true
//        case .endTime:
//            return endTime > startTime
//        case .review:
//            return selectedLocation != nil &&
//                   !meetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
//                   endTime > startTime
//        }
//    }
//    
//    // MARK: View Body
//    var body: some View
//    {
//        VStack(spacing: 0)
//        {
//            header
//            progressBar
//            
//            // Show location card for all steps except location selection
//            if currentStep != .location && selectedLocation != nil {
//                locationCard
//            }
//            
//            // Current step content
//            contentForCurrentStep
//            
//            Spacer(minLength: 0)
//            
//            // Action button
//            Button(action: nextStep)
//            {
//                Text(buttonText)
//                    .font(.system(size: 16, weight: .bold))
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 16)
//                    .background(
//                        RoundedRectangle(cornerRadius: 12)
//                            .fill(canProceed ? AppPalette.Brand.neonPink : AppPalette.Brand.neonPink.opacity(0.5))
//                    )
//            }
//            .disabled(!canProceed || isSubmitting)
//            .padding(.horizontal, 24)
//            .padding(.bottom, 24)
//            .overlay(alignment: .bottom) {
//                if let submitError {
//                    Text(submitError)
//                        .font(.footnote)
//                        .foregroundColor(.red)
//                        .padding(.bottom, 4)
//                }
//            }
//        }
//        .background(
//            RoundedRectangle(cornerRadius: 24)
//                .fill(AppPalette.Brand.russianViolet)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 24)
//                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
//                )
//        )
//        .shadow(color: AppPalette.Brand.neonPink.opacity(0.3), radius: 20, x: 0, y: 10)
//        .scaleEffect(isAnimating ? 1 : 0.95)
//        .opacity(isAnimating ? 1 : 0)
//        .scaleEffect(isExploding ? 0.6 : 1.0)
//        .opacity(isExploding ? 0.0 : 1.0)
//        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExploding)
//        .onAppear {
//            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isAnimating = true }
//            if endTime <= startTime { endTime = startTime.addingTimeInterval(3600) }
//
//            // same UX text as MeetFormView
//            if selectedLocation == nil {
//                displayLocationName = "Loading location..."
//                displayLocationSubtitle = ""
//                if let seed = seedLocation {
//                    selectedLocation = seed
//                    loadNewLocationAddress(seed)   // ⬅️ exact same logic as MeetFormView
//                } else {
//                    // no seed? keep picker usable
//                    displayLocationName = "Choose a location"
//                    displayLocationSubtitle = "Tap 'Select Location' to choose"
//                }
//            } else if let sel = selectedLocation {
//                loadNewLocationAddress(sel)
//            }
//        }
//        .onChange(of: startTime, initial: false) { _, newStart in
//            if endTime <= newStart { endTime = newStart.addingTimeInterval(3600) }
//        }
//        .onTapGesture { isNameFieldFocused = false }
//        .onDisappear { geocodingTask?.cancel() }
//        .sheet(isPresented: $showLocationPicker) {
//            LocationPickerSheet(
//                initial: selectedLocation ?? seedLocation ?? defaultLocationInfo(),
//                onPick: { picked in
//                    selectedLocation = picked
//                    displayLocationName = "Loading new location..."
//                    displayLocationSubtitle = ""
//                    loadNewLocationAddress(picked)
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showLocationPicker = false }
//                },
//                onCancel: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showLocationPicker = false } }
//            )
//        }
//        .overlay {
//            if showConfetti {
//                ConfettiBurst(color: UIColor(AppPalette.Brand.neonPink), duration: 1.0, intensity: 1.0)
//                    .allowsHitTesting(false)
//                    .transition(.opacity)
//            }
//        }
//        .overlay {
//            if isSubmitting {
//                Color.black.opacity(0.4)
//                    .ignoresSafeArea()
//                ProgressView("Creating meet...")
//                    .padding(20)
//                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
//            }
//        }
//    }
//    
//    // MARK: Button text
//    private var buttonText: String
//    {
//        switch currentStep {
//        case .location:
//            return selectedLocation != nil ? "Next" : "Select Location"
//        case .review:
//            return "Create Meet"
//        default:
//            return "Next"
//        }
//    }
//    
//    // MARK: Header & Progress
//    private var header: some View
//    {
//        VStack(spacing: 16) {
//            HStack {
//                Button(action: previousStep) {
//                    HStack(spacing: 4) {
//                        Image(systemName: "chevron.left")
//                            .font(.system(size: 16, weight: .medium))
//                        Text(currentStep == .location ? "Cancel" : "Back")
//                            .font(.system(size: 16, weight: .medium))
//                    }
//                    .foregroundColor(AppPalette.Brand.neonPink)
//                }
//                
//                Spacer()
//                
//                Text("Step \(stepNumber(for: currentStep)) of \(totalSteps)")
//                    .font(.system(size: 14, weight: .medium))
//                    .foregroundColor(AppPalette.Text.secondary)
//            }
//            .padding(.horizontal, 24)
//            .padding(.top, 20)
//        }
//        .padding(.bottom, 12)
//    }
//    
//    private var progressBar: some View
//    {
//        GeometryReader { geometry in
//            ZStack(alignment: .leading) {
//                RoundedRectangle(cornerRadius: 2)
//                    .fill(AppPalette.Surface.fieldFill)
//                    .frame(height: 4)
//                
//                RoundedRectangle(cornerRadius: 2)
//                    .fill(AppPalette.Brand.neonPink)
//                    .frame(
//                        width: geometry.size.width * (Double(stepNumber(for: currentStep)) / Double(totalSteps)),
//                        height: 4
//                    )
//                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentStep)
//            }
//        }
//        .frame(height: 4)
//        .padding(.horizontal, 24)
//        .padding(.bottom, 24)
//    }
//    
//    // MARK: Location Card
//    private var locationCard: some View
//    {
//        VStack(alignment: .leading, spacing: 8)
//        {
//            Label {
//                VStack(alignment: .leading, spacing: 4)
//                {
//                    Text(displayLocationName)
//                        .font(.system(size: 14, weight: .medium))
//                        .foregroundColor(AppPalette.Text.primary)
//                    
//                    Text(displayLocationSubtitle)
//                        .font(.system(size: 12))
//                        .foregroundColor(AppPalette.Text.secondary)
//                }
//            } icon: {
//                Image(systemName: "location.fill")
//                    .foregroundColor(AppPalette.Brand.neonPink)
//                    .font(.system(size: 16))
//            }
//            .padding(12)
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(AppPalette.Surface.fieldFill)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12)
//                            .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
//                    )
//            )
//            
//            Button {
//                showLocationPicker = true
//            } label: {
//                HStack(spacing: 6) {
//                    Image(systemName: "mappin.and.ellipse")
//                    Text("Change Location")
//                }
//                .font(.system(size: 14, weight: .semibold))
//                .foregroundColor(AppPalette.Brand.neonPink)
//                .padding(.vertical, 8)
//                .padding(.horizontal, 12)
//                .background(
//                    RoundedRectangle(cornerRadius: 10)
//                        .stroke(AppPalette.Brand.neonPink.opacity(0.6), lineWidth: 1)
//                )
//            }
//        }
//        .padding(.horizontal, 24)
//        .padding(.bottom, 24)
//    }
//    
//    // MARK: Step Content
//    private var contentForCurrentStep: some View
//    {
//        VStack(spacing: 24) {
//            Text(currentStep.title())
//                .font(.system(size: 24, weight: .bold))
//                .foregroundColor(AppPalette.Text.primary)
//                .frame(maxWidth: .infinity, alignment: .leading)
//                .padding(.horizontal, 24)
//            
//            Group
//            {
//                switch currentStep
//                {
//                case .location:
//                    VStack(spacing: 24)
//                    {
//                        // Location display
//                        if selectedLocation != nil {
//                            VStack(alignment: .leading, spacing: 8)
//                            {
//                                Label {
//                                    VStack(alignment: .leading, spacing: 4)
//                                    {
//                                        Text(displayLocationName)
//                                            .font(.system(size: 15, weight: .semibold))
//                                            .foregroundColor(AppPalette.Text.primary)
//                                        
//                                        Text(displayLocationSubtitle)
//                                            .font(.system(size: 13))
//                                            .foregroundColor(AppPalette.Text.secondary)
//                                    }
//                                } icon: {
//                                    Image(systemName: "location.fill")
//                                        .foregroundColor(AppPalette.Brand.neonPink)
//                                        .font(.system(size: 18))
//                                }
//                                .padding(16)
//                                .frame(maxWidth: .infinity, alignment: .leading)
//                                .background(
//                                    RoundedRectangle(cornerRadius: 12)
//                                        .fill(AppPalette.Surface.fieldFill)
//                                        .overlay(
//                                            RoundedRectangle(cornerRadius: 12)
//                                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
//                                        )
//                                )
//                            }
//                        } else {
//                            // Empty state
//                            VStack(spacing: 16) {
//                                Image(systemName: "location.circle")
//                                    .font(.system(size: 48))
//                                    .foregroundColor(AppPalette.Brand.neonPink.opacity(0.6))
//                                
//                                Text("Choose where your meet will happen")
//                                    .font(.system(size: 16))
//                                    .foregroundColor(AppPalette.Text.secondary)
//                                    .multilineTextAlignment(.center)
//                            }
//                            .padding(32)
//                            .frame(maxWidth: .infinity)
//                            .background(
//                                RoundedRectangle(cornerRadius: 12)
//                                    .fill(AppPalette.Surface.fieldFill.opacity(0.5))
//                                    .overlay(
//                                        RoundedRectangle(cornerRadius: 12)
//                                            .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
//                                    )
//                            )
//                        }
//                        
//                        // Select/Change location button
//                        Button {
//                            showLocationPicker = true
//                        } label: {
//                            HStack(spacing: 8) {
//                                Image(systemName: selectedLocation != nil ? "mappin.and.ellipse" : "map.fill")
//                                Text(selectedLocation != nil ? "Change Location" : "Select Location")
//                            }
//                            .font(.system(size: 16, weight: .semibold))
//                            .foregroundColor(.white)
//                            .frame(maxWidth: .infinity)
//                            .padding(.vertical, 14)
//                            .background(
//                                RoundedRectangle(cornerRadius: 12)
//                                    .fill(AppPalette.Brand.neonPink)
//                            )
//                        }
//                    }
//                    .padding(.horizontal, 24)
//                    
//                case .name:
//                    VStack(alignment: .leading, spacing: 8)
//                    {
//                        TextField("", text: $meetName, prompt: Text("Enter meet name").foregroundColor(AppPalette.Text.tertiary))
//                            .font(.system(size: 18))
//                            .foregroundColor(AppPalette.Text.primary)
//                            .focused($isNameFieldFocused)
//                            .padding(16)
//                            .background(
//                                RoundedRectangle(cornerRadius: 12)
//                                    .fill(AppPalette.Surface.fieldFill)
//                                    .overlay(
//                                        RoundedRectangle(cornerRadius: 12)
//                                            .stroke(
//                                                isNameFieldFocused ? AppPalette.Surface.focusStroke : AppPalette.Surface.fieldStroke,
//                                                lineWidth: isNameFieldFocused ? 2 : 1
//                                            )
//                                    )
//                            )
//                            .onAppear {
//                                if currentStep == .name {
//                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                                        isNameFieldFocused = true
//                                    }
//                                }
//                            }
//                        
//                        Text("\(meetName.count)/50")
//                            .font(.footnote)
//                            .foregroundColor(AppPalette.Text.tertiary)
//                            .frame(maxWidth: .infinity, alignment: .trailing)
//                    }
//                    .padding(.horizontal, 24)
//                    
//                case .startTime:
//                    VStack(spacing: 16)
//                    {
//                        DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
//                            .datePickerStyle(.wheel)
//                            .labelsHidden()
//                            .tint(AppPalette.Brand.neonPink)
//                            .frame(height: 200)
//                            .padding(.horizontal, 8)
//                            .background(
//                                RoundedRectangle(cornerRadius: 12)
//                                    .fill(AppPalette.Surface.fieldFill)
//                                    .overlay(
//                                        RoundedRectangle(cornerRadius: 12)
//                                            .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
//                                    )
//                            )
//                    }
//                    .padding(.horizontal, 24)
//                    
//                case .endTime:
//                    VStack(spacing: 16)
//                    {
//                        DatePicker("", selection: $endTime, in: startTime..., displayedComponents: [.date, .hourAndMinute])
//                            .datePickerStyle(.wheel)
//                            .labelsHidden()
//                            .tint(AppPalette.Brand.neonPink)
//                            .frame(height: 200)
//                            .padding(.horizontal, 8)
//                            .background(
//                                RoundedRectangle(cornerRadius: 12)
//                                    .fill(AppPalette.Surface.fieldFill)
//                                    .overlay(
//                                        RoundedRectangle(cornerRadius: 12)
//                                            .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
//                                    )
//                            )
//                        
//                        if endTime <= startTime {
//                            Text("End time must be after start time")
//                                .font(.system(size: 12))
//                                .foregroundColor(AppPalette.Brand.neonPink)
//                        }
//                    }
//                    .padding(.horizontal, 24)
//                    
//                case .review:
//                    VStack(spacing: 20)
//                    {
//                        VStack(alignment: .leading, spacing: 16)
//                        {
//                            DetailRow(label: "Meet Name", value: meetName)
//                            DetailRow(label: "Start", value: formatDate(startTime))
//                            DetailRow(label: "End", value: formatDate(endTime))
//                            DetailRow(label: "Duration", value: formatDuration(from: startTime, to: endTime))
//                            if selectedLocation != nil {
//                                DetailRow(label: "Location", value: displayLocationName)
//                            }
//                        }
//                        .padding(20)
//                        .background(
//                            RoundedRectangle(cornerRadius: 12)
//                                .fill(AppPalette.Surface.fieldFill)
//                                .overlay(
//                                    RoundedRectangle(cornerRadius: 12)
//                                        .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
//                                )
//                        )
//                    }
//                    .padding(.horizontal, 24)
//                }
//            }
//            .transition(.asymmetric(
//                insertion: .move(edge: .trailing).combined(with: .opacity),
//                removal: .move(edge: .leading).combined(with: .opacity)
//            ))
//        }
//    }
//    
//    // MARK: Actions
//    private func nextStep()
//    {
//        if currentStep == .location && selectedLocation == nil {
//            showLocationPicker = true
//            return
//        }
//        
//        withAnimation(.spring(response: 0.3, dampingFraction: 0.8))
//        {
//            switch currentStep {
//            case .location:
//                currentStep = .name
//            case .name:
//                isNameFieldFocused = false
//                currentStep = .startTime
//            case .startTime:
//                currentStep = .endTime
//            case .endTime:
//                currentStep = .review
//            case .review:
//                submit()
//            }
//        }
//    }
//    
//    private func previousStep()
//    {
//        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//            switch currentStep {
//            case .location:
//                onClose()
//            case .name:
//                currentStep = .location
//            case .startTime:
//                currentStep = .name
//            case .endTime:
//                currentStep = .startTime
//            case .review:
//                currentStep = .endTime
//            }
//        }
//    }
//    
//    private func submit()
//    {
//        guard !isSubmitting else { return }
//        guard let location = selectedLocation else { return }
//        
//        let trimmed = meetName.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !trimmed.isEmpty else {
//            submitError = "Meet name is required"
//            return
//        }
//        
//        isSubmitting = true
//        submitError = nil
//        
//        Task {
//            do {
//                let body = MeetInsertBody(
//                    latitude: location.Coordinate.latitude,
//                    longitude: location.Coordinate.longitude,
//                    region_latitude: location.RegionCoordinate.latitude,
//                    region_longitude: location.RegionCoordinate.longitude,
//                    region_radius: location.RegionRadius,
//                    name: String(trimmed.prefix(50)),
//                    dttm_start_utc: startTime,
//                    dttm_end_utc: endTime,
//                    description: descriptionText.isEmpty ? nil : descriptionText,
//                    meet_category_id: meetCategoryID,
//                    max_capacity: maxCapacity
//                )
//                
//                try await onCreateMeet(body)
//                
//                await MainActor.run {
//                    explodeThenDismiss()
//                }
//            } catch {
//                await MainActor.run {
//                    submitError = error.localizedDescription
//                    isSubmitting = false
//                }
//            }
//        }
//    }
//    
//    private func explodeThenDismiss()
//    {
//        guard !isExploding else { return }
//        isExploding = true
//        isSubmitting = false
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
//            showConfetti = true
//            UINotificationFeedbackGenerator().notificationOccurred(.success)
//        }
//        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
//            showConfetti = false
//            onClose()
//        }
//    }
//    
//    // MARK: Location Helpers
//    private func defaultLocationInfo() -> LocationInfo {
//        if let initialForSheet { return initialForSheet }  // prefer real user location if we have it
//        // Fallback (rare): SF as a last resort so UI still renders
//        return LocationInfo(
//            Coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
//            RegionCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
//            RegionRadius: 1000.0,
//            Name: "San Francisco",
//            ThoroughFare: nil, SubThoroughFare: nil,
//            Locality: "San Francisco", SubLocality: nil,
//            AdministrativeArea: "CA", SubAdministrativeArea: nil,
//            PostalCode: nil, Country: "United States", IsoCountryCode: "US",
//            TimeZone: nil, InlandWater: nil, Ocean: nil
//        )
//    }
//    
//    // MARK: Helpers
//    private struct DetailRow: View
//    {
//        let label: String
//        let value: String
//        var body: some View {
//            HStack {
//                Text(label)
//                    .font(.system(size: 14))
//                    .foregroundColor(AppPalette.Text.secondary)
//                Spacer()
//                Text(value)
//                    .font(.system(size: 14, weight: .medium))
//                    .foregroundColor(AppPalette.Text.primary)
//                    .multilineTextAlignment(.trailing)
//            }
//        }
//    }
//    
//    private static let reviewFormatter: DateFormatter = {
//        let f = DateFormatter()
//        f.dateStyle = .medium
//        f.timeStyle = .short
//        return f
//    }()
//    
//    private func formatDate(_ date: Date) -> String {
//        Self.reviewFormatter.string(from: date)
//    }
//    
//    private func formatDuration(from start: Date, to end: Date) -> String
//    {
//        let interval = max(0, end.timeIntervalSince(start))
//        let hours = Int(interval) / 3600
//        let minutes = (Int(interval) % 3600) / 60
//        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
//        if hours > 0 { return "\(hours) hour\(hours == 1 ? "" : "s")" }
//        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
//    }
//}
