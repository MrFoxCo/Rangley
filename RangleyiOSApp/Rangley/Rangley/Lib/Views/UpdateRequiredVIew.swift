//
//  UpdateRequiredView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/27/25.
//

import SwiftUI

struct UpdateRequiredView: View {
    let currentVersion: String
    let latestVersion: String
    
    var body: some View {
        ZStack {
            AppPalette.Brand.japDarkerPurple.ignoresSafeArea()
            VStack(spacing: 20) {
                Image("RangleySticker")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)  // Control the size here
                
                Text("Update Required")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your app version \(currentVersion) is no longer supported.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                
                Text("Please update to version \(latestVersion) to continue using Rangley.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                
                Text("If redirection link does not work please search for update in the App Store.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                
                Button("Update Now") {
                    openAppStore()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundColor(.black)
                
                // No "Cancel" or "Later" button - force the update
            }
            .padding()
        }
    }
    
    private func openAppStore() {
        // This is the ONLY format that reliably opens App Store app on iOS 14+
        if let url = URL(string: "https://apps.apple.com/app/id6751070400") {
            UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { success in
                if !success {
                    // If universal link fails, open normally (will go to App Store app)
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        }
    }
}
