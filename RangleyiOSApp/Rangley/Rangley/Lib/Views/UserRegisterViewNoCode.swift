//
//  UserRegisterFlowNoCode.swift
//  Rangley
//
//  Created by You on 9/10/25.

import SwiftUI
import Amplify
import AWSPluginsCore
import UIKit

// MARK: - Error explainer (Amplify 2.x)
fileprivate func explainAuth(_ error: Error) -> String
{
    if let ae = error as? AuthError {
        var parts = [ae.errorDescription]
        let rs = ae.recoverySuggestion; if !rs.isEmpty { parts.append(rs) }
        if let underlying = ae.underlyingError as NSError? {
            let type = (underlying.userInfo["__type"] as? String)
                ?? (underlying.userInfo["code"] as? String) ?? underlying.domain
            let msg  = (underlying.userInfo["message"] as? String)
                ?? underlying.localizedDescription
            parts.append("underlying: \(type) \(msg)")
        }
        return parts.joined(separator: " | ")
    }
    return String(describing: error)
}

// MARK: - Form & Flow State

private struct FormState: Equatable
{
    var phoneRaw: String = ""          // user-typed (we’ll normalize on advance)
    var email: String = ""
    var password: String = ""
    var displayName: String = ""
    var username: String = ""
    var dob: Date = .init(timeIntervalSince1970: 0)
}

private enum Step: Hashable {
    case cellphone
    case verifyPhone(phone: String)  // NEW
    case password
    case display
    case username
    case dob
    case agree
    case done
}

private enum BannerState: Equatable
{
    case none
    case info(String)
    case error(String)
    case success(String)
}

private enum FlowState: Equatable
{
    case collecting(Step)          // gather inputs
    case signingIn                 // transient
    case signedIn(idToken: String) // final
    case failed(String)
}

// MARK: - Auth client abstraction (thin wrapper over Amplify)

// Update your AuthClient protocol
private protocol AuthClient
{
    func signUp(username: String, password: String, attributes: [AuthUserAttribute]) async throws -> AuthSignUpResult
    func confirmSignUp(for username: String, confirmationCode: String) async throws -> AuthSignUpResult  // Updated
    func resendSignUpCode(for username: String) async throws -> AuthCodeDeliveryDetails
    func signIn(username: String, password: String) async throws -> AuthSignInResult
    func fetchTokens() async throws -> String
}

private struct AmplifyAuthClient: AuthClient
{
    func confirmSignUp(for username: String, confirmationCode: String) async throws -> AuthSignUpResult {
        try await Amplify.Auth.confirmSignUp(for: username, confirmationCode: confirmationCode)
    }
    
    func resendSignUpCode(for username: String) async throws -> AuthCodeDeliveryDetails {
        try await Amplify.Auth.resendSignUpCode(for: username)
    }
    
    
    func signUp(username: String, password: String, attributes: [AuthUserAttribute]) async throws -> AuthSignUpResult
    {
        try await Amplify.Auth.signUp(username: username, password: password, options: .init(userAttributes: attributes))
    }
    
    func signIn(username: String, password: String) async throws -> AuthSignInResult
    {
        try await Amplify.Auth.signIn(username: username, password: password)
    }
    
    func autoSignIn() async throws -> AuthSignInResult
    {
        try await Amplify.Auth.autoSignIn()
    }
    
    func fetchTokens() async throws -> String
    {
        let s = try await Amplify.Auth.fetchAuthSession()
        guard s.isSignedIn, let p = s as? AuthCognitoTokensProvider else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        let tokens = try p.getCognitoTokens().get()
        return tokens.idToken
    }
}

// MARK: - ViewModel (Reducer + Effects)

// Update RegisterVM with verification logic
@MainActor
private final class RegisterVM: ObservableObject
{
    // Add these properties
    @Published var verificationCode = ""
    @Published var isResending = false
    
    // Update createAccount method
    func createAccount() async {
        guard inputsForCreateOK else { return }
        guard let phone = e164Phone else { return }

        let handle = normalizedHandle()
        guard !handle.isEmpty, !handleLooksLikeAlias(handle) else {
            banner = .error("Pick a handle that isn't an email or phone.")
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            var attrs: [AuthUserAttribute] = [.init(.phoneNumber, value: phone)]
            if emailValid, !form.email.isEmpty {
                attrs.append(.init(.email, value: form.email))
            }

            let result = try await auth.signUp(
                username: handle,
                password: form.password,
                attributes: attrs
            )
            
            // Check if confirmation is needed
            if !result.isSignUpComplete {
                flow = .collecting(.verifyPhone(phone: phone))
                banner = .info("Verification code sent to \(phone)")
            } else {
                await postSignUpAutoFlow()
            }
            
        } catch {
            Log.auth.error("SignUp failed: \(explainAuth(error))")
            banner = .error("Sign up failed: " + explainAuth(error))
        }
    }
    
    // Add phone verification method
    func verifyPhone() async {
        guard case .collecting(.verifyPhone(_)) = flow else { return }
        guard !verificationCode.isEmpty else {
            banner = .error("Enter the verification code")
            return
        }
        
        isBusy = true
        defer { isBusy = false }
        
        do {
            let handle = normalizedHandle()
            let result = try await auth.confirmSignUp(
                for: handle,
                confirmationCode: verificationCode
            )
            
            if result.isSignUpComplete {
                await postSignUpAutoFlow()
            } else {
                banner = .error("Verification failed. Please try again.")
            }
            
        } catch {
            Log.auth.error("Phone verification failed: \(explainAuth(error))")
            banner = .error("Verification failed: " + explainAuth(error))
        }
    }
    
    // Add resend code method
    func resendVerificationCode() async {
        guard case .collecting(.verifyPhone(_)) = flow else { return }
        
        isResending = true
        defer { isResending = false }
        
        do {
            let handle = normalizedHandle()
            _ = try await auth.resendSignUpCode(for: handle)
            banner = .info("New code sent")
        } catch {
            banner = .error("Failed to resend code")
        }
    }
    
    // Update navigation methods
    func advanceFromCellphone() {
        if canAdvanceFromCellphone {
            // Skip directly to verification during sign-up
            Task { await createAccount() }
        }
    }
}


// MARK: - Views

struct UserRegisterFlow: View
{
    @StateObject private var vm = RegisterVM()
    @State private var goToMap = false

    var body: some View
    {
       NavigationStack {
           VStack(spacing: 0) {
               bannerView(vm.banner)
               content
           }
           .toolbar {
               ToolbarItem(placement: .topBarLeading) {
                   if canGoBack { Button(action: vm.back) { Image(systemName: "chevron.left") } }
               }
           }
           .background(AppPalette.bgGradient.ignoresSafeArea())
       }
       // NEW: iOS 17+ boolean destination
       .fullScreenCover(isPresented: $goToMap) {
           PublicMapView()
               .interactiveDismissDisabled(true)   // prevents swipe-to-dismiss
       }
       // Flip when VM reaches signed-in
       .onChange(of: vm.flow) { _, newValue in
           if case .signedIn = newValue { goToMap = true }
       }
   }

    @ViewBuilder
    private var content: some View
    {
        switch vm.flow {
        case .collecting(let step):
            switch step {
            case .cellphone: CellphoneStep(
                phoneRaw: $vm.form.phoneRaw,
                email: $vm.form.email,
                emailValid: vm.emailValid,
                e164Phone: vm.e164Phone,
                onNext: vm.advanceFromIdChooser,
                canContinue: vm.canAdvanceFromCellphone
            )
            case .verifyPhone(let phone): VerifyPhoneStep(
                phone: phone,
                verificationCode: $vm.verificationCode,
                isBusy: vm.isBusy,
                isResending: vm.isResending,
                onVerify: { Task { await vm.verifyPhone() } },
                onResend: { Task { await vm.resendVerificationCode() } }
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
            case .username: UsernameStep(
                username: $vm.form.username,
                onNext: vm.advanceFromUsername
            )
            case .dob: DobStep(
                dob: $vm.form.dob,
                onNext: vm.advanceFromDob
            )
            case .agree: AgreeStep(
                isBusy: vm.isBusy,
                canCreate: vm.inputsForCreateOK,
                onCreate: { Task { await vm.createAccount() } }
            )
            case .done:
                EmptyView()
            }

        case .signingIn:
            ProgressView().padding().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        case .signedIn:
            EmptyView().onAppear { goToMap = true }

        case .failed(let msg):
            VStack(spacing: 16) {
                Text("Couldn’t complete sign in.").font(.title3.bold())
                Text(msg).font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }
    }

    private var canGoBack: Bool
    {
        switch vm.flow {
        case .collecting(let step):
            return step != .cellphone
        default:
            return false
        }
    }

    private var tokenPreview: String
    {
        if case let .signedIn(idToken) = vm.flow {
            return String(idToken.prefix(32)) + "…"
        }
        return ""
    }

    @ViewBuilder
    private func bannerView(_ b: BannerState) -> some View
    {
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

private struct CellphoneStep: View
{
    @Binding var phoneRaw: String
    @Binding var email: String
    let emailValid: Bool
    let e164Phone: String?
    let onNext: () -> Void
    let canContinue : Bool

    @FocusState private var phoneFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Please Enter Phone")
                    .font(.title2.bold())
                    .foregroundStyle(AppPalette.Text.primary)

                TextField("Mobile Number (+13125551234)", text: $phoneRaw)
                    .keyboardType(.phonePad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .focused($phoneFocused)
                    .darkField(focused: phoneFocused)

                if let p = e164Phone, !p.isEmpty {
                    Text("Formatted as \(p)").font(.footnote)
                        .foregroundStyle(AppPalette.Text.secondary)
                } else if !phoneRaw.isEmpty {
                    Text("Tip: use + and digits only").font(.footnote)
                        .foregroundStyle(AppPalette.Text.secondary)
                }

                Text(.init("""
                By continuing, you agree to our [Terms](https://mrfoxco.com/terms) and [Privacy Policy](https://mrfoxco.com/privacy).
                **Note:** We aren’t sending verification codes in this release.
                """))
                .font(.subheadline)
                .foregroundStyle(AppPalette.Text.tertiary)
                .tint(AppPalette.Brand.neonPink)          // link color

                Button(action: onNext) { Text("Next") }
                    .buttonStyle(PrimaryCapsuleButton())
                    .disabled(!canContinue)
                    .opacity(canContinue ? 1 : 0.45)

                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }
}

// Add new verification step view
private struct VerifyPhoneStep: View
{
    let phone: String
    @Binding var verificationCode: String
    let isBusy: Bool
    let isResending: Bool
    let onVerify: () -> Void
    let onResend: () -> Void
    
    @FocusState private var codeFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter verification code")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("We sent a 6-digit code to \(phone)")
                .font(.subheadline)
                .foregroundStyle(AppPalette.Text.secondary)
            
            TextField("000000", text: $verificationCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title.monospacedDigit())
                .textFieldStyle(.plain)
                .focused($codeFocused)
                .darkField(focused: codeFocused)
                .onAppear { codeFocused = true }
            
            Button(action: onVerify) {
                HStack {
                    if isBusy {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.black)
                            .scaleEffect(0.8)
                    }
                    Text(isBusy ? "Verifying..." : "Verify")
                        .bold()
                }
            }
            .buttonStyle(PrimaryCapsuleButton())
            .disabled(verificationCode.count != 6 || isBusy)
            .opacity((verificationCode.count == 6 && !isBusy) ? 1 : 0.45)
            
            Button(action: onResend) {
                HStack {
                    if isResending {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                    }
                    Text(isResending ? "Sending..." : "Send new code")
                }
            }
            .font(.footnote)
            .foregroundColor(AppPalette.Brand.neonPink)
            .disabled(isResending)
            
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

private struct PasswordStep: View
{
    @Binding var password: String
    let score: (ok: Bool, reasons: [String])
    let onNext: () -> Void

    @State private var confirm: String = ""

    @FocusState private var passFocused: Bool
    @FocusState private var confirmFocused: Bool

    private var matches: Bool {
        !confirm.isEmpty && confirm == password
    }
    private var canContinue: Bool {
        score.ok && matches
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create a password")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)

            // Password
            SecureField(
                "", text: $password,
                prompt: Text("Password").foregroundStyle(.white.opacity(0.95))
            )
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.newPassword)
            .keyboardType(.default)
            .foregroundColor(.white)
            .tint(AppPalette.Brand.neonPink)
            .focused($passFocused)
            .darkField(focused: passFocused)
            .submitLabel(.next)
            .onSubmit { confirmFocused = true }

            // Confirm
            SecureField(
                "", text: $confirm,
                prompt: Text("Confirm password").foregroundStyle(.white.opacity(0.95))
            )
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.newPassword)
            .keyboardType(.default)
            .foregroundColor(.white)
            .tint(AppPalette.Brand.neonPink)
            .focused($confirmFocused)
            .darkField(focused: confirmFocused)
            .submitLabel(.done)
            .onSubmit { if canContinue { onNext() } }

            if !confirm.isEmpty && !matches {
                Text("Passwords don’t match")
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 6) {
                rule("≥ 8 characters", password.count >= 8)
                rule("1 lowercase (a–z)", password.range(of: "[a-z]", options: .regularExpression) != nil)
                rule("1 uppercase (A–Z)", password.range(of: "[A-Z]", options: .regularExpression) != nil)
                rule("1 number (0–9)", password.range(of: "\\d", options: .regularExpression) != nil)
                rule("1 special (!@#…)", password.range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil)
                rule("No leading/trailing spaces", password.range(of: #"^\S+.*\S+$"#, options: .regularExpression) != nil)
                rule("Passwords match", matches)
            }

            Button(action: onNext) { Text("Next") }
                .buttonStyle(PrimaryCapsuleButton())
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.45)
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    @ViewBuilder private func rule(_ t: String, _ ok: Bool) -> some View {
        HStack { Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle"); Text(t) }
            .foregroundStyle(ok ? .green : AppPalette.Text.secondary)
            .font(.footnote)
    }
}

private struct DisplayStep: View
{
    @Binding var displayName: String
    let onNext: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose a display name")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)

            TextField(
                "", text: $displayName,
                prompt: Text("Display name").foregroundStyle(.white.opacity(0.95))
            )
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .foregroundColor(.white)
            .tint(AppPalette.Brand.neonPink)
            .focused($focused)
            .darkField(focused: focused)

            let isNameFilled = !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            Button(action: onNext) { Text("Next") }
                .buttonStyle(PrimaryCapsuleButton())
                .disabled(!isNameFilled)
                .opacity(isNameFilled ? 1 : 0.45)
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

private struct UsernameStep: View
{
    @Binding var username: String
    let onNext: () -> Void

    @FocusState private var handleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pick a username")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)

            TextField(
                "", text: $username,
                prompt: Text("username").foregroundStyle(.white.opacity(0.95))
            )
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.username)
            .foregroundColor(.white)
            .tint(AppPalette.Brand.neonPink)
            .focused($handleFocused)
            .darkField(focused: handleFocused)
            
            Button(action: onNext) { Text("Next") }
                .buttonStyle(PrimaryCapsuleButton())
                .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

private struct DobStep: View
{
    @Binding var dob: Date
    let onNext: () -> Void

    var body: some View
    {
        VStack(alignment: .leading, spacing: 14)
        {
            Text("What's your birthday?")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)
            Text(.init("""
            Use your real date of birth. We use it only to confirm eligibility (13+) and safety; it isn’t shown publicly by default. [Why do we ask?](https://mrfoxco.com/privacy#dob)
            """))
            .font(.subheadline)
            .foregroundStyle(AppPalette.Text.tertiary)
            .tint(AppPalette.Brand.neonPink)
            // Skinned DatePicker to match fields
            DatePicker("", selection: $dob, displayedComponents: .date)
                .labelsHidden()
                .tint(AppPalette.Brand.neonPink)
                .colorScheme(.dark)
                .padding(.horizontal, 12).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.22))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )

            Button(action: onNext) { Text("Next") }
                .buttonStyle(PrimaryCapsuleButton())
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

private struct AgreeStep: View
{
    let isBusy: Bool
    let canCreate: Bool
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agree to Rangley's terms and policies")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)

            Text(.init("""
            By tapping **I agree** you agree to create an account and to Rangley's [Terms](https://mrfoxco.com/terms) & [Privacy Policy](https://mrfoxco.com/privacy).

            We use your phone and (if enabled) location to show whether you’re **near** an event or **at** it using a geofence. Other users see only “checked in”, never your exact location unless you check in. We don’t use your info for ads. No verification codes are sent in this release.
            """))
            .font(.subheadline)
            .foregroundStyle(AppPalette.Text.tertiary)
            .tint(AppPalette.Brand.neonPink)

            Button(action: onCreate) {
                HStack { if isBusy { ProgressView() }; Text(isBusy ? "Creating…" : "I Agree").bold() }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            .buttonStyle(PrimaryCapsuleButton())
            .disabled(isBusy || !canCreate)

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

private struct DoneStep: View
{
    let idToken: String
    var body: some View
    {
        VStack(alignment: .leading, spacing: 12) {
            Text("All set!")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)

            if !idToken.isEmpty {
                Text("ID: \(idToken)")
                    .font(.footnote).monospaced()
                    .foregroundStyle(AppPalette.Text.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}
