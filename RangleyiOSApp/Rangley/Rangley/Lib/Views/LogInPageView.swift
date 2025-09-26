//
//  LoginPageView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/22/25.

import SwiftUI
import Amplify
import AWSPluginsCore

// Error explainer (same shape as your register file)
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
            parts.append("underlying: \(type) (\(underlying.code)) \(msg)")
        }
        return parts.joined(separator: " | ")
    }
    return String(describing: error)
}

fileprivate enum BannerState: Equatable
{
    case none, info(String), error(String), success(String)
}

@MainActor
private final class SignInVM: ObservableObject
{
    // Inputs
    @Published var principalRaw = ""   // phone/username/email
    @Published var password = ""
    
    // UI
    @Published var banner: BannerState = .none
    @Published var isBusy = false
    @Published var idToken: String = ""
    
    // Remembered users UI
    struct SavedAccount: Identifiable, Hashable {
        let id = UUID()
        let username: String
        let label: String
    }
    @Published var savedAccounts: [SavedAccount] = []
    @Published var showUsernameChip = false
    
    // Settings
    @Published var rememberMe = true
    @Published var useBiometrics = true
    
    // CRITICAL: Load usernames WITHOUT triggering Face ID - just get the list
    func loadRememberedUsers()
    {
        // This method MUST NEVER trigger biometric authentication
        do {
            let usernames = try KeychainAuth.listUsernamesWithoutBiometrics()
            self.savedAccounts = usernames.map { username in
                let label: String
                if username.hasPrefix("+"), username.count >= 6 {
                    // Format phone numbers nicely
                    label = "Mobile ••••\(username.suffix(4))"
                } else if username.contains("@") {
                    // Format emails nicely
                    let parts = username.split(separator: "@")
                    if parts.count == 2 {
                        let localPart = String(parts[0])
                        let domain = String(parts[1])
                        if localPart.count > 3 {
                            label = "\(localPart.prefix(2))••••@\(domain)"
                        } else {
                            label = "••••@\(domain)"
                        }
                    } else {
                        label = username
                    }
                } else {
                    // Username format
                    if username.count > 6 {
                        label = "\(username.prefix(3))••••\(username.suffix(2))"
                    } else {
                        label = username
                    }
                }
                return SavedAccount(username: username, label: label)
            }
            
            // Show chip if we have saved accounts
            showUsernameChip = !savedAccounts.isEmpty
        } catch {
            // Silently fail - don't show chips if we can't load usernames safely
            self.savedAccounts = []
            self.showUsernameChip = false
        }
    }
    
    // CRITICAL: This is THE ONLY method that should trigger Face ID
    func authenticateAndFillCredentials(for username: String) async -> Bool
    {
        do {
            // This is THE SINGLE POINT where Face ID gets triggered
            guard let password = try KeychainAuth.loadPassword(
                username: username,
                prompt: "Authenticate to sign in as \(username)"
            ) else {
                await MainActor.run {
                    self.banner = .error("Could not retrieve saved password")
                }
                return false
            }
            
            // Fill both fields at once
            await MainActor.run {
                self.principalRaw = username
                self.password = password
                self.showUsernameChip = false
            }
            
            return true
        } catch {
            await MainActor.run {
                // Don't show error for user cancellation
                if (error as NSError).code != Int(errSecUserCanceled) {
                    self.banner = .error("Authentication failed")
                }
            }
            return false
        }
    }
    
    // Auto-login after successful credential fill - with better error handling
    func attemptAutoLogin(onSuccess: @escaping (String) -> Void) async
    {
        guard canSubmit else {
            await MainActor.run {
                self.banner = .error("Invalid credentials loaded")
            }
            return
        }
        
        await MainActor.run {
            self.banner = .info("Signing in...")
        }
        
        await signIn(onSuccess: onSuccess)
    }
    
    // Clear form
    func clearForm() {
        principalRaw = ""
        password = ""
        banner = .none
    }
    
    // ===== existing sign-in logic with improvements =====
    private var phoneDigits: String { principalRaw.filter(\.isNumber) }
    
    private var normalizedPrincipal: String
    {
        let trimmed = principalRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it looks like a phone number, normalize it
        let digits = trimmed.filter(\.isNumber)
        if digits.count >= 10 {
            switch digits.count {
            case 10: return "+1" + digits
            case 11 where digits.hasPrefix("1"): return "+" + digits
            case 12...15: return "+" + digits
            default: break
            }
        }
        
        // Otherwise return as-is (email or username)
        return trimmed
    }
    
    var canSubmit: Bool {
        !normalizedPrincipal.isEmpty && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func signIn(onSuccess: @escaping (String) -> Void) async
    {
        guard canSubmit else {
            banner = .error("Enter your phone (E.164), username, or email and password.")
            return
        }
        
        await MainActor.run {
            self.isBusy = true
            self.banner = .none
        }
        
        defer {
            Task { @MainActor in
                self.isBusy = false
            }
        }
        
        do {
            let res = try await Amplify.Auth.signIn(username: normalizedPrincipal, password: password)
            guard res.isSignedIn else {
                await MainActor.run {
                    self.banner = .error("Additional verification required and not supported here.")
                }
                return
            }
            let session = try await Amplify.Auth.fetchAuthSession()
            guard session.isSignedIn, let p = session as? AuthCognitoTokensProvider else {
                await MainActor.run {
                    self.banner = .error("Signed in, but no tokens available.")
                }
                return
            }
            let tokens = try p.getCognitoTokens().get()
            
            await MainActor.run {
                self.idToken = tokens.idToken
                self.banner = .success("Signed in successfully")
            }

            // Save credentials if remember me is enabled
            if rememberMe {
                try? KeychainAuth.save(username: normalizedPrincipal,
                                       password: password,
                                       protectWithBiometrics: useBiometrics)
            } else {
                // If remember me is off, remove any existing saved credentials
                KeychainAuth.delete(username: normalizedPrincipal)
            }
            
            onSuccess(tokens.idToken)
        } catch {
            await MainActor.run {
                self.banner = .error("SignIn: " + explainAuth(error))
            }
        }
    }
}

// MARK: - View

struct LogInPageView: View
{
    @EnvironmentObject private var auth: AuthStateStore
    
    @StateObject private var vm = SignInVM()
    @FocusState private var userFocused: Bool
    @FocusState private var passFocused: Bool
    
    @State private var showForgotPassword = false
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            Spacer()
            Image("RangleySticker")
                .resizable().scaledToFit().frame(width: 80, height: 80)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Banner for feedback
                    if case let .error(message) = vm.banner {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(message)
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.red.opacity(0.1))
                        .cornerRadius(8)
                    } else if case let .success(message) = vm.banner {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text(message)
                                .font(.caption)
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.green.opacity(0.1))
                        .cornerRadius(8)
                    } else if case let .info(message) = vm.banner {
                        HStack {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                            Text(message)
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.blue.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // === USERNAME ===
                    TextField("",
                              text: $vm.principalRaw,
                              prompt: Text("Phone, email, or username").foregroundStyle(.white.opacity(0.95)))
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .keyboardType(.default)
                        .foregroundColor(.white)
                        .tint(AppPalette.Brand.neonPink)
                        .focused($userFocused)
                        .darkField(focused: userFocused)
                        .onChange(of: userFocused) { _, focused in
                            if focused {
                                // CRITICAL: This MUST NOT trigger Face ID - only load the list!
                                vm.loadRememberedUsers()
                            } else {
                                vm.showUsernameChip = false
                            }
                        }
                        .onChange(of: vm.principalRaw) { _, _ in
                            // Clear banner when user starts typing manually
                            if case .error = vm.banner {
                                vm.banner = .none
                            }
                        }

                    // === PASSWORD ===
                    SecureField("",
                                text: $vm.password,
                                prompt: Text("Password").foregroundStyle(.white.opacity(0.95)))
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                        .keyboardType(.default)
                        .foregroundColor(.white)
                        .tint(AppPalette.Brand.neonPink)
                        .focused($passFocused)
                        .darkField(focused: passFocused)
                        .onChange(of: vm.password) { _, _ in
                            // Clear banner when user starts typing manually
                            if case .error = vm.banner {
                                vm.banner = .none
                            }
                        }

                    // LOG IN
                    Button {
                        Task {
                            await vm.signIn { _ in
                                auth.checkAuthenticationStatus()
                            }
                        }
                    } label: {
                        HStack {
                            if vm.isBusy {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.black)
                                    .scaleEffect(0.8)
                            }
                            Text(vm.isBusy ? "Signing in…" : "Sign In")
                                .bold()
                        }
                    }
                    .buttonStyle(PrimaryCapsuleButton(font: FontStyles.headline))
                    .disabled(!vm.canSubmit || vm.isBusy)
                    .opacity((!vm.canSubmit || vm.isBusy) ? 0.45 : 1)

                    // Remember me / Face ID
                    Toggle(isOn: $vm.rememberMe) {
                        Label("Remember me", systemImage: "key.fill")
                    }
                    .tint(AppPalette.Brand.neonPink)
                    .foregroundStyle(.white.opacity(0.9))

                    Toggle(isOn: $vm.useBiometrics) {
                        Label("Protect with Face ID", systemImage: "faceid")
                    }
                    .tint(AppPalette.Brand.neonPink)
                    .foregroundStyle(.white.opacity(0.9))
                    .disabled(!vm.rememberMe)
                    .opacity(vm.rememberMe ? 1.0 : 0.6)
                    
                    // Clear form button for testing
                    Button("Clear Form") {
                        vm.clearForm()
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    
                    Button("Forgot password?") {
                        showForgotPassword = true
                    }
                    .font(.footnote)
                    .foregroundColor(AppPalette.Brand.neonPink)
                    .padding(.top, 8)

                    Divider().background(Color.white.opacity(0.12)).padding(.vertical, 8)

                    NavigationLink { UserRegisterFlow() } label: {
                        Text("Create new account")
                    }
                    .buttonStyle(CreateNewAccountCapsuleButton(font: FontStyles.headline))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .padding(16)
            }
        }
        .foregroundStyle(.white)
        .tint(AppPalette.Brand.neonPink)
        .background(AppPalette.bgGradient.ignoresSafeArea())
        
        // CRITICAL: Username suggestion chips - NO Face ID until tapped!
        .safeAreaInset(edge: .bottom) {
            if vm.showUsernameChip && userFocused && !vm.savedAccounts.isEmpty {
                VStack(spacing: 8) {
                    // Header text
                    Text("Tap to sign in with saved account")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(vm.savedAccounts) { account in
                                Button {
                                    // CRITICAL: This is THE ONLY place Face ID should trigger
                                    Task {
                                        // First dismiss keyboard immediately for better UX
                                        userFocused = false
                                        vm.showUsernameChip = false
                                        
                                        // THIS IS THE SINGLE AUTHENTICATION POINT
                                        let success = await vm.authenticateAndFillCredentials(for: account.username)
                                        
                                        if success {
                                            // Auto-login after filling credentials successfully
                                            await vm.attemptAutoLogin { _ in
                                                auth.checkAuthenticationStatus()
                                            }
                                        }
                                        // If Face ID fails or is cancelled, do nothing
                                        // User can try again by tapping another chip
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "faceid")
                                            .imageScale(.small)
                                            .foregroundColor(.blue)
                                        Text(account.label)
                                            .font(.footnote)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.8))
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 44)
                }
                .background(.regularMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: vm.showUsernameChip)
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }
}
// MARK: - Forgot Password Flow Implementation

// Add these enums and state management to your LoginPageView.swift

private enum ForgotPasswordStep: Hashable
{
    case enterContact
    case verifyCode(contact: String)
    case enterNewPassword
    case complete
}

private enum ForgotPasswordFlowState: Equatable
{
    case collecting(ForgotPasswordStep)
    case resetting
    case completed
    case failed(String)
}

// MARK: - Forgot Password ViewModel

@MainActor
private final class ForgotPasswordVM: ObservableObject
{
    @Published var contactRaw: String = ""  // phone or email
    @Published var verificationCode: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""
    @Published var flow: ForgotPasswordFlowState = .collecting(.enterContact)
    
    // Status messages
    @Published var contactStatus: StatusMessage = .none
    @Published var verifyStatus: StatusMessage = .none
    @Published var passwordStatus: StatusMessage = .none
    
    // UI state
    @Published var isBusy = false
    @Published var isResending = false
    
    // Derived properties
    private var contactDigits: String { contactRaw.filter(\.isNumber) }
    
    private var normalizedContact: String {
        let trimmed = contactRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it looks like a phone number, normalize it
        let digits = trimmed.filter(\.isNumber)
        if digits.count >= 10 {
            switch digits.count {
            case 10: return "+1" + digits
            case 11 where digits.hasPrefix("1"): return "+" + digits
            case 12...15: return "+" + digits
            default: break
            }
        }
        
        // Otherwise return as-is (email or username)
        return trimmed
    }
    
    var canAdvanceFromContact: Bool {
        let contact = normalizedContact
        return !contact.isEmpty && (isValidEmail(contact) || isValidPhone(contact))
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    private func isValidPhone(_ phone: String) -> Bool {
        return phone.hasPrefix("+") && phone.dropFirst().allSatisfy(\.isNumber) && phone.count >= 11
    }
    
    var passwordScore: (ok: Bool, reasons: [String]) {
        var reasons: [String] = []
        if newPassword.count < 8 { reasons.append("≥ 8 chars") }
        if newPassword.range(of: "\\d", options: .regularExpression) == nil { reasons.append("number") }
        if newPassword.range(of: "[A-Z]", options: .regularExpression) == nil { reasons.append("uppercase") }
        if newPassword.range(of: "[a-z]", options: .regularExpression) == nil { reasons.append("lowercase") }
        if newPassword.range(of: #"^\S+.*\S+$"#, options: .regularExpression) == nil { reasons.append("no edge spaces") }
        return (reasons.isEmpty, reasons)
    }
    
    private var passwordsMatch: Bool {
        !confirmPassword.isEmpty && confirmPassword == newPassword
    }
    
    var canCompleteReset: Bool {
        passwordScore.ok && passwordsMatch
    }
    
    // MARK: - Navigation
    
    func back() {
        switch flow {
        case .collecting(let step):
            switch step {
            case .enterContact:
                break
            case .verifyCode:
                flow = .collecting(.enterContact)
            case .enterNewPassword:
                if let contact = getCurrentContact() {
                    flow = .collecting(.verifyCode(contact: contact))
                } else {
                    flow = .collecting(.enterContact)
                }
            case .complete:
                break
            }
        case .resetting, .completed, .failed:
            break
        }
    }
    
    private func getCurrentContact() -> String? {
        if case .collecting(.verifyCode(let contact)) = flow {
            return contact
        }
        return canAdvanceFromContact ? normalizedContact : nil
    }
    
    // MARK: - Flow Actions
    
    func initiatePasswordReset() async {
        guard canAdvanceFromContact else {
            contactStatus = .error("Enter a valid phone number or email address")
            return
        }
        
        isBusy = true
        contactStatus = .none
        defer { isBusy = false }
        
        let contact = normalizedContact
        
        do {
            _ = try await Amplify.Auth.resetPassword(for: contact)
            flow = .collecting(.verifyCode(contact: contact))
            verifyStatus = .info("Reset code sent to \(maskContact(contact))")
        } catch {
            Log.auth.error("Password reset initiation failed: \(error)")
            contactStatus = .error(userFriendlyAuthError(error))
        }
    }
    
    func verifyCodeAndProceed() async {
        guard case .collecting(.verifyCode(let contact)) = flow else { return }
        guard !verificationCode.isEmpty else {
            verifyStatus = .error("Enter the verification code")
            return
        }
        
        // Just advance to password step - we'll confirm the reset when they submit the new password
        flow = .collecting(.enterNewPassword)
        verifyStatus = .success("Code verified!")
        
        // Clear success message after transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.verifyStatus = .none
        }
    }
    
    func resendResetCode() async {
        guard case .collecting(.verifyCode(let contact)) = flow else { return }
        
        isResending = true
        verifyStatus = .none
        defer { isResending = false }
        
        do {
            _ = try await Amplify.Auth.resetPassword(for: contact)
            verifyStatus = .info("New reset code sent")
        } catch {
            Log.auth.error("Resend reset code failed: \(error)")
            verifyStatus = .error("Couldn't resend the code. Please try again")
        }
    }
    
    func completePasswordReset() async {
        guard case .collecting(.enterNewPassword) = flow else { return }
        guard canCompleteReset else {
            passwordStatus = .error("Password requirements not met")
            return
        }
        
        // We need to get the contact from our stored state
        let contact: String
        if let currentContact = getCurrentContact() {
            contact = currentContact
        } else {
            contact = normalizedContact
        }
        
        isBusy = true
        passwordStatus = .none
        flow = .resetting
        defer { isBusy = false }
        
        do {
            _ = try await Amplify.Auth.confirmResetPassword(
                for: contact,
                with: newPassword,
                confirmationCode: verificationCode
            )
            
            flow = .completed
            passwordStatus = .success("Password reset successfully!")
        } catch {
            Log.auth.error("Password reset confirmation failed: \(error)")
            flow = .collecting(.enterNewPassword)
            passwordStatus = .error(userFriendlyAuthError(error))
        }
    }
    
    // MARK: - Helper Methods
    
    private func maskContact(_ contact: String) -> String {
        if contact.hasPrefix("+") {
            // Phone number
            return "••••\(contact.suffix(4))"
        } else if contact.contains("@") {
            // Email
            let parts = contact.split(separator: "@")
            if parts.count == 2 {
                let localPart = String(parts[0])
                let domain = String(parts[1])
                let maskedLocal = localPart.count > 3 ? "\(localPart.prefix(2))••••" : "••••"
                return "\(maskedLocal)@\(domain)"
            }
        }
        return contact
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View
{
    @StateObject private var vm = ForgotPasswordVM()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            content
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(AppPalette.Brand.neonPink)
                    }
                    
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
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch vm.flow {
        case .collecting(let step):
            switch step {
            case .enterContact:
                ContactStep(
                    contactRaw: $vm.contactRaw,
                    contactStatus: vm.contactStatus,
                    isBusy: vm.isBusy,
                    canContinue: vm.canAdvanceFromContact,
                    onNext: { Task { await vm.initiatePasswordReset() } }
                )
            case .verifyCode(let contact):
                VerifyResetCodeStep(
                    contact: contact,
                    verificationCode: $vm.verificationCode,
                    verifyStatus: vm.verifyStatus,
                    isBusy: vm.isBusy,
                    isResending: vm.isResending,
                    onVerify: { Task { await vm.verifyCodeAndProceed() } },
                    onResend: { Task { await vm.resendResetCode() } }
                )
            case .enterNewPassword:
                NewPasswordStep(
                    newPassword: $vm.newPassword,
                    confirmPassword: $vm.confirmPassword,
                    passwordScore: vm.passwordScore,
                    passwordsMatch: vm.passwordsMatch,
                    passwordStatus: vm.passwordStatus,
                    isBusy: vm.isBusy,
                    canComplete: vm.canCompleteReset,
                    onComplete: { Task { await vm.completePasswordReset() } }
                )
            case .complete:
                ResetCompleteStep {
                    dismiss()
                }
            }
            
        case .resetting:
            ProgressView("Resetting password...")
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                
        case .completed:
            ResetCompleteStep {
                dismiss()
            }
            
        case .failed(let message):
            VStack(spacing: 16) {
                Text("Reset Failed")
                    .font(.title3.bold())
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Try Again") {
                    vm.flow = .collecting(.enterContact)
                }
                .buttonStyle(PrimaryCapsuleButton())
            }
            .padding()
        }
    }
    
    private var canGoBack: Bool {
        switch vm.flow {
        case .collecting(let step):
            return step != .enterContact
        default:
            return false
        }
    }
}

// MARK: - Step Views

private struct ContactStep: View
{
    @Binding var contactRaw: String
    let contactStatus: StatusMessage
    let isBusy: Bool
    let canContinue: Bool
    let onNext: () -> Void
    
    @FocusState private var contactFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reset your password")
                    .font(.title2.bold())
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("Enter the phone number or email address associated with your account.")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.Text.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    TextField(
                        "",
                        text: $contactRaw,
                        prompt: Text("Phone number or email").foregroundStyle(.white.opacity(0.95))
                    )
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .foregroundColor(.white)
                    .tint(AppPalette.Brand.neonPink)
                    .focused($contactFocused)
                    .darkField(focused: contactFocused)
                    
                    InlineStatus(status: contactStatus)
                }
                
                Button(action: onNext) {
                    HStack {
                        if isBusy {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.black)
                                .scaleEffect(0.8)
                        }
                        Text(isBusy ? "Sending..." : "Send Reset Code")
                            .bold()
                    }
                }
                .buttonStyle(PrimaryCapsuleButton())
                .disabled(!canContinue || isBusy)
                .opacity((canContinue && !isBusy) ? 1 : 0.45)
                
                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }
}

private struct VerifyResetCodeStep: View
{
    let contact: String
    @Binding var verificationCode: String
    let verifyStatus: StatusMessage
    let isBusy: Bool
    let isResending: Bool
    let onVerify: () -> Void
    let onResend: () -> Void
    
    @FocusState private var codeFocused: Bool
    
    private var maskedContact: String {
        if contact.hasPrefix("+") {
            return "••••\(contact.suffix(4))"
        } else if contact.contains("@") {
            let parts = contact.split(separator: "@")
            if parts.count == 2 {
                let localPart = String(parts[0])
                let domain = String(parts[1])
                let maskedLocal = localPart.count > 3 ? "\(localPart.prefix(2))••••" : "••••"
                return "\(maskedLocal)@\(domain)"
            }
        }
        return contact
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Enter reset code")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("We sent a 6-digit reset code to \(maskedContact)")
                .font(.subheadline)
                .foregroundStyle(AppPalette.Text.secondary)
            
            VStack(spacing: 12) {
                DigitCodeInput(
                    code: $verificationCode,
                    digitCount: 6,
                    focused: $codeFocused
                )
                .onAppear { codeFocused = true }
                
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
                    Text(isBusy ? "Verifying..." : "Continue")
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

private struct NewPasswordStep: View
{
    @Binding var newPassword: String
    @Binding var confirmPassword: String
    let passwordScore: (ok: Bool, reasons: [String])
    let passwordsMatch: Bool
    let passwordStatus: StatusMessage
    let isBusy: Bool
    let canComplete: Bool
    let onComplete: () -> Void
    
    @FocusState private var newPasswordFocused: Bool
    @FocusState private var confirmPasswordFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create new password")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("Choose a strong password for your account.")
                .font(.subheadline)
                .foregroundStyle(AppPalette.Text.secondary)
            
            // New Password
            SecureField(
                "",
                text: $newPassword,
                prompt: Text("New password").foregroundStyle(.white.opacity(0.95))
            )
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.newPassword)
            .foregroundColor(.white)
            .tint(AppPalette.Brand.neonPink)
            .focused($newPasswordFocused)
            .darkField(focused: newPasswordFocused)
            .submitLabel(.next)
            .onSubmit { confirmPasswordFocused = true }
            
            // Confirm Password
            SecureField(
                "",
                text: $confirmPassword,
                prompt: Text("Confirm new password").foregroundStyle(.white.opacity(0.95))
            )
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.newPassword)
            .foregroundColor(.white)
            .tint(AppPalette.Brand.neonPink)
            .focused($confirmPasswordFocused)
            .darkField(focused: confirmPasswordFocused)
            .submitLabel(.done)
            .onSubmit { if canComplete { onComplete() } }
            
            if !confirmPassword.isEmpty && !passwordsMatch {
                Text("Passwords don't match")
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.9))
            }
            
            // Password requirements
            VStack(alignment: .leading, spacing: 6) {
                passwordRule("≥ 8 characters", newPassword.count >= 8)
                passwordRule("1 lowercase (a–z)", newPassword.range(of: "[a-z]", options: .regularExpression) != nil)
                passwordRule("1 uppercase (A–Z)", newPassword.range(of: "[A-Z]", options: .regularExpression) != nil)
                passwordRule("1 number (0–9)", newPassword.range(of: "\\d", options: .regularExpression) != nil)
                passwordRule("1 special (!@#…)", newPassword.range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil)
                passwordRule("No leading/trailing spaces", newPassword.range(of: #"^\S+.*\S+$"#, options: .regularExpression) != nil)
                passwordRule("Passwords match", passwordsMatch)
            }
            
            VStack(spacing: 12) {
                Button(action: onComplete) {
                    HStack {
                        if isBusy {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.black)
                                .scaleEffect(0.8)
                        }
                        Text(isBusy ? "Resetting..." : "Reset Password")
                            .bold()
                    }
                }
                .buttonStyle(PrimaryCapsuleButton())
                .disabled(!canComplete || isBusy)
                .opacity((canComplete && !isBusy) ? 1 : 0.45)
                
                InlineStatus(status: passwordStatus)
            }
            .padding(.top, 10)
            
            Spacer(minLength: 0)
        }
        .padding(16)
    }
    
    @ViewBuilder
    private func passwordRule(_ text: String, _ isValid: Bool) -> some View {
        HStack {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle")
            Text(text)
        }
        .foregroundStyle(isValid ? .green : AppPalette.Text.secondary)
        .font(.footnote)
    }
}

private struct ResetCompleteStep: View
{
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Password Reset!")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("Your password has been successfully reset. You can now sign in with your new password.")
                .font(.subheadline)
                .foregroundStyle(AppPalette.Text.secondary)
                .multilineTextAlignment(.center)
            
            Button("Return to Sign In") {
                onDismiss()
            }
            .buttonStyle(PrimaryCapsuleButton())
            .padding(.top, 20)
            
            Spacer()
        }
        .padding(16)
    }
}

// MARK: - Update LogInPageView

// Add this to your existing LogInPageView struct - add the state and sheet presentation:

struct LogInPageView: View {
    @EnvironmentObject private var auth: AuthStateStore
    @StateObject private var vm = SignInVM()
    @FocusState private var userFocused: Bool
    @FocusState private var passFocused: Bool
    @State private var showForgotPassword = false  // Add this state
    
    var body: some View {
        // ... existing body code ...
        
        // Add this after the "Clear Form" button and before the Divider:
        Button("Forgot password?") {
            showForgotPassword = true
        }
        .font(.footnote)
        .foregroundColor(AppPalette.Brand.neonPink)
        .padding(.top, 8)
        
        // ... rest of existing code ...
        
        // Add this modifier to present the forgot password sheet:
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }
}
