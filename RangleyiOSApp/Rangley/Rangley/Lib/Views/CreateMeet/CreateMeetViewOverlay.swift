//
//  CreateMeetUI.swift
//  Rangle
//

import SwiftUI

// MARK: - PUBLIC OVERLAY (no .sheet, detents, grabber-only drag)

public struct CreateMeetViewOverlay: View
{
    @Binding var isPresented: Bool
    @Binding var draft: CreateMeetDraft
    
    let categories  : [MeetCategory]
    
    var onStart     : () -> Void
    var onCancel    : () -> Void

    public init(isPresented: Binding<Bool>,draft: Binding<CreateMeetDraft>, categories: [MeetCategory],
                onStart: @escaping () -> Void, onCancel: @escaping () -> Void)
    {
        _isPresented    = isPresented
        _draft          = draft
        self.categories = categories
        self.onStart    = onStart
        self.onCancel   = onCancel
    }

    public var body: some View {
        ZStack {
            if isPresented {
                FlexibleBottomCard(
                    isPresented : $isPresented,
                    detents     : [0.40, 0.65, 0.85],
                    initialIndex: 1
                ) {
                    CreateMeetCard(
                        draft       : $draft,
                        categories  : categories,
                        onStart     : onStart,
                        onCancel    : { isPresented = false; onCancel() }
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.95), value: isPresented)
    }
}

/// Card to create meets
/// - Parameters:
///   - draft: Contains meet information
///   - categories: categories from tdMeetCategory
/// - Returns: View
public struct CreateMeetCard: View
{
    @Binding var draft  : CreateMeetDraft
    let categories      : [MeetCategory]
    var onStart         : () -> Void = {}
    var onCancel        : () -> Void = {}

    @FocusState private var nameFocused: Bool

    private var isValid: Bool {
        !draft.categoryName.isBlank
            && !draft.name.isBlank
            && draft.dttmEnd > draft.dttmStart
            && draft.capacity >= 1
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header chips (location if present)
            HStack(spacing: 8) {
                if let place = draft.placeName, !place.isEmpty {
                    Pill(text: place, systemImage: "mappin.circle.fill",
                         bg: UkiyoPalette.Blues.prussianBlue.opacity(0.9))
                }
                Spacer(minLength: 0)
                Pill(text: draft.categoryName.isEmpty ? "Pick a Category" : draft.categoryName)
            }

            // Category
            SectionLabel(text: "Category")
            CategoryRouletteDynamic(categories: categories, selected: $draft.categoryName)
                .frame(height: 74)

            GhostDivider().padding(.vertical, 2)

            // Name
            SectionLabel(text: "Event name")
            SoftField {
                TextField("Event name", text: $draft.name)
                    .textInputAutocapitalization(.words)
                    .font(UkiyoFonts.ukiyoBody(size: 16))
                    .foregroundColor(UkiyoPalette.Neutrals.sumiInkBlack)
                    .submitLabel(.next)
                    .focused($nameFocused)
            }

            // Dates
            SectionLabel(text: "Date & time")
            SoftField {
                DateRangeCompact(dttmStart: $draft.dttmStart, dttmEnd: $draft.dttmEnd)
                    .font(UkiyoFonts.ukiyoBody(size: 15))
                    .foregroundColor(UkiyoPalette.Neutrals.sumiInkBlack)
            }

            // Capacity
            SectionLabel(text: "Capacity")
            SoftField {
                HStack {
                    Text("Capacity")
                        .font(UkiyoFonts.ukiyoBody(size: 15))
                        .foregroundColor(UkiyoPalette.Neutrals.sumiInkBlack)

                    Spacer()

                    // Compact capacity control
                    HStack(spacing: 0) {
                        Button {
                            draft.capacity = max(1, draft.capacity - 1)
                        } label: {
                            Image(systemName: "minus")
                                .padding(.horizontal, 12).padding(.vertical, 8)
                        }

                        Text("\(draft.capacity)")
                            .font(UkiyoFonts.ukiyoHeadline(size: 16))
                            .frame(minWidth: 36)
                            .monospacedDigit()

                        Button {
                            draft.capacity = min(100, draft.capacity + 1)
                        } label: {
                            Image(systemName: "plus")
                                .padding(.horizontal, 12).padding(.vertical, 8)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(UkiyoPalette.Blues.prussianBlue.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(UkiyoPalette.Blues.prussianBlue.opacity(0.2), lineWidth: 1)
                    )
                }
            }

            // Actions
            HStack(spacing: 12) {
                PrimaryActionButton(title: "Create Event",
                                    systemImage: "sparkles",
                                    enabled: isValid) {
                    guard isValid else { return }
                    onStart()
                }
                SecondaryGhostButton(title: "Cancel") { onCancel() }
            }
            .padding(.top, 6)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(UkiyoPalette.Semantic.cardLightBackground)
                .overlay(UkiyoPalette.Gradients.noirOverlay.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(UkiyoPalette.Semantic.cardBorder, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            TopRightCloseButton { onCancel() }.padding(10)
        }
        .shadow(color: .black.opacity(0.28), radius: 22, x: 0, y: 10)
        .onAppear { nameFocused = draft.name.isBlank }
    }
}

///uses DB-provided names
public struct CategoryRouletteDynamic: View
{
    let categories: [MeetCategory]
    @Binding var selected: String
    @State private var selectionIndex = 0

    private var hasItems: Bool { !categories.isEmpty }
    private var clampedIndex: Int {
        guard hasItems else { return 0 }
        return min(max(selectionIndex, 0), categories.count - 1)
    }
    private var selectedName: String {
        hasItems ? categories[clampedIndex].Name : ""
    }

    public var body: some View {
        VStack(spacing: 8) {
            if hasItems {
                Text(selectedName)
                    .font(UkiyoFonts.ukiyoHeadline(size: 20))
                    .foregroundColor(UkiyoPalette.Neutrals.sumiInkBlack)
            }

            GeometryReader { outer in
                let itemWidth: CGFloat = 110

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        ForEach(categories.indices, id: \.self) { index in
                            GeometryReader { item in
                                let distance = abs(item.frame(in: .global).midX - outer.frame(in: .global).midX)
                                let isSelected = distance < (itemWidth / 2)

                                Text(categories[index].Name)
                                    .font(.callout.weight(.semibold))
                                    .foregroundColor(isSelected
                                                     ? UkiyoPalette.Whites.paperWhite
                                                     : UkiyoPalette.Blues.prussianBlue)
                                    .frame(width: itemWidth)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(isSelected
                                                  ? UkiyoPalette.Blues.prussianBlue
                                                  : UkiyoPalette.Blues.prussianBlue.opacity(0.1))
                                    )
                                    .scaleEffect(isSelected ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                                    .contentShape(Rectangle())
                                    .onChangeCompat(of: distance) { newDistance in
                                        if newDistance < (itemWidth / 2) {
                                            selectionIndex = index
                                            if hasItems { selected = categories[index].Name }
                                        }
                                    }
                            }
                            .frame(width: itemWidth, height: 56)
                        }
                    }
                    .padding(.horizontal, max(0, (outer.size.width - itemWidth) / 2))
                }
            }
            .frame(height: 56)
        }
        .onChangeCompat(of: categories) { _ in
            if hasItems == false {
                selectionIndex = 0
                selected = ""
            } else {
                if let i = categories.firstIndex(where: { $0.Name.caseInsensitiveCompare(selected) == .orderedSame }) {
                    selectionIndex = i
                } else if let i = categories.firstIndex(where: { $0.Name.caseInsensitiveCompare("Activity") == .orderedSame }) {
                    selectionIndex = i
                    selected = categories[i].Name
                } else {
                    selectionIndex = clampedIndex
                    selected = categories[selectionIndex].Name
                }
            }
        }
        .onAppear { syncInitialSelection() }
    }

    private func syncInitialSelection() {
        guard hasItems else {
            selected = ""
            selectionIndex = 0
            return
        }
        if let i = categories.firstIndex(where: { $0.Name.caseInsensitiveCompare(selected) == .orderedSame }) {
            selectionIndex = i
        } else if let i = categories.firstIndex(where: { $0.Name.caseInsensitiveCompare("Activity") == .orderedSame }) {
            selectionIndex = i
            selected = categories[i].Name
        } else {
            selectionIndex = 0
            selected = categories[0].Name
        }
    }
}

///grabber-only drag, detents, non-fullscreen
public struct FlexibleBottomCard<Content: View>: View
{
    @Binding var isPresented: Bool
    let content             : Content
    var detents             : [CGFloat] = [0.40, 0.65, 0.85]
    var initialIndex        : Int = 1

    @State private var currentIndex     : Int = 1
    @State private var height           : CGFloat = 0
    @State private var dragStartHeight  : CGFloat = 0
    @State private var dragTranslation  : CGFloat = 0

    init(isPresented: Binding<Bool>, detents: [CGFloat] = [0.40, 0.65, 0.85],
         initialIndex: Int = 1,      @ViewBuilder content: () -> Content)
    {
        _isPresented        = isPresented
        self.content        = content()
        self.detents        = detents.sorted()
        self.initialIndex   = min(max(0, initialIndex), detents.count - 1)
        _currentIndex       = State(initialValue: self.initialIndex)
    }

    public var body: some View {
        GeometryReader { geo in
            
            let screenH = geo.size.height
            let minH    = screenH * detents.first!
            let maxH    = screenH * detents.last!
            let targetH = screenH * detents[currentIndex]

            ZStack {
                if isPresented {
                    Color.black.opacity(0.22)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.95)) {
                                isPresented = false
                            }
                        }
                        .transition(.opacity)
                }

                VStack(spacing: 0) {
                    // Grabber — only this drags the sheet
                    Grabber()
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 3)
                                .onChanged { value in
                                    if height == 0 { height = targetH }
                                    dragStartHeight = (dragStartHeight == 0) ? height : dragStartHeight
                                    dragTranslation = -value.translation.height
                                    height = (dragStartHeight + dragTranslation).clamped(minH, maxH)
                                }
                                .onEnded { _ in
                                    let nearest = nearestDetentIndex(for: height, screenH: screenH)
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                                        currentIndex = nearest
                                        height = screenH * detents[nearest]
                                        dragStartHeight = 0
                                        dragTranslation = 0
                                    }
                                }
                        )

                    // Scrollable content does NOT trigger expansion
                    ScrollView(.vertical, showsIndicators: true) {
                        content
                            .padding(.bottom, 24)
                    }
                    .applyBounceBehavior()
                }
                .frame(height: max(height == 0 ? targetH : height, minH), alignment: .top)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(UkiyoPalette.Semantic.cardLightBackground)
                        .overlay(UkiyoPalette.Gradients.noirOverlay.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(UkiyoPalette.Semantic.cardBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.28), radius: 22, x: 0, y: 10)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .offset(y: isPresented ? 0 : screenH)
                .animation(.spring(response: 0.32, dampingFraction: 0.95), value: isPresented)
            }
            .onChangeCompat(of: isPresented) { shown in
                guard shown else { return }
                height          = screenH * detents[currentIndex]
                dragStartHeight = 0
                dragTranslation = 0
            }
        }
    }

    private func nearestDetentIndex(for height: CGFloat, screenH: CGFloat) -> Int
    {
        let target      = height / screenH
        var best        = 0
        var bestDelta   = CGFloat.greatestFiniteMagnitude
        
        for (i, f) in detents.enumerated() {
            let d = abs(CGFloat(f) - target)
            if d < bestDelta { bestDelta = d; best = i }
        }
        return best
    }

    private struct Grabber: View
    {
        var body: some View {
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(UkiyoPalette.Blues.prussianBlue.opacity(0.6))
                    .frame(width: 42, height: 5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle()) // easy to grab
        }
    }
}



///These are reusable bits could be place elswhere maybe
// MARK: - Class Methods

private struct Pill: View
{
    let text        : String
    var systemImage : String? = nil
    var bg          : Color = UkiyoPalette.Semantic.pillBackground

    var body: some View
    {
        HStack(spacing: 6) {
            if let s = systemImage { Image(systemName: s) }
            Text(text)
        }
        .font(UkiyoFonts.ukiyoCaption())
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
        Divider().overlay(UkiyoPalette.Semantic.cardBorder)
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
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("Close")
    }
}

private struct SectionLabel: View
{
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(UkiyoFonts.ukiyoCaption())
            .foregroundColor(UkiyoPalette.Semantic.metaText)
            .kerning(0.6)
            .padding(.top, 2)
    }
}

private struct SoftField<Content: View>: View
{
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(12)
            .background(UkiyoPalette.Whites.paperWhite, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(UkiyoPalette.Blues.prussianBlue.opacity(0.12), lineWidth: 1.2)
            )
    }
}

private struct PrimaryActionButton: View
{
    let title: String
    var systemImage: String = "plus.circle.fill"
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(UkiyoFonts.ukiyoBody(size: 16))
                .foregroundColor(UkiyoPalette.Whites.paperWhite)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(UkiyoPalette.Semantic.accentPrimary)
        .clipShape(Capsule())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
    }
}

private struct SecondaryGhostButton: View
{
    let title: String
    var systemImage: String = "xmark"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(UkiyoFonts.ukiyoBody(size: 15))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(UkiyoPalette.Semantic.dangerFill)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(UkiyoPalette.Semantic.dangerFill.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - END Class Methods



// MARK: - Extensions

private extension String {
    var isBlank: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

private extension CGFloat {
    func clamped(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let low  = Swift.min(a, b)
        let high = Swift.max(a, b)
        return Swift.max(low, Swift.min(self, high))
    }
}

private extension ScrollView {
    @ViewBuilder
    func applyBounceBehavior() -> some View {
        if #available(iOS 17.0, *) {
            self.scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }
}

// iOS 17 onChange deprecation shim
private extension View {
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value, initial: false) { _, new in perform(new) }
        } else {
            self.onChange(of: value, perform: perform)
        }
    }
}

// MARK: - END Extensions
