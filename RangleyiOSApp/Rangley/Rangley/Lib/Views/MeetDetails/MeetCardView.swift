//
//  MeetCard.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/9/25.
//
import SwiftUI

// MARK: - Floating Card Content
struct MeetCardView: View
{
    let meetCardData    : MeetCardData

    var onCloseMeetCard : (MeetCardData) -> Void = { _ in }
    var onDeleteMeet    : (MeetCardData) -> Void = { _ in }
    
    @State private var showConfirmDelete = false
    @State private var isDeleting = false
    
    
    // MARK: - Date Components
    
    private var owner: String {
        "\(meetCardData.FirstName) \(meetCardData.LastName)"
    }
    private var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(meetCardData.EpochRange.startEpoch))
    }
    private var endDate: Date {
        Date(timeIntervalSince1970: TimeInterval(meetCardData.EpochRange.endEpoch))
    }
    private var timeRange: String {
        let sameDay = Calendar.current.isDate(startDate, inSameDayAs: endDate)
        let f = Self.intervalFormatter
        f.dateStyle = sameDay ? .none : .medium
        return f.string(from: startDate, to: endDate)
    }
    private static let intervalFormatter: DateIntervalFormatter = {
        let f = DateIntervalFormatter()
        f.timeZone = .current
        f.timeStyle = .short
        return f
    }()
    
    // MARK: - END Date Components
    
    
    // MARK: - Body Components
    
    private struct Pill: View
    {
        let text: String
        var systemImage: String? = nil
        var bg: Color = UkiyoPalette.Semantic.pillBackground
        
        var body: some View {
            HStack(spacing: 6) {
                if let s = systemImage { Image(systemName: s) }
                Text(text)
            }
            .font(UkiyoFonts.ukiyoTitle(size: 15))
            .foregroundColor(UkiyoPalette.Whites.paperWhite)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(bg, in: Capsule())
            .accessibilityElement(children: .combine)
        }
    }
    
    private struct GhostDivider: View
    {
        var body: some View {
            Divider()
                .overlay(UkiyoPalette.Yellows.paleStraw.opacity(0.18))
        }
    }
    
    private struct TopRightCloseButton: View
    {
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .padding(10)
                    .background(UkiyoPalette.Semantic.dangerFill, in: Circle())
                    .foregroundColor(UkiyoPalette.Whites.paperWhite)
                    .shadow(radius: 3, y: 1)
                    .accessibilityLabel("Close")
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
    }
    
    // MARK: - END Body Components
    
    
    
    
    // MARK: - Body

    @ViewBuilder var body: some View
    {
        

        //print("End Date: \(endDate), Start Date: \(startDate)")
        VStack(alignment: .leading, spacing: 12) {

            // Category + Owner chips
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Pill(text: owner, systemImage: "person.crop.circle.fill")
                
                // If you want a close button (it will MeetPopup will dissapear if you tap elsewhere) uncomment below
                //TopRightCloseButton { onCloseMeetCard(meetCardData) }
            }
            
            // Title
            Text(meetCardData.AddressName)
                .font(UkiyoFonts.ukiyoTitle(size: 22))
                .foregroundColor(UkiyoPalette.Neutrals.sumiInkBlack)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            
            // Title
            Text(meetCardData.Name)
                .font(UkiyoFonts.ukiyoTitle(size: 22))
                .foregroundColor(UkiyoPalette.Neutrals.sumiInkBlack)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            // Description
            if !meetCardData.Description.isEmpty {
                Text(meetCardData.Description)
                    .font(UkiyoFonts.ukiyoBody(size: 15))
                    .foregroundColor(UkiyoPalette.Neutrals.sumiInkBlack)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            // Meta row
            HStack(spacing: 14) {
                Label("\(meetCardData.MaxCapacity)", systemImage: "person.3.fill")
                Label(timeRange, systemImage: "clock.fill")
                    .lineLimit(1)
                    .monospacedDigit()
            }
            .font(UkiyoFonts.ukiyoCaption())
            .foregroundColor(UkiyoPalette.Blues.prussianBlue)
            .symbolRenderingMode(.hierarchical)
            .padding(.top, 2)

            GhostDivider().padding(.vertical, 4)

            // Footer actions
            HStack {
                Spacer()
                Button {
                    showConfirmDelete = true
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                        .font(UkiyoFonts.ukiyoBody(size: 14))
                        .foregroundColor(UkiyoPalette.Whites.paperWhite)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(UkiyoPalette.Semantic.dangerFill)
                .clipShape(Capsule())
                .disabled(isDeleting)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(UkiyoPalette.Semantic.cardLightBackground)
                .overlay(UkiyoPalette.Gradients.noirOverlay.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(UkiyoPalette.Semantic.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 8)
        .alert("Delete this meet?", isPresented: $showConfirmDelete) {
            Button("Delete", role: .destructive) {
                let (ok, err) = MeetCommands.delete(meetCardData: meetCardData, db: DbManager.shared.database)
                if let err { print("Delete failed: \(err)") }
                else if ok { onDeleteMeet(meetCardData) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action can’t be undone.")
        }
        
        
    }
    
    // MARK: - END Body
    
}


// MARK: - View Modifier for easy presentation
extension View
{
    public func meetPopup(
        item: Binding<MeetCardData?>,
        yOffset: CGFloat = 110,
        onCloseMeetCard: @escaping (MeetCardData) -> Void = { _ in },
        onDeleteMeet: @escaping (MeetCardData) -> Void = { _ in }
    ) -> some View
    {
        ZStack {
            self.disabled(item.wrappedValue != nil)

            if let m = item.wrappedValue {
                MeetPopupView(
                    meetCardData: m,
                    yOffset: yOffset,
                    onDismiss: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            item.wrappedValue = nil
                        }
                    },
                    onCloseMeetCard: { meet in
                        onCloseMeetCard(meet)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            item.wrappedValue = nil
                        }
                    },
                    onDeleteMeet: { meet in
                        onDeleteMeet(meet)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            item.wrappedValue = nil
                        }
                    }
                )
                .zIndex(1)
                .animation(.spring(response: 0.28, dampingFraction: 0.85),
                           value: item.wrappedValue != nil)
            }
        }
    }
}



// Reusable sheet remains unchanged
private struct ChangeReasonSheet: View
{
    let title: String
    let subtitle: String
    @Binding var reason: String
    let primaryTitle: String
    let primaryRole: ButtonRole?
    let onPrimary: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)

            TextEditor(text: $reason)
                .frame(minHeight: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.quaternary, lineWidth: 1)
                )

            HStack {
                Button("Dismiss", action: onCancel)
                Spacer()
                Button(primaryTitle, role: primaryRole, action: onPrimary)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .presentationDetents([.medium])
    }
}


private func makeDeleteBatch(
    for meet: MeetCardData,
    reason: String = "User deleted from card",
    meetStatusID: MeetStatusId = .Deleted
) -> ModifyMeetBatch
{
    ModifyMeetBatch(
        MeetCardData: meet,
        MeetStatusId: meetStatusID,
        ChangeReason: reason
    )
}

