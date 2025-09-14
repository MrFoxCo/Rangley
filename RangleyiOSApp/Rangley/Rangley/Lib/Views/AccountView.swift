//
//  AccountView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

import SwiftUI
import Amplify
import AWSPluginsCore

struct AccountView: View
{
    @State private var profile: ViewUserMe?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let p = profile {
                    Section {
                        row("Username", p.username)
                        row("Display Name", p.display_name)
                        row("Email", p.email)
                        row("Cellphone", p.cellphone)
                        row("Date of Birth", formatDate(p.dob))
                        row("Member Since", formatDate(p.dttm_created_utc))
                    }
                } else if let e = error {
                    Text(e).foregroundStyle(.red)
                } else {
                    HStack { Spacer(); ProgressView("Loading…"); Spacer() }
                }
            }
            .navigationTitle("Account")
            .refreshable {                               // ← ADD: pull-to-refresh
                await load()
            }
        }
        .task { await load() }
    }

    @ViewBuilder private func row(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value ?? "—").foregroundStyle(.secondary)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private func load() async {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            guard let provider = session as? AuthCognitoTokensProvider else {
                throw AuthAPIError.http(-1, "No Cognito token provider")
            }

            // Tokens via Result API (no await)
            let tokens = try provider.getCognitoTokens().get()
            let idToken = tokens.idToken

            let me = try await AuthAPI.me(baseURL: Env.apiBaseURL, token: idToken)

            await MainActor.run {
                self.profile = me
                self.error = nil
            }

        } catch AuthAPIError.http(let code, _) where code == 401 {   // ← ADD: 401 handling
            await MainActor.run {
                self.error = "Session expired. Please sign in again."
                self.profile = nil
            }

        } catch let apiError as AuthAPIError {
            await MainActor.run { self.error = apiError.localizedDescription }
        } catch {
            await MainActor.run { self.error = String(describing: error) }
        }
    }
}
