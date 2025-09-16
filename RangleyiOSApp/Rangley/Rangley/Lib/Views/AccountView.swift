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
    @State private var isAnimating = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header section with profile avatar and name
                    profileHeader
                    
                    // Account details section
                    if let p = profile {
                        accountDetails(for: p)
                    } else if let e = error {
                        errorView(e)
                    } else {
                        loadingView
                    }
                    
                    Spacer(minLength: 100) // Bottom padding
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        AppPalette.Brand.russianViolet,
                        AppPalette.Brand.violetMid,
                        AppPalette.Brand.nearBlack
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppPalette.Brand.neonPink)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Account")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppPalette.Text.primary)
                }
            }
            .refreshable {
                await load()
            }
        }
        .preferredColorScheme(.dark)
        .task { await load() }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 20) {
            // Profile avatar with aura effect
            ZStack {
                // Aura rings
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppPalette.Brand.neonPink,
                                    AppPalette.Brand.electricViolet,
                                    AppPalette.Brand.brightTeal,
                                    AppPalette.Brand.neonPink
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 90 + CGFloat(index * 20), height: 90 + CGFloat(index * 20))
                        .opacity(0.6 - Double(index) * 0.2)
                }
                
                // Avatar background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppPalette.Brand.neonPink.opacity(0.3),
                                AppPalette.Brand.electricViolet.opacity(0.2)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 45
                        )
                    )
                    .frame(width: 80, height: 80)
                
                // Profile initials or icon
                if let profile = profile {
                    Text(getInitials(from: profile.display_name))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppPalette.Text.primary)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppPalette.Brand.neonPink)
                }
            }
            .scaleEffect(isAnimating ? 1.0 : 0.8)
            .opacity(isAnimating ? 1.0 : 0.5)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: isAnimating)
            
            // Display name
            if let profile = profile {
                Text(profile.display_name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppPalette.Brand.neonPink,
                                AppPalette.Brand.electricViolet
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(y: isAnimating ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: isAnimating)
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 32)
    }
    
    // MARK: - Account Details
    private func accountDetails(for profile: ViewUserMe) -> some View {
        VStack(spacing: 16) {
            accountInfoCard(
                title: "Personal Information",
                items: [
                    ("Username", profile.username),
                    ("Display Name", profile.display_name),
                    ("Email", profile.email),
                    ("Phone", profile.cellphone)
                ]
            )
            
            accountInfoCard(
                title: "Account Details",
                items: [
                    ("Date of Birth", formatDate(profile.dob)),
                    ("Member Since", formatDate(profile.dttm_created_utc))
                ]
            )
        }
        .padding(.horizontal, 24)
    }
    
    private func accountInfoCard(title: String, items: [(String, String?)]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section title
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppPalette.Text.primary)
                .padding(.bottom, 8)
            
            // Info rows
            VStack(spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    accountInfoRow(label: item.0, value: item.1)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(x: isAnimating ? 0 : 30)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(0.3 + Double(index) * 0.1),
                            value: isAnimating
                        )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppPalette.Surface.fieldFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppPalette.Brand.neonPink.opacity(0.3),
                                    AppPalette.Brand.electricViolet.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func accountInfoRow(label: String, value: String?) -> some View {
        HStack {
            // Label with icon
            HStack(spacing: 8) {
                Circle()
                    .fill(AppPalette.Brand.neonPink.opacity(0.2))
                    .frame(width: 6, height: 6)
                
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppPalette.Text.secondary)
            }
            
            Spacer()
            
            // Value
            Text(value ?? "—")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppPalette.Text.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Error View
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(AppPalette.Brand.neonPink)
            
            Text("Something went wrong")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppPalette.Text.primary)
            
            Text(error)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppPalette.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: AppPalette.Brand.neonPink))
            
            Text("Loading your account...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppPalette.Text.secondary)
        }
        .padding(.top, 60)
    }
    
    // MARK: - Helpers
    private func getInitials(from name: String) -> String {
        let components = name.trimmingCharacters(in: .whitespaces).split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }
        return String(initials).uppercased()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func load() async {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            guard let provider = session as? AuthCognitoTokensProvider else {
                throw AuthAPIError.http(-1, "No Cognito token provider")
            }

            let tokens = try provider.getCognitoTokens().get()
            let idToken = tokens.idToken
            let me = try await AuthAPI.me(baseURL: Env.apiBaseURL, token: idToken)

            await MainActor.run {
                self.profile = me
                self.error = nil
            }

        } catch AuthAPIError.http(let code, _) where code == 401 {
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
