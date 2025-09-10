//
//  UserRegisterView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/2/25.
//

import SwiftUI
import Amplify
import AWSPluginsCore
import UIKit

// MARK: - Error explainer (Amplify 2.x)
fileprivate func explainAuth(_ error: Error) -> String {
    if let ae = error as? AuthError {
        var parts = [ae.errorDescription]
        let rs = ae.recoverySuggestion; if !rs.isEmpty { parts.append(rs) }
        if let underlying = ae.underlyingError as NSError? {
            let type = (underlying.userInfo["__type"] as? String)
                ?? (underlying.userInfo["code"] as? String) ?? underlying.domain
            let msg  = (underlying.userInfo["message"] as? String)
                ?? underlying.localizedDescription
            parts.append("underlying: \(type) (\(underlying.code)) \(msg)")
        }
        return parts.joined(separator: " | ")
    }
    return String(describing: error)
}

// MARK: - Steps
private enum RegStep: Hashable {
    case phone, email, password, display, handle, agree, verify, challenge, done
}

// MARK: - Flow (single NavigationStack; Back arrow works)
struct UserRegisterFlow: View {
    @State private var path: [RegStep] = []

    // Inputs
    @State private var phone = ""            // UI shows "+digits"
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var handle = ""
    @State private var dobDate = Date()

    // Runtime
    @State private var status = ""
    @State private var isBusy = false
    @State private var idToken = ""
    @State private var verifyInfo = ""
    @State private var pendingMFA = false
    @State private var pendingNewPassword = false
    @State private var code = ""

    private let baseURL = URL(string: "https://api.mrfoxco.com")! // TODO: move to config
    private let df: DateFormatter = {
        let f = DateFormatter()
        f.calendar = .init(identifier: .iso8601)
        f.locale   = .init(identifier: "en_US_POSIX")
        f.timeZone = .init(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationStack(path: $path) {
            // Root = Phone screen
            PhoneStep(
                phone: $phone,
                onNext: { path.append(.password) },    // phone → password by default
                onUseEmail: { path.append(.email) },   // only when explicitly chosen
                phoneIsValid: phoneIsValid
            )
            .toolbar { ToolbarItem(placement: .principal) { Text("Phone").font(.headline) } }
        }
        // Attach destinations to the stack (more reliable than attaching inside child)
        .navigationDestination(for: RegStep.self) { step in
            switch step {
            case .email:
                EmailStep(
                    email: $email,
                    onNext: { path.append(.password) },
                    onUsePhone: {
                        // back to phone; if phone valid, skip to password
                        while path.last != .phone { _ = path.popLast() }
                        if phoneIsValid { path.append(.password) }
                    },
                    emailIsValid: emailIsValid,
                    allowSkip: phoneIsValid
                )

            case .password:
                PasswordStep(
                    password: $password,
                    passwordIsValid: passwordIsValid,
                    rulesView: { PasswordRulesView(pw: password) },
                    onNext: { path.append(.display) }
                )

            case .display:
                DisplayStep(
                    displayName: $displayName,
                    onNext: { path.append(.handle) }
                )

            case .handle:
                HandleStep(
                    handle: $handle,
                    dobDate: $dobDate,
                    onNext: { path.append(.agree) }
                )

            case .agree:
                AgreeStep(
                    isBusy: isBusy,
                    onCreate: { Task { await signUp() } },
                    onSignIn: { Task { await signIn() } },
                    canCreate: basicInputsValid,
                    canSignIn: signInInputsValid
                )
                .toolbar { ToolbarItem(placement: .principal) { Text("Create account").font(.headline) } }

            case .verify:
                VerifyStep(
                    info: verifyInfo,
                    code: $code,
                    isBusy: isBusy,
                    onConfirm: { Task { await confirmSignUp() } }
                )

            case .challenge:
                ChallengeStep(
                    code: $code,
                    isBusy: isBusy,
                    isNewPassword: pendingNewPassword,
                    onSubmit: { Task { await confirmSignIn(with: code) } }
                )

            case .done:
                DoneStep(idToken: idToken)

            case .phone:
                EmptyView()
            }
        }
    }

    // MARK: - Validations / transforms

    private var phoneDigits: String { phone.filter(\.isNumber) }
    private var phoneIsValid: Bool { phoneDigits.count >= 10 }

    // Return "+<E.164>" or nil
    private var e164PhoneForCognito: String? {
        let ds = phoneDigits
        switch ds.count {
        case 10:                         return "+1" + ds              // US default
        case 11 where ds.hasPrefix("1"): return "+" + ds               // already CC=1
        case 12...15:                    return "+" + ds               // other CCs
        default:                         return nil
        }
    }

    private var emailIsValid: Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // password rules
    private var pwHasMinLen: Bool { password.count >= 8 }
    private var pwHasDigit:   Bool { password.range(of: "\\d", options: .regularExpression) != nil }
    private var pwHasUpper:   Bool { password.range(of: "[A-Z]", options: .regularExpression) != nil }
    private var pwHasLower:   Bool { password.range(of: "[a-z]", options: .regularExpression) != nil }
    private var pwHasSpecial: Bool { password.range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil }
    private var pwNoEdgeWhitespace: Bool {
        password.range(of: #"^\S+.*\S+$"#, options: .regularExpression) != nil
    }
    private var passwordIsValid: Bool {
        pwHasMinLen && pwHasDigit && pwHasUpper && pwHasLower && pwHasSpecial && pwNoEdgeWhitespace
    }

    private var basicInputsValid: Bool {
        cognitoPrincipal != nil
        && passwordIsValid
        && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        && !handle.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var signInInputsValid: Bool {
        cognitoPrincipal != nil && !password.isEmpty
    }

    private var cognitoPrincipal: String? {
        if emailIsValid { return email }
        if let e164 = e164PhoneForCognito { return e164 }
        return nil
    }

    // MARK: - Flows

    private func signUp() async {
        await setBusy(true); defer { Task { await setBusy(false) } }
        status = ""
        do {
            guard passwordIsValid else {
                status = "Password doesn’t meet policy."
                while path.last != .password { _ = path.popLast() }
                return
            }
            guard let principal = cognitoPrincipal else {
                status = "Enter a valid email or a 10+ digit mobile number."
                // Go back to the right identifier step
                if path.contains(.email) && !emailIsValid {
                    while path.last != .email { _ = path.popLast() }
                } else {
                    while path.last != .phone { _ = path.popLast() }
                }
                return
            }

            var attrs: [AuthUserAttribute] = []
            if emailIsValid { attrs.append(.init(.email, value: email)) }
            if let e164 = e164PhoneForCognito { attrs.append(.init(.phoneNumber, value: e164)) }
            if !handle.isEmpty { attrs.append(.init(.preferredUsername, value: handle)) }

            let res = try await Amplify.Auth.signUp(
                username: principal,
                password: password,
                options: .init(userAttributes: attrs)
            )

            switch res.nextStep {
            case .done:
                await signIn() // auto-confirmed pools

            case let .confirmUser(details, _, _):
                verifyInfo = String(describing: details?.destination)
                status = "Code sent — check \(verifyInfo)"
                if path.last != .verify { path.append(.verify) }

            case .completeAutoSignIn(_):
                do {
                    let auto = try await Amplify.Auth.autoSignIn()
                    await handleNextStep(auto)
                } catch {
                    status = "AutoSignIn error: " + explainAuth(error)
                }

            @unknown default:
                status = "SignUp next: \(String(describing: res.nextStep))"
            }

        } catch {
            status = "SignUp error: " + explainAuth(error)
        }
    }

    private func confirmSignUp() async {
        await setBusy(true); defer { Task { await setBusy(false) } }
        status = ""
        do {
            guard let principal = cognitoPrincipal else {
                status = "Use the same email/phone as sign-up."
                return
            }
            let res = try await Amplify.Auth.confirmSignUp(for: principal, confirmationCode: code)
            if res.isSignUpComplete {
                code = ""; status = "Verified"
                _ = path.popLast() // drop .verify
                if path.last != .agree { path.append(.agree) }
                await signIn()
            } else {
                status = "Confirm next: \(res.nextStep)"
            }
        } catch {
            status = "Confirm error: " + explainAuth(error)
        }
    }

    private func signIn() async {
        await setBusy(true); defer { Task { await setBusy(false) } }
        status = ""; pendingMFA = false; pendingNewPassword = false
        do {
            guard let principal = cognitoPrincipal else {
                status = "Sign in with your email or mobile."
                return
            }
            let res = try await Amplify.Auth.signIn(username: principal, password: password)
            await handleNextStep(res)
        } catch {
            status = "SignIn error: " + explainAuth(error)
        }
    }

    private func confirmSignIn(with response: String) async {
        await setBusy(true); defer { Task { await setBusy(false) } }
        status = ""
        do {
            let res = try await Amplify.Auth.confirmSignIn(challengeResponse: response)
            await handleNextStep(res)
        } catch {
            status = "ConfirmSignIn error: " + explainAuth(error)
        }
    }

    private func handleNextStep(_ res: AuthSignInResult) async {
        if res.isSignedIn {
            status = "Signed in"
            await fetchIdToken()
            await registerBackendIfNeeded()
            if path.last != .done { path.append(.done) }
            return
        }

        pendingMFA = false
        pendingNewPassword = false

        switch res.nextStep {
        case .confirmSignInWithNewPassword:
            pendingNewPassword = true

        case .confirmSignInWithSMSMFACode,
             .confirmSignInWithTOTPCode,
             .confirmSignInWithCustomChallenge(_):
            pendingMFA = true

        default:
            // Covers .done/.resetPassword and any newer/unknown steps (incl. MFA selection on newer SDKs).
            pendingMFA = true
        }

        code = ""
        if path.last != .challenge { path.append(.challenge) }
        status = "Additional verification required — enter code or new password, then Submit"
    }


    // MARK: - Token + backend

    private func fetchIdToken() async {
        do {
            let s = try await Amplify.Auth.fetchAuthSession()
            guard s.isSignedIn, let p = s as? AuthCognitoTokensProvider else { status = "Not signed in"; return }
            idToken = try p.getCognitoTokens().get().idToken
            status = "ID token fetched"
        } catch { status = "Fetch token error: \(error.localizedDescription)" }
    }

    private func registerBackendIfNeeded() async {
        guard !idToken.isEmpty else { status = "No token; cannot register."; return }
        await setBusy(true); defer { Task { await setBusy(false) } }
        do {
            let payload = UserRegisterModel(
                username: handle,
                display_name: displayName,
                cellphone: e164PhoneForCognito,               // already includes '+'
                email: emailIsValid ? email : nil,
                dob: df.string(from: dobDate),
                first_name: nil,
                last_name: nil
            )
            let res = try await AuthAPI.register(baseURL: baseURL, token: idToken, payload: payload)
            status = (res.is_success == true) ? "Provisioned in DB ✔︎"
                 :  "Registered (is_success=\(String(describing: res.is_success)))"
        } catch { status = "Register error: \(error.localizedDescription)" }
    }

    // MARK: - misc
    private func setBusy(_ b: Bool) async {
        await MainActor.run { isBusy = b }
    }
}

// MARK: - Step Views

private struct PhoneStep: View {
    @Binding var phone: String
    let onNext: () -> Void
    let onUseEmail: () -> Void
    let phoneIsValid: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your phone").font(.title2.bold())
            TextField("Mobile number", text: $phone)
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)
                .onChange(of: phone, initial: false) {
                    let digits = phone.filter(\.isNumber)
                    let formatted = "+" + digits
                    if formatted != phone { phone = formatted }
                }



            Text("We’ll use phone or email as your sign-in.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Use email instead", action: onUseEmail)
                .buttonStyle(.plain).foregroundStyle(.blue)

            Button(action: onNext) {
                Text("Next")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(!phoneIsValid)
            .padding(.top, 24)

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

private struct EmailStep: View {
    @Binding var email: String
    let onNext: () -> Void
    let onUsePhone: () -> Void
    let emailIsValid: Bool
    let allowSkip: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your email").font(.title2.bold())
            TextField("email", text: $email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)
            if !email.isEmpty && !emailIsValid {
                Text("Enter a valid email like name@example.com")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Button("Use phone instead", action: onUsePhone)
                .buttonStyle(.plain).foregroundStyle(.blue)

            Button(action: onNext) {
                Text("Next")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(!(emailIsValid || allowSkip))   // allow skip if phone is valid
            .padding(.top, 24)

            Spacer(minLength: 0)
        }
        .padding(16)
        .toolbar { ToolbarItem(placement: .principal) { Text("Email").font(.headline) } }
    }
}

private struct PasswordRulesView: View {
    let pw: String
    private var hasMin: Bool { pw.count >= 8 }
    private var hasDigit: Bool { pw.range(of: "\\d", options: .regularExpression) != nil }
    private var hasUpper: Bool { pw.range(of: "[A-Z]", options: .regularExpression) != nil }
    private var hasLower: Bool { pw.range(of: "[a-z]", options: .regularExpression) != nil }
    private var hasSpec: Bool { pw.range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil }
    private var noEdge: Bool { pw.range(of: #"^\S+.*\S+$"#, options: .regularExpression) != nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            rule("≥ 8 characters", hasMin)
            rule("1 uppercase (A–Z)", hasUpper)
            rule("1 lowercase (a–z)", hasLower)
            rule("1 number (0–9)", hasDigit)
            rule("1 special (!@#…)", hasSpec)
            rule("No leading/trailing spaces", noEdge)
        }
    }
    @ViewBuilder private func rule(_ t: String, _ ok: Bool) -> some View {
        HStack { Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle")
                Text(t) }
        .foregroundStyle(ok ? .green : .secondary)
        .font(.footnote)
    }
}

private struct PasswordStep: View {
    @Binding var password: String
    let passwordIsValid: Bool
    let rulesView: () -> PasswordRulesView
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create a password").font(.title2.bold())
            SecureField("password", text: $password)
                .textFieldStyle(.roundedBorder)
            rulesView()

            Button(action: onNext) {
                Text("Next")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(!passwordIsValid)
            .padding(.top, 24)

            Spacer(minLength: 0)
        }
        .padding(16)
        .toolbar { ToolbarItem(placement: .principal) { Text("Password").font(.headline) } }
    }
}

private struct DisplayStep: View {
    @Binding var displayName: String
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a display name").font(.title2.bold())
            TextField("display name", text: $displayName)
                .textFieldStyle(.roundedBorder)

            Button(action: onNext) {
                Text("Next")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.top, 24)

            Spacer(minLength: 0)
        }
        .padding(16)
        .toolbar { ToolbarItem(placement: .principal) { Text("Display name").font(.headline) } }
    }
}

private struct HandleStep: View {
    @Binding var handle: String
    @Binding var dobDate: Date
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick a username").font(.title2.bold())
            TextField("username (handle)", text: $handle)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            DatePicker("DOB (≥13 yrs)", selection: $dobDate, displayedComponents: .date)

            Button(action: onNext) {
                Text("Next")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(handle.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.top, 24)

            Spacer(minLength: 0)
        }
        .padding(16)
        .toolbar { ToolbarItem(placement: .principal) { Text("Username").font(.headline) } }
    }
}

private struct AgreeStep: View {
    let isBusy: Bool
    let onCreate: () -> Void
    let onSignIn: () -> Void
    let canCreate: Bool
    let canSignIn: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agree & create account").font(.title2.bold())
            Text("By tapping **Create Account**, you agree to the Terms & Privacy.")
                .font(.subheadline)
            Button(action: onCreate) {
                HStack {
                    if isBusy { ProgressView() }
                    Text(isBusy ? "Creating…" : "Create Account").bold()
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy || !canCreate)

            Button("I already have an account – Sign In", action: onSignIn)
                .buttonStyle(.bordered)
                .disabled(isBusy || !canSignIn)

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

private struct VerifyStep: View {
    let info: String
    @Binding var code: String
    let isBusy: Bool
    let onConfirm: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Verify your account").font(.title2.bold())
            if !info.isEmpty {
                Text("Enter the code sent to \(info).")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            TextField("verification code", text: $code)
                .textFieldStyle(.roundedBorder)
            Button(action: onConfirm) {
                Text("Confirm")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)

            Spacer(minLength: 0)
        }
        .padding(16)
        .toolbar { ToolbarItem(placement: .principal) { Text("Verify").font(.headline) } }
    }
}

private struct ChallengeStep: View {
    @Binding var code: String
    let isBusy: Bool
    let isNewPassword: Bool
    let onSubmit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNewPassword ? "New password required" : "MFA / challenge")
                .font(.title2.bold())
            TextField(isNewPassword ? "NEW PASSWORD" : "MFA / TOTP code", text: $code)
                .textFieldStyle(.roundedBorder)
            Button(action: onSubmit) {
                Text("Submit")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)

            Spacer(minLength: 0)
        }
        .padding(16)
        .toolbar { ToolbarItem(placement: .principal) { Text("Security check").font(.headline) } }
    }
}

private struct DoneStep: View {
    let idToken: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All set!").font(.title2.bold())
            if !idToken.isEmpty {
                Text("ID: \(idToken.prefix(32))…").font(.footnote).monospaced()
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .toolbar { ToolbarItem(placement: .principal) { Text("Done").font(.headline) } }
    }
}

// MARK: - Preview (ContentView not needed)
#Preview {
    UserRegisterFlow()
}
