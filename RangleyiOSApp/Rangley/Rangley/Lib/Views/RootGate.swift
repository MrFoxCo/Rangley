//
//  RootGate.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/10/25.
//
import SwiftUI
import Amplify

enum RootRoute { case checking, start, map }

struct RootGate: View {
    @EnvironmentObject private var session: SessionModel
    @State private var route: RootRoute = .checking

    var body: some View {
        Group {
            switch route {
            case .checking:
                ProgressView()
                    .task { await checkSession() }

            case .start:
                StartScreenView(onAuthenticated: {
                    Task {
                        await session.reloadMe()       // fetch /v/me once after login/register
                        route = .map
                    }
                })

            case .map:
                PublicMapView()                       // reads session via @EnvironmentObject
                    .preferredColorScheme(.dark)
            }
        }
    }

    @MainActor
    private func checkSession() async {
        do {
            let s = try await Amplify.Auth.fetchAuthSession()
            if s.isSignedIn {
                await session.ensureMe()              // loads /v/me if not already loaded
                route = .map
            } else {
                route = .start
            }
        } catch {
            route = .start
        }
    }
}
