////
////  MeetCreationFomView.swift
////  Rangley
////
////  Created by Anthony Guzzardo on 9/12/25.
////
//
//import SwiftUI
//import CoreLocation
//
//struct MeetCreationFormView: View {
//    let locationInfo: LocationInfo
//    let onConfirm: (String, Date, Date) -> Void
//    let onBack: () -> Void
//
//    @State private var meetName = ""
//    @State private var startTime = Date()
//    @State private var endTime = Date().addingTimeInterval(3600) // Default 1 hour later
//    @State private var maxCapacity = ""
//    @State private var unlimitedCapacity = true
//    @State private var capacityRaw: String = "8"   // required; user-editable numeric text
//
//
//
//
//    @State private var isAnimating = false
//    @State private var currentFieldStep: FieldStep = .name
//
//    @FocusState private var isNameFieldFocused: Bool
//    @FocusState private var isCapacityFieldFocused: Bool
//
//    
//    
//    enum FieldStep: CaseIterable {
//        case name,
//             startTime,
//             endTime,
////             capacity,
//             review
//
//        var title: String {
//            switch self {
//            case .name: return "Name your meet"
//            case .startTime: return "When does it start?"
//            case .endTime: return "When does it end?"
////            case .capacity: return "Set capacity (optional)"
//            case .review: return "Review & Create"
//            }
//        }
//
//        var stepNumber: Int {
//            switch self {
//            case .name: return 1
//            case .startTime: return 2
//            case .endTime: return 3
////            case .capacity: return 4
//            case .review: return 4
//            }
//        }
//    }
//
//    private var locationDisplayName: String {
//        if let name = locationInfo.Name, !name.isEmpty { return name }
//        if let thoroughfare = locationInfo.ThoroughFare { return thoroughfare }
//        if let locality = locationInfo.Locality { return locality }
//        return "Selected location"
//    }
//
////    private func adjustCapacity(_ delta: Int) {
////        let current = Int(capacityRaw) ?? 0
////        let next = max(2, current + delta)
////        capacityRaw = String(next)
////    }
//
//    private var canProceed: Bool {
//        switch currentFieldStep {
//        case .name:
//            return !meetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
//        case .startTime:
//            return true
//        case .endTime:
//            return endTime > startTime
////        case .capacity:
////            return (Int(capacityRaw) ?? 0) >= 2
//        case .review:
//            return !meetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
//                && endTime > startTime
////                && (Int(capacityRaw) ?? 0) >= 2
//        }
//    }
//
//
//    private func nextStep()
//    {
//        withAnimation(.spring(response: 0.3, dampingFraction: 0.8))
//        {
//            switch currentFieldStep
//            {
//            case .name:
//                currentFieldStep = .startTime
//            case .startTime:
//                currentFieldStep = .endTime
//            case .endTime:
//                currentFieldStep = .review
////            case .capacity:
////                currentFieldStep = .review
//            case .review:
////                let cap = max(2, Int(capacityRaw) ?? 2)
////                onConfirm(meetName, startTime, endTime, cap)   // still Int? param; pass non-nil
//                onConfirm(meetName, startTime, endTime)
//
//            }
//        }
//    }
//
//    private func previousStep()
//    {
//        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//            switch currentFieldStep {
//            case .name:
//                onBack()
//            case .startTime:
//                currentFieldStep = .name
//            case .endTime:
//                currentFieldStep = .startTime
////            case .capacity:
////                currentFieldStep = .endTime
//            case .review:
//                currentFieldStep = .endTime
//            }
//        }
//    }
//
//    
//    
//    var body: some View
//    {
//        VStack(spacing: 0) {
//            // Header with back button and progress
//            VStack(spacing: 16) {
//                HStack {
//                    Button(action: previousStep) {
//                        HStack(spacing: 4) {
//                            Image(systemName: "chevron.left")
//                                .font(.system(size: 16, weight: .medium))
//                            Text(currentFieldStep == .name ? "Cancel" : "Back")
//                                .font(.system(size: 16, weight: .medium))
//                        }
//                        .foregroundColor(AppPalette.Brand.neonPink)
//                    }
//
//                    Spacer()
//
//                    // Step indicator
//                    Text("Step \(currentFieldStep.stepNumber) of 5")
//                        .font(.system(size: 14, weight: .medium))
//                        .foregroundColor(AppPalette.Text.secondary)
//                }
//
//                // Progress bar
//                GeometryReader { geometry in
//                    ZStack(alignment: .leading) {
//                        RoundedRectangle(cornerRadius: 2)
//                            .fill(AppPalette.Surface.fieldFill)
//                            .frame(height: 4)
//
//                        RoundedRectangle(cornerRadius: 2)
//                            .fill(AppPalette.Brand.neonPink)
//                            .frame(
//                                width: geometry.size.width * (Double(currentFieldStep.stepNumber) / 5.0),
//                                height: 4
//                            )
//                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentFieldStep)
//                    }
//                }
//                .frame(height: 4)
//            }
//            .padding(.horizontal, 24)
//            .padding(.top, 20)
//            .padding(.bottom, 24)
//
//            // Location preview (always visible)
//            VStack(alignment: .leading, spacing: 8) {
//                Label {
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text(locationDisplayName)
//                            .font(.system(size: 14, weight: .medium))
//                            .foregroundColor(AppPalette.Text.primary)
//
//                        if let locality = locationInfo.Locality,
//                           let state = locationInfo.AdministrativeArea {
//                            Text("\(locality), \(state)")
//                                .font(.system(size: 12))
//                                .foregroundColor(AppPalette.Text.secondary)
//                        }
//                    }
//                } icon: {
//                    Image(systemName: "location.fill")
//                        .foregroundColor(AppPalette.Brand.neonPink)
//                        .font(.system(size: 16))
//                }
//                .padding(12)
//                .frame(maxWidth: .infinity, alignment: .leading)
//                .background(
//                    RoundedRectangle(cornerRadius: 12)
//                        .fill(AppPalette.Surface.fieldFill)
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 12)
//                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
//                        )
//                )
//            }
//            .padding(.horizontal, 24)
//            .padding(.bottom, 24)
//
//            // Current field content
//            VStack(spacing: 24)
//            {
//                Text(currentFieldStep.title)
//                    .font(.system(size: 24, weight: .bold))
//                    .foregroundColor(AppPalette.Text.primary)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.horizontal, 24)
//
//                Group {
//                    switch currentFieldStep {
//                    case .name:
//                        VStack(alignment: .leading, spacing: 8) {
//                            TextField("", text: $meetName, prompt: Text("Enter meet name").foregroundColor(AppPalette.Text.tertiary))
//                                .font(.system(size: 18))
//                                .foregroundColor(AppPalette.Text.primary)
//                                .focused($isNameFieldFocused)
//                                .padding(16)
//                                .background(
//                                    RoundedRectangle(cornerRadius: 12)
//                                        .fill(AppPalette.Surface.fieldFill)
//                                        .overlay(
//                                            RoundedRectangle(cornerRadius: 12)
//                                                .stroke(
//                                                    isNameFieldFocused ? AppPalette.Surface.focusStroke : AppPalette.Surface.fieldStroke,
//                                                    lineWidth: isNameFieldFocused ? 2 : 1
//                                                )
//                                        )
//                                )
//                                .onAppear {
//                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                                        isNameFieldFocused = true
//                                    }
//                                }
//                        }
//                        .padding(.horizontal, 24)
//
//                    case .startTime:
//                        VStack(spacing: 16) {
//                            DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
//                                .datePickerStyle(.wheel)
//                                .labelsHidden()
//                                .accentColor(AppPalette.Brand.neonPink)
//                                .frame(height: 200)
//                                .padding(.horizontal, 8)
//                                .background(
//                                    RoundedRectangle(cornerRadius: 12)
//                                        .fill(AppPalette.Surface.fieldFill)
//                                        .overlay(
//                                            RoundedRectangle(cornerRadius: 12)
//                                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
//                                        )
//                                )
//                        }
//                        .padding(.horizontal, 24)
//
//                    case .endTime:
//                        VStack(spacing: 16) {
//                            DatePicker("", selection: $endTime, in: startTime..., displayedComponents: [.date, .hourAndMinute])
//                                .datePickerStyle(.wheel)
//                                .labelsHidden()
//                                .accentColor(AppPalette.Brand.neonPink)
//                                .frame(height: 200)
//                                .padding(.horizontal, 8)
//                                .background(
//                                    RoundedRectangle(cornerRadius: 12)
//                                        .fill(AppPalette.Surface.fieldFill)
//                                        .overlay(
//                                            RoundedRectangle(cornerRadius: 12)
//                                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
//                                        )
//                                )
//
//                            if endTime <= startTime {
//                                Text("End time must be after start time")
//                                    .font(.system(size: 12))
//                                    .foregroundColor(AppPalette.Brand.neonPink)
//                            }
//                        }
//                        .padding(.horizontal, 24)
//
////                    case .capacity:
////                        VStack(alignment: .leading, spacing: 16) {
////
////                            // Inline +/- with numeric field
////                            HStack(spacing: 12) {
////                                Button {
////                                    adjustCapacity(-1)
////                                } label: {
////                                    Image(systemName: "minus")
////                                        .font(.system(size: 14, weight: .bold))
////                                        .padding(10)
////                                        .background(RoundedRectangle(cornerRadius: 10).fill(AppPalette.Surface.fieldFill))
////                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppPalette.Surface.fieldStroke, lineWidth: 1))
////                                }
////
////                                TextField("", text: $capacityRaw,
////                                          prompt: Text("Enter max people").foregroundColor(AppPalette.Text.tertiary))
////                                    .keyboardType(.numberPad)
////                                    .multilineTextAlignment(.center)
////                                    .font(.system(size: 18, weight: .medium))
////                                    .foregroundColor(AppPalette.Text.primary)
////                                    .frame(width: 120, height: 44)
////                                    .background(
////                                        RoundedRectangle(cornerRadius: 12)
////                                            .fill(AppPalette.Surface.fieldFill)
////                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppPalette.Surface.fieldStroke, lineWidth: 1))
////                                    )
////                                    .onChange(of: capacityRaw) { newVal in
////                                        // keep only digits; strip leading zeros
////                                        let digits = newVal.filter(\.isNumber)
////                                        if digits != newVal { capacityRaw = digits }
////                                        if capacityRaw.hasPrefix("0") {
////                                            capacityRaw = String(capacityRaw.drop { $0 == "0" })
////                                        }
////                                    }
////
////                                Button {
////                                    adjustCapacity(+1)
////                                } label: {
////                                    Image(systemName: "plus")
////                                        .font(.system(size: 14, weight: .bold))
////                                        .padding(10)
////                                        .background(RoundedRectangle(cornerRadius: 10).fill(AppPalette.Surface.fieldFill))
////                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppPalette.Surface.fieldStroke, lineWidth: 1))
////                                }
////
////                                Spacer()
////                                Text("people")
////                                    .font(.system(size: 16))
////                                    .foregroundColor(AppPalette.Text.secondary)
////                            }
////                            .padding(.horizontal, 4)
////
////                            // Quick picks
////                            HStack(spacing: 8) {
////                                ForEach([2, 4, 8, 12, 16, 24, 50, 100], id: \.self) { cap in
////                                    Button {
////                                        capacityRaw = String(cap)
////                                    } label: {
////                                        Text("\(cap)")
////                                            .font(.system(size: 14, weight: .medium))
////                                            .padding(.vertical, 8).padding(.horizontal, 12)
////                                            .background(
////                                                RoundedRectangle(cornerRadius: 10)
////                                                    .fill(Int(capacityRaw) == cap ? AppPalette.Brand.neonPink : AppPalette.Surface.fieldFill)
////                                            )
////                                            .overlay(
////                                                RoundedRectangle(cornerRadius: 10)
////                                                    .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
////                                            )
////                                            .foregroundColor(Int(capacityRaw) == cap ? .white : AppPalette.Text.primary)
////                                    }
////                                }
////                            }
////
////                            if (Int(capacityRaw) ?? 0) < 2 {
////                                Text("Capacity must be at least 2.")
////                                    .font(.system(size: 12))
////                                    .foregroundColor(AppPalette.Brand.neonPink)
////                            }
////                        }
////                        .padding(.horizontal, 24)
//                    
//                    case .review:
//                        VStack(spacing: 20) {
//                            VStack(alignment: .leading, spacing: 16) {
//                                DetailRow(label: "Meet Name", value: meetName)
//                                DetailRow(label: "Start", value: formatDate(startTime))
//                                DetailRow(label: "End", value: formatDate(endTime))
//                                DetailRow(label: "Duration", value: formatDuration(from: startTime, to: endTime))
//                                DetailRow(label: "Capacity", value: maxCapacity.isEmpty ? "Unlimited" : maxCapacity)
//                            }
//                            .padding(20)
//                            .background(
//                                RoundedRectangle(cornerRadius: 12)
//                                    .fill(AppPalette.Surface.fieldFill)
//                                    .overlay(
//                                        RoundedRectangle(cornerRadius: 12)
//                                            .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
//                                    )
//                            )
//                        }
//                        .padding(.horizontal, 24)
//                    }
//                }
//                .transition(.asymmetric(
//                    insertion: .move(edge: .trailing).combined(with: .opacity),
//                    removal: .move(edge: .leading).combined(with: .opacity)
//                ))
//            }
//
//            Spacer()
//
//            // Action button
//            Button(action: nextStep)
//            {
//                Text(currentFieldStep == .review ? "Create Meet" : (currentFieldStep == .capacity ? "Continue" : "Next"))
//                    .font(.system(size: 16, weight: .bold))
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 16)
//                    .background(
//                        RoundedRectangle(cornerRadius: 12)
//                            .fill(canProceed ? AppPalette.Brand.neonPink : AppPalette.Brand.neonPink.opacity(0.5))
//                    )
//            }
//            .disabled(!canProceed)
//            .padding(.horizontal, 24)
//            .padding(.bottom, 24)
//        }
//        .background(
//            RoundedRectangle(cornerRadius: 24)
//                .fill(AppPalette.Brand.russianViolet)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 24)
//                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
//                )
//        )
//        .shadow(color: AppPalette.Brand.neonPink.opacity(0.3), radius: 20, x: 0, y: 10)
//        .scaleEffect(isAnimating ? 1 : 0.95)
//        .opacity(isAnimating ? 1 : 0)
//        .onAppear {
//            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
//                isAnimating = true
//            }
//            // keep end >= start if user scrolls start earlier
//            if endTime <= startTime { endTime = startTime.addingTimeInterval(3600) }
//        }
//        .onChange(of: startTime) { newStart in
//            if endTime <= newStart { endTime = newStart.addingTimeInterval(3600) }
//        }
//        .onTapGesture {
//            isNameFieldFocused = false
//            isCapacityFieldFocused = false
//        }
//    }
//
//    private func formatDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
//        return formatter.string(from: date)
//    }
//
//    private func formatDuration(from start: Date, to end: Date) -> String {
//        let interval = max(0, end.timeIntervalSince(start))
//        let hours = Int(interval) / 3600
//        let minutes = (Int(interval) % 3600) / 60
//        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
//        if hours > 0 { return "\(hours) hour\(hours > 1 ? "s" : "")" }
//        return "\(minutes) minutes"
//    }
//}
//
//struct DetailRow: View {
//    let label: String
//    let value: String
//
//    var body: some View {
//        HStack {
//            Text(label)
//                .font(.system(size: 14))
//                .foregroundColor(AppPalette.Text.secondary)
//
//            Spacer()
//
//            Text(value)
//                .font(.system(size: 14, weight: .medium))
//                .foregroundColor(AppPalette.Text.primary)
//        }
//    }
//}
//
//// Updated Overlay with both popups
//struct MeetCreationOverlay: View {
//    @Binding var selectedLocation: LocationInfo?
//    @Binding var showPopup: Bool
//    let onCreateMeet: (LocationInfo, String, Date, Date) -> Void
//
//    @State private var currentStep: Step = .locationConfirm
//
//    enum Step { case locationConfirm, meetDetails }
//
//    var body: some View {
//        ZStack {
//            if showPopup, let location = selectedLocation {
//                Color.black.opacity(0.4)
//                    .ignoresSafeArea()
//                    .onTapGesture {
//                        if currentStep == .locationConfirm {
//                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                                showPopup = false
//                                currentStep = .locationConfirm
//                            }
//                        }
//                    }
//
//                Group {
//                    switch currentStep {
//                    case .locationConfirm:
//                        LocationConfirmationPopupView(
//                            locationInfo: location,
//                            onConfirm: {
//                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                                    currentStep = .meetDetails
//                                }
//                            },
//                            onCancel: {
//                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                                    showPopup = false
//                                    currentStep = .locationConfirm
//                                }
//                            }
//                        )
//                        .transition(.asymmetric(
//                            insertion: .scale.combined(with: .opacity),
//                            removal: .scale(scale: 0.95).combined(with: .opacity)
//                        ))
//
//                    case .meetDetails:
//                        MeetCreationFormView(
//                            locationInfo: location,
//                            onConfirm: { name, startTime, endTime in
//                                onCreateMeet(location, name, startTime, endTime)
//                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                                    showPopup = false
//                                    currentStep = .locationConfirm
//                                }
//                            },
//                            onBack: {
//                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                                    currentStep = .locationConfirm
//                                }
//                            }
//                        )
//                        .frame(maxWidth: 400, maxHeight: 650)
//                        .transition(.asymmetric(
//                            insertion: .move(edge: .trailing).combined(with: .opacity),
//                            removal: .scale(scale: 0.95).combined(with: .opacity)
//                        ))
//                    }
//                }
//            }
//        }
//        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPopup)
//        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentStep)
//    }
//}
