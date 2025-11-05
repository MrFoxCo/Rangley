//
//  LoginPageView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/22/25.

import SwiftUI
import Amplify
import AWSPluginsCore

// MARK: - Better Error Handler
fileprivate func getUserFriendlyError(_ error: Error) -> String {
    #if DEBUG
    print("Auth Error Debug: \(error)")
    if let ae = error as? AuthError {
        print("AuthError details: \(ae.errorDescription)")
        if let underlying = ae.underlyingError {
            print("Underlying error: \(underlying)")
        }
    }
    #endif
    
    if let ae = error as? AuthError {
        let errorDesc = ae.errorDescription.lowercased()
        
        // Check for account lockout FIRST
        if errorDesc.contains("password attempts exceeded") {
            return "Too many failed attempts. Account locked for 1 hour. Try resetting your password to unlock."
        }
        
        if let underlying = ae.underlyingError as NSError? {
            let errorType = (underlying.userInfo["__type"] as? String) ?? ""
            
            switch errorType {
            case "UserNotFoundException":
                return "No account found. Check your phone number format (+13125551234)"
            case "NotAuthorizedException":
                return "Incorrect credentials. Sign in with your phone number (+13125551234), not username."
            case "UserNotConfirmedException":
                return "Account not verified. Check your phone for verification code."
            case "PasswordResetRequiredException":
                return "Password reset required. Use 'Forgot Password' below."
            case "TooManyRequestsException":
                return "Too many attempts. Wait 15 minutes."
            case "LimitExceededException":
                return "Rate limit hit. Wait 1 hour."
            default:
                break
            }
            
            if underlying.domain == NSURLErrorDomain {
                switch underlying.code {
                case NSURLErrorNotConnectedToInternet:
                    return "No internet connection"
                case NSURLErrorTimedOut:
                    return "Connection timed out"
                default:
                    return "Network error"
                }
            }
        }
        
        if errorDesc.contains("network") || errorDesc.contains("connection") {
            return "Connection problem"
        }
        if errorDesc.contains("user") && errorDesc.contains("not found") {
            return "No account found. Check phone number format."
        }
    }
    
    return "Sign in failed. Check credentials."
}

@MainActor
private final class SignInVM: ObservableObject
{
    // Inputs
    @Published var principalRaw = ""
    @Published var password = ""
    
    // UI State
    @Published var isBusy = false
    @Published var idToken: String = ""
    @Published var statusMessage: String = ""
    @Published var isError: Bool = false
    @Published var isAccountLocked: Bool = false
    
    // Remembered users UI
    struct SavedAccount: Identifiable, Hashable {
        let id = UUID()
        let username: String
        let label: String
    }
    @Published var savedAccounts: [SavedAccount] = []
    @Published var showUsernameChip = false
    
    // Settings
    @Published var shouldOfferBiometrics = false
    
    func loadRememberedUsers()
    {
        do {
            let usernames = try KeychainAuth.listUsernamesWithoutBiometrics()
            self.savedAccounts = usernames.map { username in
                let label: String
                if username.hasPrefix("+"), username.count >= 6 {
                    label = "Mobile ••••\(username.suffix(4))"
                } else if username.contains("@") {
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
                    if username.count > 6 {
                        label = "\(username.prefix(3))••••\(username.suffix(2))"
                    } else {
                        label = username
                    }
                }
                return SavedAccount(username: username, label: label)
            }
            
            showUsernameChip = !savedAccounts.isEmpty
        } catch {
            self.savedAccounts = []
            self.showUsernameChip = false
        }
    }
    
    func authenticateAndFillCredentials(for username: String) async -> Bool
    {
        do {
            guard let password = try KeychainAuth.loadPassword(
                username: username,
                prompt: "Authenticate to sign in as \(username)"
            ) else {
                await MainActor.run {
                    self.showError("Could not retrieve saved password")
                }
                return false
            }
            
            await MainActor.run {
                self.principalRaw = username
                self.password = password
                self.showUsernameChip = false
            }
            
            return true
        } catch {
            await MainActor.run {
                if (error as NSError).code != Int(errSecUserCanceled) {
                    self.showError("Authentication failed")
                }
            }
            return false
        }
    }
    
    func attemptAutoLogin(onSuccess: @escaping (String) -> Void) async
    {
        guard canSubmit else {
            await MainActor.run {
                self.showError("Invalid credentials loaded")
            }
            return
        }
        
        await MainActor.run {
            self.showMessage("Signing in...", isError: false)
        }
        
        await signIn(onSuccess: onSuccess)
    }
    
    private func showError(_ message: String) {
        statusMessage = message
        isError = true
        isAccountLocked = message.contains("locked") || message.contains("Wait") || message.contains("hour")
    }
    
    private func showSuccess(_ message: String) {
        statusMessage = message
        isError = false
        isAccountLocked = false
    }
    
    private func showMessage(_ message: String, isError: Bool) {
        statusMessage = message
        self.isError = isError
        if isError {
            isAccountLocked = message.contains("locked") || message.contains("Wait") || message.contains("hour")
        }
    }
    
    private func clearMessage() {
        statusMessage = ""
        isError = false
        isAccountLocked = false
    }
    
    func clearForm() {
        principalRaw = ""
        password = ""
        clearMessage()
    }
    
    // ✅ FIXED: Improved phone normalization
    private var normalizedPrincipal: String
    {
        let trimmed = principalRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Normalize phone numbers to +1XXXXXXXXXX format
        let digits = trimmed.filter(\.isNumber)
        if digits.count >= 10 {
            switch digits.count {
            case 10:
                // 3125551234 → +13125551234
                return "+1" + digits
            case 11 where digits.hasPrefix("1"):
                // 13125551234 → +13125551234
                return "+" + digits
            case 12...15:
                // Already has country code, just add + if missing
                return trimmed.hasPrefix("+") ? ("+" + digits) : ("+" + digits)
            default:
                break
            }
        }
        
        // Not a phone number - return as-is (email or username)
        return trimmed
    }
    
    var canSubmit: Bool
    {
        !normalizedPrincipal.isEmpty && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func signIn(onSuccess: @escaping (String) -> Void) async
    {
        guard canSubmit else {
            showError("Please enter your login details")
            return
        }
        
        // Show what we're using for sign in (debug)
        #if DEBUG
        print("Signing in with normalized principal: \(normalizedPrincipal)")
        #endif
        
        await MainActor.run {
            self.isBusy = true
            self.clearMessage()
        }
        
        defer {
            Task { @MainActor in
                self.isBusy = false
            }
        }
        
        do {
            // Use normalized phone number
            let res = try await Amplify.Auth.signIn(username: normalizedPrincipal, password: password)
            guard res.isSignedIn else {
                await MainActor.run {
                    self.showError("Additional verification required")
                }
                return
            }
            
            let session = try await Amplify.Auth.fetchAuthSession()
            guard session.isSignedIn, let p = session as? AuthCognitoTokensProvider else {
                await MainActor.run {
                    self.showError("Sign in incomplete")
                }
                return
            }
            
            let tokens = try p.getCognitoTokens().get()
            
            await MainActor.run {
                self.idToken = tokens.idToken
                self.showSuccess("Signed in successfully")
            }

            let hasExistingCredentials = KeychainAuth.hasCredentials(for: normalizedPrincipal)
            
            if !hasExistingCredentials && BiometricAuth.isAvailable() {
                await MainActor.run {
                    self.pendingSuccessCallback = onSuccess
                    self.pendingToken = tokens.idToken
                    self.shouldOfferBiometrics = true
                }
            } else {
                try? KeychainAuth.save(username: normalizedPrincipal,
                                     password: password,
                                     protectWithBiometrics: hasExistingCredentials)
                
                onSuccess(tokens.idToken)
            }
        } catch {
            await MainActor.run {
                self.showError(getUserFriendlyError(error))
            }
        }
    }
    
    private var pendingSuccessCallback: ((String) -> Void)?
    private var pendingToken: String?
    
    func setupBiometrics(enable: Bool) {
        shouldOfferBiometrics = false
        
        do {
            try KeychainAuth.save(username: normalizedPrincipal,
                                password: password,
                                protectWithBiometrics: enable)
        } catch {
            // Silent fail
        }
        
        if let callback = pendingSuccessCallback, let token = pendingToken {
            callback(token)
            pendingSuccessCallback = nil
            pendingToken = nil
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
                    if !vm.statusMessage.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vm.statusMessage)
                                .font(.caption)
                                .foregroundColor(vm.isError ? .red : .green)
                            
                            //  Show "Reset Password" link when account is locked
                            if vm.isAccountLocked {
                                Button("Reset Password to Unlock") {
                                    showForgotPassword = true
                                }
                                .font(.caption2)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(vm.isError ? .red.opacity(0.1) : .green.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // === USERNAME ===
                    TextField("",
                              text: $vm.principalRaw,
                              prompt: Text("Phone (+13125551234)").foregroundStyle(.white.opacity(0.95)))
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
                                vm.loadRememberedUsers()
                            } else {
                                vm.showUsernameChip = false
                            }
                        }
                        .onChange(of: vm.principalRaw) { _, _ in
                            if !vm.statusMessage.isEmpty {
                                vm.statusMessage = ""
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
                            if !vm.statusMessage.isEmpty {
                                vm.statusMessage = ""
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
                    .disabled(!vm.canSubmit || vm.isBusy || vm.isAccountLocked)  // Disable when locked
                    .opacity((!vm.canSubmit || vm.isBusy || vm.isAccountLocked) ? 0.45 : 1)
                    
                    Button("Forgot Password?") {
                        showForgotPassword = true
                    }
                    .font(.footnote)
                    .foregroundColor(AppPalette.Brand.neonPink)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                    
                    Button("Clear Form") {
                        vm.clearForm()
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

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
        
        .safeAreaInset(edge: .bottom) {
            if vm.showUsernameChip && userFocused && !vm.savedAccounts.isEmpty {
                VStack(spacing: 8) {
                    Text("Tap to sign in with saved account")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(vm.savedAccounts) { account in
                                Button {
                                    Task {
                                        userFocused = false
                                        vm.showUsernameChip = false
                                        
                                        let success = await vm.authenticateAndFillCredentials(for: account.username)
                                        
                                        if success {
                                            await vm.attemptAutoLogin { _ in
                                                auth.checkAuthenticationStatus()
                                            }
                                        }
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
        .alert("Use Face ID for faster sign in?", isPresented: $vm.shouldOfferBiometrics) {
            Button("Not Now") {
                vm.setupBiometrics(enable: false)
            }
            Button("Use Face ID") {
                vm.setupBiometrics(enable: true)
            }
        } message: {
            Text("Securely sign in with Face ID instead of typing your password each time.")
        }
    }
}
