//
//  LocationPickerSheet.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/16/25.
//

import SwiftUI

/// Streamlined address search for location selection
public struct LocationPickerSheet: View
{
    let initial: LocationInfo
    let onPick: (LocationInfo) -> Void
    let onCancel: () -> Void
    
    @State private var isAnimating = false
    
    public var body: some View
    {
        NavigationView {
            VStack(spacing: 0) {
                // Compact header
                header
                
                // Progress indicator
                progressIndicator
                
                // Address search (no method selection needed)
                AddressSearchPicker(
                    onPick: onPick,
                    onCancel: onCancel
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppPalette.Brand.russianViolet.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .scaleEffect(isAnimating ? 1 : 0.98)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - Components
    private var header: some View {
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
            
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppPalette.Brand.neonPink)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(AppPalette.Brand.neonPink.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var progressIndicator: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppPalette.Surface.fieldFill)
                    .frame(height: 3)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppPalette.Brand.neonPink)
                    .frame(
                        width: geometry.size.width * 0.5,
                        height: 3
                    )
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
