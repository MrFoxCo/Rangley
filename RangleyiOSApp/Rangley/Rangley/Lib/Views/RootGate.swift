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
            // Block all app functionality - show only update screen
            UpdateRequiredView(currentVersion: current, latestVersion: latest)
        case .checking:
            // Show loading while checking version
            ZStack {
                AppPalette.Brand.japDarkerPurple.ignoresSafeArea()
                VStack {
                    ProgressView()
                    Text("Checking app version...")
                        .foregroundStyle(.white)
                }
            }
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
            } else if auth.isAuthenticated {
                PublicMapView().environmentObject(auth)
            } else {
                StartScreenView().environmentObject(auth)
            }
        case .networkError(_):
            NetworkErrorView {
                Task {
                    await checkAppVersion()
                }
            }
        case .serverError(let message):
            ServerErrorView(errorMessage: message) {
                Task {
                    await checkAppVersion()
                }
            }
        }
    }
    
    private func checkAppVersion() async
    {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            versionStatus = .networkError("Could not read app version")  // Changed from .error
            return
        }
        
        let baseURL = URL(string: "https://api.mrfoxco.com")! // Your API URL here
        let versionInt = versionToInt(version)
        
        do {
            let response = try await AuthAPI.viewAppVersion(baseURL: baseURL, appVersion: versionInt)
            
            if response.is_supported {
                versionStatus = .supported
            } else {
                let latest = intToVersion(response.latest_version)
                versionStatus = .updateRequired(current: version, latest: latest)
            }
        } catch {
            // Categorize the error
            if error.localizedDescription.contains("network") || error.localizedDescription.contains("connection") {
                versionStatus = .networkError("Please check your internet connection and try again.")
            } else {
                versionStatus = .serverError("Our servers are temporarily unavailable. Please try again later.")
            }
        }
    }
    
    // Add the helper functions
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
