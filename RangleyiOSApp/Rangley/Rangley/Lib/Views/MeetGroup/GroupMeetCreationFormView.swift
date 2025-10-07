//
//  GroupMeetCreationFormView.swift
//  Rangley
//
//  Dedicated form for creating meets from group context
//

import SwiftUI
import CoreLocation

struct GroupMeetCreationFormView: View
{
    let group: MeetGroup
    let members: [GroupMember]
    let baseURL: URL
    let token: String
    let onSuccess: () async -> Void
    let onDismiss: () -> Void
    
    @StateObject private var vm: GroupMeetFormModel
    @State private var currentStep: FormStep = .location
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var showLocationPicker = false
    @State private var isAnimating = false
    
    @FocusState private var isNameFieldFocused: Bool
    
    init(
        group: MeetGroup,
        members: [GroupMember],
        baseURL: URL,
        token: String,
        onSuccess: @escaping () async -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.group = group
        self.members = members
        self.baseURL = baseURL
        self.token = token
        self.onSuccess = onSuccess
        self.onDismiss = onDismiss
        
        // Initialize with default max capacity = group size
        _vm = StateObject(wrappedValue: GroupMeetFormModel(defaultMaxCapacity: Int32(members.count)))
    }
    
    enum FormStep: CaseIterable
    {
        case location, name, details, startTime, endTime, review
        
        var title: String {
            switch self {
            case .location: return "Choose Location"
            case .name: return "Name your meet"
            case .details: return "Meet Details (optional)"
            case .startTime: return "When does it start?"
            case .endTime: return "When does it end?"
            case .review: return "Review & Create"
            }
        }
        
        var stepNumber: Int {
            FormStep.allCases.firstIndex(of: self)! + 1
        }
    }
    
    private var totalSteps: Int { FormStep.allCases.count }
    
    private var canProceed: Bool
    {
        switch currentStep {
        case .location:
            return vm.hasValidLocation
        case .name:
            return !vm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .details:
            return true // Optional step
        case .startTime:
            return true
        case .endTime:
            return vm.end > vm.start
        case .review:
            return vm.validate() == nil
        }
    }
    
    var body: some View
    {
        NavigationView {
            ZStack {
                AppPalette.Brand.formBlack.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress bar
                    progressBar
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Group header
                            groupHeader
                            
                            // Location card (if selected)
                            if currentStep != .location {
                                locationCard
                            }
                            
                            // Step title
                            Text(currentStep.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AppPalette.Text.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                            
                            // Step content
                            stepContent
                        }
                        .padding(.bottom, 100)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    actionButtons
                }
            }
            .navigationTitle("Create Meet with \(group.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .foregroundStyle(AppPalette.Text.secondary)
                }
            }
            .fullScreenCover(isPresented: $showLocationPicker) {
                LocationPickerSheet(
                    initial: vm.currentLocationInfo,
                    onPick: { picked in
                        vm.applyLocation(picked)
                        showLocationPicker = false
                        
                        // Auto-advance to next step after picking location
                        if currentStep == .location {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                nextStep()
                            }
                        }
                    },
                    onCancel: {
                        showLocationPicker = false
                        // If we're on location step and cancel, dismiss the whole form
                        if currentStep == .location {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                onDismiss()
                            }
                        }
                    }
                )
            }
        }
        .scaleEffect(isAnimating ? 1 : 0.95)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isAnimating = true
            }
            // Auto-show location picker on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showLocationPicker = true
            }
        }
        .onChange(of: vm.start) { _, newStart in
            if vm.end <= newStart {
                vm.end = newStart.addingTimeInterval(3600)
            }
        }
    }
    
    // MARK: - Components
    
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
        .padding(.top, 12)
        .padding(.bottom, 24)
    }
    
    private var groupHeader: some View
    {
        VStack(spacing: 12) {
            Image(systemName: group.image_reference)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(iconColor(for: group.image_reference))
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(AppPalette.Brand.neonPink.opacity(0.2))
                        .overlay(
                            Circle().stroke(AppPalette.Brand.neonPink.opacity(0.4), lineWidth: 1)
                        )
                )
            
            Text("Creating meet for")
                .font(.system(size: 12))
                .foregroundStyle(AppPalette.Text.secondary)
            
            Text(group.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("\(members.count) member\(members.count == 1 ? "" : "s") will be invited")
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.Text.tertiary)
        }
        .padding(.horizontal, 24)
    }
    
    private var locationCard: some View
    {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.locationDisplayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppPalette.Text.primary)
                    
                    if !vm.locationSubtitle.isEmpty {
                        Text(vm.locationSubtitle)
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
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private var stepContent: some View
    {
        Group {
            switch currentStep {
            case .location:
                locationStepContent
            case .name:
                nameStepContent
            case .details:
                detailsStepContent
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
    
    private var locationStepContent: some View
    {
        VStack(spacing: 12) {
            Text("Tap below to search for a location")
                .font(.system(size: 16))
                .foregroundColor(AppPalette.Text.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showLocationPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 18))
                    Text("Open Location Picker")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppPalette.Brand.neonPink)
                )
            }
            .buttonStyle(.plain)
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
    
    private var detailsStepContent: some View
    {
        VStack(alignment: .leading, spacing: 20) {
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppPalette.Text.secondary)
                
                ZStack(alignment: .topLeading) {
                    if vm.descriptionText.isEmpty {
                        Text("What's this meet about?")
                            .font(.system(size: 16))
                            .foregroundColor(AppPalette.Text.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    
                    TextEditor(text: $vm.descriptionText)
                        .font(.system(size: 16))
                        .foregroundColor(AppPalette.Text.primary)
                        .frame(height: 80)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppPalette.Surface.fieldFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                        )
                )
                
                Text("\(vm.descriptionText.count)/50")
                    .font(.footnote)
                    .foregroundColor(AppPalette.Text.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppPalette.Text.secondary)
                
                Menu {
                    ForEach(MeetCategory.allCases, id: \.rawValue) { category in
                        Button {
                            vm.meetCategoryID = category.rawValue
                        } label: {
                            HStack {
                                Text(category.displayName)
                                if vm.meetCategoryID == category.rawValue {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(MeetCategory(rawValue: vm.meetCategoryID)?.displayName ?? "Activity")
                            .font(.system(size: 16))
                            .foregroundColor(AppPalette.Text.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppPalette.Text.tertiary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppPalette.Surface.fieldFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                            )
                    )
                }
            }
            
            // Max Capacity
            VStack(alignment: .leading, spacing: 8) {
                Text("Max Capacity")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppPalette.Text.secondary)
                
                HStack {
                    Text("\(vm.maxCapacity) people")
                        .font(.system(size: 16))
                        .foregroundColor(AppPalette.Text.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button {
                            if vm.maxCapacity > 2 {
                                vm.maxCapacity -= 1
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(vm.maxCapacity > 2 ? AppPalette.Brand.neonPink : AppPalette.Text.tertiary)
                        }
                        .disabled(vm.maxCapacity <= 2)
                        
                        Button {
                            if vm.maxCapacity < 50 {
                                vm.maxCapacity += 1
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(vm.maxCapacity < 50 ? AppPalette.Brand.neonPink : AppPalette.Text.tertiary)
                        }
                        .disabled(vm.maxCapacity >= 50)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppPalette.Surface.fieldFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var startTimeStepContent: some View
    {
        ThemedDatePicker(selection: $vm.start)
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
            .foregroundColor(AppPalette.Text.primary)
            .padding(.horizontal, 24)
    }
    
    private var endTimeStepContent: some View
    {
        VStack(spacing: 16) {
            ThemedDatePicker(
                selection: $vm.end,
                minimumDate: vm.start,
                maximumDate: nil
            )
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
        .foregroundColor(AppPalette.Text.primary)
        .padding(.horizontal, 24)
    }
    
    private var reviewStepContent: some View
    {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                DetailRow(label: "Group", value: group.name)
                DetailRow(label: "Location", value: vm.locationDisplayName)
                DetailRow(label: "Meet Name", value: vm.name)
                
                if !vm.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DetailRow(label: "Description", value: vm.descriptionText)
                }
                
                DetailRow(label: "Category", value: MeetCategory(rawValue: vm.meetCategoryID)?.displayName ?? "Activity")
                DetailRow(label: "Max Capacity", value: "\(vm.maxCapacity) people")
                DetailRow(label: "Start", value: formatDate(vm.start))
                DetailRow(label: "End", value: formatDate(vm.end))
                DetailRow(label: "Duration", value: formatDuration(from: vm.start, to: vm.end))
                DetailRow(label: "Members", value: "\(members.count) invited")
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
            
            if let error = submitError {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var actionButtons: some View
    {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if currentStep != .location {
                    Button(action: previousStep) {
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppPalette.Text.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                            )
                    }
                    .disabled(isSubmitting)
                }
                
                Button(action: nextStep) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(buttonTitle)
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(canProceed && !isSubmitting ? AppPalette.Brand.neonPink : AppPalette.Brand.neonPink.opacity(0.5))
                    )
                }
                .disabled(!canProceed || isSubmitting)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
    
    private var buttonTitle: String
    {
        switch currentStep {
        case .details:
            return vm.hasChangedOptionalDetails ? "Next" : "Skip"
        case .review:
            return "Create Meet"
        default:
            return "Next"
        }
    }
    
    // MARK: - Actions
    
    private func nextStep()
    {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if currentStep == .name {
                isNameFieldFocused = false
            }
            
            if currentStep == .review {
                submit()
            } else if let currentIndex = FormStep.allCases.firstIndex(of: currentStep),
                      currentIndex < FormStep.allCases.count - 1 {
                currentStep = FormStep.allCases[currentIndex + 1]
            }
        }
    }
    
    private func previousStep()
    {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if let currentIndex = FormStep.allCases.firstIndex(of: currentStep),
               currentIndex > 0 {
                currentStep = FormStep.allCases[currentIndex - 1]
            }
        }
    }
    
    private func submit()
    {
        guard !isSubmitting else { return }
        submitError = vm.validate()
        guard submitError == nil else { return }
        
        isSubmitting = true
        Task {
            do {
                // Create body with group members as invites
                let invitedUserUUIDs = members.map { $0.user_uuid }
                
                guard let body = vm.makeCreateBodyWithInvites(invitedUserUUIDs: invitedUserUUIDs) else {
                    await MainActor.run {
                        isSubmitting = false
                        submitError = "Missing required information"
                    }
                    return
                }
                
                let response = try await AuthAPI.createMeetWithInvites(
                    baseURL: baseURL,
                    token: token,
                    body: body
                )
                
                // Check validation failure
                if response.validation_failed {
                    await MainActor.run {
                        isSubmitting = false
                        submitError = response.validation_message ?? "Content violates community guidelines"
                    }
                    return
                }
                
                // Check if meet was actually created (num_inserted should be > 0)
                if response.num_inserted == 0 || response.new_meet_id_uuid == nil {
                    await MainActor.run {
                        isSubmitting = false
                        submitError = "Failed to create meet. Please try again."
                    }
                    return
                }
                
                // Success - meet created
                await onSuccess()
                await MainActor.run {
                    isSubmitting = false
                    onDismiss()
                }
                
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    submitError = parseErrorMessage(error)
                }
            }
        }
    }
    
    private func parseErrorMessage(_ error: Error) -> String
    {
        let errorString = error.localizedDescription.lowercased()
        
        if errorString.contains("content not allowed") ||
           errorString.contains("violates") ||
           errorString.contains("inappropriate") {
            return "Content not allowed - please review your meet details"
        }
        
        if errorString.contains("network") ||
           errorString.contains("connection") {
            return "Network error. Please check your connection."
        }
        
        return "Something went wrong. Please try again."
    }
    
    // MARK: - Helpers
    
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
    
    private static let reviewFormatter: DateFormatter =
    {
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


// MARK: - View Model
final class GroupMeetFormModel: ObservableObject
{
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var regionLatitude: Double?
    @Published var regionLongitude: Double?
    @Published var regionRadius: Double?
    @Published var locationDisplayName = "Choose a location"
    @Published var locationSubtitle = ""
    
    @Published var name = ""
    @Published var start = Date().addingTimeInterval(3600)
    @Published var end = Date().addingTimeInterval(7200)
    @Published var descriptionText: String
    @Published var meetCategoryID: Int16
    @Published var maxCapacity: Int32
    
    // Store initial defaults
    private let initialDescriptionText: String
    private let initialMeetCategoryID: Int16
    private let initialMaxCapacity: Int32
    
    init(
        descriptionText: String = "",
        meetCategoryID: Int16 = 1,
        defaultMaxCapacity: Int32 = 8
    ) {
        self.descriptionText = descriptionText
        self.meetCategoryID = meetCategoryID
        self.maxCapacity = defaultMaxCapacity
        
        self.initialDescriptionText = descriptionText
        self.initialMeetCategoryID = meetCategoryID
        self.initialMaxCapacity = defaultMaxCapacity
    }
    
    var hasValidLocation: Bool {
        latitude != nil && longitude != nil &&
        regionLatitude != nil && regionLongitude != nil &&
        regionRadius != nil
    }
    
    var hasChangedOptionalDetails: Bool {
        let hasDescription = !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let changedCategory = meetCategoryID != initialMeetCategoryID
        let changedCapacity = maxCapacity != initialMaxCapacity
        
        return hasDescription || changedCategory || changedCapacity
    }
    
    var currentLocationInfo: LocationInfo {
        LocationInfo(
            Coordinate: .init(latitude ?? 37.7749, longitude ?? -122.4194),
            RegionCoordinate: .init(regionLatitude ?? 37.7749, regionLongitude ?? -122.4194),
            RegionRadius: regionRadius ?? 1000.0,
            Name: "Current Location",
            ThoroughFare: nil, SubThoroughFare: nil, Locality: nil, SubLocality: nil,
            AdministrativeArea: nil, SubAdministrativeArea: nil, PostalCode: nil,
            Country: nil, IsoCountryCode: nil, TimeZone: nil, InlandWater: nil, Ocean: nil
        )
    }
    
    func applyLocation(_ location: LocationInfo) {
        latitude = location.Coordinate.latitude
        longitude = location.Coordinate.longitude
        regionLatitude = location.RegionCoordinate.latitude
        regionLongitude = location.RegionCoordinate.longitude
        regionRadius = location.RegionRadius
        
        // Update display names
        if let name = location.Name, !name.isEmpty {
            locationDisplayName = name
        } else {
            locationDisplayName = "Selected Location"
        }
        
        // Build subtitle from location components
        var components: [String] = []
        if let locality = location.Locality {
            components.append(locality)
        }
        if let state = location.AdministrativeArea {
            components.append(state)
        }
        locationSubtitle = components.joined(separator: ", ")
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
