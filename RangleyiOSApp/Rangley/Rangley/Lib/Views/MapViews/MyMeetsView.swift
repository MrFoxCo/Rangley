//
//  MyMeetsView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/16/25.
//

// =========================================================
// =========================================================
// =========================================================
// MARK: - IGNORE THE BELOW TODOs FOR NOW

// TODO: - Top of this is a little compacted with the top

// MARK: - IGNORE THE ABOVE TODOs FOR NOW
// =========================================================
// =========================================================
// =========================================================

import SwiftUI
import Foundation

struct MyMeetsView: View
{
    @State private var meets        : [ViewMeetsModel] = []
    @State private var notifications: [ViewNotificationsModel] = []
    @State private var errorMessage : String?
    @State private var isLoading    = false
    @State private var isPresented  = false

    
    // These would come from your app's environment/state management
    let baseURL     : URL
    let authToken   : String
    
    // Callback for when a meet is selected
    let onMeetSelected: ((ViewMeetsModel) -> Void)?
    
    init(baseURL: URL, authToken: String, onMeetSelected: ((ViewMeetsModel) -> Void)? = nil)
    {
        self.baseURL        = baseURL
        self.authToken      = authToken
        self.onMeetSelected = onMeetSelected
    }
    
    var body: some View {
        Button(action: {
            isPresented = true
            Task {
                await loadMeets()
            }
        }) {
            VStack(spacing: 2) {
                Text("My Meets")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(AppPalette.Brand.neonPink)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppPalette.Brand.neonPink.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppPalette.Brand.neonPink.opacity(0.55), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .frame(height: 48)
            .fixedSize(horizontal: true, vertical: false)
            .lineLimit(1)
            .foregroundColor(.white)
        }
        .sheet(isPresented: $isPresented) {
            MyMeetsOverlay(
                meets: meets,
                notifications: notifications,  // ADD THIS
                isLoading: isLoading,
                errorMessage: errorMessage,
                onRetry: {
                    Task {
                        await loadMeets()
                    }
                },
                onMeetSelected: { meet in
                    isPresented = false
                    onMeetSelected?(meet)
                },
                onInvitationResponse: { notification, responseStatusId in  // ADD THIS
                    Task {
                        await respondToInvitation(notification: notification, responseStatusId: responseStatusId)
                    }
                }
            )
        }
    }
    
    // Update your loadMeets function to also load notifications
    private func loadMeets() async
    {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load both meets and notifications concurrently
            async let meetsTask = AuthAPI.viewMeets(baseURL: baseURL, token: authToken)
            async let notificationsTask = AuthAPI.viewNotifications(baseURL: baseURL, token: authToken)
            
            let allMeets = try await meetsTask
            let allNotifications = try await notificationsTask
            
            await MainActor.run {
                self.meets = allMeets
                self.notifications = allNotifications
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // ADD THIS FUNCTION
    private func respondToInvitation(notification: ViewNotificationsModel, responseStatusId: Int16) async
    {
        do {
            let body = RespondToInviteBody(
                meet_id_uuid: notification.meet_id_uuid,
                response_status_id: responseStatusId
            )
            
            _ = try await AuthAPI.respondToInvitation(
                baseURL: baseURL,
                token: authToken,
                body: body
            )
            
            // Reload data after responding
            await loadMeets()
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to respond to invitation: \(error.localizedDescription)"
            }
        }
    }
    
}


// MARK: - MyMeetsOverlay
struct MyMeetsOverlay: View
{
    let meets           : [ViewMeetsModel]
    let notifications   : [ViewNotificationsModel]
    let isLoading       : Bool
    let errorMessage    : String?
    let onRetry         : () -> Void
    let onMeetSelected  : ((ViewMeetsModel) -> Void)?
    let onInvitationResponse: ((ViewNotificationsModel, Int16) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View
    {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                
                ZStack {
                    AppPalette.Brand.russianViolet.opacity(0.05)
                        .ignoresSafeArea()
                    
                    if isLoading {
                        loadingView
                    } else if let errorMessage = errorMessage {
                        errorView(errorMessage)
                    } else if meets.isEmpty && notifications.isEmpty {
                        emptyStateView
                    } else {
                        MyMeetsContentView(
                            meets: meets,
                            notifications: notifications,
                            onMeetSelected: onMeetSelected,
                            onInvitationResponse: onInvitationResponse
                        )
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}


// MARK: - Content Views
private extension MyMeetsOverlay
{
    var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppPalette.Brand.neonPink.opacity(0.1))
                    )
            }
            
            Spacer()
            
            Text("My Meets")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primary)
            
            Spacer()
            
            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppPalette.Brand.neonPink)
            
            Text("Loading your meets...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.orange.opacity(0.7))
            
            VStack(spacing: 8) {
                Text("Unable to Load Meets")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.primary)
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Retry") {
                onRetry()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppPalette.Brand.neonPink)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No Meets Yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.primary)
                
                Text("Your created meets and invitations will appear here")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}


// MARK: - Content View


/// Meet Notification IDS
///0    NULL_VALUE
///1    Meet Created
///2    Meet Updated
///3    Meet Cancelled
///4    New Attendee
///5    Attendee Left
///6    Meet Reminder
///7    System Alert
///8    Meet Invitation Received
///9    Meet Invitation Accepted
///10    Meet Invitation Declined
///11    Meet Invitation Expired
///12    Meet Full
///13    Meet Role Changed
///14    Meet Location Changed
struct MyMeetsContentView     : View
{
    let meets: [ViewMeetsModel]
    let notifications: [ViewNotificationsModel]  // ADD THIS
    let onMeetSelected: ((ViewMeetsModel) -> Void)?
    let onInvitationResponse: ((ViewNotificationsModel, Int16) -> Void)?  // ADD THIS

    
    private var ownedMeets: [ViewMeetsModel] {
        meets.filter { $0.is_owner }
    }
    
    private var invitationNotifications: [ViewNotificationsModel] {
        notifications.filter { notification in
            notification.notification_type_id == 8 &&
            notification.participant_status_id == 4
        }
    }
    
    // For showing unread count (if needed elsewhere)
    private var unreadCount: Int {
        notifications.filter { !$0.is_read }.count
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 24) {
                OwnedMeetsSection(
                    meets: ownedMeets,
                    onMeetSelected: onMeetSelected
                )
                
                InvitationsSection(  // UPDATE THIS
                     notifications: invitationNotifications,
                     meets: meets,
                     onInvitationResponse: onInvitationResponse
                 )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}


// MARK: - Owned Meets Section
struct OwnedMeetsSection      : View
{
    let meets: [ViewMeetsModel]
    let onMeetSelected: ((ViewMeetsModel) -> Void)?
    
    var body: some View {
        MeetsSectionView(
            title: "My Meets",
            icon: "crown.fill",
            meets: meets,
            emptyMessage: "You haven't created any meets yet",
            emptyIcon: "calendar.badge.plus",
            onMeetSelected: onMeetSelected
        )
    }
}


struct InvitationsSection: View
{
    let notifications: [ViewNotificationsModel]
    let meets: [ViewMeetsModel]
    let onInvitationResponse: ((ViewNotificationsModel, Int16) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            
            if notifications.isEmpty {
                EmptyMeetsSectionView(
                    message: "No pending invitations",
                    icon: "envelope",
                    isPlaceholder: false
                )
            } else {
                invitationsContent
            }
        }
    }
    
    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "envelope")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.Brand.neonPink)
            
            Text("Invitations")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primary)
            
            Text("(\(notifications.count))")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    private var invitationsContent: some View
    {
        ForEach(notifications) { notification in
            InvitationCard(
                notification: notification,
                onResponse: onInvitationResponse
            )
        }
    }
}


private func prettyPayload(_ raw: String?) -> String {
    guard var s = raw, !s.isEmpty else { return "(payload_json is nil/empty)" }

    // unwrap one layer of quotes if server double-quoted
    if s.first == "\"", s.last == "\"" {
        s.removeFirst(); s.removeLast()
    }

    // try base64 → utf8 string
    if let b64 = Data(base64Encoded: s), let str = String(data: b64, encoding: .utf8) {
        s = str
    }

    // pretty JSON if possible
    if let data = s.data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: data),
       let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
       let out = String(data: pretty, encoding: .utf8) {
        return out
    }
    return s // fallback: show whatever we have
}

struct InvitationCard: View
{
    let notification: ViewNotificationsModel
    let onResponse: ((ViewNotificationsModel, Int16) -> Void)?

    private var meetInfo: InvitationPayload? {
        notification.decodePayload(as: InvitationPayload.self)
    }

    @State private var showRaw = true // default ON so you can see it immediately

    init(notification: ViewNotificationsModel, onResponse: ((ViewNotificationsModel, Int16) -> Void)?) {
        self.notification = notification
        self.onResponse = onResponse
        
        // Log the payload to terminal immediately on init
        print("=== INVITATION CARD DEBUG ===")
        print("Notification ID: \(notification.notification_id)")
        print("Notification Name: \(notification.notification_name)")
        print("Meet ID UUID: \(notification.meet_id_uuid)")
        print("Participant Status ID: \(notification.participant_status_id)")
        print("Is Read: \(notification.is_read)")
        
        if let payload = notification.payload_json {
            print("Raw payload_json: \(payload)")
            
            // Try to pretty print it
            var s = payload
            if s.first == "\"" && s.last == "\"" {
                s.removeFirst()
                s.removeLast()
                print("After removing quotes: \(s)")
            }
            
            if let data = Data(base64Encoded: s),
               let decoded = String(data: data, encoding: .utf8) {
                print("Base64 decoded: \(decoded)")
                
                if let jsonData = decoded.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData),
                   let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    print("Pretty printed JSON:\n\(prettyString)")
                }
            } else if let jsonData = s.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData),
                      let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
                      let prettyString = String(data: prettyData, encoding: .utf8) {
                print("Pretty printed JSON:\n\(prettyString)")
            }
        } else {
            print("WARNING: payload_json is NIL!")
        }
        print("============================")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Always show the notification name first
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.notification_name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    
                    Text("Notification ID: \(notification.notification_id)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                }
                
                Spacer()
                
                Image(systemName: "envelope.badge")
                    .foregroundStyle(AppPalette.Brand.neonPink)
            }
            
            // Show decoded info if available
            if let info = meetInfo {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Meet: \(info.meet_name)")
                        .font(.system(size: 14, weight: .medium))
                    
                    if let msg = info.invitation_message, !msg.isEmpty {
                        Text("Message: \(msg)")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    
                    Label(info.meet_start.formatted(date: .abbreviated, time: .shortened),
                          systemImage: "calendar")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            // Debug section - always visible
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Show raw JSON", isOn: $showRaw)
                    .font(.system(size: 13, weight: .medium))
                
                if showRaw {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Raw payload_json:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                        
                        // Show the raw string first
                        if let rawPayload = notification.payload_json {
                            ScrollView(.vertical) {
                                Text(rawPayload)
                                    .font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(Color.primary)
                            }
                            .frame(height: 120)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            
                            // Try to pretty print it
                            if let prettyVersion = tryPrettyPrint(rawPayload), prettyVersion != rawPayload {
                                Text("Pretty printed:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
                                    .padding(.top, 8)
                                
                                ScrollView(.vertical) {
                                    Text(prettyVersion)
                                        .font(.system(size: 11, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .foregroundStyle(Color.primary)
                                }
                                .frame(height: 120)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(.secondarySystemBackground))
                                )
                            }
                        } else {
                            Text("payload_json is nil")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.red)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(.secondarySystemBackground))
                                )
                        }
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    print("Accept pressed for notification: \(notification.notification_id)")
                    onResponse?(notification, 6)
                }) {
                    Text("Accept")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.Brand.neonPink)
                
                Button(action: {
                    print("Decline pressed for notification: \(notification.notification_id)")
                    onResponse?(notification, 5)
                }) {
                    Text("Decline")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1.5)
                )
        )
    }
    
    private func tryPrettyPrint(_ raw: String) -> String? {
        var s = raw
        
        // Remove outer quotes if present
        if s.first == "\"" && s.last == "\"" {
            s.removeFirst()
            s.removeLast()
        }
        
        // Try to decode as base64
        if let data = Data(base64Encoded: s),
           let decoded = String(data: data, encoding: .utf8) {
            s = decoded
        }
        
        // Try to pretty print as JSON
        if let data = s.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        
        return nil
    }
}



// MARK: - Generic Meets Section
struct MeetsSectionView       : View
{
    let title: String
    let icon: String
    let meets: [ViewMeetsModel]
    let emptyMessage: String
    let emptyIcon: String
    let onMeetSelected: ((ViewMeetsModel) -> Void)?
    let isPlaceholder: Bool
    
    init(
        title: String,
        icon: String,
        meets: [ViewMeetsModel],
        emptyMessage: String,
        emptyIcon: String,
        onMeetSelected: ((ViewMeetsModel) -> Void)?,
        isPlaceholder: Bool = false
    ) {
        self.title = title
        self.icon = icon
        self.meets = meets
        self.emptyMessage = emptyMessage
        self.emptyIcon = emptyIcon
        self.onMeetSelected = onMeetSelected
        self.isPlaceholder = isPlaceholder
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            
            if meets.isEmpty {
                EmptyMeetsSectionView(
                    message: emptyMessage,
                    icon: emptyIcon,
                    isPlaceholder: isPlaceholder
                )
            } else {
                meetsContent
            }
        }
    }
    
    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isPlaceholder ? Color.secondary : AppPalette.Brand.neonPink)
            
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primary)
            
            if isPlaceholder {
                Text("(Coming soon)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.secondary)
            } else {
                Text("(\(meets.count))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    private var meetsContent: some View {
        ForEach(meets) { meet in
            MeetCard(meet: meet, onTap: { onMeetSelected?(meet) })
        }
    }
}


// MARK: - Empty Section View
struct EmptyMeetsSectionView  : View
{
    let message: String
    let icon: String
    let isPlaceholder: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.secondary.opacity(0.6))
            
            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        )
        .opacity(isPlaceholder ? 0.6 : 1.0)
    }
}


// MARK: - Meet Card
struct MeetCard: View
{
    let meet: ViewMeetsModel
    let onTap: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow
                
                if !meet.description.isEmpty {
                    descriptionText
                }
                
                metaInfoRow
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meet.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                
                Text(meet.category_name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.Brand.neonPink)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if meet.is_owner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.orange)
                }
                
                Image(systemName: categoryIcon(for: meet.category_name))
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.7))
            }
        }
    }
    
    private var descriptionText: some View {
        Text(meet.description)
            .font(.system(size: 14))
            .foregroundStyle(Color.secondary)
            .lineLimit(2)
    }
    
    private var metaInfoRow: some View {
        HStack {
            Label(dateFormatter.string(from: meet.dttm_start_utc), systemImage: "calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.secondary)
            
            Spacer()
            
            Label("\(meet.max_capacity)", systemImage: "person.3")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.secondary)
        }
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "activity": return "figure.run"
        case "sports": return "sportscourt"
        case "outdoors": return "tree"
        case "social": return "person.2"
        case "music": return "music.note"
        case "food": return "fork.knife"
        case "planned trip": return "airplane"
        default: return "calendar"
        }
    }
}
