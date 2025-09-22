//
//  RangleApp.swift
//
//  Created by Anthony Guzzardo on 7/1/25.
//


import SwiftUI
import Amplify
import AWSCognitoAuthPlugin
import UIKit
import AWSPluginsCore


final class AppDelegate: NSObject, UIApplicationDelegate
{
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Amplify SDK log level (console only)
        #if DEBUG
        Amplify.Logging.logLevel = .debug   // or .verbose if you want maximum noise
        #else
        Amplify.Logging.logLevel = .warn
        #endif

        Log.app.info("Launching… bundle=\(Bundle.main.bundleIdentifier ?? "nil")")

        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            Log.app.info("Added AWSCognitoAuthPlugin")
        } catch {
            Log.app.critical("Failed to add AWSCognitoAuthPlugin: \(error.localizedDescription, privacy: .private)")
        }

        do {
            try Amplify.configure()   // reads amplifyconfiguration.json from bundle
            Log.app.info("Amplify configured")
        } catch {
            Log.app.critical("Amplify configure failed: \(error.localizedDescription, privacy: .private)")
            return true
        }

        // Post-config smoke test (console logs only; no UI)
        Task {
            do {
                let session = try await Amplify.Auth.fetchAuthSession()
                Log.auth.info("Auth session: isSignedIn=\(session.isSignedIn)")

                if let tokenProv = session as? AuthCognitoTokensProvider {
                    switch tokenProv.getCognitoTokens() {
                    case .success(let t):
                        // Don’t print tokens; just lengths
                        Log.auth.debug(
                            "Tokens present: id.len=\(t.idToken.count), access.len=\(t.accessToken.count), refresh.len=\(t.refreshToken.count)"
                        )
                    case .failure(let e):
                        Log.auth.error("getCognitoTokens failed: \(String(describing: e), privacy: .private)")
                    }
                } else {
                    Log.auth.warning("Session is not AuthCognitoTokensProvider (unexpected for Cognito)")
                }
            } catch {
                // This can log the identity-pool noise if misconfigured; still console-only
                Log.auth.error("fetchAuthSession failed: \(error.localizedDescription, privacy: .private)")
            }
        }

        return true
    }
}

@main
struct RangleyApp: App {
    // Create it here
    @StateObject private var auth = AuthStateStore()

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootGate()
                //  Provide it to the tree
                .environmentObject(auth)
        }
    }
}
