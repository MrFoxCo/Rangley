//
//  RootGate.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/10/25.
//

import SwiftUI
import Amplify

struct RootGate: View {
    @State private var isAuthed = false
    @State private var checking = true

    var body: some View {
        Group {
            if checking {
                ProgressView().task { await checkSession() }
            } else if isAuthed {
                PublicMapView()
            } else {
                StartScreenView(onAuthenticated: { isAuthed = true })
            }
        }
    }

    @MainActor
    private func checkSession() async {
        do {
            let s = try await Amplify.Auth.fetchAuthSession()
            isAuthed = s.isSignedIn
        } catch {
            isAuthed = false
        }
        checking = false
    }
}
