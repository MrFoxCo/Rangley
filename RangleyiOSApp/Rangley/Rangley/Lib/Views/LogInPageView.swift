//
//  LoginPageView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/22/25.

import SwiftUI
import Amplify
import AWSPluginsCore

// User-friendly error handler
fileprivate func getUserFriendlyError(_ error: Error) -> String {
    // Log the full error for debugging (in development only)
    #if DEBUG
    print("Auth Error Debug: \(error)")
    if let ae = error as? AuthError {
        print("AuthError details: \(ae.errorDescription)")
        if let underlying = ae.underlyingError {
            print("Underlying error: \(underlying)")
        }
    }
    #endif
    
    // Return user-friendly messages only
    if let ae = error as? AuthError {
        // Check the underlying error type for specific AWS errors
        if let underlying = ae.underlyingError as NSError? {
            let errorType = (underlying.userInfo["__type"] as? String) ?? ""
            
            switch errorType {
            case "UserNotFoundException":
                return "Account not found"
            case "NotAuthorizedException":
                return "Incorrect password"
            case "UserNotConfirmedException":
                return "Please verify your account first"
            case "PasswordResetRequiredException":
                return "Password reset required"
            case "TooManyRequestsException":
                return "Too many attempts. Try again later"
            case "LimitExceededException":
                return "Rate limit exceeded. Try again later"
            default:
                break
            }
            
            // Check for network-related errors
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
        
        // Check AuthError description for common patterns
        let description = ae.errorDescription.lowercased()
        if description.contains("network") || description.contains("connection") {
            return "Connection problem"
        }
        if description.contains("invalid") && description.contains("password") {
            return "Invalid password"
        }
        if description.contains("user") && description.contains("not found") {
            return "Account not found"
        }
    }
    
    // Generic fallback
    return "Sign in failed"
}

@MainActor
private final class SignInVM: ObservableObject
{
    // Inputs
    @Published var principalRaw = ""   // phone/username/email
    @Published var password = ""
    
    // UI State
    @Published var isBusy = false
    @Published var idToken: String = ""
    @Published var statusMessage: String = ""
    @Published var isError: Bool = false
    
    // Remembered users UI
    struct SavedAccount: Identifiable, Hashable {
        let id = UUID()
        let username: String
        let label: String
    }
    @Published var savedAccounts: [SavedAccount] = []
    @Published var showUsernameChip = false
    
    // Settings - simplified
    @Published var shouldOfferBiometrics = false
    
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
                    self.showError("Could not retrieve saved password")
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
                    self.showError("Authentication failed")
                }
            }
            return false
        }
    }
    
    // Auto-login after successful credential fill
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
    
    // Message helpers
    private func showError(_ message: String) {
        statusMessage = message
        isError = true
    }
    
    private func showSuccess(_ message: String) {
        statusMessage = message
        isError = false
    }
    
    private func showMessage(_ message: String, isError: Bool) {
        statusMessage = message
        self.isError = isError
    }
    
    private func clearMessage() {
        statusMessage = ""
        isError = false
    }
    
    // Clear form
    func clearForm() {
        principalRaw = ""
        password = ""
        clearMessage()
    }
    
    // ===== existing sign-in logic =====
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

            // Check if we should offer biometric setup for this user
            let hasExistingCredentials = KeychainAuth.hasCredentials(for: normalizedPrincipal)
            
            if !hasExistingCredentials && BiometricAuth.isAvailable() {
                // New user - offer to save with biometrics
                // Store the success callback to call after biometric setup
                await MainActor.run {
                    self.pendingSuccessCallback = onSuccess
                    self.pendingToken = tokens.idToken
                    self.shouldOfferBiometrics = true
                }
            } else {
                // Just save credentials normally (existing user or no biometrics)
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
    
    // Add these properties to store the callback and token
    private var pendingSuccessCallback: ((String) -> Void)?
    private var pendingToken: String?
    
    // Handle biometric setup decision
    func setupBiometrics(enable: Bool) {
        shouldOfferBiometrics = false
        
        do {
            try KeychainAuth.save(username: normalizedPrincipal,
                                password: password,
                                protectWithBiometrics: enable)
        } catch {
            // Silent fail - credentials still work without biometrics
        }
        
        // Now call the success callback that was delayed
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
                    
                    // Clean status message display
                    if !vm.statusMessage.isEmpty {
                        Text(vm.statusMessage)
                            .font(.caption)
                            .foregroundColor(vm.isError ? .red : .green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(vm.isError ? .red.opacity(0.1) : .green.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // === USERNAME ===
                    TextField("",
                              text: $vm.principalRaw,
                              prompt: Text("Phone or username").foregroundStyle(.white.opacity(0.95)))
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
                            // Clear message when user starts typing
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
                            // Clear message when user starts typing
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
                    .disabled(!vm.canSubmit || vm.isBusy)
                    .opacity((!vm.canSubmit || vm.isBusy) ? 0.45 : 1)
                    
                    Button("Forgot Password?") {
                        showForgotPassword = true
                    }
                    .font(.footnote)
                    .foregroundColor(AppPalette.Brand.neonPink)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                    
                    // Clear form button for testing
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
