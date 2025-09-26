//
//  ForgotPasswordView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/25/25.
//

import SwiftUI
import Amplify
import AWSPluginsCore

// MARK: - Error handling (reused from LoginPageView)
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

// MARK: - Status Messages (reused from UserRegisterView)
fileprivate enum StatusMessage: Equatable
{
    case none
    case info(String)
    case error(String)
    case success(String)
}

// MARK: - Flow State
fileprivate enum ForgotPasswordStep: Hashable {
    case enterPhone
    case verifyCode(phone: String)
    case setNewPassword(phone: String, code: String)
    case complete
}

// MARK: - ViewModel
@MainActor
fileprivate final class ForgotPasswordVM: ObservableObject
{
    // Form inputs
    @Published var phoneRaw: String = ""
    @Published var verificationCode: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""
    
    // Flow state
    @Published var currentStep: ForgotPasswordStep = .enterPhone
    
    // UI state
    @Published var phoneStatus: StatusMessage = .none
    @Published var verifyStatus: StatusMessage = .none
    @Published var passwordStatus: StatusMessage = .none
    @Published var isBusy = false
    @Published var isResending = false
    
    // MARK: - Computed Properties
    
    private var phoneDigits: String { phoneRaw.filter(\.isNumber) }
    
    var e164Phone: String? {
        let ds = phoneDigits
        switch ds.count {
        case 10: return "+1" + ds          // US default
        case 11 where ds.hasPrefix("1"): return "+" + ds
        case 12...15: return "+" + ds
        default: return nil
        }
    }
    
    var canAdvanceFromPhone: Bool {
        return e164Phone != nil
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
    
    var passwordsMatch: Bool {
        !confirmPassword.isEmpty && confirmPassword == newPassword
    }
    
    var canSetNewPassword: Bool {
        passwordScore.ok && passwordsMatch
    }
    
    var canSubmitVerificationCode: Bool {
        verificationCode.count == 6
    }
    
    // MARK: - Actions
    
    func sendResetCode() async {
        guard let phone = e164Phone else {
            phoneStatus = .error("Please enter a valid phone number")
            return
        }
        
        isBusy = true
        phoneStatus = .none
        defer { isBusy = false }
        
        do {
            // Use Amplify's resetPassword to initiate the flow
            let resetResult = try await Amplify.Auth.resetPassword(for: phone)
            
            if case .confirmResetPasswordWithCode = resetResult.nextStep {
                currentStep = .verifyCode(phone: phone)
                verifyStatus = .info("Reset code sent to \(phone)")
            } else {
                phoneStatus = .error("Unexpected reset flow. Please try again")
            }
        } catch {
            Log.auth.error("Password reset initiation failed: \(error)")
            phoneStatus = .error("Couldn't send reset code: " + userFriendlyAuthError(error))
        }
    }
    
    func verifyCode() async {
        guard case .verifyCode(let phone) = currentStep else { return }
        guard canSubmitVerificationCode else {
            verifyStatus = .error("Enter the 6-digit verification code")
            return
        }
        
        isBusy = true
        verifyStatus = .none
        defer { isBusy = false }
        
        // Move to password step - we'll verify the code when setting the password
        currentStep = .setNewPassword(phone: phone, code: verificationCode)
        passwordStatus = .info("Now create your new password")
    }
    
    func setNewPassword() async {
        guard case .setNewPassword(let phone, let code) = currentStep else { return }
        guard canSetNewPassword else {
            passwordStatus = .error("Please check password requirements")
            return
        }
        
        isBusy = true
        passwordStatus = .none
        defer { isBusy = false }
        
        do {
            // Confirm the password reset with Amplify
            try await Amplify.Auth.confirmResetPassword(
                for: phone,
                with: newPassword,
                confirmationCode: code
            )
            
            currentStep = .complete
            passwordStatus = .success("Password reset successfully!")
            
        } catch {
            Log.auth.error("Password reset confirmation failed: \(error)")
            passwordStatus = .error("Reset failed: " + userFriendlyAuthError(error))
        }
    }
    
    func resendVerificationCode() async
    {
        guard case .verifyCode(let phone) = currentStep else { return }
        
        isResending = true
        verifyStatus = .none
        defer { isResending = false }
        
        do {
            // Resend using Amplify's reset flow
            let resetResult = try await Amplify.Auth.resetPassword(for: phone)
            
            if case .confirmResetPasswordWithCode = resetResult.nextStep {
                verifyStatus = .info("New reset code sent to \(phone)")
            } else {
                verifyStatus = .error("Unexpected reset flow. Please try again")
            }
        } catch {
            Log.auth.error("Password reset resend failed: \(error)")
            verifyStatus = .error("Couldn't resend code: " + userFriendlyAuthError(error))
        }
    }
    
    func startOver() {
        phoneRaw = ""
        verificationCode = ""
        newPassword = ""
        confirmPassword = ""
        currentStep = .enterPhone
        phoneStatus = .none
        verifyStatus = .none
        passwordStatus = .none
    }
    
    func goBack()
    {
        switch currentStep {
        case .enterPhone:
            break // Can't go back further
        case .verifyCode:
            currentStep = .enterPhone
        case .setNewPassword(let phone, _):
            currentStep = .verifyCode(phone: phone)
        case .complete:
            break // Usually won't go back from complete
        }
    }
}

// MARK: - Inline Status View (reused from UserRegisterView)
fileprivate struct InlineStatus: View
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

// MARK: - Main View
struct ForgotPasswordView: View
{
    @StateObject private var vm = ForgotPasswordVM()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Content based on current step
                ScrollView {
                    switch vm.currentStep {
                    case .enterPhone:
                        EnterPhoneStep(
                            phoneRaw: $vm.phoneRaw,
                            phoneStatus: vm.phoneStatus,
                            isBusy: vm.isBusy,
                            canContinue: vm.canAdvanceFromPhone,
                            e164Phone: vm.e164Phone,
                            onNext: { Task { await vm.sendResetCode() } }
                        )
                        
                    case .verifyCode(let phone):
                        VerifyCodeStep(
                            phone: phone,
                            verificationCode: $vm.verificationCode,
                            verifyStatus: vm.verifyStatus,
                            isBusy: vm.isBusy,
                            isResending: vm.isResending,
                            canContinue: vm.canSubmitVerificationCode,
                            onNext: { Task { await vm.verifyCode() } },
                            onResend: { Task { await vm.resendVerificationCode() } }
                        )
                        
                    case .setNewPassword(let phone, let code):
                        SetNewPasswordStep(
                            phone: phone,
                            code: code,
                            newPassword: $vm.newPassword,
                            confirmPassword: $vm.confirmPassword,
                            passwordScore: vm.passwordScore,
                            passwordsMatch: vm.passwordsMatch,
                            passwordStatus: vm.passwordStatus,
                            isBusy: vm.isBusy,
                            canReset: vm.canSetNewPassword,
                            onReset: { Task { await vm.setNewPassword() } }
                        )
                        
                    case .complete:
                        CompleteStep(
                            onDone: { dismiss() }
                        )
                    }
                }
            }
            .background(AppPalette.bgGradient.ignoresSafeArea())
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppPalette.Brand.neonPink)
                }
                
                if vm.currentStep != .enterPhone && vm.currentStep != .complete {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Back") {
                            vm.goBack()
                        }
                        .foregroundColor(AppPalette.Brand.neonPink)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Step Views

fileprivate struct EnterPhoneStep: View
{
    @Binding var phoneRaw: String
    let phoneStatus: StatusMessage
    let isBusy: Bool
    let canContinue: Bool
    let e164Phone: String?
    let onNext: () -> Void
    
    @FocusState private var phoneFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter your phone number")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("We'll send a verification code to reset your password")
                .font(.subheadline)
                .foregroundStyle(AppPalette.Text.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("Mobile Number (+13125551234)", text: $phoneRaw)
                    .keyboardType(.phonePad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .focused($phoneFocused)
                    .darkField(focused: phoneFocused)
                    .onAppear { phoneFocused = true }
                
                if let p = e164Phone, !p.isEmpty {
                    Text("Formatted as \(p)")
                        .font(.footnote)
                        .foregroundStyle(AppPalette.Text.secondary)
                } else if !phoneRaw.isEmpty {
                    Text("Tip: use + and digits only")
                        .font(.footnote)
                        .foregroundStyle(AppPalette.Text.secondary)
                }
                
                InlineStatus(status: phoneStatus)
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

fileprivate struct VerifyCodeStep: View
{
    let phone: String
    @Binding var verificationCode: String
    let verifyStatus: StatusMessage
    let isBusy: Bool
    let isResending: Bool
    let canContinue: Bool
    let onNext: () -> Void
    let onResend: () -> Void
    
    @FocusState private var codeFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Enter verification code")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("Enter the 6-digit code sent to \(phone)")
                .font(.subheadline)
                .foregroundStyle(AppPalette.Text.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                DigitCodeInput(
                    code: $verificationCode,
                    digitCount: 6,
                    focused: $codeFocused
                )
                .onAppear { codeFocused = true }
                
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
                
                InlineStatus(status: verifyStatus)
            }
            
            Button(action: onNext) {
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
            .disabled(!canContinue || isBusy)
            .opacity((canContinue && !isBusy) ? 1 : 0.45)
            
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

fileprivate struct SetNewPasswordStep: View
{
    let phone: String
    let code: String
    @Binding var newPassword: String
    @Binding var confirmPassword: String
    let passwordScore: (ok: Bool, reasons: [String])
    let passwordsMatch: Bool
    let passwordStatus: StatusMessage
    let isBusy: Bool
    let canReset: Bool
    let onReset: () -> Void
    
    @FocusState private var newPasswordFocused: Bool
    @FocusState private var confirmPasswordFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Create new password")
                .font(.title2.bold())
                .foregroundStyle(AppPalette.Text.primary)
            
            Text("Enter your new password for \(phone)")
                .font(.subheadline)
                .foregroundStyle(AppPalette.Text.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                SecureField(
                    "", text: $newPassword,
                    prompt: Text("New password").foregroundStyle(.white.opacity(0.95))
                )
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.newPassword)
                .keyboardType(.default)
                .foregroundColor(.white)
                .tint(AppPalette.Brand.neonPink)
                .focused($newPasswordFocused)
                .darkField(focused: newPasswordFocused)
                .submitLabel(.next)
                .onAppear { newPasswordFocused = true }
                .onSubmit { confirmPasswordFocused = true }
                
                SecureField(
                    "", text: $confirmPassword,
                    prompt: Text("Confirm password").foregroundStyle(.white.opacity(0.95))
                )
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.newPassword)
                .keyboardType(.default)
                .foregroundColor(.white)
                .tint(AppPalette.Brand.neonPink)
                .focused($confirmPasswordFocused)
                .darkField(focused: confirmPasswordFocused)
                .submitLabel(.done)
                .onSubmit { if canReset { onReset() } }
                
                if !confirmPassword.isEmpty && !passwordsMatch {
                    Text("Passwords don't match")
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.9))
                }
                
                // Password requirements
                VStack(alignment: .leading, spacing: 6) {
                    rule("≥ 8 characters", newPassword.count >= 8)
                    rule("1 lowercase (a–z)", newPassword.range(of: "[a-z]", options: .regularExpression) != nil)
                    rule("1 uppercase (A–Z)", newPassword.range(of: "[A-Z]", options: .regularExpression) != nil)
                    rule("1 number (0–9)", newPassword.range(of: "\\d", options: .regularExpression) != nil)
                    rule("1 special (!@#…)", newPassword.range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil)
                    rule("No leading/trailing spaces", newPassword.range(of: #"^\S+.*\S+$"#, options: .regularExpression) != nil)
                    rule("Passwords match", passwordsMatch)
                }
            }
            
            VStack(spacing: 12) {
                Button(action: onReset) {
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
                .disabled(!canReset || isBusy)
                .opacity((canReset && !isBusy) ? 1 : 0.45)
                
                InlineStatus(status: passwordStatus)
            }
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

fileprivate struct CompleteStep: View
{
    let onDone: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Password Reset Complete")
                    .font(.title2.bold())
                    .foregroundStyle(AppPalette.Text.primary)
                
                Text("Your password has been successfully reset. You can now sign in with your new password.")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.Text.secondary)
            }
            
            Button("Done") {
                onDone()
            }
            .buttonStyle(PrimaryCapsuleButton())
            .padding(.top, 20)
            
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

// MARK: - Reused Components

// Reuse DigitCodeInput from UserRegisterView
fileprivate struct DigitCodeInput: View
{
    @Binding var code: String
    let digitCount: Int
    @FocusState.Binding var focused: Bool
    
    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0)
                .onChange(of: code) { _, newValue in
                    let filtered = String(newValue.filter { $0.isNumber }.prefix(digitCount))
                    if filtered != code {
                        code = filtered
                    }
                }
            
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

fileprivate struct DigitBlock: View
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
                Rectangle()
                    .fill(AppPalette.Brand.neonPink)
                    .frame(width: 2, height: 24)
                    .opacity(isActive ? 1 : 0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isActive)
            }
        }
    }
}

// MARK: - Helper Functions

// Reuse user-friendly error messages
fileprivate func userFriendlyAuthError(_ error: Error) -> String {
    if let ae = error as? AuthError {
        Log.auth.error("Auth error: \(ae.errorDescription) | \(ae.recoverySuggestion)")
        if let underlying = ae.underlyingError {
            Log.auth.error("Underlying error: \(underlying)")
        }
        
        switch ae.errorDescription {
        case let desc where desc.contains("UserNotFoundException"):
            return "No account found with this phone number"
        case let desc where desc.contains("CodeMismatchException"):
            return "Invalid verification code"
        case let desc where desc.contains("ExpiredCodeException"):
            return "Verification code has expired"
        case let desc where desc.contains("InvalidPasswordException"):
            return "Password doesn't meet requirements"
        case let desc where desc.contains("TooManyRequestsException"):
            return "Too many attempts. Please try again later"
        case let desc where desc.contains("LimitExceededException"):
            return "Password reset limit exceeded. Please try again later"
        default:
            return "Something went wrong. Please try again"
        }
    }
    
    Log.auth.error("Non-auth error: \(error)")
    return "Something went wrong. Please try again"
}
