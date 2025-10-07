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
    case createWithGroup(group: MeetGroup, members: [GroupMember])
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
    let preselectedGroupMembers: [ViewUsersModel]?
    let skipInviteStep: Bool
    
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
    @State private var showCreateGroupForm = false
    @State private var createdGroupId: Int64?
    @State private var existingMeetGroups: [MeetGroup] = []
    @State private var selectedGroupId: Int64?

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
        
        // Handle group mode
        if case .createWithGroup(_, let members) = entryMode {
            self.skipInviteStep = true
            self.preselectedGroupMembers = members.map { member in
                ViewUsersModel(
                    user_uuid: member.user_uuid,
                    username: member.username,
                    display_name: member.display_name,
                    matched_by: [],
                    can_invite: true
                )
            }
        } else {
            self.skipInviteStep = false
            self.preselectedGroupMembers = nil
        }
        
        // Initialize VM - ONLY with location if tapOnMap mode
        let initialLocation: LocationInfo? = {
            if case .tapOnMap(let loc) = entryMode {
                return loc
            }
            return nil
        }()
        
        _vm = StateObject(wrappedValue: MeetFormUnifiedModel(location: initialLocation))
        
        // Set initial step based on whether we have a location
        if case .tapOnMap = entryMode {
            _currentStep = State(initialValue: .name)
        } else {
            _currentStep = State(initialValue: .location)
        }
    }
    
    // MARK: Steps
    enum UnifiedStep: CaseIterable
    {
        case location, name, details, startTime, endTime, inviteFriends, review
        
        var title: String {
            switch self {
            case .location: return "Choose Location"
            case .name: return "Name your meet"
            case .details: return "Meet Details (optional)"
            case .startTime: return "When does it start?"
            case .endTime: return "When does it end?"
            case .inviteFriends: return "Invite Friends"
            case .review: return "Review & Create"
            }
        }
    }
    
    // Get active steps based on entry mode
    private var activeSteps: [UnifiedStep]
    {
        var steps = UnifiedStep.allCases
        
        // Remove location step for tapOnMap
        if case .tapOnMap = entryMode {
            steps.removeAll { $0 == .location }
        }
        
        // Remove invite step for group meets
        if skipInviteStep {
            steps.removeAll { $0 == .inviteFriends }
        }
        
        return steps
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
        case .details:
            return true  // Optional step - always can proceed
        case .startTime:
            return true
        case .endTime:
            return vm.end > vm.start
        case .inviteFriends:
            return true
        case .review:
            return vm.validate() == nil
        }
    }
    
    // MARK: Body
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
                            // Location card (if not on location step)
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
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onClose()
                    }
                    .foregroundStyle(AppPalette.Text.secondary)
                }
            }
            .fullScreenCover(isPresented: $showLocationPicker) {
                LocationPickerSheet(
                    initial: vm.currentLocationInfo,
                    onPick: { picked in
                        vm.applyLocation(picked)
                        
                        if let name = picked.Name, !name.isEmpty {
                            displayLocationName = name
                        } else {
                            displayLocationName = "Selected Location"
                        }
                        
                        loadLocationAddress(picked)
                        showLocationPicker = false
                        
                        if currentStep == .location {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                nextStep()
                            }
                        }
                    },
                    onCancel: {
                        showLocationPicker = false
                        if currentStep == .location {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                onClose()
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showCreateGroupForm) {
                MeetGroupFormView(
                    baseURL: baseURL,
                    token: token,
                    preselectedUsers: invitedUsers,
                    onGroupCreated: { groupId in
                        createdGroupId = groupId
                        showCreateGroupForm = false
                        Task {
                            await loadExistingGroups()
                        }
                    },
                    onCancel: { showCreateGroupForm = false }
                )
            }
        }
        .scaleEffect(isAnimating ? 1 : 0.95)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            if let preselected = preselectedGroupMembers {
                invitedUsers = preselected
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isAnimating = true
            }
            setupInitialState()
            
            Task {
                await loadExistingGroups()
            }
            
            // Auto-show location picker for createButton flow on location step
            if case .createButton = entryMode, currentStep == .location {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showLocationPicker = true
                }
            }
        }
        .onChange(of: vm.start) { _, newStart in
            if vm.end <= newStart {
                vm.end = newStart.addingTimeInterval(3600)
            }
        }
        .onDisappear { geocodingTask?.cancel() }
    }
    
    // MARK: - Components
    
    private var navigationTitle: String {
        switch entryMode {
        case .tapOnMap:
            return "Create Meet"
        case .createButton:
            return "Create Meet"
        case .createWithGroup(let group, _):
            return "Create Meet with \(group.name)"
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
                        width: geometry.size.width * (Double(currentStepNumber) / Double(totalSteps)),
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
            
            // Change location button (only for createButton flow)
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
    
    private var inviteFriendsStepContent: some View
    {
        VStack(spacing: 16) {
            // Existing groups
            if !existingMeetGroups.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Groups")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.Text.secondary)
                        .padding(.horizontal, 24)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(existingMeetGroups, id: \.meet_group_id) { group in
                                GroupQuickSelectButton(
                                    group: group,
                                    isSelected: selectedGroupId == group.meet_group_id,
                                    onTap: {
                                        if selectedGroupId == group.meet_group_id {
                                            selectedGroupId = nil
                                            invitedUsers.removeAll()
                                        } else {
                                            selectedGroupId = group.meet_group_id
                                            invitedUsers.removeAll()
                                            Task { await loadGroupMembers(group) }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                
                Divider()
                    .background(AppPalette.Surface.fieldStroke)
                    .padding(.horizontal, 24)
            }
            
            // Invite friends UI
            InviteFriendsEmbedded(
                baseURL: baseURL,
                token: token,
                selectedUsers: $invitedUsers
            )
            .disabled(selectedGroupId != nil)
            .opacity(selectedGroupId != nil ? 0.5 : 1.0)
            
            // Save as group button
            if !invitedUsers.isEmpty && selectedGroupId == nil {
                Divider()
                    .background(AppPalette.Surface.fieldStroke)
                    .padding(.horizontal, 24)
                
                Button {
                    showCreateGroupForm = true
                } label: {
                    HStack(spacing: 8) {
                        if createdGroupId != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Group Created")
                                .font(.system(size: 14, weight: .semibold))
                        } else {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Create Group")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundStyle(
                        createdGroupId != nil
                            ? AppPalette.Brand.spearmintGreen
                            : AppPalette.Brand.neonPink
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                createdGroupId != nil
                                    ? AppPalette.Brand.spearmintGreen.opacity(0.6)
                                    : AppPalette.Brand.neonPink.opacity(0.6),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(createdGroupId != nil)
                .padding(.horizontal, 24)
            }
        }
    }
    
    private var reviewStepContent: some View
    {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                DetailRow(label: "Location", value: displayLocationName)
                DetailRow(label: "Meet Name", value: vm.name)
                
                if !vm.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DetailRow(label: "Description", value: vm.descriptionText)
                }
                
                DetailRow(label: "Category", value: MeetCategory(rawValue: vm.meetCategoryID)?.displayName ?? "Activity")
                DetailRow(label: "Max Capacity", value: "\(vm.maxCapacity) people")
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
                // Back button (only show if not on first step)
                if !isFirstStep {
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
                
                // Next/Create button
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
            // If any detail was changed from defaults, show "Next" instead of "Skip"
            let hasDescription = !vm.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let changedCategory = vm.meetCategoryID != 1  // Default is Activity (1)
            let changedCapacity = vm.maxCapacity != 8     // Default is 8
            
            return (hasDescription || changedCategory || changedCapacity) ? "Next" : "Skip"
        case .review:
            return "Create Meet"
        case .inviteFriends:
            return invitedUsers.isEmpty ? "Skip" : "Continue"
        default:
            return "Next"
        }
    }
    
    // MARK: - Navigation
    
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
            if let currentIndex = activeSteps.firstIndex(of: currentStep),
               currentIndex > 0 {
                currentStep = activeSteps[currentIndex - 1]
            }
        }
    }
    
    // MARK: - Submit
    
    private func submit()
    {
        guard !isSubmitting else { return }
        submitError = vm.validate()
        guard submitError == nil else { return }
        
        isSubmitting = true
        Task {
            do {
                if invitedUsers.isEmpty {
                    if let body = vm.makeCreateBody() {
                        try await onCreate(body)
                    } else {
                        await MainActor.run {
                            isSubmitting = false
                            submitError = "Missing required information"
                        }
                    }
                } else {
                    if let body = vm.makeCreateBodyWithInvites(invitedUserUUIDs: invitedUsers.map { $0.user_uuid }) {
                        try await onCreateWithInvites(body)
                    } else {
                        await MainActor.run {
                            isSubmitting = false
                            submitError = "Missing required information"
                        }
                    }
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
        case .createWithGroup:
            displayLocationName = "Choose a location"
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
                    }
                    return
                }
                
                let name = p.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                let street = p.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines)
                let city = p.locality?.trimmingCharacters(in: .whitespacesAndNewlines)
                let state = p.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines)
                
                await MainActor.run {
                    displayLocationName = name ?? street ?? "Selected Location"
                    displayLocationSubtitle = [city, state].compactMap { $0 }.joined(separator: ", ")
                }
            } catch {
                await MainActor.run {
                    displayLocationName = "Selected location"
                }
            }
        }
    }
    
    private func loadExistingGroups() async
    {
        do {
            let groups = try await AuthAPI.viewMeetGroups(baseURL: baseURL, token: token)
            await MainActor.run {
                existingMeetGroups = groups
            }
        } catch {
            print("Failed to load groups: \(error)")
        }
    }
    
    private func loadGroupMembers(_ group: MeetGroup) async
    {
        do {
            let members = try await AuthAPI.viewMeetGroupMembers(
                baseURL: baseURL,
                token: token,
                meetGroupId: group.meet_group_id
            )
            
            let memberUsers = members.map { member in
                ViewUsersModel(
                    user_uuid: member.user_uuid,
                    username: member.username,
                    display_name: member.display_name,
                    matched_by: [],
                    can_invite: true
                )
            }
            
            await MainActor.run {
                for user in memberUsers {
                    if !invitedUsers.contains(where: { $0.user_uuid == user.user_uuid }) {
                        invitedUsers.append(user)
                    }
                }
            }
        } catch {
            print("Failed to load group members: \(error)")
        }
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


// MARK: - Supporting Components
private struct GroupQuickSelectButton: View
{
    let group: MeetGroup
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: group.image_reference)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor(for: group.image_reference))
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(
                                isSelected
                                    ? AppPalette.Brand.spearmintGreen.opacity(0.2)
                                    : AppPalette.Brand.neonPink.opacity(0.2)
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected
                                    ? AppPalette.Brand.spearmintGreen
                                    : AppPalette.Brand.neonPink.opacity(0.4),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .clipShape(Circle())
                
                Text(group.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(
                        isSelected
                            ? AppPalette.Brand.spearmintGreen
                            : AppPalette.Text.primary
                    )
                    .lineLimit(1)
                    .frame(width: 70, height: 14)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meet Category Enum
enum MeetCategory: Int16, CaseIterable
{
    case activity = 1
    case sports = 2
    case outdoors = 3
    case social = 4
    case music = 5
    case food = 6
    case plannedTrip = 7
    case spontaneous = 8
    case custom = 9
    
    var displayName: String {
        switch self {
        case .activity: return "Activity"
        case .sports: return "Sports"
        case .outdoors: return "Outdoors"
        case .social: return "Social"
        case .music: return "Music"
        case .food: return "Food"
        case .plannedTrip: return "Planned Trip"
        case .spontaneous: return "Spontaneous"
        case .custom: return "Custom"
        }
    }
}

// MARK: - Unified View Model
final class MeetFormUnifiedModel: ObservableObject
{
    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var regionLatitude: Double?
    @Published var regionLongitude: Double?
    @Published var regionRadius: Double?
    
    @Published var name = ""
    @Published var start = Date().addingTimeInterval(3600)
    @Published var end = Date().addingTimeInterval(7200)
    @Published var descriptionText: String
    @Published var meetCategoryID: Int16
    @Published var maxCapacity: Int32
    
    // Store initial default values
    private let initialDescriptionText: String
    private let initialMeetCategoryID: Int16
    private let initialMaxCapacity: Int32
    
    init(
        location: LocationInfo? = nil,
        descriptionText: String = "",
        meetCategoryID: Int16 = 1,
        maxCapacity: Int32 = 8
    ) {
        self.descriptionText = descriptionText
        self.meetCategoryID = meetCategoryID
        self.maxCapacity = maxCapacity
        
        self.initialDescriptionText = descriptionText
        self.initialMeetCategoryID = meetCategoryID
        self.initialMaxCapacity = maxCapacity
        
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
            Coordinate: .init(latitude ?? 37.7749, longitude ?? -122.4194),
            RegionCoordinate: .init(regionLatitude ?? 37.7749, regionLongitude ?? -122.4194),
            RegionRadius: regionRadius ?? 1000.0,
            Name: "Current Location",
            ThoroughFare: nil, SubThoroughFare: nil, Locality: nil, SubLocality: nil,
            AdministrativeArea: nil, SubAdministrativeArea: nil, PostalCode: nil,
            Country: nil, IsoCountryCode: nil, TimeZone: nil, InlandWater: nil, Ocean: nil
        )
    }
    
    // Check if any optional details have been changed from defaults
    var hasChangedOptionalDetails: Bool {
        let hasDescription = !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let changedCategory = meetCategoryID != initialMeetCategoryID
        let changedCapacity = maxCapacity != initialMaxCapacity
        
        return hasDescription || changedCategory || changedCapacity
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
