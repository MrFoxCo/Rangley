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
    func loadRememberedUsers() {
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
    func authenticateAndFillCredentials(for username: String) async -> Bool {
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
    func attemptAutoLogin(onSuccess: @escaping (String) -> Void) async {
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
    private var normalizedPrincipal: String {
        let ds = phoneDigits
        switch ds.count {
        case 10:                         return "+1" + ds
        case 11 where ds.hasPrefix("1"): return "+" + ds
        case 12...15:                    return "+" + ds
        default:                         return principalRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    var canSubmit: Bool {
        !normalizedPrincipal.isEmpty && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func signIn(onSuccess: @escaping (String) -> Void) async {
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

                    Divider().background(Color.white.opacity(0.12)).padding(.vertical, 8)

                    NavigationLink { UserRegisterNoCodeFlow() } label: {
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
    }
}

/*
 
 Critical Authentication UX Requirement: Single Face ID/Passcode Entry
 THE CARDINAL RULE: Under absolutely NO circumstances should a user EVER have to authenticate with Face ID or enter their iPhone passcode more than ONCE during the login flow. This is non-negotiable. When implementing saved credentials with biometric protection, the authentication must be triggered EXACTLY ONCE - when the user explicitly chooses to use saved credentials by tapping on a username chip. Any implementation that triggers Face ID/passcode when focusing the username field, when loading the list of saved usernames, or at any point before the user actively selects a saved account is COMPLETELY UNACCEPTABLE.
 What Must Happen: When the username field gains focus, the keyboard should appear immediately with saved username chips displayed above it (if any exist). Loading and displaying these chips must NEVER trigger biometric authentication - use methods that only retrieve account names without accessing protected data. The Face ID/passcode prompt should appear ONLY when the user taps on a specific saved username chip. At that single authentication moment, the system should retrieve BOTH the username and password, fill BOTH fields, and ideally auto-submit the login. One authentication, complete login - that's the only acceptable flow.
 What Must NOT Happen: Never trigger Face ID when the username field is focused. Never trigger it when loading the list of saved accounts. Never trigger it twice - once for username and once for password. Never use iOS's built-in "Passwords" autofill that takes users to a system list. The ONLY acceptable UI is custom username chips that appear above the keyboard, showing masked usernames (like "Mobile ••••1234"), that when tapped trigger a SINGLE biometric authentication to completely fill and submit the login form.
 Technical Implementation: Use separate Keychain methods - one that lists usernames WITHOUT requiring authentication (for displaying chips), and another that retrieves the password WITH authentication (when chip is tapped). The username list method should ONLY access the account attribute, never the protected password data. Store credentials per-username, not as a single "primary" entry. When the user taps a chip: trigger Face ID once, retrieve the password, fill both fields, and auto-submit. If Face ID fails or is cancelled, simply do nothing - don't prompt again unless the user taps another chip. This creates a seamless, single-authentication experience that respects both security and user sanity.
 */
