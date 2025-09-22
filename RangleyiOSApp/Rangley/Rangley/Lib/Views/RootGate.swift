//
//  RootGate.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/10/25.
//

// RootGate.swift
import SwiftUI

struct RootGate: View {
    @StateObject private var auth = AuthStateStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
        // Refresh auth whenever the app becomes active
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                auth.checkAuthenticationStatus()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if auth.isCheckingAuth {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    ProgressView().scaleEffect(1.3)
                    Text("Checking authentication…")
                        .foregroundStyle(.white)
                        .padding(.top, 8)
                }
            }
        } else if auth.isAuthenticated {
            PublicMapView()
                .environmentObject(auth)
        } else {
            StartScreenView()
                .environmentObject(auth)
        }
    }
}
