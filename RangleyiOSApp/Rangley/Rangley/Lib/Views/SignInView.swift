//
//  SignIn.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/10/25.
//

import SwiftUI
import Amplify

struct SignInView: View {
    let onAuthenticated: () -> Void
    @State private var isBusy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image("AppLogo").resizable().scaledToFit().frame(width: 140, height: 140)

                Button {
                    Task {
                        guard !isBusy else { return }
                        isBusy = true; defer { isBusy = false }

                        // TODO: replace with your real sign-in UI/flow
                        // Example (if you add text fields later):
                        // let _ = try await Amplify.Auth.signIn(username: user, password: pass)
                        // let s = try await Amplify.Auth.fetchAuthSession()
                        // guard s.isSignedIn else { return }
                        onAuthenticated()
                    }
                } label: {
                    HStack { if isBusy { ProgressView() }; Text(isBusy ? "Signing in…" : "Sign In").bold() }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)
                .padding(.horizontal, 20)

                Spacer()

                NavigationLink("Create new account") {
                    UserRegisterFlow()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 16)
            .toolbar { ToolbarItem(placement: .principal) { Text("Welcome").font(.headline) } }
        }
    }
}

#Preview { SignInView(onAuthenticated: {}) }
