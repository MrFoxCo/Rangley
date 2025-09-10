//
//  AuthSRPView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/9/25.
//

// Minimal SRP auth harness (Amplify 2.x)
import SwiftUI
import Amplify
import AWSPluginsCore
import UIKit

private func explainAuth(_ error: Error) -> String {
    if let ae = error as? AuthError {
        var parts: [String] = [ae.errorDescription]            // String
        let rs = ae.recoverySuggestion                         // String
        if !rs.isEmpty { parts.append(rs) }
        if let underlying = ae.underlyingError as NSError? {
            let type = (underlying.userInfo["__type"] as? String)
                   ?? (underlying.userInfo["code"] as? String)
                   ?? underlying.domain
            let msg  = (underlying.userInfo["message"] as? String)
                   ?? underlying.localizedDescription
            parts.append("underlying: \(type) (\(underlying.code)) \(msg)")
        }
        return parts.joined(separator: " | ")
    }
    return String(describing: error)
}


struct AuthSRPView: View {
    @State private var username = ""   // alias: email/phone/handle
    @State private var password = ""
    @State private var email = ""      // optional for signUp
    @State private var phone = ""      // optional for signUp (E.164)
    @State private var code  = ""      // MFA code OR new password
    @State private var status = ""
    @State private var idToken = ""
    @State private var whoami  = ""
    @State private var pendingMFA = false
    @State private var pendingNewPassword = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cognito SRP").font(.largeTitle.bold())

                // Credentials
                VStack(spacing: 8) {
                    TextField("username / email / +1phone", text: $username)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    SecureField("password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }

                // Sign Up attrs
                VStack(spacing: 8) {
                    TextField("email", text: $email)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                    TextField("phone (+13125550123)", text: $phone)
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(.roundedBorder)
                }

                // Actions
                HStack {
                    Button("Sign Up") { Task { await signUp() } }.buttonStyle(.bordered)
                    Button("Confirm Sign Up") { Task { await confirmSignUp() } }.buttonStyle(.bordered)
                    //Button("Sign In") { Task { await signIn() } }.buttonStyle(.borderedProminent)
                }

                // Challenges
                VStack(alignment: .leading, spacing: 8) {
                    Text(pendingNewPassword ? "New password required" : "MFA / challenge")
                        .font(.subheadline).foregroundStyle(.secondary)
                    TextField(pendingNewPassword ? "NEW PASSWORD" : "MFA / challenge code", text: $code)
                        .textFieldStyle(.roundedBorder)
                    Button("Submit Challenge") { Task { await confirmSignIn(with: code) } }
                        .buttonStyle(.bordered)
                        .disabled(!pendingMFA && !pendingNewPassword)
                }

                Divider().padding(.vertical, 4)

                // Token & API
                HStack {
                    Button("Fetch ID Token") { Task { await fetchIdToken() } }.buttonStyle(.bordered)
                    Button("Copy ID Token") {
                        UIPasteboard.general.string = idToken
                        status = "ID token copied"
                    }
                    .buttonStyle(.bordered)
                    .disabled(idToken.isEmpty)
                }
                Button("GET /auth/whoami") { Task { await callWhoAmI() } }.buttonStyle(.bordered)

                if !idToken.isEmpty { Text("id: \(idToken.prefix(32))…").font(.footnote).monospaced() }
                if !whoami.isEmpty { Text(whoami).font(.footnote).monospaced() }
                if !status.isEmpty { Text(status).font(.footnote).foregroundStyle(.secondary) }
            }
            .padding(16)
        }
    }

    // MARK: - Flows (no signOut here)

    private func signUp() async {
        status = ""
        do {
            var attrs: [AuthUserAttribute] = []
            if !email.isEmpty { attrs.append(.init(.email, value: email)) }
            if !phone.isEmpty { attrs.append(.init(.phoneNumber, value: phone)) }
            if !username.isEmpty { attrs.append(.init(.preferredUsername, value: username)) }
            let res = try await Amplify.Auth.signUp(
                username: username,
                password: password,
                options: .init(userAttributes: attrs)
            )
            status = "SignUp: \(String(describing: res.nextStep))"
        } catch {
            status = "SignUp error: " + explainAuth(error)
        }

    }

    private func confirmSignUp() async {
        status = ""
        do {
            let res = try await Amplify.Auth.confirmSignUp(for: username, confirmationCode: code)
            status = res.isSignUpComplete ? "SignUp confirmed" : "Confirm next: \(res.nextStep)"
        } catch { status = "Confirm error: \(error.localizedDescription)" }
    }

    private func signIn() async {
        status = ""; pendingMFA = false; pendingNewPassword = false
        do {
            let res = try await Amplify.Auth.signIn(username: username, password: password)
            await handleNextStep(res)
        } catch { status = "SignIn error: \(error.localizedDescription)" }
    }

    private func confirmSignIn(with response: String) async {
        status = ""
        do {
            let res = try await Amplify.Auth.confirmSignIn(challengeResponse: response)
            await handleNextStep(res)
        } catch { status = "ConfirmSignIn error: \(error.localizedDescription)" }
    }

    private func handleNextStep(_ res: AuthSignInResult) async {
        if res.isSignedIn { status = "Signed in"; await fetchIdToken(); return }
        switch res.nextStep {
        case .confirmSignInWithSMSMFACode(_, _),
                .confirmSignInWithTOTPCode,
             .confirmSignInWithOTP(_):
            pendingMFA = true; pendingNewPassword = false
            status = "Enter MFA/OTP code then Submit"

        case .confirmSignInWithNewPassword(_):
            pendingMFA = false; pendingNewPassword = true
            status = "Enter NEW PASSWORD then Submit"
        case .confirmSignInWithCustomChallenge(_):
            status = "Custom challenge — enter response then Submit"
        default:
            status = "Next step: \(String(describing: res.nextStep))"
        }
    }

    private func fetchIdToken() async {
        do {
            let s = try await Amplify.Auth.fetchAuthSession()
            guard s.isSignedIn, let p = s as? AuthCognitoTokensProvider else { status = "Not signed in"; return }
            idToken = try p.getCognitoTokens().get().idToken
            status = "ID token fetched"
        } catch { status = "Fetch token error: \(error.localizedDescription)" }
    }

    private func callWhoAmI() async {
        guard !idToken.isEmpty else { status = "Fetch ID token first"; return }
        do {
            whoami = try await AuthAPI.whoAmI(baseURL: URL(string: "https://api.mrfoxco.com")!, token: idToken)
            status = "whoami OK"
        } catch { status = "whoami error: \(error.localizedDescription)" }
    }
}

