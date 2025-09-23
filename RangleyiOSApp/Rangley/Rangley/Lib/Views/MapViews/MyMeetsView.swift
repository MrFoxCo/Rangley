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
// TODO: - NEED TO ADD LITTLE Meet Participants if there are other meet participants

// MARK: - IGNORE THE ABOVE TODOs FOR NOW
// =========================================================
// =========================================================
// =========================================================

import SwiftUI
import Foundation

struct MyMeetsView: View
{
    @EnvironmentObject var inbox: InboxStore
    @ObservedObject var mapDataStore: MapDataStore // Use global store instead of local state
    
    @State private var isPresented = false
    
    // These would come from your app's environment/state management
    let baseURL: URL
    let authToken: String
    
    // Callback for when a meet is selected
    let onMeetSelected: ((ViewMeetsModel) -> Void)?
    
    init(
        baseURL: URL,
        authToken: String,
        mapDataStore: MapDataStore, // Add this parameter
        onMeetSelected: ((ViewMeetsModel) -> Void)? = nil
    ) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.mapDataStore = mapDataStore
        self.onMeetSelected = onMeetSelected
    }
    
    var body: some View {
        Button(action: {
            isPresented = true
            Task {
                await mapDataStore.loadMeets() // Use global store
                await inbox.refresh()
            }
        }) {
            VStack(spacing: 2) {
                Text("My Meets")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(AppPalette.Brand.neonPink)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppPalette.Brand.neonPink.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppPalette.Brand.neonPink.opacity(0.55), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .frame(height: 48)
            .fixedSize(horizontal: true, vertical: false)
            .overlay(alignment: .topTrailing) {
                if inbox.inviteCount > 0 {
                    CountBadge(count: inbox.inviteCount).offset(x: 8, y: -8)
                }
            }
        }
        .sheet(isPresented: $isPresented) {
            MyMeetsOverlay(
                meets: mapDataStore.meets, // Use global state
                notifications: inbox.notifications,
                isLoading: mapDataStore.isLoading, // Use global loading state
                errorMessage: mapDataStore.error, // Use global error state
                onRetry: {
                    Task {
                        await mapDataStore.forceRefresh() // Use global refresh
                        await inbox.refresh()
                    }
                },
                onMeetSelected: { meet in
                    isPresented = false
                    onMeetSelected?(meet)
                },
                onInvitationResponse: { n, status in
                    Task {
                        try? await inbox.respondToInvitation(n, statusId: status)
                        await mapDataStore.forceRefresh() // This will update global state immediately
                    }
                }
            )
        }
    }
    
    private struct CountBadge: View
    {
        let count: Int

        private var text: String {
            if count > 99 { return "99+" }
            return "\(count)"
        }

        private var size: CGFloat {
            (count <= 9) ? 18 : 22
        }

        var body: some View {
            Group {
                if count <= 99 {
                    Text(text)
                        .font(.system(size: count <= 9 ? 11 : 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: size, height: size)
                        .background(
                            Circle().fill(AppPalette.Brand.neonPink)
                        )
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.85), lineWidth: 1)
                        )
                        .accessibilityHidden(true)
                } else {
                    Text(text)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(
                            Capsule().fill(AppPalette.Brand.neonPink)
                        )
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.85), lineWidth: 1)
                        )
                        .accessibilityHidden(true)
                }
            }
            .shadow(color: AppPalette.Brand.neonPink.opacity(0.35), radius: 4, x: 0, y: 1)
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
struct MyMeetsContentView: View
{
    let meets: [ViewMeetsModel]
    let notifications: [ViewNotificationsModel]
    let onMeetSelected: ((ViewMeetsModel) -> Void)?
    let onInvitationResponse: ((ViewNotificationsModel, Int16) -> Void)?

    private var ownedMeets: [ViewMeetsModel]   { meets.filter {  $0.is_owner } }
    private var joinedMeets: [ViewMeetsModel]  { meets.filter { !$0.is_owner } }

    private var invitationNotifications: [ViewNotificationsModel] {
        notifications.filter {
            $0.notification_type_id == 8 && $0.participant_status_id == 4
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 24) {

                // 👇 If there are invitations, put them first.
                if !invitationNotifications.isEmpty {
                    InvitationsSection(
                        notifications: invitationNotifications,
                        meets: meets,
                        onInvitationResponse: onInvitationResponse
                    )
                }

                // My Meets always shows (possibly empty state)
                OwnedMeetsSection(
                    meets: ownedMeets,
                    onMeetSelected: onMeetSelected
                )
                JoinedMeetsSection(
                    meets: joinedMeets,
                    onMeetSelected: onMeetSelected
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

struct JoinedMeetsSection: View
{
    let meets: [ViewMeetsModel]
    let onMeetSelected: ((ViewMeetsModel) -> Void)?

    var body: some View {
        MeetsSectionView(
            title: "Joined Meets",
            icon: "person.2.fill",
            meets: meets,
            emptyMessage: "You haven’t joined any meets yet",
            emptyIcon: "person.2.slash",
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
            InvitationDisclosureCard(
                notification: notification,
                onAccept: { onInvitationResponse?(notification, 6) },
                onDecline: { onInvitationResponse?(notification, 5) }
            )
        }
    }
}

// 3) Recursive key/value renderer
struct JSONKeyValueView: View
{
    let value: Any
    var body: some View {
        switch value {
        case let dict as [String: Any]:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(dict.keys.sorted(), id: \.self) { k in
                    HStack(alignment: .top, spacing: 8) {
                        Text(k + ":")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .leading)
                        JSONKeyValueView(value: dict[k] as Any)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        case let arr as [Any]:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(arr.enumerated()), id: \.offset) { idx, el in
                    HStack(alignment: .top, spacing: 8) {
                        Text("[\(idx)]")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .leading)
                        JSONKeyValueView(value: el)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        case let num as NSNumber:
            Text(num.stringValue).font(.system(size: 12, design: .monospaced))
        case let s as String:
            Text(s).font(.system(size: 12, design: .monospaced))
        case _ as NSNull:
            Text("null").italic().font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
        default:
            Text("\(value)").font(.system(size: 12, design: .monospaced))
        }
    }
}


// In InvitationCard
struct InvitationCard: View
{
    let notification: ViewNotificationsModel
    let onResponse: ((ViewNotificationsModel, Int16) -> Void)?

    @State private var showRaw = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(notification.notification_name).font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: "envelope.badge").foregroundStyle(AppPalette.Brand.neonPink)
            }

            // Prefer typed payload when available:
            if let typed: InvitationPayload = notification.payload() {
                // Show a nice key/value or custom view using typed values:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Meet: \(typed.meet_name)")
                    Text("Starts: \(typed.meet_start.formatted())")
                    Text("Ends: \(typed.meet_end.formatted())")
                    Text("Category: \(typed.category_name)")
                }
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            // Else, fall back to generic Any renderer:
            else if let any = notification.payloadAny() {
                ScrollView(.vertical) {
                    JSONKeyValueView(value: any)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 240)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            } else {
                // Loud diagnostics
                VStack(alignment: .leading, spacing: 6) {
                    Text("payload_json could not be parsed").foregroundStyle(.red)
                    if let s = notification.payload_json {
                        Text("length=\(s.count)").font(.system(size: 12, design: .monospaced))
                        Text("prefix=\(s.prefix(40))").font(.system(size: 12, design: .monospaced))
                        Text("suffix=\(s.suffix(40))").font(.system(size: 12, design: .monospaced))
                    } else {
                        Text("payload_json = nil").font(.system(size: 12, design: .monospaced))
                    }
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
            HStack(spacing: 12) {
                Button("Accept") { onResponse?(notification, 6) }
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.Brand.neonPink)
                Button("Decline") { onResponse?(notification, 5) }
                    .buttonStyle(.bordered)
                Spacer()
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
}


struct InvitationDisclosureCard: View
{
    let notification: ViewNotificationsModel
    var onAccept: () -> Void
    var onDecline: () -> Void

    @State private var isExpanded = false

    // prefer typed payload first; fall back to generic Any
    private var payload: InvitationPayload? { notification.payload(InvitationPayload.self) }
    private var payloadAny: Any? { notification.payloadAny() }

    private var titleText: String {
        // show inviter display name when we have it; else creator_display_name; else fallback
        payload?.invited_by_display_name
        ?? payload?.invited_by_username
        ?? notification.creator_display_name
        ?? "Invitation"
    }

    private var timestamp: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: notification.dttm_notification_created_utc)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // HEADER (compact look like your top card)
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppPalette.Brand.neonPink.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(timestamp)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                }

                Spacer()

                // disclosure chevron
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.Brand.neonPink)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    isExpanded.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            // ACTIONS (always visible like your top card)
            HStack(spacing: 12) {
                Button("Accept", action: onAccept)
                    .buttonStyle(.borderedProminent)
                    .tint(AppPalette.Brand.neonPink)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button("Decline", action: onDecline)
                    .buttonStyle(.bordered)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer(minLength: 0)
            }

            // EXPANDED CONTENT
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {

                    // elegant summary from typed payload
                    if let p = payload {
                        VStack(alignment: .leading, spacing: 6) {
                            labeledRow("Meet", p.meet_name)
                            labeledRow("When",
                                       "\(p.meet_start.formatted(date: .abbreviated, time: .shortened)) → \(p.meet_end.formatted(date: .omitted, time: .shortened))")
                            labeledRow("Category", p.category_name)
                            labeledRow("Location",
                                       String(format: "%.5f, %.5f",
                                              p.meet_location.latitude, p.meet_location.longitude))
                            if let msg = p.invitation_message, !msg.isEmpty {
                                labeledRow("Message", msg)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.secondarySystemBackground).opacity(0.8))
                        )
                    }
                    // fallback generic renderer
                    else if let any = payloadAny {
                        ScrollView(.vertical) {
                            JSONKeyValueView(value: any)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                        .frame(maxHeight: 240)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.secondarySystemBackground).opacity(0.8))
                        )
                    } else {
                        Text("No additional details.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.25), lineWidth: 1)
                )
        )
        .animation(.default, value: isExpanded)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Invitation from \(titleText) on \(timestamp)"))
    }

    // small helper for the summary rows
    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                if !meet.is_owner {
                    Text("Hosted by \(meet.display_name)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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
