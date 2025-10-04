//
//  UserRegisterViewNoAudt.swift
//  Rangley
//
//  Created by You on 9/10/25.

import SwiftUI
import Amplify
import AWSPluginsCore
import UIKit



//TODO: pull base url from config
// MARK: - Form & Flow State

private struct FormState: Equatable
{
    var phoneRaw        : String = ""          // user-typed (we'll normalize on advance)
    var email           : String = ""
    var password        : String = ""
    var displayName     : String = ""
    var username        : String = ""
    var dob             : String = ""
}

// Add these to your existing Step enum
private enum Step: Hashable {
    case cellphone
    case verifyPhone(phone: String)
    case display
    case username
    case dob
    case password  // Moved to second-to-last
    case agree
    case saveCredentials
    case done
}

private enum FlowState: Equatable
{
    case collecting(Step)          // gather inputs
    case signingIn                 // transient
    case signedIn(idToken: String) // final
    case failed(String)
}

// MARK: - Auth client abstraction (thin wrapper over Amplify)

private protocol AuthClient {
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

@MainActor
private final class RegisterVM: ObservableObject
{
    @Published var form = FormState()
    @Published var flow: FlowState = .collecting(.cellphone)
    @Published var phoneStatus      : StatusMessage = .none
    @Published var verifyStatus     : StatusMessage = .none
    @Published var passwordStatus   : StatusMessage = .none
    @Published var signUpStatus     : StatusMessage = .none
    @Published var isBusy = false
    @Published var verificationCode = ""
    @Published var isResending = false
    @Published var rememberPassword = true
    @Published var useBiometrics = true
    @Published var isSavingCredentials = false
    @Published var pendingIdToken: String?
    
    // MARK: cleanign input
    @Published var displayNameStatus: StatusMessage = .none
    @Published var usernameStatus: StatusMessage = .none
    @Published var isValidatingDisplayName = false
    @Published var isValidatingUsername = false
    
    // config
    let baseURL = URL(string: "https://api.mrfoxco.com")! // move to config as needed

    // deps
    private let auth: AuthClient
    private let df: DateFormatter

    init(auth: AuthClient = AmplifyAuthClient())
    {
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
    var e164Phone: String?
    {
        let ds = phoneDigits
        switch ds.count {
        case 10:                         return "+1" + ds          // US default
        case 11 where ds.hasPrefix("1"): return "+" + ds
        case 12...15:                    return "+" + ds
        default:                         return nil
        }
    }
    // ^^ Connected to this
    var canAdvanceFromCellphone: Bool
    {
        // phone required (email ignored for now)
        return e164Phone != nil
    }
    
    var emailValid: Bool
    {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return form.email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    var passwordScore: (ok: Bool, reasons: [String])
    {
        var reasons: [String] = []
        if form.password.count < 8 { reasons.append("≥ 8 chars") }
        if form.password.range(of: "\\d", options: .regularExpression) == nil { reasons.append("number") }
        if form.password.range(of: "[A-Z]", options: .regularExpression) == nil { reasons.append("uppercase") }
        if form.password.range(of: "[a-z]", options: .regularExpression) == nil { reasons.append("lowercase") }
        if form.password.range(of: #"^\S+.*\S+$"#, options: .regularExpression) == nil { reasons.append("no edge spaces") }
        return (reasons.isEmpty, reasons)
    }
    
    private var principal: String?
    {
        if emailValid { return form.email }
        if let p = e164Phone { return p }
        return nil
    }
    
    var inputsForCreateOK: Bool
    {
        principal != nil
        && passwordScore.ok
        && !form.displayName.trimmingCharacters(in: .whitespaces).isEmpty
        && !form.username.trimmingCharacters(in: .whitespaces).isEmpty
        && is13OrOlder(form.dob)
    }

    private func is13OrOlder(_ dobString: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let dob = formatter.date(from: dobString) else { return false }
        
        let years = Calendar(identifier: .gregorian).dateComponents([.year], from: dob, to: Date()).year ?? 0
        return years >= 13
    }

    // MARK: - Navigation / Reducer-ish methods


    // MARK: - Updated navigation methods to include phone verification
    func back()
    {
        switch flow {
        case .collecting(let step):
            switch step {
            case .cellphone: break
            case .verifyPhone: flow = .collecting(.cellphone)
            case .display: flow = .collecting(.verifyPhone(phone: e164Phone ?? ""))  // Go back to verification
            case .username: flow = .collecting(.display)
            case .dob: flow = .collecting(.username)
            case .password: flow = .collecting(.dob)
            case .agree: flow = .collecting(.password)
            case .saveCredentials: flow = .collecting(.agree)
            case .done: break
            }
        case .signingIn, .signedIn, .failed:
            break
        }
    }

    func advanceFromCellphone() {
        if canAdvanceFromCellphone {
            // Send verification code and advance to verification step
            Task { await sendPhoneVerification() }
        }
    }

    
    func advanceFromIdChooser() {
        if self.canAdvanceFromCellphone {
            // Send verification code and advance to verification step
            Task { await sendPhoneVerification() }
        } else {
            Log.auth.debug("advanceFromIdChooser: invalid phone \(self.form.phoneRaw, privacy: .private)")
        }
    }
    
    // MARK: - Phone verification methods
    func sendPhoneVerification() async {
        guard let phone = e164Phone else { return }
        
        isBusy = true
        phoneStatus = .none
        defer { isBusy = false }
        
        do {
            try await AuthAPI.sendVerificationCode(baseURL: baseURL, phone: phone)
            flow = .collecting(.verifyPhone(phone: phone))
            verifyStatus = .info("Code sent to \(phone)")
        } catch {
            phoneStatus = .error("Couldn't send the code. Please try again")
        }
    }

    func verifyPhone() async
    {
        guard case .collecting(.verifyPhone(let phone)) = flow else { return }
        guard !verificationCode.isEmpty else {
            verifyStatus = .error("Enter the verification code")
            return
        }
        
        isBusy = true
        verifyStatus = .none
        defer { isBusy = false }
        
        do {
            let response = try await AuthAPI.verifyPhoneCode(
                baseURL: baseURL,
                phone: phone,
                code: verificationCode
            )
            
            if response.verified {
                flow = .collecting(.display)  // Go to display name after verification
                verifyStatus = .success("Phone verified!")
                // Clear the success after transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.verifyStatus = .none
                }
            } else {
                verifyStatus = .error("Invalid code. Please check and try again")
            }
        } catch {
            verifyStatus = .error("Verification failed")
        }
    }

    func resendVerificationCode() async
    {
        guard case .collecting(.verifyPhone(let phone)) = flow else { return }
        
        isResending = true
        verifyStatus = .none
        defer { isResending = false }
        
        do {
            // Resend using the same phone verification API
            try await AuthAPI.sendVerificationCode(baseURL: baseURL, phone: phone)
            verifyStatus = .info("New code sent to \(phone)")
        } catch {
            verifyStatus = .error("Couldn't resend the code. Please try again")
        }
    }
    
    func advanceFromPassword()
    {
        guard passwordScore.ok else {
            Log.auth.debug("Weak password")
            return
        }
        flow = .collecting(.agree)  // Go to agree after password
    }

    // Update advance methods to check validation status:
    func advanceFromDisplay() async
    {
        guard !form.displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            Log.auth.debug("Missing displayName")
            return
        }
        
        // Force validation if not already done
        if case .none = displayNameStatus {
            await validateDisplayName()
        }
        
        // Only advance if display name is valid
        switch displayNameStatus {
        case .success:
            flow = .collecting(.username)
        case .error:
            // Stay on current step - error is already shown
            break
        case .none, .info:
            // Validation in progress or failed to validate
            displayNameStatus = .error("Please verify your display name first")
        }
    }
    
    func advanceFromUsername() async
    {
        guard !form.username.trimmingCharacters(in: .whitespaces).isEmpty else {
            Log.auth.debug("Missing username")
            return
        }
        
        // Force validation if not already done
        if case .none = usernameStatus {
            await checkUsernameAvailability()
        }
        
        // Only advance if username is available
        switch usernameStatus {
        case .success:
            flow = .collecting(.dob)
        case .error:
            // Stay on current step - error is already shown
            break
        case .none, .info:
            // Validation in progress or failed to validate
            usernameStatus = .error("Please verify your username is available first")
        }
    }

    func advanceFromDob()
    {
        guard is13OrOlder(form.dob) else {
            Log.auth.warning("DOB under 13")
            return
        }
        flow = .collecting(.password)  // Go to password after DOB
    }
    
    // Put this in RegisterVM
    private func dobStringUTC(_ d: Date) -> String
    {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!         // pin UTC
        let parts = cal.dateComponents([.year,.month,.day], from: d)
        let noonUTC = cal.date(from: .init(year: parts.year, month: parts.month, day: parts.day, hour: 12))!
        return df.string(from: noonUTC)                     // df = "yyyy-MM-dd", tz UTC (as you already set)
    }


    // MARK: - Effects

    private func normalizedHandle() -> String
    {
        form.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private func handleLooksLikeAlias(_ s: String) -> Bool
    {
        let s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.contains("@") { return true }                            // email-like
        let allDigits = s.allSatisfy(\.isNumber)
        let plusDigits = s.hasPrefix("+") && s.dropFirst().allSatisfy(\.isNumber)
        return allDigits || plusDigits                                // phone-like
    }

    func validateDisplayName() async
    {
        guard !form.displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            displayNameStatus = .none
            return
        }
        
        isValidatingDisplayName = true
        displayNameStatus = .none
        defer { isValidatingDisplayName = false }
        
        do {
            let body = ValidateDisplayNameModelBody(display_name: form.displayName)
            let result = try await AuthAPI.validateDisplayName(baseURL: baseURL, body: body)
            
            if result.isValid {
                displayNameStatus = .success("Display name looks good!")
            } else {
                displayNameStatus = .error(result.message)
            }
        } catch {
            Log.auth.error("Display name validation failed: \(error)")
            displayNameStatus = .error("Unable to validate display name")
        }
    }

    func checkUsernameAvailability() async
    {
        let cleanUsername = form.username.trimmingCharacters(in: .whitespaces)
        guard !cleanUsername.isEmpty else {
            usernameStatus = .none
            return
        }
        
        isValidatingUsername = true
        usernameStatus = .none
        defer { isValidatingUsername = false }
        
        do {
            let body = CheckUsernameAvailabilityModelBody(username: cleanUsername)
            let result = try await AuthAPI.checkUsernameAvailability(baseURL: baseURL, body: body)
            
            if result.isAvailable {
                usernameStatus = .success("Username is available!")
            } else {
                usernameStatus = .error(result.message)
            }
        } catch {
            Log.auth.error("Username check failed: \(error)")
            usernameStatus = .error("Unable to check username availability")
        }
    }
    
    // MARK: - Updated validation methods with debouncing
    private var displayNameDebounceTask: Task<Void, Never>?
    private var usernameDebounceTask: Task<Void, Never>?

    func validateDisplayNameWithDebounce() {
        displayNameDebounceTask?.cancel()
        displayNameDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            if !Task.isCancelled {
                await validateDisplayName()
            }
        }
    }

    func checkUsernameAvailabilityWithDebounce() {
        usernameDebounceTask?.cancel()
        usernameDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            if !Task.isCancelled {
                await checkUsernameAvailability()
            }
        }
    }
    
    
    // SIGN UP
    func createAccount() async
    {
        guard inputsForCreateOK else { return }
        guard let phone = e164Phone else { return }

        let handle = normalizedHandle()
        guard !handle.isEmpty, !handleLooksLikeAlias(handle) else {
            signUpStatus = .error("Pick a handle that isn't an email or phone.")
            return
        }

        isBusy = true
        signUpStatus = .none
        defer { isBusy = false }

        do {
            var attrs: [AuthUserAttribute] = [.init(.phoneNumber, value: phone)]
            if emailValid, !form.email.isEmpty {
                attrs.append(.init(.email, value: form.email))
            }

            _ = try await auth.signUp(
                username: handle,
                password: form.password,
                attributes: attrs
            )
            
            // MODIFIED: Skip verification check, proceed directly
            await postSignUpAutoFlow()
            
        } catch {
            Log.auth.error("SignUp failed: \(error)")
            signUpStatus = .error(userFriendlyAuthError(error))
        }
    }

    // SIGN IN immediately after sign-up
    private func postSignUpAutoFlow() async
    {
        do {
            let uname = normalizedHandle()
            let res = try await self.auth.signIn(username: uname, password: self.form.password)
            await self.handleSignInResult(res)
        } catch {
            Log.auth.error("postSignUpAutoFlow signIn failed: \(error, privacy: .private)")
        }
    }

    @MainActor
    private func handleSignInResult(_ res: AuthSignInResult) async
    {
        if res.isSignedIn {
            guard let tok = try? await self.auth.fetchTokens() else {
                Log.auth.error("fetchTokens failed")
                return
            }
            
            // Store token and show credential saving screen
            pendingIdToken = tok
            flow = .collecting(.saveCredentials)
            
            // Do backend registration in background
            Task {
                do {
                    try await self.registerBackend(idToken: tok)
                    Log.auth.debug("Backend register OK")
                } catch {
                    Log.auth.error("Backend register failed: \(error.localizedDescription, privacy: .private)")
                }
            }
            return
        }
        Log.auth.warning("Additional verification required: \(String(describing: res.nextStep))")
    }
    

    func saveCredentialsAndComplete() async
    {
        let username = normalizedHandle()
        
        if rememberPassword {
            do {
                try KeychainAuth.save(
                    username: username,
                    password: form.password,
                    protectWithBiometrics: useBiometrics
                )
                Log.auth.info("Credentials saved successfully")
            } catch {
                Log.auth.error("Failed to save credentials: \(error)")
                // Don't block registration completion on keychain failure
            }
        }
        
        // Complete the flow using stored token
        if let token = pendingIdToken {
            flow = .signedIn(idToken: token)
        }
    }

    func skipCredentialSaving()
    {
        // Complete without saving
        if let token = pendingIdToken {
            flow = .signedIn(idToken: token)
        }
    }

    private func registerBackend(idToken: String) async throws
    {
        // Uses your existing AuthAPI + UserRegisterModel types
        let payload = UserRegisterModel(
            username: form.username,
            display_name: form.displayName,
            cellphone: e164Phone,
            email: emailValid ? form.email : nil,
            dob: form.dob,
            first_name: nil,
            last_name: nil
        )
        _ = try await AuthAPI.register(baseURL: baseURL, token: idToken, payload: payload)
    }
}

// MARK: - Status Message Types
private enum StatusMessage: Equatable
{
    case none
    case info(String)
    case error(String)
    case success(String)
}

// MARK: - Inline Status View Component
private struct InlineStatus: View
{
    let status: StatusMessage
    
    var body: some View {
        switch status {
        case .none:
            EmptyView()
        case .info(let message):
            statusView(message: message, color: .blue, icon: "info.circle.fill")
        case .success(let message):
            statusView(message: message, color: .green, icon: "checkmark.circle.fill")
        case .error(let message):
            statusView(message: message, color: .red, icon: "exclamationmark.triangle.fill")
        }
    }
    
    private func statusView(message: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
            Text(message)
                .font(.footnote)
        }
        .foregroundColor(color.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeInOut(duration: 0.2), value: status)
    }
}



// MARK: - Views

struct UserRegisterFlow: View
{
    @StateObject private var vm = RegisterVM()
    @State private var goToMap = false

    var body: some View
    {
        content
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    if canGoBack {
                        HStack {
                            Button(action: vm.back) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Previous")
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
            .background(AppPalette.bgGradient.ignoresSafeArea())
            .fullScreenCover(isPresented: $goToMap) {
                PublicMapView()
                    .interactiveDismissDisabled(true)
            }
            .onChange(of: vm.flow) { _, newValue in
                if case .signedIn = newValue { goToMap = true }
            }
   }

    // MARK: - Updated view builder to include phone verification step
    @ViewBuilder
    private var content: some View {
        switch vm.flow {
        case .collecting(let step):
            switch step {
            case .cellphone: CellphoneStep(
                phoneRaw: $vm.form.phoneRaw,
                email: $vm.form.email,
                emailValid: vm.emailValid,
                e164Phone: vm.e164Phone,
                phoneStatus: vm.phoneStatus,
                onNext: vm.advanceFromIdChooser,
                canContinue: vm.canAdvanceFromCellphone
            )
            case .verifyPhone(let phone): VerifyPhoneStep(
                phone: phone,
                verificationCode: $vm.verificationCode,
                verifyStatus: vm.verifyStatus,
                isBusy: vm.isBusy,
                isResending: vm.isResending,
                onVerify: { Task { await vm.verifyPhone() } },
                onResend: { Task { await vm.resendVerificationCode() } }
            )
            case .display: DisplayStep(
                displayName: $vm.form.displayName,
                displayNameStatus: vm.displayNameStatus,
                isValidating: vm.isValidatingDisplayName,
                onNext: { Task { await vm.advanceFromDisplay() } },
                onValidate: { vm.validateDisplayNameWithDebounce() }
            )
            case .username: UsernameStep(
                username: $vm.form.username,
                usernameStatus: vm.usernameStatus,
                isValidating: vm.isValidatingUsername,
                onNext: { Task { await vm.advanceFromUsername() } },
                onValidate: { vm.checkUsernameAvailabilityWithDebounce() }
            )
            case .dob: DobStep(
                dob: $vm.form.dob,
                onNext: vm.advanceFromDob
            )
            case .password: PasswordStep(
                password: $vm.form.password,
                score: vm.passwordScore,
                onNext: vm.advanceFromPassword
            )
            case .agree: AgreeStep(
                isBusy: vm.isBusy,
                canCreate: vm.inputsForCreateOK,
                signUpStatus: vm.signUpStatus,
                onCreate: { Task { await vm.createAccount() } }
            )
            case .saveCredentials: SaveCredentialsStep(
                rememberPassword: $vm.rememberPassword,
                useBiometrics: $vm.useBiometrics,
                isBusy: vm.isSavingCredentials,
                onSave: { Task { await vm.saveCredentialsAndComplete() } },
                onSkip: vm.skipCredentialSaving
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
                Text("Couldn't complete sign in.").font(.title3.bold())
                Text(msg).font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }
    }

    private var canGoBack: Bool {
        switch vm.flow {
        case .collecting(let step):
            return step != .cellphone && step != .saveCredentials
        default:
            return false
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
    let phoneStatus: StatusMessage
    let onNext: () -> Void
    let canContinue: Bool

    @FocusState private var phoneFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Please Enter Phone")
                    .font(.title2.bold())
                    .foregroundStyle(AppPalette.Text.primary)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Mobile Number (+13125551234)", text: $phoneRaw)
                        .keyboardType(.phonePad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.plain)
                        .focused($phoneFocused)
                        .darkField(focused: phoneFocused)

                    if let p = e164Phone, !p.isEmpty {
                        Text("Formatted as \(p)")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.Text.secondary)
                    } else if !phoneRaw.isEmpty {
                        Text("Tip: use + and digits only")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.Text.secondary)
                    }
                    
                    // Seamless status integration
                    InlineStatus(status: phoneStatus)
                }

                Text(.init("""
                By continuing, you agree to our [Terms](https://mrfoxco.com/terms) and [Privacy Policy](https://mrfoxco.com/privacy).
                """))
                .font(.subheadline)
                .foregroundStyle(AppPalette.Text.tertiary)
                .tint(AppPalette.Brand.neonPink)

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

private struct VerifyPhoneStep: View
{
    let phone: String
    @Binding var verificationCode: String
    let verifyStatus: StatusMessage
    let isBusy: Bool
    let isResending: Bool
    let onVerify: () -> Void
    let onResend: () -> Void
    
    @FocusState private var codeFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Enter verification code")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("We sent a 6-digit code to \(phone)")
                .font(.subheadline)
                .foregroundStyle(AppPalette.Text.secondary)
            
            VStack(spacing: 12) {
                DigitCodeInput(
                    code: $verificationCode,
                    digitCount: 6,
                    focused: $codeFocused
                )
                .onAppear { codeFocused = true }
                
                // Status integrated right below the input
                InlineStatus(status: verifyStatus)
            }
            
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

private struct AgreeStep: View
{
    let isBusy: Bool
    let canCreate: Bool
    let signUpStatus: StatusMessage
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Agree to Rangley's terms and policies")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)

            Text(.init("""
            By tapping **I agree** you agree to create an account and to Rangley's [Terms](https://mrfoxco.com/terms) & [Privacy Policy](https://mrfoxco.com/privacy).

            We use your phone and (if enabled) location to show whether you're **near** an event or **at** it using a geofence. Other users see only "checked in", never your exact location unless you check in. We don't use your info for ads.
            """))
            .font(.subheadline)
            .foregroundStyle(AppPalette.Text.tertiary)
            .tint(AppPalette.Brand.neonPink)

            VStack(spacing: 12) {
                Button(action: onCreate) {
                    HStack {
                        if isBusy { ProgressView() }
                        Text(isBusy ? "Creating…" : "I Agree").bold()
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                }
                .buttonStyle(PrimaryCapsuleButton())
                .disabled(isBusy || !canCreate)
                
                // Status appears right after the button
                InlineStatus(status: signUpStatus)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

// MARK: - Custom 6-Digit Code Input

private struct DigitCodeInput: View
{
    @Binding var code: String
    let digitCount: Int
    @FocusState.Binding var focused: Bool
    
    var body: some View {
        ZStack {
            // Hidden TextField that captures the actual input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0) // Make it invisible
                .onChange(of: code) { _, newValue in
                    // Limit to digit count and only allow numbers
                    let filtered = String(newValue.filter { $0.isNumber }.prefix(digitCount))
                    if filtered != code {
                        code = filtered
                    }
                }
            
            // Visual representation with individual digit blocks
            HStack(spacing: 12) {
                ForEach(0..<digitCount, id: \.self) { index in
                    DigitBlock(
                        digit: digitAt(index: index),
                        isActive: index == code.count && focused,
                        isFilled: index < code.count
                    )
                }
            }
        }
        .onTapGesture {
            focused = true
        }
    }
    
    private func digitAt(index: Int) -> String {
        guard index < code.count else { return "" }
        let digitIndex = code.index(code.startIndex, offsetBy: index)
        return String(code[digitIndex])
    }
}


private struct DigitBlock: View
{
    let digit: String
    let isActive: Bool
    let isFilled: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.15))
                .frame(width: 44, height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isActive ? AppPalette.Brand.neonPink : Color.white.opacity(0.3),
                            lineWidth: isActive ? 2 : 1
                        )
                )
            
            if !digit.isEmpty {
                Text(digit)
                    .font(.title.monospacedDigit().bold())
                    .foregroundColor(.white)
            } else if isActive {
                // Blinking cursor effect
                Rectangle()
                    .fill(AppPalette.Brand.neonPink)
                    .frame(width: 2, height: 24)
                    .opacity(isActive ? 1 : 0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isActive)
            }
        }
    }
}

// MARK: - Fixed UsernameStep with proper pattern matching
private struct UsernameStep: View
{
    @Binding var username: String
    let usernameStatus: StatusMessage
    let isValidating: Bool
    let onNext: () -> Void
    let onValidate: () -> Void

    @FocusState private var handleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pick a username")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)

            VStack(alignment: .leading, spacing: 8) {
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
                .onChange(of: username) { _, newValue in
                    if !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                        onValidate()
                    }
                }
                
                // Show validation status
                if isValidating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                        Text("Checking availability...")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.Text.secondary)
                    }
                } else {
                    InlineStatus(status: usernameStatus)
                }
            }
            
            let isUsernameFilled = !username.trimmingCharacters(in: .whitespaces).isEmpty
            // Fixed pattern matching syntax
            let isAvailable: Bool = {
                if case .success = usernameStatus {
                    return true
                }
                return false
            }()
           let _ = isUsernameFilled && !isValidating && isAvailable

            Button(action: onNext) {
                Text(isAvailable ? "Next" : "Check & Continue")
            }
            .buttonStyle(PrimaryCapsuleButton())
            .disabled(!isUsernameFilled || isValidating)
            .opacity(isUsernameFilled && !isValidating ? 1 : 0.45)
            .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

// MARK: - Fixed DisplayStep with proper pattern matching
private struct DisplayStep: View
{
    @Binding var displayName: String
    let displayNameStatus: StatusMessage
    let isValidating: Bool
    let onNext: () -> Void
    let onValidate: () -> Void
    
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose a display name")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)

            VStack(alignment: .leading, spacing: 8) {
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
                .onChange(of: displayName) { _, newValue in
                    if !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                        onValidate()
                    }
                }
                
                // Show validation status
                if isValidating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                        Text("Checking...")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.Text.secondary)
                    }
                } else {
                    InlineStatus(status: displayNameStatus)
                }
            }

            let isNameFilled = !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            // Fixed pattern matching syntax
            let isValidated: Bool = {
                if case .success = displayNameStatus {
                    return true
                }
                return false
            }()
            let _ = isNameFilled && !isValidating && isValidated

            Button(action: onNext) {
                Text(isValidated ? "Next" : "Verify & Continue")
            }
            .buttonStyle(PrimaryCapsuleButton())
            .disabled(!isNameFilled || isValidating)
            .opacity(isNameFilled && !isValidating ? 1 : 0.45)
            .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}


private struct DobStep: View
{
    @Binding var dob: String
    let onNext: () -> Void
    
    @State private var pickerDate = Date()
    // Remove dobStatus - no longer needed since invalid dates can't be selected
    
    // Calculate the maximum date (13 years ago)
    private var maxBirthDate: Date {
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(byAdding: .year, value: -13, to: Date()) ?? Date()
    }
    
    var body: some View
    {
        VStack(alignment: .leading, spacing: 14)
        {
            Text("What's your birthday?")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)
            Text(.init("""
            Use your real date of birth. We use it only to confirm eligibility (13+) and safety; it isn't shown publicly by default. [Why do we ask?](https://mrfoxco.com/privacy#dob)
            """))
            .font(.subheadline)
            .foregroundStyle(AppPalette.Text.tertiary)
            .tint(AppPalette.Brand.neonPink)
            
            ThemedDOBOnlyPicker(
                selection: $pickerDate,
                maximumDate: maxBirthDate
            )
            .onAppear {
                if !dob.isEmpty {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let existingDate = formatter.date(from: dob) {
                        pickerDate = existingDate
                    }
                } else {
                    pickerDate = maxBirthDate
                }
            }
            .onChange(of: pickerDate) { _, newDate in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                dob = formatter.string(from: newDate)
                // Remove dobStatus validation - no longer needed
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            
            // Remove InlineStatus - no validation errors possible
            // Remove hasAgeError logic - button is always enabled now
            Button(action: onNext) { Text("Next") }
                .buttonStyle(PrimaryCapsuleButton())
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .foregroundColor(AppPalette.Text.primary)
        .padding(16)
    }
}

private struct SaveCredentialsStep: View
{
    @Binding var rememberPassword: Bool
    @Binding var useBiometrics: Bool
    let isBusy: Bool
    let onSave: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Save your login?")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)

            Text("We can securely save your login details for faster access next time.")
                .font(.subheadline)
                .foregroundStyle(AppPalette.Text.secondary)

            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $rememberPassword) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Remember me")
                            .foregroundStyle(AppPalette.Text.primary)
                        Text("Save username and password")
                            .font(.caption)
                            .foregroundStyle(AppPalette.Text.secondary)
                    }
                }
                .tint(AppPalette.Brand.neonPink)

                Toggle(isOn: $useBiometrics) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Protect with Face ID")
                            .foregroundStyle(AppPalette.Text.primary)
                        Text("Require biometric authentication")
                            .font(.caption)
                            .foregroundStyle(AppPalette.Text.secondary)
                    }
                }
                .tint(AppPalette.Brand.neonPink)
                .disabled(!rememberPassword)
                .opacity(rememberPassword ? 1.0 : 0.6)
            }
            .padding(.vertical, 8)

            VStack(spacing: 12) {
                Button(action: onSave) {
                    HStack {
                        if isBusy {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.black)
                                .scaleEffect(0.8)
                        }
                        Text(rememberPassword ? (isBusy ? "Saving..." : "Save & Continue") : "Continue")
                            .bold()
                    }
                }
                .buttonStyle(PrimaryCapsuleButton())
                .disabled(isBusy)

                Button("Skip for now") {
                    onSkip()
                }
                .font(.footnote)
                .foregroundColor(AppPalette.Brand.neonPink)
                .disabled(isBusy)
            }

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

// MARK: - User-friendly error messages
fileprivate func userFriendlyAuthError(_ error: Error) -> String {
    if let ae = error as? AuthError {
        // Log the full technical details for debugging
        Log.auth.error("Auth error: \(ae.errorDescription) | \(ae.recoverySuggestion)")
        if let underlying = ae.underlyingError {
            Log.auth.error("Underlying error: \(underlying)")
        }
        
        // Return simple, user-friendly messages
        switch ae.errorDescription {
        case let desc where desc.contains("UsernameExistsException"):
            return "This username is already taken"
        case let desc where desc.contains("InvalidPasswordException"):
            return "Password doesn't meet requirements"
        case let desc where desc.contains("CodeMismatchException"):
            return "Invalid verification code"
        case let desc where desc.contains("ExpiredCodeException"):
            return "Verification code has expired"
        case let desc where desc.contains("NotAuthorizedException"):
            return "Incorrect username or password"
        case let desc where desc.contains("UserNotConfirmedException"):
            return "Account needs verification"
        case let desc where desc.contains("TooManyRequestsException"):
            return "Too many attempts. Please try again later"
        default:
            return "Something went wrong. Please try again"
        }
    }
    
    // Log non-auth errors too
    Log.auth.error("Non-auth error: \(error)")
    return "Something went wrong. Please try again"
}
