////
////  AiChatInterfaceView.swift
////  Rangley
////
////  Created by Anthony Guzzardo on 10/25/25.
////
//
//import SwiftUI
//import MapKit
//import CoreLocation
//
//enum MeetCreationError: Error {
//    case noLocationAvailable
//    case geocodingFailed
//    case geocodingWLocationNameFailed(locationName: String)
//    case invalidDateRange
//    // add more cases as needed
//}
//
//struct AiChatInterfaceView: View
//{
//    
//    @EnvironmentObject private var locationData: LocationDataStore
//    @EnvironmentObject private var authState: AuthStateStore
//    
//    //entry mode contains the meet location if entry mode is by onTap
//    let entryMode           : MeetCreationEntryMode
//    let baseURL             : URL
//    let token               : String
//    let onClose             : () -> Void
//    let onCreate            : (MeetInsertBody) async throws -> Void
//    let onCreateWithInvites : (MeetWithInvitesInsertBody) async throws -> Void
//    
//    @State private var messageText            : String = ""
//    @State private var chatHistory            : [ClaudeModel.ChatMessage] = []
//    @State private var isLoading              : Bool = false
//    @State private var errorMessage           : String?
//    @State private var showConfirmation       : Bool = false
//    @State private var proposedMeet           : ProposedMeet?
//    @State private var resolvedInvitees       : [ViewUsersModel] = []
//    @State private var showLocationPicker     : Bool = false
//    @State private var selectedLocation       : LocationInfo?
//    @State private var locationName           : String = "Loading location..."
//    @State private var selectedItem           : MKMapItem?
//    @State private var isSearching            : Bool = false
//    @FocusState private var isTextFieldFocused: Bool
//    
//
//
//    
//    
//    // Struct to hold the AI's proposed meet data
//    struct ProposedMeet: Codable
//    {
//        let ready           : Bool
//        let name            : String
//        let dttm_start_utc  : String
//        let dttm_end_utc    : String
//        let description     : String?
//        let meet_category_id: Int16?
//        let invitees        : [String]?  // Raw usernames (without @)
//        let assumptions     : [String]?  // AI's assumptions about the meet
//        let confidence      : Double?  // AI's confidence level (0.0-1.0)
//        
//        // Location fields - AI can provide these when location isn't from map tap
//        let location_name   : String?  // Human-readable location name
//        let latitude        : Double?
//        let longitude       : Double?
//        let region_latitude : Double?
//        let region_longitude: Double?
//        let region_radius   : Double?
//    }
//    
//    var body: some View
//    {
//        ZStack {
//            // Main chat interface
//            if !showConfirmation {
//                chatInterfaceView
//            }
//            
//            // Confirmation overlay
//            if showConfirmation, let proposed = proposedMeet {
//                MeetConfirmationView(
//                    proposedMeet    : proposed,
//                    entryMode       : entryMode,
//                    resolvedInvitees: resolvedInvitees,
//                    onApprove       : { try await handleApproval(proposed) },
//                    onEdit          : { handleEditRequest() }
//                )
//                .transition(.asymmetric(
//                    insertion: .move(edge: .trailing).combined(with: .opacity),
//                    removal: .move(edge: .leading).combined(with: .opacity)
//                ))
//            }
//        }
//        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showConfirmation)
//        .onAppear {
//            loadLocationNameIfExists()
//        }
//    }
//    
//    // MARK: - Chat Interface
//    private var chatInterfaceView: some View
//    {
//        VStack(spacing: 0) {
//            // Header
//            headerView
//            
//            // Chat messages
//            ScrollViewReader { proxy in
//                ScrollView {
//                    VStack(spacing: 12) {
//                        // Welcome message
//                        welcomeMessageView
//                        
//                        // Chat history
//                        ForEach(Array(chatHistory.enumerated()), id: \.offset) { index, message in
//                            ChatBubbleView(
//                                message: message,
//                                proposedMeet: (message.role == "assistant" && index == chatHistory.count - 1) ? proposedMeet : nil,
//                                resolvedInvitees: (message.role == "assistant" && index == chatHistory.count - 1) ? resolvedInvitees : [],
//                                onCreate: (message.role == "assistant" && index == chatHistory.count - 1 && proposedMeet != nil) ? {
//                                    Task {
//                                        guard let meet = proposedMeet else { return }
//                                        do {
//                                            try await handleApproval(meet)
//                                        } catch {
//                                            errorMessage = "Failed to create meet. Please try again."
//                                        }
//                                    }
//                                } : nil
//                            )
//                            .id(index)
//                        }
//                        
//                        // Loading indicator
//                        if isLoading {
//                            loadingIndicatorView
//                        }
//                        
//                        // Error message
//                        if let error = errorMessage {
//                            errorMessageView(error)
//                        }
//                    }
//                    .padding(.horizontal, 16)
//                    .padding(.vertical, 12)
//                }
//                .onChange(of: chatHistory.count) { oldValue, newValue in
//                    withAnimation {
//                        proxy.scrollTo(chatHistory.count - 1, anchor: .bottom)
//                    }
//                }
//            }
//            
//            // Input area
//            inputAreaView
//        }
//        .background(AppPalette.Brand.japDarkerPurple)
//        .cornerRadius(16)
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .padding(.horizontal, 20)
//        .onAppear {
//            isTextFieldFocused = true
//        }
//    }
//    
//    // MARK: - Header
//    private var headerView: some View
//    {
//        HStack {
//            // AI Icon
//            Image(systemName: "sparkles")
//                .font(.system(size: 20, weight: .semibold))
//                .foregroundColor(AppPalette.Brand.neonPink)
//            
//            VStack(alignment: .leading, spacing: 2) {
//                Text("AI Assistant")
//                    .font(.system(size: 16, weight: .bold))
//                    .foregroundColor(AppPalette.Text.primary)
//                // TODO: - if it's by onTap the text needs
//                Text("Let's create your meet together")
//                    .font(.system(size: 12, weight: .regular))
//                    .foregroundColor(AppPalette.Text.secondary)
//            }
//            
//            Spacer()
//            
//            // Close button
//            Button(action: onClose) {
//                Image(systemName: "xmark.circle.fill")
//                    .font(.system(size: 24))
//                    .foregroundColor(AppPalette.Text.secondary)
//            }
//        }
//        .padding(.horizontal, 16)
//        .padding(.vertical, 14)
//        .background(AppPalette.Brand.japDarkerPurple.opacity(0.95))
//        .overlay(
//            Rectangle()
//                .frame(height: 1)
//                .foregroundColor(AppPalette.Brand.neonPink.opacity(0.2)),
//            alignment: .bottom
//        )
//    }
//    
//    // MARK: - Welcome Message
//    private var welcomeMessageView: some View
//    {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack(spacing: 8) {
//                Image(systemName: "wand.and.stars")
//                    .font(.system(size: 16, weight: .semibold))
//                    .foregroundColor(AppPalette.Brand.neonPink)
//                
//                Text("Welcome!")
//                    .font(.system(size: 15, weight: .bold))
//                    .foregroundColor(AppPalette.Text.primary)
//            }
//            
//            Text(welcomeMessageText)
//                .font(.system(size: 14, weight: .regular))
//                .foregroundColor(AppPalette.Text.secondary)
//                .fixedSize(horizontal: false, vertical: true)
//        }
//        .padding(12)
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(Color.white.opacity(0.05))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 12)
//                        .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
//                )
//        )
//    }
//    
//    // TODO: we need to insert the locationName in the same way
//    private var welcomeMessageText: String
//    {
//        switch entryMode {
//        case .tapOnMap:
//            // if there is location.name use location.address
//            return "I'll help you create a meet at \(locationName). Tell me about your event - what are you planning?"
//        case .createButton:
//            return "I'll help you create your meet. Tell me what kind of event you're planning!"
//        case .createWithGroup(let group, _):
//            return "I'll help you create a meet with \(group.name). What kind of event do you want to plan?"
//        case .update:
//            return "I'll help you update this meet. What changes would you like to make?"
//        }
//    }
//    
//    // MARK: - Loading Indicator
//    private var loadingIndicatorView: some View
//    {
//        HStack(spacing: 8) {
//            ForEach(0..<3) { index in
//                Circle()
//                    .fill(AppPalette.Brand.neonPink)
//                    .frame(width: 8, height: 8)
//                    .opacity(0.6)
//                    .scaleEffect(isLoading ? 1.0 : 0.5)
//                    .animation(
//                        Animation.easeInOut(duration: 0.6)
//                            .repeatForever()
//                            .delay(Double(index) * 0.2),
//                        value: isLoading
//                    )
//            }
//        }
//        .padding(.vertical, 12)
//        .padding(.horizontal, 16)
//        .background(
//            RoundedRectangle(cornerRadius: 18)
//                .fill(Color.white.opacity(0.08))
//        )
//        .frame(maxWidth: .infinity, alignment: .leading)
//    }
//    
//    // MARK: - Error Message
//    private func errorMessageView(_ error: String) -> some View
//    {
//        HStack(spacing: 8) {
//            Image(systemName: "exclamationmark.triangle.fill")
//                .font(.system(size: 14))
//                .foregroundColor(.red)
//            
//            Text(error)
//                .font(.system(size: 13, weight: .medium))
//                .foregroundColor(.red)
//        }
//        .padding(10)
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .background(
//            RoundedRectangle(cornerRadius: 10)
//                .fill(Color.red.opacity(0.15))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 10)
//                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
//                )
//        )
//    }
//    
//    // MARK: - Input Area
//    private var inputAreaView: some View
//    {
//        HStack(spacing: 12) {
//            // Text field
//            TextField("Type your message...", text: $messageText, axis: .vertical)
//                .font(.system(size: 15))
//                .foregroundColor(AppPalette.Text.primary)
//                .padding(.horizontal, 14)
//                .padding(.vertical, 10)
//                .lineLimit(1...4)
//                .background(
//                    RoundedRectangle(cornerRadius: 20)
//                        .fill(Color.white.opacity(0.08))
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 20)
//                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
//                        )
//                )
//                .focused($isTextFieldFocused)
//                .disabled(isLoading)
//            
//            // Send button
//            Button(action: sendMessage) {
//                Image(systemName: "arrow.up.circle.fill")
//                    .font(.system(size: 32))
//                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
//                        ? AppPalette.Text.secondary.opacity(0.3)
//                        : AppPalette.Brand.neonPink
//                    )
//            }
//            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
//        }
//        .padding(.horizontal, 16)
//        .padding(.vertical, 12)
//        .background(AppPalette.Brand.japDarkerPurple.opacity(0.95))
//        .overlay(
//            Rectangle()
//                .frame(height: 1)
//                .foregroundColor(AppPalette.Brand.neonPink.opacity(0.2)),
//            alignment: .top
//        )
//    }
//    
//    // MARK: - Context Helpers
//
//    private func resolveUserLocationString() async -> String? {
//        guard let userLoc = locationData.userLocation else { return nil }
//        
//        let info = await locationData.reverseGeocode(coordinate: userLoc.coordinate)
//        
//        // Build string like "Near Wicker Park, Chicago, IL"
//        var components: [String] = []
//        
//        if let subLocality = info?.SubLocality {
//            components.append(subLocality)
//        } else if let locality = info?.Locality {
//            components.append(locality)
//        }
//        
//        if let city = info?.Locality, !components.contains(city) {
//            components.append(city)
//        }
//        
//        if let state = info?.AdministrativeArea {
//            components.append(state)
//        }
//        
//        return components.isEmpty ? nil : "Near \(components.joined(separator: ", "))"
//    }
//
//    private func extractTapLocation() -> ClaudeModel.TapLocationContext? {
//        guard case .tapOnMap(let location) = entryMode else { return nil }
//        
//        // Build a descriptive name from the location info
//        let name: String
//        if let locName = location.Name {
//            name = locName
//        } else if let thoroughfare = location.ThoroughFare {
//            if let subThoroughfare = location.SubThoroughFare {
//                name = "\(subThoroughfare) \(thoroughfare)"
//            } else {
//                name = thoroughfare
//            }
//        } else if let locality = location.Locality {
//            name = locality
//        } else {
//            name = "Selected location"
//        }
//        
//        return ClaudeModel.TapLocationContext(
//            name: name,
//            latitude: location.Coordinate.latitude,
//            longitude: location.Coordinate.longitude
//        )
//    }
//    // MARK: - END Context Helpers
//
//    
//    // MARK: - Actions
//    private func sendMessage()
//    {
//        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !trimmedMessage.isEmpty else { return }
//        
//        // Add user message to history
//        let userMessage = ClaudeModel.ChatMessage(role: "user", content: trimmedMessage)
//        chatHistory.append(userMessage)
//        
//        // Clear input
//        messageText = ""
//        errorMessage = nil
//        isLoading = true
//        
//        // Call API
//        Task {
//            // SNAPSHOT CONTEXT (only on first message)
//            let shouldSendContext = chatHistory.count == 1
//            
//            let userTimezone = shouldSendContext ? TimeZone.current.identifier : nil
//            let currentTimeISO = shouldSendContext ? ISO8601DateFormatter().string(from: Date()) : nil
//            let userDisplayName = shouldSendContext ? authState.currentUser?.display_name : nil
//            let userLocation = shouldSendContext ? await resolveUserLocationString() : nil
//            let tapLocation = shouldSendContext ? extractTapLocation() : nil
//            
//            do {
//                let response = try await AuthAPI.postChatBot(
//                    baseURL: baseURL,
//                    token: token,
//                    message: trimmedMessage,
//                    history: Array(chatHistory.dropLast()),
//                    userTimezone: userTimezone,
//                    currentTimeISO: currentTimeISO,
//                    userLocation: userLocation,
//                    userDisplayName: userDisplayName,
//                    tapLocation: tapLocation
//                )
//                
//                await MainActor.run {
//                    // Try to parse as JSON first
//                    if let proposed = tryParseProposedMeet(from: response) {
//                        // Extract the natural language text BEFORE the JSON
//                        let naturalText = extractTextBeforeJSON(from: response)
//                        
//                        // Always add the AI's natural language response to chat
//                        let assistantMessage = ClaudeModel.ChatMessage(
//                            role: "assistant",
//                            content: naturalText.isEmpty ? "Here's what I've put together for you:" : naturalText
//                        )
//                        chatHistory.append(assistantMessage)
//                        
//                        // Store the proposed meet for the preview card
//                        proposedMeet = proposed
//                        
//                        // Resolve invitees in the background
//                        Task {
//                            await resolveInvitees(from: proposed.invitees)
//                        }
//                        
//                        // If ready, we'll show the button in the chat
//                        // No need for separate confirmation overlay
//                        isLoading = false
//                    } else {
//                        // Regular chat message (no JSON found)
//                        let assistantMessage = ClaudeModel.ChatMessage(role: "assistant", content: response)
//                        chatHistory.append(assistantMessage)
//                        isLoading = false
//                    }
//                }
//                
//            } catch {
//                await MainActor.run {
//                    errorMessage = "Failed to send message. Please try again."
//                    isLoading = false
//                }
//            }
//        }
//    }
//    
//    private func extractTextBeforeJSON(from response: String) -> String
//    {
//        // Look for all possible JSON start patterns
//        var earliestJsonStart: String.Index? = nil
//        
//        let jsonPatterns = [
//            "```json",           // Markdown code block
//            "```",               // Generic code block
//            "{\"ready\"",        // Direct JSON object start
//            "{ \"ready\"",       // JSON with space
//            "{",                 // Any object start (last resort)
//        ]
//        
//        for pattern in jsonPatterns {
//            if let range = response.range(of: pattern) {
//                if earliestJsonStart == nil || range.lowerBound < earliestJsonStart! {
//                    earliestJsonStart = range.lowerBound
//                }
//            }
//        }
//        
//        // Extract text BEFORE the JSON
//        if let jsonStart = earliestJsonStart {
//            let textBefore = String(response[..<jsonStart])
//            let cleaned = textBefore.trimmingCharacters(in: .whitespacesAndNewlines)
//            
//            // If there's meaningful text before JSON, return it
//            if !cleaned.isEmpty && cleaned.count > 5 {
//                return cleaned
//            }
//        }
//        
//        // If we get here, either:
//        // 1. No JSON was found (unlikely)
//        // 2. There was no meaningful text before the JSON
//        // Return a default message
//        return ""
//    }
//    
//    private func tryParseProposedMeet(from response: String) -> ProposedMeet?
//    {
//        // Find the JSON object in the response
//        var jsonString = ""
//        
//        // Try to find JSON in markdown code block first
//        if let codeBlockStart = response.range(of: "```json"),
//           let codeBlockEnd = response.range(of: "```", range: codeBlockStart.upperBound..<response.endIndex) {
//            jsonString = String(response[codeBlockStart.upperBound..<codeBlockEnd.lowerBound])
//        }
//        // Try to find raw JSON object
//        else if let jsonStart = response.range(of: "{\"ready\"") ?? response.range(of: "{ \"ready\"") {
//            // Find the matching closing brace
//            var braceCount = 0
//            var foundStart = false
//            var endIndex = response.endIndex
//            
//            for i in response[jsonStart.lowerBound...].indices {
//                let char = response[i]
//                if char == "{" {
//                    braceCount += 1
//                    foundStart = true
//                } else if char == "}" {
//                    braceCount -= 1
//                    if foundStart && braceCount == 0 {
//                        endIndex = response.index(after: i)
//                        break
//                    }
//                }
//            }
//            
//            jsonString = String(response[jsonStart.lowerBound..<endIndex])
//        }
//        
//        guard !jsonString.isEmpty else { return nil }
//        
//        // Clean up the JSON string
//        let cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard let data = cleaned.data(using: .utf8) else { return nil }
//        
//        do {
//            let proposed = try JSONDecoder().decode(ProposedMeet.self, from: data)
//            return proposed
//        } catch {
//            print("Failed to decode ProposedMeet: \(error)")
//            return nil
//        }
//    }
//    
//    private func resolveInvitees(from usernames: [String]?) async
//    {
//        guard let usernames = usernames, !usernames.isEmpty else {
//            await MainActor.run { resolvedInvitees = [] }
//            return
//        }
//        
//        // Search for each username in the user's friends
//        var resolved: [ViewUsersModel] = []
//        
//        for username in usernames {
//            do {
//                // Use the search endpoint to find matching users
//                let results = try await AuthAPI.searchUsers(
//                    baseURL: baseURL,
//                    token: token,
//                    usernames: [username]
//                )
//                
//                // Find exact or close matches
//                if let match = results.first(where: { user in
//                    user.username.lowercased() == username.lowercased() ||
//                    user.display_name.lowercased() == username.lowercased()
//                }) {
//                    resolved.append(match)
//                } else if let firstResult = results.first {
//                    // If no exact match, take the first result (best guess)
//                    resolved.append(firstResult)
//                }
//            } catch {
//                print("Failed to resolve username: \(username)")
//            }
//        }
//        
//        await MainActor.run {
//            resolvedInvitees = resolved
//        }
//    }
//        
//    
//    private func geocodeLocationName(_ query: String) async -> MKMapItem?
//    {
//        let request = MKLocalSearch.Request(naturalLanguageQuery: query)
//        let search = MKLocalSearch(request: request)
//        if let response = try? await search.start(), let first = response.mapItems.first {
//            return first
//        }
//        return nil
//    }
//    
//    private func makeLocationInfo(from item: MKMapItem) -> LocationInfo
//    {
//        let p = item.placemark
//        let c = p.coordinate
//        
//        // Use a reasonable default radius based on placemark type
//        let defaultRadius: Double = {
//            if p.thoroughfare != nil {
//                return 500.0  // Street address - smaller radius
//            } else if p.locality != nil {
//                return 1000.0 // City/locality - medium radius
//            } else {
//                return 2000.0 // Larger area - bigger radius
//            }
//        }()
//        
//        return LocationInfo(
//            Coordinate           : .init(c.latitude, c.longitude),
//            RegionCoordinate     : .init(c.latitude, c.longitude),
//            RegionRadius         : defaultRadius,
//            Name                 : p.name,
//            ThoroughFare         : p.thoroughfare,
//            SubThoroughFare      : p.subThoroughfare,
//            Locality             : p.locality,
//            SubLocality          : p.subLocality,
//            AdministrativeArea   : p.administrativeArea,
//            SubAdministrativeArea: p.subAdministrativeArea,
//            PostalCode           : p.postalCode,
//            Country              : p.country,
//            IsoCountryCode       : p.isoCountryCode,
//            TimeZone             : nil,
//            InlandWater          : nil,
//            Ocean                : nil
//        )
//    }
//    
//    private func handleApproval(_ proposed: ProposedMeet) async throws
//    {
//        
//        let locationInfo: LocationInfo
//
//        if let locationName = proposed.location_name {
//            if let mkItem = await geocodeLocationName(locationName) {
//                locationInfo = makeLocationInfo(from: mkItem)
//            } else if case .tapOnMap(let location) = entryMode {
//                locationInfo = location
//            } else {
//                throw MeetCreationError.noLocationAvailable
//            }
//        } else if case .tapOnMap(let location) = entryMode {
//            locationInfo = location
//        } else {
//            throw MeetCreationError.noLocationAvailable
//        }
//
//        // 2) Parse dates and enforce end > start like the form logic does
//        let startDate = dateFromISO(proposed.dttm_start_utc)
//        var endDate   = dateFromISO(proposed.dttm_end_utc)
//        if endDate <= startDate {
//            endDate = startDate.addingTimeInterval(3600) // fallback: +1h
//        }
//
//        // 3) Normalize fields like manual
//        let safeName = String(proposed.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50))
//        let safeDescription: String? = {
//            let t = proposed.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
//            return t.isEmpty ? nil : t
//        }()
//
//
//        // 4) Create the exact same bodies the manual path uses
//        if let invitees = proposed.invitees, !invitees.isEmpty, !resolvedInvitees.isEmpty {
//            // With invites
//            let body = MeetCreationService.buildMeetWithInvitesBody(
//                locationInfo        : locationInfo,
//                name                : safeName,
//                startTime           : startDate,
//                endTime             : endDate,
//                invitedUsers        : resolvedInvitees.map { $0.user_uuid },
//                description         : safeDescription,
//                meetCategoryID      : proposed.meet_category_id,
//                maxCapacity         : -1,
//                invitationMessage   : ""
//            )
//            try await onCreateWithInvites(body)
//        } else {
//            // No invites
//            let body = MeetCreationService.buildMeetBody(
//                locationInfo    : locationInfo,
//                name            : safeName,
//                startTime       : startDate,
//                endTime         : endDate,
//                description     : safeDescription,
//                meetCategoryID  : proposed.meet_category_id,
//                maxCapacity     : -1
//            )
//            try await onCreate(body)
//        }
//    }
//
//    
//    private func handleEditRequest()
//    {
//        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//            showConfirmation = false
//            proposedMeet = nil
//            
//            // Add a message to chat history asking what to change
//            let assistantMessage = ClaudeModel.ChatMessage(
//                role: "assistant",
//                content: "No problem! What would you like to change about the meet?"
//            )
//            chatHistory.append(assistantMessage)
//        }
//    }
//    
//    // Extract location from entryMode if available
//    private func loadLocationNameIfExists()
//    {
//        guard case .tapOnMap(let location) = entryMode else { return }
//        
//        let clLocation = CLLocation(
//            latitude    : location.Coordinate.latitude,
//            longitude   : location.Coordinate.longitude
//        )
//        
//        CLGeocoder().reverseGeocodeLocation(clLocation) { placemarks, error in
//            DispatchQueue.main.async {
//                if error != nil {
//                    locationName = "Selected location"
//                    return
//                }
//                
//                guard let placemark = placemarks?.first else {
//                    locationName = "Selected location"
//                    return
//                }
//                
//                // Build location name similar to other components
//                var components: [String] = []
//                
//                if let name = placemark.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
//                    components.append(name)
//                } else if let street = placemark.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines), !street.isEmpty {
//                    if let number = placemark.subThoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines), !number.isEmpty {
//                        components.append("\(number) \(street)")
//                    } else {
//                        components.append(street)
//                    }
//                }
//                
//                if let city = placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty {
//                    components.append(city)
//                }
//                
//                locationName = components.isEmpty ? "Selected location" : components.joined(separator: ", ")
//            }
//        }
//    }
//    
//    // Add this helper function in AiChatInterfaceView
//    private func dateFromISO(_ isoString: String) -> Date
//    {
//        let iso8601Formatter = ISO8601DateFormatter()
//        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
//        
//        if let date = iso8601Formatter.date(from: isoString) {
//            return date
//        }
//        
//        // Fallback without fractional seconds
//        iso8601Formatter.formatOptions = [.withInternetDateTime]
//        return iso8601Formatter.date(from: isoString) ?? Date()
//    }
//    
//}
//
//// MARK: - Chat Bubble View
//struct ChatBubbleView: View
//{
//    let message             : ClaudeModel.ChatMessage
//    var proposedMeet        : AiChatInterfaceView.ProposedMeet? = nil
//    var resolvedInvitees    : [ViewUsersModel] = []
//    var onCreate            : (() -> Void)? = nil
//    
//    private var isUser: Bool {
//        message.role == "user"
//    }
//    
//    var body: some View
//    {
//        HStack(alignment: .top, spacing: 8) {
//            if !isUser {
//                // AI avatar
//                Image(systemName: "sparkles")
//                    .font(.system(size: 12, weight: .semibold))
//                    .foregroundColor(AppPalette.Brand.neonPink)
//                    .frame(width: 28, height: 28)
//                    .background(
//                        Circle()
//                            .fill(AppPalette.Brand.neonPink.opacity(0.15))
//                    )
//            }
//            
//            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
//                // Regular message bubble
//                if !message.content.isEmpty {
//                    Text(cleanMarkdown(message.content))
//                        .font(.system(size: 14, weight: .regular))
//                        .foregroundColor(isUser ? .white : AppPalette.Text.primary)
//                        .padding(.horizontal, 12)
//                        .padding(.vertical, 10)
//                        .background(
//                            RoundedRectangle(cornerRadius: 16)
//                                .fill(isUser
//                                    ? AppPalette.Brand.neonPink
//                                    : Color.white.opacity(0.08)
//                                )
//                        )
//                        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
//                }
//                
//                // Meet preview card (if proposed meet exists)
//                if let meet = proposedMeet {
//                    MeetPreviewCard(
//                        proposedMeet    : meet,
//                        resolvedInvitees: resolvedInvitees,
//                        onCreate        : onCreate ?? {}
//                    )
//                }
//            }
//            
//            if isUser {
//                // User avatar placeholder
//                Circle()
//                    .fill(Color.white.opacity(0.1))
//                    .frame(width: 28, height: 28)
//                    .overlay(
//                        Image(systemName: "person.fill")
//                            .font(.system(size: 12))
//                            .foregroundColor(AppPalette.Text.secondary)
//                    )
//            }
//        }
//        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
//    }
//    
//    private func cleanMarkdown(_ text: String) -> String {
//        // Remove ** markdown formatting
//        return text.replacingOccurrences(of: "**", with: "")
//    }
//}
//
//// MARK: - Meet Confirmation View
//struct MeetConfirmationView: View
//{
//    let proposedMeet: AiChatInterfaceView.ProposedMeet
//    let entryMode: MeetCreationEntryMode
//    let resolvedInvitees: [ViewUsersModel]
//    let onApprove: () async throws -> Void
//    let onEdit: () -> Void
//    
//    @State private var isSubmitting = false
//    @State private var errorMessage: String?
//    
//    var body: some View
//    {
//        VStack(spacing: 20) {
//            // Header
//            VStack(spacing: 8) {
//                Image(systemName: "checkmark.circle.fill")
//                    .font(.system(size: 48))
//                    .foregroundColor(AppPalette.Brand.neonPink)
//                
//                Text("Ready to Create?")
//                    .font(.system(size: 22, weight: .bold))
//                    .foregroundColor(AppPalette.Text.primary)
//                
//                Text("Review the details below")
//                    .font(.system(size: 14, weight: .regular))
//                    .foregroundColor(AppPalette.Text.secondary)
//            }
//            .padding(.top, 20)
//            
//            // Meet details
//            VStack(spacing: 16) {
//                detailRow(icon: "calendar", label: "Event", value: proposedMeet.name)
//                detailRow(icon: "clock", label: "Starts", value: formatDate(proposedMeet.dttm_start_utc))
//                detailRow(icon: "clock.fill", label: "Ends", value: formatDate(proposedMeet.dttm_end_utc))
//                
//                if let description = proposedMeet.description {
//                    detailRow(icon: "text.alignleft", label: "Description", value: description)
//                }
//                
//                if let categoryId = proposedMeet.meet_category_id {
//                    detailRow(icon: "tag", label: "Category", value: categoryName(for: categoryId))
//                }
//                
//                if !resolvedInvitees.isEmpty {
//                    inviteesRow()
//                }
//            }
//            .padding(16)
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(Color.white.opacity(0.05))
//            )
//            
//            // Error message
//            if let error = errorMessage {
//                Text(error)
//                    .font(.system(size: 13, weight: .medium))
//                    .foregroundColor(.red)
//                    .padding(.horizontal)
//            }
//            
//            Spacer()
//            
//            // Action buttons
//            VStack(spacing: 12) {
//                Button(action: { Task { await approveAndCreate() } }) {
//                    HStack(spacing: 8) {
//                        if isSubmitting {
//                            ProgressView()
//                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                .scaleEffect(0.8)
//                        } else {
//                            Image(systemName: "checkmark.circle.fill")
//                                .font(.system(size: 16))
//                        }
//                        Text(isSubmitting ? "Creating..." : "Create Meet")
//                            .font(.system(size: 16, weight: .bold))
//                    }
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 14)
//                    .background(
//                        RoundedRectangle(cornerRadius: 12)
//                            .fill(AppPalette.Brand.neonPink)
//                    )
//                }
//                .disabled(isSubmitting)
//                
//                Button(action: onEdit) {
//                    Text("Make Changes")
//                        .font(.system(size: 15, weight: .medium))
//                        .foregroundColor(AppPalette.Text.primary)
//                        .frame(maxWidth: .infinity)
//                        .padding(.vertical, 12)
//                        .background(
//                            RoundedRectangle(cornerRadius: 12)
//                                .fill(Color.white.opacity(0.1))
//                        )
//                }
//                .disabled(isSubmitting)
//            }
//            .padding(.horizontal, 20)
//            .padding(.bottom, 20)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(AppPalette.Brand.japDarkerPurple)
//        .cornerRadius(16)
//        .padding(.horizontal, 20)
//    }
//    
//    private func detailRow(icon: String, label: String, value: String) -> some View
//    {
//        HStack(alignment: .top, spacing: 12) {
//            Image(systemName: icon)
//                .font(.system(size: 16))
//                .foregroundColor(AppPalette.Brand.neonPink)
//                .frame(width: 24)
//            
//            VStack(alignment: .leading, spacing: 2) {
//                Text(label)
//                    .font(.system(size: 12, weight: .medium))
//                    .foregroundColor(AppPalette.Text.secondary)
//                
//                Text(value)
//                    .font(.system(size: 15, weight: .regular))
//                    .foregroundColor(AppPalette.Text.primary)
//                    .fixedSize(horizontal: false, vertical: true)
//            }
//            
//            Spacer()
//        }
//    }
//    
//    private func inviteesRow() -> some View
//    {
//        HStack(alignment: .top, spacing: 12) {
//            Image(systemName: "person.2.fill")
//                .font(.system(size: 16))
//                .foregroundColor(AppPalette.Brand.neonPink)
//                .frame(width: 24)
//            
//            VStack(alignment: .leading, spacing: 6) {
//                Text("Inviting")
//                    .font(.system(size: 12, weight: .medium))
//                    .foregroundColor(AppPalette.Text.secondary)
//                
//                VStack(alignment: .leading, spacing: 4) {
//                    ForEach(resolvedInvitees) { user in
//                        Text("@\(user.username)")
//                            .font(.system(size: 14, weight: .medium))
//                            .foregroundColor(AppPalette.Brand.spearmintGreen)
//                    }
//                }
//            }
//            
//            Spacer()
//        }
//    }
//    
//    private func formatDate(_ isoString: String) -> String
//    {
//        let iso8601Formatter = ISO8601DateFormatter()
//        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
//        
//        guard let date = iso8601Formatter.date(from: isoString) else {
//            return isoString
//        }
//        
//        let formatter = DateFormatter()
//        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
//        formatter.locale = Locale(identifier: "en_US_POSIX")
//        formatter.timeZone = TimeZone.current
//        return formatter.string(from: date)
//    }
//    
//    private func categoryName(for id: Int16) -> String
//    {
//        let categories = [
//            1: "Activiy", 2: "Sports", 3: "Outdoors", 4: "Social",
//            5: "Music", 6: "Food", 7: "Planned Trip", 8: "Spontaneous",
//            9: "Custom"
//        ]
//        return categories[Int(id)] ?? "Other"
//    }
//    
//    private func approveAndCreate() async
//    {
//        guard !isSubmitting else { return }
//        isSubmitting = true
//        errorMessage = nil
//        
//        do {
//            try await onApprove()
//        } catch {
//            errorMessage = "Failed to create meet. Please try again."
//            isSubmitting = false
//        }
//    }
//}
//
//// MARK: - Meet Preview Card (for inline chat previews)
//struct MeetPreviewCard: View
//{
//    let proposedMeet: AiChatInterfaceView.ProposedMeet
//    let resolvedInvitees: [ViewUsersModel]
//    let onCreate    : () -> Void
//    
//    var body: some View
//    {
//        VStack(alignment: .leading, spacing: 12) {
//            // Header
//            HStack(spacing: 8) {
//                Image(systemName: "doc.text.fill")
//                    .font(.system(size: 14))
//                    .foregroundColor(AppPalette.Brand.neonPink)
//                
//                Text("Meet Preview")
//                    .font(.system(size: 13, weight: .semibold))
//                    .foregroundColor(AppPalette.Text.secondary)
//            }
//            
//            // Meet details
//            VStack(spacing: 10) {
//                previewRow(icon: "calendar", label: "Event", value: proposedMeet.name)
//                previewRow(icon: "clock", label: "Starts", value: formatDate(proposedMeet.dttm_start_utc))
//                previewRow(icon: "clock.fill", label: "Ends", value: formatDate(proposedMeet.dttm_end_utc))
//                
//                if let description = proposedMeet.description, !description.isEmpty {
//                    previewRow(icon: "text.alignleft", label: "Description", value: description)
//                }
//                
//                if let categoryId = proposedMeet.meet_category_id {
//                    previewRow(icon: "tag", label: "Category", value: categoryName(for: categoryId))
//                }
//                
//                if !resolvedInvitees.isEmpty {
//                    inviteesPreviewRow()
//                }
//            }
//            
//            // Create button - BIG AND OBVIOUS
//            Button(action: onCreate) {
//                HStack(spacing: 8) {
//                    Image(systemName: "checkmark.circle.fill")
//                        .font(.system(size: 16, weight: .bold))
//                    Text("YES - CREATE THIS MEET")
//                        .font(.system(size: 16, weight: .bold))
//                        .tracking(0.5)
//                }
//                .foregroundColor(.white)
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 16)
//                .background(
//                    RoundedRectangle(cornerRadius: 12)
//                        .fill(AppPalette.Brand.neonPink)
//                        .shadow(color: AppPalette.Brand.neonPink.opacity(0.4), radius: 8, x: 0, y: 4)
//                )
//            }
//            .padding(.top, 4)
//        }
//        .padding(12)
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(Color.white.opacity(0.05))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 12)
//                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
//                )
//        )
//    }
//    
//    private func previewRow(icon: String, label: String, value: String) -> some View
//    {
//        HStack(alignment: .top, spacing: 8) {
//            Image(systemName: icon)
//                .font(.system(size: 12))
//                .foregroundColor(AppPalette.Brand.neonPink.opacity(0.8))
//                .frame(width: 20)
//            
//            VStack(alignment: .leading, spacing: 1) {
//                Text(label)
//                    .font(.system(size: 11, weight: .medium))
//                    .foregroundColor(AppPalette.Text.secondary)
//                
//                Text(value)
//                    .font(.system(size: 13, weight: .regular))
//                    .foregroundColor(AppPalette.Text.primary)
//                    .fixedSize(horizontal: false, vertical: true)
//            }
//            
//            Spacer()
//        }
//    }
//    
//    private func inviteesPreviewRow() -> some View
//    {
//        HStack(alignment: .top, spacing: 8) {
//            Image(systemName: "person.2.fill")
//                .font(.system(size: 12))
//                .foregroundColor(AppPalette.Brand.neonPink.opacity(0.8))
//                .frame(width: 20)
//            
//            VStack(alignment: .leading, spacing: 3) {
//                Text("Inviting")
//                    .font(.system(size: 11, weight: .medium))
//                    .foregroundColor(AppPalette.Text.secondary)
//                
//                HStack(spacing: 6) {
//                    ForEach(resolvedInvitees.prefix(3)) { user in
//                        Text("@\(user.username)")
//                            .font(.system(size: 12, weight: .medium))
//                            .foregroundColor(AppPalette.Brand.spearmintGreen)
//                    }
//                    
//                    if resolvedInvitees.count > 3 {
//                        Text("+\(resolvedInvitees.count - 3)")
//                            .font(.system(size: 12, weight: .medium))
//                            .foregroundColor(AppPalette.Text.secondary)
//                    }
//                }
//            }
//            
//            Spacer()
//        }
//    }
//    
//    private func formatDate(_ isoString: String) -> String
//    {
//        let iso8601Formatter = ISO8601DateFormatter()
//        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
//        
//        guard let date = iso8601Formatter.date(from: isoString) else {
//            return isoString
//        }
//        
//        let formatter = DateFormatter()
//        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
//        formatter.locale = Locale(identifier: "en_US_POSIX")
//        formatter.timeZone = TimeZone.current
//        return formatter.string(from: date)
//    }
//    
//    private func categoryName(for id: Int16) -> String
//    {
//        let categories = [
//            1: "Activiy", 2: "Sports", 3: "Outdoors", 4: "Social",
//            5: "Music", 6: "Food", 7: "Planned Trip", 8: "Spontaneous",
//            9: "Custom"
//        ]
//        return categories[Int(id)] ?? "Other"
//    }
//}
