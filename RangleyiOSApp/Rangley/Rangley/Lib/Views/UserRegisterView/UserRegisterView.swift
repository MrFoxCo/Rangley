//
//  UserRegisterFlow.swift
//  Rangley
//
//  Created by You on 9/10/25.


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

// MARK: - Form & Flow State

private struct FormState: Equatable {
    var phoneRaw: String = ""          // user-typed (we’ll normalize on advance)
    var email: String = ""
    var password: String = ""
    var displayName: String = ""
    var handle: String = ""
    var dobDate: Date = .init(timeIntervalSince1970: 0)
}

private enum Step: Hashable {
    case idChooser         // phone/email screen combined
    case password
    case display
    case handleDob
    case agree
    case verify(String?)   // NOTE: no label to avoid tuple-with-label error
    case done
}

private enum BannerState: Equatable {
    case none
    case info(String)
    case error(String)
    case success(String)
}

private enum FlowState: Equatable {
    case collecting(Step)          // gather inputs
    case awaitingVerification(String?)
    case signingIn                 // transient
    case signedIn(idToken: String) // final
    case failed(String)
}

// MARK: - Auth client abstraction (thin wrapper over Amplify)

private protocol AuthClient {
    func signUp(username: String, password: String, attributes: [AuthUserAttribute]) async throws -> AuthSignUpResult
    func confirmSignUp(for username: String, code: String) async throws -> AuthSignUpResult
    func signIn(username: String, password: String) async throws -> AuthSignInResult
    func autoSignIn() async throws -> AuthSignInResult
    func fetchTokens() async throws -> String   // return just the idToken
}

private struct AmplifyAuthClient: AuthClient {
    func signUp(username: String, password: String, attributes: [AuthUserAttribute]) async throws -> AuthSignUpResult {
        try await Amplify.Auth.signUp(username: username, password: password, options: .init(userAttributes: attributes))
    }
    func confirmSignUp(for username: String, code: String) async throws -> AuthSignUpResult {
        try await Amplify.Auth.confirmSignUp(for: username, confirmationCode: code)
    }
    func signIn(username: String, password: String) async throws -> AuthSignInResult {
        try await Amplify.Auth.signIn(username: username, password: password)
    }
    func autoSignIn() async throws -> AuthSignInResult {
        try await Amplify.Auth.autoSignIn()
    }
    func fetchTokens() async throws -> String {
        let s = try await Amplify.Auth.fetchAuthSession()
        guard s.isSignedIn, let p = s as? AuthCognitoTokensProvider else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        let tokens = try p.getCognitoTokens().get()
        return tokens.idToken
    }
}

// MARK: - ViewModel (Reducer + Effects)

@MainActor
private final class RegisterVM: ObservableObject {
    @Published var form = FormState()
    @Published var flow: FlowState = .collecting(.idChooser)
    @Published var banner: BannerState = .none
    @Published var isBusy = false
    @Published var code = ""                // verification code when needed

    // config
    let baseURL = URL(string: "https://api.mrfoxco.com")! // move to config as needed

    // deps
    private let auth: AuthClient
    private let df: DateFormatter

    init(auth: AuthClient = AmplifyAuthClient()) {
        self.auth = auth
        self.df = DateFormatter()
        self.df.calendar = .init(identifier: .iso8601)
        self.df.locale   = .init(identifier: "en_US_POSIX")
        self.df.timeZone = .init(secondsFromGMT: 0)
        self.df.dateFormat = "yyyy-MM-dd"
    }

    // MARK: - Derived helpers

    private var phoneDigits: String { form.phoneRaw.filter(\.isNumber) }

    // Exposed (not private) so the IdChooser step can read it
    var e164Phone: String? {
        let ds = phoneDigits
        switch ds.count {
        case 10:                         return "+1" + ds          // US default
        case 11 where ds.hasPrefix("1"): return "+" + ds
        case 12...15:                    return "+" + ds
        default:                         return nil
        }
    }

    var emailValid: Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return form.email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    var passwordScore: (ok: Bool, reasons: [String]) {
        var reasons: [String] = []
        if form.password.count < 8 { reasons.append("≥ 8 chars") }
        if form.password.range(of: "\\d", options: .regularExpression) == nil { reasons.append("number") }
        if form.password.range(of: "[A-Z]", options: .regularExpression) == nil { reasons.append("uppercase") }
        if form.password.range(of: "[a-z]", options: .regularExpression) == nil { reasons.append("lowercase") }
        if form.password.range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) == nil { reasons.append("special") }
        if form.password.range(of: #"^\S+.*\S+$"#, options: .regularExpression) == nil { reasons.append("no edge spaces") }
        return (reasons.isEmpty, reasons)
    }
    private var principal: String? {
        if emailValid { return form.email }
        if let p = e164Phone { return p }
        return nil
    }
    var inputsForCreateOK: Bool {
        principal != nil
        && passwordScore.ok
        && !form.displayName.trimmingCharacters(in: .whitespaces).isEmpty
        && !form.handle.trimmingCharacters(in: .whitespaces).isEmpty
        && is13OrOlder(form.dobDate)
    }

    private func is13OrOlder(_ dob: Date) -> Bool {
        let years = Calendar(identifier: .gregorian).dateComponents([.year], from: dob, to: Date()).year ?? 0
        return years >= 13
    }

    // MARK: - Navigation / Reducer-ish methods

    func back() {
        switch flow {
        case .collecting(let step):
            switch step {
            case .idChooser: break
            case .password: flow = .collecting(.idChooser)
            case .display: flow = .collecting(.password)
            case .handleDob: flow = .collecting(.display)
            case .agree: flow = .collecting(.handleDob)
            case .verify: flow = .collecting(.agree)
            case .done: break
            }
        case .awaitingVerification:
            flow = .collecting(.agree)
        case .signingIn, .signedIn, .failed:
            break
        }
    }

    func advanceFromIdChooser() {
        banner = .none
        flow = .collecting(.password)
    }

    func advanceFromPassword() {
        if !passwordScore.ok {
            banner = .error("Add: " + passwordScore.reasons.joined(separator: ", "))
            return
        }
        banner = .none
        flow = .collecting(.display)
    }

    func advanceFromDisplay() {
        guard !form.displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            banner = .error("Enter a display name.")
            return
        }
        banner = .none
        flow = .collecting(.handleDob)
    }

    func advanceFromHandleDob() {
        guard !form.handle.trimmingCharacters(in: .whitespaces).isEmpty else {
            banner = .error("Pick a username.")
            return
        }
        guard is13OrOlder(form.dobDate) else {
            banner = .error("You must be at least 13 years old.")
            return
        }
        banner = .none
        flow = .collecting(.agree)
    }

    // MARK: - Effects

    func createAccount() async {
        guard inputsForCreateOK else {
            banner = .error("Add a valid email or phone, a strong password, display name, and username.")
            return
        }
        guard let principal = principal else {
            banner = .error("Use a valid email or an E.164 phone like +13125551234.")
            return
        }

        isBusy = true; defer { isBusy = false }
        banner = .none

        do {
            var attrs: [AuthUserAttribute] = []
            if emailValid { attrs.append(.init(.email, value: form.email)) }
            if let p = e164Phone { attrs.append(.init(.phoneNumber, value: p)) }
            if !form.handle.isEmpty { attrs.append(.init(.preferredUsername, value: form.handle)) }

            let res = try await auth.signUp(username: principal, password: form.password, attributes: attrs)

            switch res.nextStep {
            case .done:
                // Pool is auto-confirmed → sign in then register backend
                try await postSignUpAutoFlow(principal: principal)

            case let .confirmUser(details, _, _):
                let dest = String(describing: details?.destination)
                flow = .awaitingVerification(dest)
                banner = .info("Code sent — check \(dest)")

            case .completeAutoSignIn(_):
                // Auto-sign-in path
                let auto = try await auth.autoSignIn()
                try await handleSignInResult(auto)

            @unknown default:
                banner = .info("Next: \(String(describing: res.nextStep))")
            }

        } catch {
            banner = .error("SignUp: " + explainAuth(error))
        }
    }

    func confirmCodeAndFinish() async {
        guard case let .awaitingVerification(dest) = flow else { return }
        guard let principal = principal else {
            banner = .error("Use the same email/phone as sign-up.")
            return
        }
        guard !code.trimmingCharacters(in: .whitespaces).isEmpty else {
            banner = .error("Enter the verification code.")
            return
        }
        isBusy = true; defer { isBusy = false }
        banner = .none
        do {
            let r = try await auth.confirmSignUp(for: principal, code: code)
            if r.isSignUpComplete {
                code = ""
                try await postSignUpAutoFlow(principal: principal)
            } else {
                banner = .info("Confirm next: \(r.nextStep)")
                flow = .awaitingVerification(dest)
            }
        } catch {
            banner = .error("Confirm: " + explainAuth(error))
        }
    }

    private func postSignUpAutoFlow(principal: String) async throws {
        // sign in
        let signInRes = try await auth.signIn(username: principal, password: form.password)
        try await handleSignInResult(signInRes)
    }

    private func handleSignInResult(_ res: AuthSignInResult) async throws {
        if res.isSignedIn {
            let tok = try await auth.fetchTokens() // now returns String idToken
            do {
                try await registerBackend(idToken: tok)
                banner = .success("Provisioned in DB")
            } catch {
                banner = .error("Backend register: \(error.localizedDescription)")
            }
            flow = .signedIn(idToken: tok)
            return
        }

        // No MFA in v1: if we get here with a challenge, surface a friendly error
        banner = .error("This account requires additional verification not yet supported.")
        flow = .failed("Pending unsupported challenge")
    }

    private func registerBackend(idToken: String) async throws {
        // Uses your existing AuthAPI + UserRegisterModel types
        let payload = UserRegisterModel(
            username: form.handle,
            display_name: form.displayName,
            cellphone: e164Phone,
            email: emailValid ? form.email : nil,
            dob: df.string(from: form.dobDate),
            first_name: nil,
            last_name: nil
        )
        _ = try await AuthAPI.register(baseURL: baseURL, token: idToken, payload: payload)
    }
}

// MARK: - Views

struct UserRegisterFlow: View {
    @StateObject private var vm = RegisterVM()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                bannerView(vm.banner)
                content
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if canGoBack { Button(action: vm.back) { Image(systemName: "chevron.left") } }
                }
                ToolbarItem(placement: .principal) { Text(titleForStep).font(.headline) }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.flow {
        case .collecting(let step):
            switch step {
            case .idChooser: IdChooserStep(
                phoneRaw: $vm.form.phoneRaw,
                email: $vm.form.email,
                emailValid: vm.emailValid,
                e164Phone: vm.e164Phone,
                onNext: vm.advanceFromIdChooser
            )
            case .password: PasswordStep(
                password: $vm.form.password,
                score: vm.passwordScore,
                onNext: vm.advanceFromPassword
            )
            case .display: DisplayStep(
                displayName: $vm.form.displayName,
                onNext: vm.advanceFromDisplay
            )
            case .handleDob: HandleDobStep(
                handle: $vm.form.handle,
                dob: $vm.form.dobDate,
                onNext: vm.advanceFromHandleDob
            )
            case .agree: AgreeStep(
                isBusy: vm.isBusy,
                canCreate: vm.inputsForCreateOK,
                onCreate: { Task { await vm.createAccount() } }
            )
            case .verify(let dest):
                VerifyStep(
                    dest: dest,
                    code: $vm.code,
                    isBusy: vm.isBusy,
                    onConfirm: { Task { await vm.confirmCodeAndFinish() } }
                )
            case .done:
                DoneStep(idToken: tokenPreview)
            }

        case .awaitingVerification(let dest):
            VerifyStep(
                dest: dest,
                code: $vm.code,
                isBusy: vm.isBusy,
                onConfirm: { Task { await vm.confirmCodeAndFinish() } }
            )

        case .signingIn:
            ProgressView().padding().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        case .signedIn:
            DoneStep(idToken: tokenPreview)

        case .failed(let msg):
            VStack(spacing: 16) {
                Text("Couldn’t complete sign in.").font(.title3.bold())
                Text(msg).font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }
    }

    private var canGoBack: Bool {
        switch vm.flow {
        case .collecting(let step):
            return step != .idChooser
        case .awaitingVerification:
            return true
        default:
            return false
        }
    }

    private var titleForStep: String {
        switch vm.flow {
        case .collecting(let step):
            switch step {
            case .idChooser: return "Phone or Email"
            case .password: return "Password"
            case .display: return "Display name"
            case .handleDob: return "Username"
            case .agree: return "Create account"
            case .verify: return "Verify"
            case .done: return "Done"
            }
        case .awaitingVerification: return "Verify"
        case .signingIn: return "Signing in"
        case .signedIn: return "Done"
        case .failed: return "Sign in"
        }
    }

    private var tokenPreview: String {
        if case let .signedIn(idToken) = vm.flow {
            return String(idToken.prefix(32)) + "…"
        }
        return ""
    }

    @ViewBuilder
    private func bannerView(_ b: BannerState) -> some View {
        switch b {
        case .none: EmptyView()
        case .info(let s):
            Text(s).font(.footnote).padding(10).frame(maxWidth: .infinity).background(.blue.opacity(0.15))
        case .success(let s):
            Text(s).font(.footnote).padding(10).frame(maxWidth: .infinity).background(.green.opacity(0.15))
        case .error(let s):
            Text(s).font(.footnote).padding(10).frame(maxWidth: .infinity).background(.red.opacity(0.15))
        }
    }
}

// MARK: - Step Subviews

private struct IdChooserStep: View {
    @Binding var phoneRaw: String
    @Binding var email: String
    let emailValid: Bool
    let e164Phone: String?
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Use your phone or email").font(.title2.bold())

                TextField("mobile (e.g. +13125551234)", text: $phoneRaw)
                    .keyboardType(.phonePad)
                    .textFieldStyle(.roundedBorder)

                if let p = e164Phone, !p.isEmpty {
                    Text("Formatted as \(p)").font(.footnote).foregroundStyle(.secondary)
                } else if !phoneRaw.isEmpty {
                    Text("Tip: use + and digits only").font(.footnote).foregroundStyle(.secondary)
                }

                TextField("email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)

                if !email.isEmpty && !emailValid {
                    Text("Enter a valid email like name@example.com")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Button(action: onNext) {
                    Text("Next")
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .font(.title3.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 10)

                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }
}

private struct PasswordStep: View {
    @Binding var password: String
    let score: (ok: Bool, reasons: [String])
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create a password").font(.title2.bold())
            SecureField("password", text: $password)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                rule("≥ 8 characters", password.count >= 8)
                rule("1 uppercase (A–Z)", password.range(of: "[A-Z]", options: .regularExpression) != nil)
                rule("1 lowercase (a–z)", password.range(of: "[a-z]", options: .regularExpression) != nil)
                rule("1 number (0–9)", password.range(of: "\\d", options: .regularExpression) != nil)
                rule("1 special (!@#…)", password.range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil)
                rule("No leading/trailing spaces", password.range(of: #"^\S+.*\S+$"#, options: .regularExpression) != nil)
            }

            Button(action: onNext) {
                Text("Next")
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(!score.ok)
            .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    @ViewBuilder private func rule(_ t: String, _ ok: Bool) -> some View {
        HStack { Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle"); Text(t) }
            .foregroundStyle(ok ? .green : .secondary)
            .font(.footnote)
    }
}

private struct DisplayStep: View {
    @Binding var displayName: String
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose a display name").font(.title2.bold())
            TextField("display name", text: $displayName)
                .textFieldStyle(.roundedBorder)

            Button(action: onNext) {
                Text("Next")
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

private struct HandleDobStep: View {
    @Binding var handle: String
    @Binding var dob: Date
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pick a username").font(.title2.bold())
            TextField("username (handle)", text: $handle)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            DatePicker("DOB (≥13 yrs)", selection: $dob, displayedComponents: .date)

            Button(action: onNext) {
                Text("Next")
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(handle.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

private struct AgreeStep: View {
    let isBusy: Bool
    let canCreate: Bool
    let onCreate: () -> Void
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

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

private struct VerifyStep: View {
    let dest: String?
    @Binding var code: String
    let isBusy: Bool
    let onConfirm: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Verify your account").font(.title2.bold())
            if let d = dest, !d.isEmpty {
                Text("Enter the code sent to \(d).")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            TextField("verification code", text: $code)
                .textFieldStyle(.roundedBorder)

            Button(action: onConfirm) {
                Text("Confirm")
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

private struct DoneStep: View {
    let idToken: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All set!").font(.title2.bold())
            if !idToken.isEmpty {
                Text("ID: \(idToken)").font(.footnote).monospaced()
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

// MARK: - Preview

#Preview {
    UserRegisterFlow()
}
