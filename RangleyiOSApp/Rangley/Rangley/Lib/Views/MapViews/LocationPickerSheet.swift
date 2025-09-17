//
//  LocationPickerSheet.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/16/25.
//


// =========================================================
// =========================================================
// =========================================================
// MARK: - IGNORE THE BELOW TODOs FOR NOW

// TODO: - Figure out radius logic is a little messy

// MARK: - IGNORE THE ABOVE TODOs FOR NOW
// =========================================================
// =========================================================
// =========================================================


import SwiftUI

/// Used for manually searching the address by typing or creating a popup draggable map
public struct LocationPickerSheet: View
{
    let initial: LocationInfo
    let onPick: (LocationInfo) -> Void
    let onCancel: () -> Void
    
    @State private var selectedMethod: LocationMethod = .map
    @State private var isAnimating = false
    
    enum LocationMethod: String, CaseIterable {
        case map = "Pick on Map"
        case address = "Enter Address"
        
        var icon: String {
            switch self {
            case .map: return "map"
            case .address: return "magnifyingglass"
            }
        }
    }
    
    public var body: some View
    {
        VStack(spacing: 0) {
            // Header matching MeetFormView style
            HStack {
                Button(action: onCancel) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(AppPalette.Brand.neonPink)
                }
                
                Spacer()
                
                Text("Choose Location")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppPalette.Text.primary)
                
                Spacer()
                
                // Invisible button for symmetry
                Button("") {}
                    .opacity(0)
                    .disabled(true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            // Method selector with matching style
            VStack(spacing: 16) {
                Text("How would you like to pick your location?")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppPalette.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Picker("Location Method", selection: $selectedMethod) {
                    ForEach(LocationMethod.allCases, id: \.self) { method in
                        Text(method.rawValue)
                            .tag(method)
                    }
                }
                .pickerStyle(.segmented)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppPalette.Surface.fieldFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppPalette.Surface.fieldStroke, lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            // Content based on selected method
            Group {
                switch selectedMethod {
                case .map:
                    MapLocationPicker(
                        initial: initial,
                        onPick: onPick,
                        onCancel: onCancel
                    )
                case .address:
                    AddressSearchPicker(
                        initialRadiusMeters: initial.RegionRadius,
                        onPick: onPick,
                        onCancel: onCancel
                    )
                }
            }
            .transition(.opacity.combined(with: .slide))
            .animation(.easeInOut(duration: 0.3), value: selectedMethod)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(AppPalette.Brand.russianViolet)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(AppPalette.Brand.neonPink.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: AppPalette.Brand.neonPink.opacity(0.3), radius: 20, x: 0, y: 10)
        .scaleEffect(isAnimating ? 1 : 0.95)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
        .presentationDetents([.large])
    }
}
