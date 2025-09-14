//
//  AccountView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

import SwiftUI
import Amplify
import AWSPluginsCore


import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var session: SessionModel

    var body: some View {
        NavigationStack {
            List {
                if let p = session.me {
                    Section {
                        row("Username", p.username)
                        row("Display Name", p.display_name)
                        row("Email", p.email)
                        row("Cellphone", p.cellphone)
                        row("Date of Birth", formatDate(p.dob))
                        row("Member Since", formatDate(p.dttm_created_utc))
                    }
                } else {
                    HStack { Spacer(); Text("Not signed in").foregroundStyle(.secondary); Spacer() }
                }
            }
            .navigationTitle("Account")
            // Optional: let the user manually refresh the cached profile
            .refreshable { await session.reloadMe() }
        }
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
}
