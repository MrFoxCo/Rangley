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
// TODO: - Need to setup a refresh so that you don't have to tap on MyMeets button just to see updated shit
// TODO: - My meets button is still kinda not working 
// MARK: - IGNORE THE ABOVE TODOs FOR NOW
// =========================================================
// =========================================================
// =========================================================

import SwiftUI
import Foundation
import CoreLocation

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
    
    var body: some View
    {
        Button(action: {
            isPresented = true
            Task {
                await mapDataStore.loadMeets()
                await inbox.refresh()
            }
        }) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 18, weight: .semibold))
                .imageScale(.large)
                .foregroundStyle(AppPalette.Brand.neonPink)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppPalette.Brand.neonPink.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.55), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .topTrailing) {
                    if inbox.inviteCount > 0 {
                        CountBadge(count: inbox.inviteCount).offset(x: 4, y: -4)
                    }
                }
        }
        .sheet(isPresented: $isPresented) {
            MyMeetsOverlay(
                onMeetSelected: { meet in
                    isPresented = false
                    onMeetSelected?(meet)
                },
                onInvitationResponse: { n, status in
                    Task {
                        try? await inbox.respondToInvitation(n, statusId: status)
                        await mapDataStore.forceRefresh()
                    }
                }
            )
            .environmentObject(inbox)         // LIVE InboxStore
            .environmentObject(mapDataStore)  // LIVE MapDataStore
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
                            Circle().stroke(AppPalette.Text.secondary, lineWidth: 1)
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
                            Capsule().stroke(AppPalette.Text.secondary, lineWidth: 1)
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
    @EnvironmentObject var inbox: InboxStore
    @EnvironmentObject var mapDataStore: MapDataStore

    let onMeetSelected: ((ViewMeetsModel) -> Void)?
    let onInvitationResponse: ((ViewNotificationsModel, Int16) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0)
            {
                headerView

                ZStack
                {
                    AppPalette.Brand.russianViolet.opacity(0.05).ignoresSafeArea()

                    if mapDataStore.isLoading {
                        loadingView
                    } else if let e = mapDataStore.error {
                        errorView(e)
                    } else if mapDataStore.meets.isEmpty && inbox.notifications.isEmpty {
                        emptyStateView
                    } else {
                        MyMeetsContentView(
                            meets: mapDataStore.meets,
                            notifications: inbox.notifications,
                            onMeetSelected: onMeetSelected,
                            onInvitationResponse: onInvitationResponse
                        )
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await mapDataStore.forceRefresh()
            await inbox.refresh(force: true)
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
                .foregroundStyle(AppPalette.Text.primary)
            
            Spacer()
            
            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Color(AppPalette.Brand.formBlack))
    }
    
    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppPalette.Brand.neonPink)
            
            Text("Loading your meets...")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(AppPalette.Brand.formBlack))
    }
    
    private func errorView(_ message: String) -> some View
    {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.orange.opacity(0.7))

            VStack(spacing: 8) {
                Text("Unable to Load Meets")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.primary)

                Text(message)
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Retry") {
                Task {
                    await mapDataStore.forceRefresh()
                    await inbox.refresh(force: true)
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppPalette.Text.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppPalette.Brand.neonPink)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .background(Color(AppPalette.Brand.formBlack))
    }

    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppPalette.Brand.neonPink.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No Meets Yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("Your created meets and invitations will appear here")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.Text.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .background(Color(AppPalette.Brand.formBlack))
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

        ScrollView(.vertical, showsIndicators: false)
        {
            LazyVStack(spacing: 24) {

                // If there are invitations, put them first.
                if !invitationNotifications.isEmpty {
                    CollapsibleInvitationsSection(
                        notifications: invitationNotifications,
                        meets: meets,
                        onInvitationResponse: onInvitationResponse
                    )
                }

                // My Meets always shows (possibly empty state)
                CollapsibleOwnedMeetsSection(
                    meets: ownedMeets,
                    onMeetSelected: onMeetSelected
                )
                CollapsibleJoinedMeetsSection(
                    meets: joinedMeets,
                    onMeetSelected: onMeetSelected
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .background(Color(AppPalette.Brand.formBlack))
    }
}



// MARK: - Collapsible Owned Meets Section
struct CollapsibleOwnedMeetsSection: View
{
    let meets: [ViewMeetsModel]
    let onMeetSelected: ((ViewMeetsModel) -> Void)?
    @State private var isExpanded = true
    @State private var emptyMessage = EasterEggMessages.getRandomSelfMessage()
    
    var body: some View {
        CollapsibleMeetsSectionView(
            title: "My Meets",
            icon: "crown.fill",
            meets: meets,
            emptyMessage: emptyMessage,
            emptyIcon: "calendar.badge.plus",
            isExpanded: $isExpanded,
            onMeetSelected: onMeetSelected
        )
        .onAppear {
            emptyMessage = EasterEggMessages.getRandomSelfMessage()
        }
    }
}

struct CollapsibleJoinedMeetsSection: View
{
    let meets: [ViewMeetsModel]
    let onMeetSelected: ((ViewMeetsModel) -> Void)?
    @State private var isExpanded = true
    @State private var emptyMessage = EasterEggMessages.getRandomJoinedMessage()

    var body: some View {
        CollapsibleMeetsSectionView(
            title: "Joined Meets",
            icon: "person.2.fill",
            meets: meets,
            emptyMessage: emptyMessage,
            emptyIcon: "person.2.slash",
            isExpanded: $isExpanded,
            onMeetSelected: onMeetSelected
        )
        .onAppear {
            emptyMessage = EasterEggMessages.getRandomJoinedMessage()
        }
    }
}

struct CollapsibleInvitationsSection: View
{
    let notifications: [ViewNotificationsModel]
    let meets: [ViewMeetsModel]
    let onInvitationResponse: ((ViewNotificationsModel, Int16) -> Void)?
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            
            if isExpanded {
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
    }
    
    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "envelope")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.Brand.neonPink)
            
            Text("Invitations")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("(\(notifications.count))")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
            
            Spacer()
            
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.Brand.neonPink)
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
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
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("(\(notifications.count))")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
            
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
        // TODO: fix
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
                .background(Color(AppPalette.Surface.invitationCard))
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
                .background(Color(AppPalette.Surface.invitationCard))
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
                .background(Color(AppPalette.Surface.invitationCard))
                .cornerRadius(8)
            }
            HStack(spacing: 12) {
                Button(action: { onResponse?(notification, 6) }) {
                    Text("Accept")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black) // set the text color
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.Brand.spearmintGreen)

                Button("Decline") { onResponse?(notification, 5) }
                    .buttonStyle(.bordered)
                    .tint(AppPalette.Brand.neonPink)
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(AppPalette.Surface.invitationCard))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Something informational
struct InvitationDisclosureCard: View
{
    let notification: ViewNotificationsModel
    var onAccept: () -> Void
    var onDecline: () -> Void

    @State private var isExpanded = false
    @State private var locationName: String = "Loading location..."

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
                        .foregroundStyle(AppPalette.Text.tertiary)
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
                Button {
                    onAccept()
                } label: {
                    Text("Accept")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)          // <- force text color
                        // .foregroundStyle(AppPalette.Brand.russianViolet) // any color you want
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.Brand.spearmintGreen)
                .frame(height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))


                Button("Decline", action: onDecline)
                    .buttonStyle(.bordered)
                    .tint(AppPalette.Brand.neonPink)
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
                            labeledRow("Location", locationName)
                            if let msg = p.invitation_message, !msg.isEmpty {
                                labeledRow("Message", msg)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(AppPalette.Surface.invitationCard))
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
                                .fill(Color(AppPalette.Surface.invitationCard))
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
                .fill(Color(AppPalette.Surface.invitationCard))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.25), lineWidth: 1)
                )
        )
        .animation(.default, value: isExpanded)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Invitation from \(titleText) on \(timestamp)"))
        .onAppear {
            loadLocationName()
        }
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
    
    private func loadLocationName() {
        guard let payload = payload else {
            locationName = "Location unavailable"
            return
        }
        
        let location = CLLocation(
            latitude: payload.meet_location.latitude,
            longitude: payload.meet_location.longitude
        )
        
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if error != nil {
                    locationName = String(format: "%.4f, %.4f",
                                        payload.meet_location.latitude,
                                        payload.meet_location.longitude)
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    locationName = String(format: "%.4f, %.4f",
                                        payload.meet_location.latitude,
                                        payload.meet_location.longitude)
                    return
                }
                
                // Build a nice location name
                var components: [String] = []
                
                if let name = placemark.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                    components.append(name)
                } else if let street = placemark.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines), !street.isEmpty {
                    if let number = placemark.subThoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines), !number.isEmpty {
                        components.append("\(number) \(street)")
                    } else {
                        components.append(street)
                    }
                }
                
                if let city = placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty {
                    components.append(city)
                }
                
                if let state = placemark.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines), !state.isEmpty {
                    components.append(state)
                }
                
                if components.isEmpty {
                    locationName = String(format: "%.4f, %.4f",
                                        payload.meet_location.latitude,
                                        payload.meet_location.longitude)
                } else {
                    locationName = components.joined(separator: ", ")
                }
            }
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
                .foregroundStyle(isPlaceholder ? AppPalette.Text.primary : AppPalette.Brand.neonPink)
            
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppPalette.Text.primary)
            
            if isPlaceholder {
                Text("(Coming soon)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppPalette.Text.secondary)
            } else {
                Text("(\(meets.count))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppPalette.Text.secondary)
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
                .foregroundStyle(AppPalette.Text.tertiary)
            
            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(AppPalette.Text.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(AppPalette.Brand.formBlack))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppPalette.Text.quaternary, lineWidth: 1)
                )
        )
        .opacity(isPlaceholder ? 0.6 : 1.0)
    }
}

struct CollapsibleMeetsSectionView: View
{
    let title: String
    let icon: String
    let meets: [ViewMeetsModel]
    let emptyMessage: String
    let emptyIcon: String
    @Binding var isExpanded: Bool
    let onMeetSelected: ((ViewMeetsModel) -> Void)?
    let isPlaceholder: Bool
    
    init(
        title: String,
        icon: String,
        meets: [ViewMeetsModel],
        emptyMessage: String,
        emptyIcon: String,
        isExpanded: Binding<Bool>,
        onMeetSelected: ((ViewMeetsModel) -> Void)?,
        isPlaceholder: Bool = false
    ) {
        self.title = title
        self.icon = icon
        self.meets = meets
        self.emptyMessage = emptyMessage
        self.emptyIcon = emptyIcon
        self._isExpanded = isExpanded
        self.onMeetSelected = onMeetSelected
        self.isPlaceholder = isPlaceholder
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            
            if isExpanded {
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
    }
    
    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isPlaceholder ? AppPalette.Text.primary : AppPalette.Brand.neonPink)
            
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppPalette.Text.primary)
            
            if isPlaceholder {
                Text("(Coming soon)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppPalette.Text.secondary)
            } else {
                Text("(\(meets.count))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppPalette.Text.secondary)
            }
            
            Spacer()
            
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.Brand.neonPink)
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    private var meetsContent: some View {
        ForEach(meets) { meet in
            CollapsibleMeetCard(meet: meet, onTap: { onMeetSelected?(meet) })
        }
    }
}


struct CollapsibleMeetCard: View
{
    let meet: ViewMeetsModel
    let onTap: () -> Void
    @State private var isExpanded = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row - Always Visible
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meet.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.Text.primary)
                        .lineLimit(isExpanded ? nil : 2)
                    
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
                    
                    // Chevron for expansion
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                }
            }
            
            // Quick Info Row - Always Visible
            HStack {
                Label(dateFormatter.string(from: meet.dttm_start_utc), systemImage: "calendar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppPalette.Text.secondary)
                
                Spacer()
            }
            
            // Expanded Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(AppPalette.Text.quaternary)
                    
                    if !meet.description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppPalette.Text.secondary)
                            
                            Text(meet.description)
                                .font(.system(size: 14))
                                .foregroundStyle(AppPalette.Text.primary)
                        }
                    }
                    
                    // Additional details can go here
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Details")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppPalette.Text.secondary)
                        
                        HStack {
                            Label("Start", systemImage: "clock")
                                .font(.system(size: 12))
                                .foregroundStyle(AppPalette.Text.secondary)
                            
                            Text(dateFormatter.string(from: meet.dttm_start_utc))
                                .font(.system(size: 12))
                                .foregroundStyle(AppPalette.Text.primary)
                            
                            Spacer()
                        }
                        
                        HStack {
                            Label("End", systemImage: "clock.badge.checkmark")
                                .font(.system(size: 12))
                                .foregroundStyle(AppPalette.Text.secondary)
                            
                            Text(dateFormatter.string(from: meet.dttm_end_utc))
                                .font(.system(size: 12))
                                .foregroundStyle(AppPalette.Text.primary)
                            
                            Spacer()
                        }
                    }
                    
                    // Action Button
                    Button("View Details", action: onTap)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.Brand.neonPink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppPalette.Brand.neonPink.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(AppPalette.Surface.joinedMeetsCard))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.2), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .animation(.default, value: isExpanded)
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
                    .fill(Color(AppPalette.Surface.joinedMeetsCard))
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
                    .foregroundStyle(AppPalette.Text.primary)
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
            .foregroundStyle(AppPalette.Text.secondary)
            .lineLimit(2)
    }
    
    private var metaInfoRow: some View {
        HStack {
            Label(dateFormatter.string(from: meet.dttm_start_utc), systemImage: "calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppPalette.Text.secondary)
            
            Spacer()
            
//            Label("\(meet.max_capacity)", systemImage: "person.3")
//                .font(.system(size: 12, weight: .medium))
//                .foregroundStyle(AppPalette.Text.secondary)
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


// MARK: - Easter Egg Message Provider
struct EasterEggMessages
{
    // Cheeky messages for empty "My Meets"
    static let cheekySelfMessages = [
        "Might be time to re-watch the first 7 seasons of Game of Thrones with your buds.",
    ]
    
    // Cheeky messages for empty "Joined Meets"
    static let cheekyJoinedMessages = [
        "Make like a tomatoe, and catch up with some friends!",
        "Do you also want to go play tennis right now?"
    ]
    
    // Standard fallback messages
    static let standardSelfMessage = "You haven't created any meets yet"
    static let standardJoinedMessage = "You haven't joined any meets yet"
    
    // 20% chance for cheeky, 80% for standard
    static func getRandomSelfMessage() -> String {
        return Double.random(in: 0...1) < 0.2 ? cheekySelfMessages.randomElement()! : standardSelfMessage
    }
    
    static func getRandomJoinedMessage() -> String {
        return Double.random(in: 0...1) < 0.2 ? cheekyJoinedMessages.randomElement()! : standardJoinedMessage
    }
}

// TODO: - O

/*
 
 "Your schedule is wide open, time for something fun"
 
 "FOMO Alert NO JOined meets"
 
 "Don't see anything planned, maybe it's time to hit up one of your pals"
 
 "Working on yourself, I like it."
 
 "Might be time to re-watch the first 7 season of Game of Thrones"
 
 "Make like a tomatoe, and Ketchup with some friends!"
 
 "I remember when I had no friends"
 
 "Me time. That's what it's all about"
 
 "Maybe time to read a book, go for a walk, fold the pile of clothes in the corner of your bedroom"
 
 "What's your favorite movie? You should totally go invite some peopel to see it with you. Like right now."
 
 "GOOOOOOOOD MORNING Meet.com."
 

 
 
 
 */
