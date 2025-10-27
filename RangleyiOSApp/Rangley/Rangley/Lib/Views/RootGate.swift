//
//  RootGate.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/10/25.
//

import SwiftUI

struct RootGate: View
{
    @StateObject private var auth = AuthStateStore()
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var versionStatus: VersionStatus = .checking
    @State private var isCheckingVersion = true
    
    enum VersionStatus {
        case checking
        case supported
        case updateRequired(current: String, latest: String)
        case networkError(String)
        case serverError(String)
    }
    
    var body: some View
    {
        content
            .task {
                await checkAppVersion()
            }
            // Refresh auth whenever the app becomes active
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    auth.checkAuthenticationStatus()
                }
            }
    }

    @ViewBuilder
    private var content: some View
    {
        switch versionStatus {
        case .updateRequired(let current, let latest):
            UpdateRequiredView(currentVersion: current, latestVersion: latest)
        case .checking:
            ZStack {
                AppPalette.Brand.japDarkerPurple.ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: -8) { // negative spacing pulls them closer
                        Image("RangleySticker")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                        
                        Text("Rangley")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    
                    Spacer()
                    
                    Image("MrFoxOrange")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 540, height:180)
                        .padding(.bottom, 40)
                }
            }
            .transition(.opacity)
        case .supported:
            // Normal app flow
            if auth.isCheckingAuth {
                ZStack {
                    AppPalette.Brand.japDarkerPurple.ignoresSafeArea()
                    VStack {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.white)
                        Text("Checking authentication…")
                            .foregroundStyle(.white)
                            .padding(.top, 8)
                    }
                }
                .transition(.opacity)
            } else if auth.isAuthenticated {
                PublicMapView()
                    .environmentObject(auth)
                    .transition(.opacity)
            } else {
                StartScreenView()
                    .environmentObject(auth)
                    .transition(.opacity)
            }
        case .networkError(_):
            NetworkErrorView {
                Task {
                    await checkAppVersion()
                }
            }
            .transition(.opacity)
        case .serverError(let message):
            ServerErrorView(errorMessage: message) {
                Task {
                    await checkAppVersion()
                }
            }
            .transition(.opacity)
        }
    }
    
    private func checkAppVersion() async
    {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            versionStatus = .networkError("Could not read app version")
            return
        }
        
        let baseURL = URL(string: "https://api.mrfoxco.com")!
        let versionInt = versionToInt(version)
        
        do {
            let response = try await AuthAPI.viewAppVersion(baseURL: baseURL, appVersion: versionInt)
            
            // Add a small delay to show the splash screen gracefully
            try? await Task.sleep(for: .milliseconds(500))
            
            withAnimation(.easeInOut(duration: 0.5)) {
                if response.is_supported {
                    versionStatus = .supported
                } else {
                    let latest = intToVersion(response.latest_version)
                    versionStatus = .updateRequired(current: version, latest: latest)
                }
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.3)) {
                if error.localizedDescription.contains("network") || error.localizedDescription.contains("connection") {
                    versionStatus = .networkError("Please check your internet connection and try again.")
                } else {
                    versionStatus = .serverError("Our servers are temporarily unavailable. Please try again later.")
                }
            }
        }
    }
    
    private func versionToInt(_ versionString: String) -> Int32
    {
        let components = versionString.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 3 else { return 10000 }
        return Int32(components[0] * 10000 + components[1] * 100 + components[2])
    }

    private func intToVersion(_ versionInt: Int32) -> String
    {
        let major = versionInt / 10000
        let minor = (versionInt % 10000) / 100
        let patch = versionInt % 100
        return "\(major).\(minor).\(patch)"
    }
}

extension RootGate.VersionStatus
{
    var isUpdateRequired: Bool {
        if case .updateRequired = self { return true }
        return false
    }
}

extension Bundle
{
    var baseURL: URL {
        return URL(string: "https://api.mrfoxco.com")! // Replace with your real URL
    }
}
