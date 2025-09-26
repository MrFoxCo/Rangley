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
    @State private var profile: ViewUserMeModel?
    @State private var error: String?
    @State private var isAnimating = false
    @State private var showingPasswordReset = false
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
                        
                        // Security section
                        securitySection
                        
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
                        AppPalette.Brand.japPurple,
                        AppPalette.Brand.japDarkerPurple
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
            .sheet(isPresented: $showingPasswordReset) {
                ChangePasswordView()
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
    private func accountDetails(for profile: ViewUserMeModel) -> some View {
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
    
    // MARK: - Security Section
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section title
            Text("Security")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppPalette.Text.primary)
                .padding(.bottom, 8)
            
            // Change Password button
            Button(action: { showingPasswordReset = true }) {
                HStack {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppPalette.Brand.neonPink.opacity(0.2))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "key.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppPalette.Brand.neonPink)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Change Password")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppPalette.Text.primary)
                            
                            Text("Update your account password")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppPalette.Text.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppPalette.Text.secondary)
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppPalette.Surface.fieldFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
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
        .padding(.horizontal, 24)
        .padding(.top, 16)
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

// MARK: - Change Password View
struct ChangePasswordView: View
{
    @StateObject private var vm = ChangePasswordVM()
    @Environment(\.dismiss) private var dismiss
    
    @FocusState private var currentPasswordFocused: Bool
    @FocusState private var newPasswordFocused: Bool
    @FocusState private var confirmPasswordFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Change Password")
                                .font(.title2.bold())
                                .foregroundStyle(AppPalette.Text.primary)
                            
                            Text("Enter your current password and choose a new one")
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.Text.secondary)
                            // Timing notice
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(AppPalette.Brand.brightTeal)
                                
                                Text("Password changes may take a few minutes to take effect")
                                    .font(.caption)
                                    .foregroundColor(AppPalette.Text.secondary)
                            }
                            .padding(.top, 4)
                        }
                        
                        // Current password
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Password")
                                .font(.headline)
                                .foregroundStyle(AppPalette.Text.primary)
                            
                            SecureField(
                                "", text: $vm.currentPassword,
                                prompt: Text("Enter current password").foregroundStyle(.white.opacity(0.95))
                            )
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.password)
                            .foregroundColor(.white)
                            .tint(AppPalette.Brand.neonPink)
                            .focused($currentPasswordFocused)
                            .darkField(focused: currentPasswordFocused)
                            .submitLabel(.next)
                            .onAppear { currentPasswordFocused = true }
                            .onSubmit { newPasswordFocused = true }
                        }
                        
                        // New password
                        VStack(alignment: .leading, spacing: 12)
                        {
                            Text("New Password")
                                .font(.headline)
                                .foregroundStyle(AppPalette.Text.primary)
                            
                            SecureField(
                                "", text: $vm.newPassword,
                                prompt: Text("Enter new password").foregroundStyle(.white.opacity(0.95))
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
                            
                            SecureField(
                                "", text: $vm.confirmPassword,
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
                            .onSubmit { if vm.canChangePassword { Task { await vm.changePassword() } } }
                            
                            if !vm.confirmPassword.isEmpty && !vm.passwordsMatch {
                                Text("Passwords don't match")
                                    .font(.footnote)
                                    .foregroundStyle(.red.opacity(0.9))
                            }
                            
                            // Password requirements
                            VStack(alignment: .leading, spacing: 6) {
                                passwordRule("≥ 8 characters", vm.newPassword.count >= 8)
                                passwordRule("1 lowercase (a–z)", vm.newPassword.range(of: "[a-z]", options: .regularExpression) != nil)
                                passwordRule("1 uppercase (A–Z)", vm.newPassword.range(of: "[A-Z]", options: .regularExpression) != nil)
                                passwordRule("1 number (0–9)", vm.newPassword.range(of: "\\d", options: .regularExpression) != nil)
                                passwordRule("1 special (!@#…)", vm.newPassword.range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil)
                                passwordRule("No leading/trailing spaces", vm.newPassword.range(of: #"^\S+.*\S+$"#, options: .regularExpression) != nil)
                                passwordRule("Passwords match", vm.passwordsMatch)
                            }
                        }
                        
                        // Change password button
                        VStack(spacing: 12)
                        {
                            Button(action: { Task { await vm.changePassword() } }) {
                                HStack {
                                    if vm.isBusy {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.black)
                                            .scaleEffect(0.8)
                                    }
                                    Text(vm.isBusy ? "Changing..." : "Change Password")
                                        .bold()
                                }
                            }
                            .buttonStyle(PrimaryCapsuleButton())
                            .disabled(!vm.canChangePassword || vm.isBusy)
                            .opacity((vm.canChangePassword && !vm.isBusy) ? 1 : 0.45)
                            
                            ChangePasswordStatus(status: vm.status)
                        }
                        .padding(.top, 8)
                        
                        Spacer(minLength: 0)
                    }
                    .padding(24)
                }
            }
            .background(AppPalette.bgGradient.ignoresSafeArea())
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppPalette.Brand.neonPink)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onReceive(NotificationCenter.default.publisher(for: .passwordChangeSuccess)) { _ in
                dismiss()
            }
        }
    }
    
    @ViewBuilder private func passwordRule(_ text: String, _ satisfied: Bool) -> some View {
        HStack {
            Image(systemName: satisfied ? "checkmark.circle.fill" : "xmark.circle")
            Text(text)
        }
        .foregroundStyle(satisfied ? .green : AppPalette.Text.secondary)
        .font(.footnote)
    }
}

// MARK: - Change Password ViewModel

@MainActor
fileprivate final class ChangePasswordVM: ObservableObject
{
    @Published var currentPassword: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""
    @Published var status: ChangePasswordStatus.StatusType = .none
    @Published var isBusy = false
    
    // Remove @FocusState from here - they need to be in the view
    
    var passwordsMatch: Bool {
        !confirmPassword.isEmpty && confirmPassword == newPassword
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
    
    var canChangePassword: Bool {
        !currentPassword.isEmpty && passwordScore.ok && passwordsMatch
    }
    
    func changePassword() async
    {
        guard canChangePassword else {
            status = .error("Please check all requirements")
            return
        }
        
        isBusy = true
        status = .none
        defer { isBusy = false }
        
        do {
            try await Amplify.Auth.update(oldPassword: currentPassword, to: newPassword)
            status = .success("Password changed successfully!")
            
            // Shorter delay for better UX - dismiss after 1.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                NotificationCenter.default.post(name: .passwordChangeSuccess, object: nil)
            }
            
        } catch {
            Log.auth.error("Password change failed: \(error)")
            
            if let authError = error as? AuthError {
                switch authError.errorDescription {
                case let desc where desc.contains("NotAuthorizedException"):
                    status = .error("Current password is incorrect")
                case let desc where desc.contains("InvalidPasswordException"):
                    status = .error("New password doesn't meet requirements")
                case let desc where desc.contains("LimitExceededException"):
                    status = .error("Too many attempts. Please try again later")
                default:
                    status = .error("Unable to change password. Please try again")
                }
            } else {
                status = .error("Unable to change password. Please try again")
            }
        }
    }
    
}
// MARK: - Change Password Status Component

extension Notification.Name {
    static let passwordChangeSuccess = Notification.Name("passwordChangeSuccess")
}

fileprivate struct ChangePasswordStatus: View
{
    enum StatusType: Equatable {
        case none
        case error(String)
        case success(String)
    }
    
    let status: StatusType
    
    var body: some View {
        switch status {
        case .none:
            EmptyView()
        case .error(let message):
            statusView(message: message, color: .red, icon: "exclamationmark.triangle.fill")
        case .success(let message):
            statusView(message: message, color: .green, icon: "checkmark.circle.fill")
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
