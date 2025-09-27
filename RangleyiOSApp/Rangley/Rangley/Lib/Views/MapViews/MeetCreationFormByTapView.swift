//
//  MeetCreationFormByTapView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

// =========================================================
// =========================================================
// =========================================================
// MARK: - IGNORE THE BELOW TODOs FOR NOW

// TODO: - Closing the screens is a little too quick should be smoother
// TODO: - The search friends looks absolutely fantastic, maybe make the icons a little smaller tho


// MARK: - IGNORE THE ABOVE TODOs FOR NOW
// =========================================================
// =========================================================
// =========================================================

import UIKit
import SwiftUI
import CoreLocation
import QuartzCore // for confetti supports the CA_* stuff

struct MeetCreationFormByTapView: View
{
    //================================================
    // MARK: - PARAMS
    //================================================
    
    let baseURL: URL
    let token: String
    let locationInfo: LocationInfo
    let onConfirm: (String, Date, Date, [ViewUsersModel]) -> Void // Updated to include invited users
    let onBack: () -> Void
    
    //================================================
    // MARK: - END PARAMS
    //================================================
    
    // API dependencies for user search

    
    init(
        locationInfo: LocationInfo,
        baseURL: URL,
        token: String,
        onConfirm: @escaping (String, Date, Date, [ViewUsersModel]) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.locationInfo = locationInfo
        self.baseURL = baseURL
        self.token = token
        self.onConfirm = onConfirm
        self.onBack = onBack
    }

    @State private var meetName = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600) // Default 1 hour later
    @State private var invitedUsers: [ViewUsersModel] = [] // New state for invited users

    @State private var isAnimating = false
    @State private var currentFieldStep: FieldStep = .name

    @FocusState private var isNameFieldFocused: Bool

    enum FieldStep: CaseIterable
    {
        case name, startTime, endTime, inviteFriends, review

        var title: String {
            switch self {
            case .name: return "Name your meet"
            case .startTime: return "When does it start?"
            case .endTime: return "When does it end?"
            case .inviteFriends: return "Invite Friends"
            case .review: return "Review & Create"
            }
        }

        var stepNumber: Int {
            switch self {
            case .name: return 1
            case .startTime: return 2
            case .endTime: return 3
            case .inviteFriends: return 4
            case .review: return 5
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
        case .inviteFriends:
            return true // Optional step - can proceed with or without invites
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
        case .startTime:
            currentFieldStep = .endTime
        case .endTime:
            currentFieldStep = .inviteFriends
        case .inviteFriends:
            currentFieldStep = .review
        case .review:
          let trimmed = meetName.trimmingCharacters(in: .whitespacesAndNewlines)
          onConfirm(String(trimmed.prefix(50)), startTime, endTime, invitedUsers)
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
            case .inviteFriends:
                currentFieldStep = .endTime
            case .review:
                currentFieldStep = .inviteFriends
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
        VStack(spacing: 0)
        {
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
                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 3)
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
                            ThemedDatePicker(selection: $startTime)
                                .frame(height: 200)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppPalette.Surface.fieldFill)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 3)
                                        )
                                )
                        }
                        .foregroundColor(AppPalette.Text.primary)
                        .padding(.horizontal, 24)

                    case .endTime:
                        VStack(spacing: 16) {
                            ThemedDatePicker(
                                selection: $endTime,
                                minimumDate: startTime,
                                maximumDate: nil
                            )
                            .frame(height: 200)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppPalette.Surface.fieldFill)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppPalette.Surface.fieldStroke, lineWidth: 3)
                                        )
                                )

                            if endTime <= startTime {
                                Text("End time must be after start time")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppPalette.Brand.neonPink)
                            }
                        }
                        .foregroundColor(AppPalette.Text.primary)
                        .padding(.horizontal, 24)

                    case .inviteFriends:
                        // Embedded invite friends functionality
                        InviteFriendsEmbedded(
                            baseURL: baseURL,
                            token: token,
                            selectedUsers: $invitedUsers
                        )

                    case .review:
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 16) {
                                DetailRow(label: "Meet Name", value: meetName)
                                DetailRow(label: "Start", value: formatDate(startTime))
                                DetailRow(label: "End", value: formatDate(endTime))
                                DetailRow(label: "Duration", value: formatDuration(from: startTime, to: endTime))
                                
                                if !invitedUsers.isEmpty {
                                    DetailRow(label: "Invites", value: "\(invitedUsers.count) friend\(invitedUsers.count == 1 ? "" : "s")")
                                }
                                // Capacity intentionally removed (feature paused)
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppPalette.Surface.fieldFill)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AppPalette.Surface.fieldStroke, lineWidth: 3)
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
                Text(currentFieldStep == .review ? "Create Meet" :
                     currentFieldStep == .inviteFriends ? "Continue" : "Next")
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
        .frame(maxWidth: 360)   // <- keep it compact on iPhone/iPad
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(AppPalette.Brand.japDarkerPurple)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 3)
                )
        )
        .padding(.horizontal, 20) // <- breathing room from screen edges
        .shadow(color: AppPalette.Brand.neonPink.opacity(0.3), radius: 20, x: 0, y: 10)
        .scaleEffect(isAnimating ? 1 : 0.95)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isAnimating = true }
            if endTime <= startTime { endTime = startTime.addingTimeInterval(3600) }
        }
        .onChange(of: startTime) { _, newStart in
            if endTime <= newStart { endTime = newStart.addingTimeInterval(3600) }
        }
        .onTapGesture { isNameFieldFocused = false }
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

// MARK: - Refactored Invite Friends Component
struct InviteFriendsEmbedded: View
{
    let baseURL: URL
    let token: String
    @Binding var selectedUsers: [ViewUsersModel]
    
    @State private var showUserSearch = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Subtitle
            Text("Search by username to invite friends (optional)")
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            // Selected users chips (if any)
            if !selectedUsers.isEmpty {
                selectedUsersSection
            }
            
            // Search button - opens SearchView
            Button(action: {
                showUserSearch = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
                    
                    Text("Search by username...")
                        .font(.system(size: 16))
                        .foregroundStyle(AppPalette.Text.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppPalette.Brand.japPurple)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 3)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showUserSearch) {
            UserSearchView(
                baseURL: baseURL,
                token: token,
                selectedUsers: $selectedUsers,
                excludedUserUUIDs: [],
                onDismiss: {
                    showUserSearch = false
                }
            )
        }
    }
    
    // MARK: - Selected Users Section
    private var selectedUsersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(selectedUsers.count) selected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                
                Spacer()
                
                Button("Clear All") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedUsers.removeAll()
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120), spacing: 8)
            ], spacing: 8) {
                ForEach(selectedUsers) { user in
                    CompactUserCard(user: user) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedUsers.removeAll { $0.id == user.id }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
}


// MARK: - Compact User Card (Updated for selected users display)
struct CompactUserCard: View
{
    let user: ViewUsersModel
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(user.display_name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppPalette.Text.primary)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(AppPalette.Text.secondary.opacity(0.2)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppPalette.Surface.fieldFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 3)
                )
        )
    }
}

// MARK: - Full Screen User Card
private struct FullScreenUserCard: View
{
    let user: ViewUsersModel
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View
    {
        Button(action: onTap)
        {
            HStack(spacing: 12)
            {
                // Avatar
                Circle()
                    .fill(AppPalette.Brand.neonPink.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(user.display_name.prefix(1))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppPalette.Brand.neonPink)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.display_name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.Text.primary)
                        .lineLimit(1)
                    
                    Text("@\(user.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.Text.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppPalette.Brand.neonPink : AppPalette.Text.tertiary, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected
                    {
                        Circle()
                            .fill(AppPalette.Brand.neonPink)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AppPalette.Brand.neonPink.opacity(0.05) : Color(AppPalette.Brand.japDarkerPurple))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? AppPalette.Brand.neonPink.opacity(0.5) : AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 3)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
}


struct MeetCreationOverlayByTap: View
{
    //================================================
    // MARK: - PARAMS
    //================================================
    
    @Binding var selectedLocation: LocationInfo?
    @Binding var showPopup: Bool
    let baseURL : URL
    let token   : String
    let onCreateMeet: (LocationInfo, String, Date, Date, [ViewUsersModel]) async throws -> Void
    
    //================================================
    // MARK: - END PARAMS
    //================================================
    
    //================================================
    // MARK: - MeetCreation Effect Flow
    //================================================
    
    @State private var isSubmitting     = false
    @State private var submitError: String?
    @State private var isSoftDismissing = false
    @State private var isExploding      = false
    @State private var showConfetti     = false
    @State private var currentStep: Step = .locationConfirm
    
    //================================================
    // MARK: - END MeetCreation Effect Flow
    //================================================
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
                                baseURL: baseURL,  // NEW: Pass API dependencies
                                token: token,      // NEW: Pass API dependencies
                                onConfirm: { name, start, end, invitedUsers in // UPDATED: Now includes invitedUsers
                                    guard !isSubmitting else { return }
                                    submitError = nil
                                    isSubmitting = true
                                    Task {
                                        do {
                                            try await onCreateMeet(location, name, start, end, invitedUsers) // UPDATED: Pass invitedUsers
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
                                    isSoftDismissing = true
                                    // run the fade/scale, then actually hide after it finishes
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                            showPopup = false
                                            currentStep = .locationConfirm
                                            isSoftDismissing = false
                                        }
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

// MARK: - User Search View (Specialized for user selection)
struct UserSearchView: View
{
    let baseURL: URL
    let token: String
    @Binding var selectedUsers: [ViewUsersModel]
    let excludedUserUUIDs: [UUID]
    let onDismiss: () -> Void
    
    @State private var searchText = ""
    @State private var searchResults: [ViewUsersModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // Search configuration
    private let searchDelay: TimeInterval = 0.5
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search header
                searchHeader
                
                // Results
                if isLoading {
                    loadingView
                } else if searchText.isEmpty {
                    emptyStateView
                } else if searchResults.isEmpty {
                    noResultsView
                } else {
                    searchResultsList
                }
                
                // Selected users section at bottom (if any)
                if !selectedUsers.isEmpty {
                    selectedUsersBottomSection
                }
            }
            .background(AppPalette.Brand.japDarkerPurple)
            .navigationBarHidden(true)
        }
        .alert("Search Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
    }
    
    // MARK: - Search Header
    private var searchHeader: some View {
        HStack(spacing: 16) {
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppPalette.Brand.neonPink.opacity(0.1))
                    )
            }
            
            // Search field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
                
                TextField("Search by username...", text: $searchText)
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Surface.primary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(AppPalette.Brand.japDarkerPurple))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 3)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppPalette.Brand.neonPink)
            
            Text("Searching users...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("Find Friends")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.Surface.primary)
                
                Text("Search by username to invite friends")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - No Results View
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No Users Found")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.Surface.primary)
                
                Text("Try searching for the exact username")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Results List
    private var searchResultsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(filteredSearchResults) { user in
                    // Simple tap-to-add user card (no checkmarks)
                    TapToAddUserCard(user: user) {
                        addUser(user)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Selected Users Bottom Section
    private var selectedUsersBottomSection: some View {
        VStack(spacing: 0)
        {
            // Divider
            Rectangle()
                .fill(AppPalette.Brand.neonPink.opacity(0.2))
                .frame(height: 1)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(selectedUsers.count) friend\(selectedUsers.count == 1 ? "" : "s") selected")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                    
                    Spacer()
                    
                    Button("Clear All") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedUsers.removeAll()
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppPalette.Text.secondary)
                }
                
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 120), spacing: 8)
                ], spacing: 8) {
                    ForEach(selectedUsers) { user in
                        SelectedUserChip(user: user) {
                            removeUser(user)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(AppPalette.Brand.japPurple).opacity(0.95))
            // Add this to the bottom of selectedUsersBottomSection:
            Button(action: onDismiss) {
                Text("Continue")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppPalette.Brand.neonPink)
                    )
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Filter out already selected users from search results
    private var filteredSearchResults: [ViewUsersModel] {
        let selectedUserIds = Set(selectedUsers.map { $0.id })
        let excludedIds = Set(excludedUserUUIDs)
        return searchResults.filter {
            !selectedUserIds.contains($0.id) && !excludedIds.contains($0.user_uuid)
        }
    }
    
    // MARK: - User Selection Logic
    
    private func addUser(_ user: ViewUsersModel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedUsers.append(user)
        }
        // Clear search after adding
        searchText = ""
    }
    
    private func removeUser(_ user: ViewUsersModel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedUsers.removeAll { $0.id == user.id }
        }
    }
    
    // MARK: - Search Logic
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(Int(searchDelay * 1000)))
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                let results = try await searchUsers(query: query.trimmingCharacters(in: .whitespacesAndNewlines))
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    searchResults = results
                    isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    searchResults = []
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func searchUsers(query: String) async throws -> [ViewUsersModel] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        do {
            return try await AuthAPI.searchUsers(
                baseURL: baseURL,
                token: token,
                usernames: [query]
            )
        } catch {
            print("User search failed: \(error)")
            throw error
        }
    }
}

// MARK: - Simple Tap-to-Add User Card (replaces SelectableUserSearchResultCard)
struct TapToAddUserCard: View
{
    let user: ViewUsersModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar placeholder
                Circle()
                    .fill(AppPalette.Brand.neonPink.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(user.display_name.prefix(1))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppPalette.Brand.neonPink)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.display_name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.Text.primary)
                        .lineLimit(1)
                    
                    Text("@\(user.username)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.Text.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Match badges
                HStack(spacing: 6) {
                    if user.matchedByUsername {
                        matchBadge(text: "U", color: AppPalette.Brand.neonPink)
                    }
                    if user.matchedByEmail {
                        matchBadge(text: "E", color: Color.blue)
                    }
                    if user.matchedByPhone {
                        matchBadge(text: "P", color: Color.green)
                    }
                }
                
                // Add indicator
                Image(systemName: "plus.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(AppPalette.Brand.japPurple))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 3)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(0.98)
        .animation(.easeInOut(duration: 0.1), value: false)
    }
    
    private func matchBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 18, height: 18)
            .background(
                Circle()
                    .fill(color.opacity(0.2))
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.5), lineWidth: 3)
                    )
            )
    }
}

// MARK: - Selected User Chip (for bottom section)
struct SelectedUserChip: View
{
    let user: ViewUsersModel
    let onRemove: () -> Void
    
    var body: some View
    {
        HStack(spacing: 6) {
            // Avatar
            Circle()
                .fill(AppPalette.Brand.neonPink.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(user.display_name.prefix(1))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                )
            
            Text(user.display_name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.Text.primary)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Text.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppPalette.Surface.fieldFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 3)
                )
        )
    }
}
