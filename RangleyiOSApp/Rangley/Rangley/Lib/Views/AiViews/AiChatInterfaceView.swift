//
//  AiChatInterfaceView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 10/25/25.
//

import SwiftUI

struct AiChatInterfaceView: View
{
    let entryMode: MeetCreationEntryMode
    let baseURL: URL
    let token: String
    let onClose: () -> Void
    let onCreateMeet: (MeetInsertBody) async throws -> Void
    let onCreateWithInvites: ([ViewUsersModel], MeetInsertBody) async throws -> Void
    
    @State private var messageText: String = ""
    @State private var chatHistory: [ClaudeModel.ChatMessage] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showConfirmation: Bool = false
    @State private var proposedMeet: ProposedMeet?
    @State private var resolvedInvitees: [ViewUsersModel] = []
    @FocusState private var isTextFieldFocused: Bool
    
    // Struct to hold the AI's proposed meet data
    struct ProposedMeet: Codable {
        let ready: Bool
        let name: String
        let dttm_start_utc: String
        let dttm_end_utc: String
        let description: String?
        let meet_category_id: Int16?
        let invitees: [String]?  // Raw usernames (without @)
        let assumptions: [String]?  // AI's assumptions about the meet
        let confidence: Double?  // AI's confidence level (0.0-1.0)
    }
    
    var body: some View
    {
        ZStack {
            // Main chat interface
            if !showConfirmation {
                chatInterfaceView
            }
            
            // Confirmation overlay
            if showConfirmation, let proposed = proposedMeet {
                MeetConfirmationView(
                    proposedMeet: proposed,
                    entryMode: entryMode,
                    resolvedInvitees: resolvedInvitees,
                    onApprove: { try await handleApproval(proposed) },
                    onEdit: { handleEditRequest() }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showConfirmation)
    }
    
    // MARK: - Chat Interface
    private var chatInterfaceView: some View
    {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        // Welcome message
                        welcomeMessageView
                        
                        // Chat history
                        ForEach(Array(chatHistory.enumerated()), id: \.offset) { index, message in
                            ChatBubbleView(
                                message: message,
                                proposedMeet: (message.role == "assistant" && index == chatHistory.count - 1) ? proposedMeet : nil,
                                resolvedInvitees: (message.role == "assistant" && index == chatHistory.count - 1) ? resolvedInvitees : [],
                                onCreateMeet: (message.role == "assistant" && index == chatHistory.count - 1 && proposedMeet != nil) ? {
                                    Task {
                                        guard let meet = proposedMeet else { return }
                                        do {
                                            try await handleApproval(meet)
                                        } catch {
                                            errorMessage = "Failed to create meet. Please try again."
                                        }
                                    }
                                } : nil
                            )
                            .id(index)
                        }
                        
                        // Loading indicator
                        if isLoading {
                            loadingIndicatorView
                        }
                        
                        // Error message
                        if let error = errorMessage {
                            errorMessageView(error)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: chatHistory.count) { oldValue, newValue in
                    withAnimation {
                        proxy.scrollTo(chatHistory.count - 1, anchor: .bottom)
                    }
                }
            }
            
            // Input area
            inputAreaView
        }
        .background(AppPalette.Brand.japDarkerPurple)
        .cornerRadius(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    // MARK: - Header
    private var headerView: some View
    {
        HStack {
            // AI Icon
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppPalette.Brand.neonPink)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Assistant")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppPalette.Text.primary)
                
                Text("Let's create your meet together")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppPalette.Text.secondary)
            }
            
            Spacer()
            
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppPalette.Text.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppPalette.Brand.japDarkerPurple.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppPalette.Brand.neonPink.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    // MARK: - Welcome Message
    private var welcomeMessageView: some View
    {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppPalette.Brand.neonPink)
                
                Text("Welcome!")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppPalette.Text.primary)
            }
            
            Text(welcomeMessageText)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppPalette.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var welcomeMessageText: String {
        switch entryMode {
        case .tapOnMap:
            return "I'll help you create a meet at this location. Tell me about your event - what are you planning?"
        case .createButton:
            return "I'll help you create your meet. Tell me what kind of event you're planning!"
        case .createWithGroup(let group, _):
            return "I'll help you create a meet with \(group.name). What kind of event do you want to plan?"
        case .update:
            return "I'll help you update this meet. What changes would you like to make?"
        }
    }
    
    // MARK: - Loading Indicator
    private var loadingIndicatorView: some View
    {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(AppPalette.Brand.neonPink)
                    .frame(width: 8, height: 8)
                    .opacity(0.6)
                    .scaleEffect(isLoading ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isLoading
                    )
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Error Message
    private func errorMessageView(_ error: String) -> some View
    {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.red)
            
            Text(error)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.red)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Input Area
    private var inputAreaView: some View
    {
        HStack(spacing: 12) {
            // Text field
            TextField("Type your message...", text: $messageText, axis: .vertical)
                .font(.system(size: 15))
                .foregroundColor(AppPalette.Text.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .lineLimit(1...4)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .focused($isTextFieldFocused)
                .disabled(isLoading)
            
            // Send button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
                        ? AppPalette.Text.secondary.opacity(0.3)
                        : AppPalette.Brand.neonPink
                    )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppPalette.Brand.japDarkerPurple.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppPalette.Brand.neonPink.opacity(0.2)),
            alignment: .top
        )
    }
    
    // MARK: - Actions
    private func sendMessage()
    {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        // Add user message to history
        let userMessage = ClaudeModel.ChatMessage(role: "user", content: trimmedMessage)
        chatHistory.append(userMessage)
        
        // Clear input
        messageText = ""
        errorMessage = nil
        isLoading = true
        
        // Call API
        Task {
            do {
                let response = try await AuthAPI.postChatBot(
                    baseURL: baseURL,
                    token: token,
                    message: trimmedMessage,
                    history: Array(chatHistory.dropLast())
                )
                
                await MainActor.run {
                    // Try to parse as JSON first
                    if let proposed = tryParseProposedMeet(from: response) {
                        if proposed.ready {
                            // Show full confirmation overlay
                            proposedMeet = proposed
                            showConfirmation = true
                            
                            // Resolve invitees in the background
                            Task {
                                await resolveInvitees(from: proposed.invitees)
                            }
                        } else {
                            // Show preview in chat with create button
                            let assistantMessage = ClaudeModel.ChatMessage(
                                role: "assistant",
                                content: extractTextBeforeJSON(from: response)
                            )
                            chatHistory.append(assistantMessage)
                            
                            // Store the proposed meet for this message
                            proposedMeet = proposed
                            
                            // Resolve invitees in the background
                            Task {
                                await resolveInvitees(from: proposed.invitees)
                            }
                        }
                        isLoading = false
                    } else {
                        // Regular chat message
                        let assistantMessage = ClaudeModel.ChatMessage(role: "assistant", content: response)
                        chatHistory.append(assistantMessage)
                        isLoading = false
                    }
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to send message. Please try again."
                    isLoading = false
                }
            }
        }
    }
    
    private func extractTextBeforeJSON(from response: String) -> String {
        // Extract any text that appears before the JSON block
        if let jsonStart = response.range(of: "```json") ?? response.range(of: "{") {
            let textBefore = String(response[..<jsonStart.lowerBound])
            return textBefore.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
    
    private func tryParseProposedMeet(from response: String) -> ProposedMeet? {
        // Try to extract JSON from response (in case Claude wraps it)
        let cleaned = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleaned.data(using: .utf8) else { return nil }
        
        do {
            let proposed = try JSONDecoder().decode(ProposedMeet.self, from: data)
            return proposed
        } catch {
            return nil
        }
    }
    
    private func resolveInvitees(from usernames: [String]?) async {
        guard let usernames = usernames, !usernames.isEmpty else {
            await MainActor.run { resolvedInvitees = [] }
            return
        }
        
        // Search for each username in the user's friends
        var resolved: [ViewUsersModel] = []
        
        for username in usernames {
            do {
                // Use the search endpoint to find matching users
                let results = try await AuthAPI.searchUsers(
                    baseURL: baseURL,
                    token: token,
                    usernames: [username]
                )
                
                // Find exact or close matches
                if let match = results.first(where: { user in
                    user.username.lowercased() == username.lowercased() ||
                    user.display_name.lowercased() == username.lowercased()
                }) {
                    resolved.append(match)
                } else if let firstResult = results.first {
                    // If no exact match, take the first result (best guess)
                    resolved.append(firstResult)
                }
            } catch {
                print("Failed to resolve username: \(username)")
            }
        }
        
        await MainActor.run {
            resolvedInvitees = resolved
        }
    }
    
    private func handleApproval(_ proposed: ProposedMeet) async throws {
        // Get location from entryMode
        guard let location = getLocationFromEntryMode() else {
            errorMessage = "Could not determine location"
            return
        }
        
        // Parse dates
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let startDate = iso8601Formatter.date(from: proposed.dttm_start_utc),
              let endDate = iso8601Formatter.date(from: proposed.dttm_end_utc) else {
            errorMessage = "Invalid date format"
            return
        }
        
        // Check if we have invitees
        if !resolvedInvitees.isEmpty {
            // Create meet with invites
            let body = MeetInsertBody(
                latitude: location.Coordinate.latitude,
                longitude: location.Coordinate.longitude,
                region_latitude: location.RegionCoordinate.latitude,
                region_longitude: location.RegionCoordinate.longitude,
                region_radius: location.RegionRadius,
                name: proposed.name,
                dttm_start_utc: startDate,
                dttm_end_utc: endDate,
                description: proposed.description,
                meet_category_id: proposed.meet_category_id,
                max_capacity: nil
            )

            try await onCreateWithInvites(resolvedInvitees, body)
        } else {
            // Create meet without invites
            let body = MeetInsertBody(
                latitude: location.Coordinate.latitude,
                longitude: location.Coordinate.longitude,
                region_latitude: location.RegionCoordinate.latitude,
                region_longitude: location.RegionCoordinate.longitude,
                region_radius: location.RegionRadius,
                name: proposed.name,
                dttm_start_utc: startDate,
                dttm_end_utc: endDate,
                description: proposed.description,
                meet_category_id: proposed.meet_category_id,
                max_capacity: nil
            )
            
            try await onCreateMeet(body)
        }
    }
    
    private func handleEditRequest() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showConfirmation = false
            proposedMeet = nil
            
            // Add a message to chat history asking what to change
            let assistantMessage = ClaudeModel.ChatMessage(
                role: "assistant",
                content: "No problem! What would you like to change about the meet?"
            )
            chatHistory.append(assistantMessage)
        }
    }
    
    private func getLocationFromEntryMode() -> LocationInfo? {
        switch entryMode {
        case .tapOnMap(let location):
            return location
        case .createButton:
            // Would need default location or error
            return nil
        case .createWithGroup(_, _):
            // Would need default location or error
            return nil
        case .update(let meet):
            // FIX THIS PART - meet is ViewMeetsModel, need to check what properties it has
            return LocationInfo(
                Coordinate: .init(meet.latitude, meet.longitude),
                RegionCoordinate: .init(meet.region_latitude, meet.region_longitude),
                RegionRadius: meet.region_radius,
                Name: meet.name,
                ThoroughFare: nil, SubThoroughFare: nil, Locality: nil, SubLocality: nil,
                AdministrativeArea: nil, SubAdministrativeArea: nil, PostalCode: nil,
                Country: nil, IsoCountryCode: nil, TimeZone: nil, InlandWater: nil, Ocean: nil
            )
        }
    }
}

// MARK: - Chat Bubble View
struct ChatBubbleView: View
{
    let message: ClaudeModel.ChatMessage
    var proposedMeet: AiChatInterfaceView.ProposedMeet? = nil
    var resolvedInvitees: [ViewUsersModel] = []
    var onCreateMeet: (() -> Void)? = nil
    
    private var isUser: Bool {
        message.role == "user"
    }
    
    var body: some View
    {
        HStack(alignment: .top, spacing: 8) {
            if !isUser {
                // AI avatar
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppPalette.Brand.neonPink)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(AppPalette.Brand.neonPink.opacity(0.15))
                    )
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                // Regular message bubble
                if !message.content.isEmpty {
                    Text(cleanMarkdown(message.content))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(isUser ? .white : AppPalette.Text.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isUser
                                    ? AppPalette.Brand.neonPink
                                    : Color.white.opacity(0.08)
                                )
                        )
                        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
                }
                
                // Meet preview card (if proposed meet exists)
                if let meet = proposedMeet {
                    MeetPreviewCard(
                        proposedMeet: meet,
                        resolvedInvitees: resolvedInvitees,
                        onCreateMeet: onCreateMeet ?? {}
                    )
                }
            }
            
            if isUser {
                // User avatar placeholder
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppPalette.Text.secondary)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
    
    private func cleanMarkdown(_ text: String) -> String {
        // Remove ** markdown formatting
        return text.replacingOccurrences(of: "**", with: "")
    }
}

// MARK: - Meet Confirmation View
struct MeetConfirmationView: View
{
    let proposedMeet: AiChatInterfaceView.ProposedMeet
    let entryMode: MeetCreationEntryMode
    let resolvedInvitees: [ViewUsersModel]
    let onApprove: () async throws -> Void
    let onEdit: () -> Void
    
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    var body: some View
    {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppPalette.Brand.neonPink)
                
                Text("Ready to Create?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppPalette.Text.primary)
                
                Text("Review the details below")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(AppPalette.Text.secondary)
            }
            .padding(.top, 20)
            
            // Meet details
            VStack(spacing: 16) {
                detailRow(icon: "calendar", label: "Event", value: proposedMeet.name)
                detailRow(icon: "clock", label: "Starts", value: formatDate(proposedMeet.dttm_start_utc))
                detailRow(icon: "clock.fill", label: "Ends", value: formatDate(proposedMeet.dttm_end_utc))
                
                if let description = proposedMeet.description {
                    detailRow(icon: "text.alignleft", label: "Description", value: description)
                }
                
                if let categoryId = proposedMeet.meet_category_id {
                    detailRow(icon: "tag", label: "Category", value: categoryName(for: categoryId))
                }
                
                if !resolvedInvitees.isEmpty {
                    inviteesRow()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
            
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: { Task { await approveAndCreate() } }) {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                        }
                        Text(isSubmitting ? "Creating..." : "Create Meet")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppPalette.Brand.neonPink)
                    )
                }
                .disabled(isSubmitting)
                
                Button(action: onEdit) {
                    Text("Make Changes")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppPalette.Text.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .disabled(isSubmitting)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppPalette.Brand.japDarkerPurple)
        .cornerRadius(16)
        .padding(.horizontal, 20)
    }
    
    private func detailRow(icon: String, label: String, value: String) -> some View
    {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppPalette.Brand.neonPink)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppPalette.Text.secondary)
                
                Text(value)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppPalette.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
    
    private func inviteesRow() -> some View
    {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 16))
                .foregroundColor(AppPalette.Brand.neonPink)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Inviting")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppPalette.Text.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(resolvedInvitees) { user in
                        Text("@\(user.username)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppPalette.Brand.spearmintGreen)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private func formatDate(_ isoString: String) -> String
    {
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = iso8601Formatter.date(from: isoString) else {
            return isoString
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    private func categoryName(for id: Int16) -> String
    {
        let categories = [
            1: "Activiy", 2: "Sports", 3: "Outdoors", 4: "Social",
            5: "Music", 6: "Food", 7: "Planned Trip", 8: "Spontaneous",
            9: "Custom"
        ]
        return categories[Int(id)] ?? "Other"
    }
    
    private func approveAndCreate() async
    {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        
        do {
            try await onApprove()
        } catch {
            errorMessage = "Failed to create meet. Please try again."
            isSubmitting = false
        }
    }
}

// MARK: - Meet Preview Card (for inline chat previews)
struct MeetPreviewCard: View
{
    let proposedMeet: AiChatInterfaceView.ProposedMeet
    let resolvedInvitees: [ViewUsersModel]
    let onCreateMeet: () -> Void
    
    var body: some View
    {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppPalette.Brand.neonPink)
                
                Text("Meet Preview")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppPalette.Text.secondary)
            }
            
            // Meet details
            VStack(spacing: 10) {
                previewRow(icon: "calendar", label: "Event", value: proposedMeet.name)
                previewRow(icon: "clock", label: "Starts", value: formatDate(proposedMeet.dttm_start_utc))
                previewRow(icon: "clock.fill", label: "Ends", value: formatDate(proposedMeet.dttm_end_utc))
                
                if let description = proposedMeet.description, !description.isEmpty {
                    previewRow(icon: "text.alignleft", label: "Description", value: description)
                }
                
                if let categoryId = proposedMeet.meet_category_id {
                    previewRow(icon: "tag", label: "Category", value: categoryName(for: categoryId))
                }
                
                if !resolvedInvitees.isEmpty {
                    inviteesPreviewRow()
                }
            }
            
            // Create button
            Button(action: onCreateMeet) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Create This Meet")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppPalette.Brand.neonPink)
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func previewRow(icon: String, label: String, value: String) -> some View
    {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppPalette.Brand.neonPink.opacity(0.8))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppPalette.Text.secondary)
                
                Text(value)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppPalette.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
    
    private func inviteesPreviewRow() -> some View
    {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 12))
                .foregroundColor(AppPalette.Brand.neonPink.opacity(0.8))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Inviting")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppPalette.Text.secondary)
                
                HStack(spacing: 6) {
                    ForEach(resolvedInvitees.prefix(3)) { user in
                        Text("@\(user.username)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppPalette.Brand.spearmintGreen)
                    }
                    
                    if resolvedInvitees.count > 3 {
                        Text("+\(resolvedInvitees.count - 3)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppPalette.Text.secondary)
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private func formatDate(_ isoString: String) -> String
    {
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = iso8601Formatter.date(from: isoString) else {
            return isoString
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    private func categoryName(for id: Int16) -> String
    {
        let categories = [
            1: "Activiy", 2: "Sports", 3: "Outdoors", 4: "Social",
            5: "Music", 6: "Food", 7: "Planned Trip", 8: "Spontaneous",
            9: "Custom"
        ]
        return categories[Int(id)] ?? "Other"
    }
}
