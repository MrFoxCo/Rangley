//  SignInPageView.swift
//  Rangley
//
//  Matches UserRegisterFlow styling.

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
    @Published var principalRaw = ""   // phone (+1312…), username, or email
    @Published var password = ""
    // UI
    @Published var banner: BannerState = .none
    @Published var isBusy = false
    // Output
    @Published var idToken: String = ""

    // Normalize: allow 10 US digits -> +1…, 11 starting with 1 -> +…, 12–15 -> +…
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

    func signIn(onSuccess: @escaping (String) -> Void) async
    {
        guard canSubmit else {
            banner = .error("Enter your phone (E.164), username, or email and password.")
            return
        }
        isBusy = true; defer { isBusy = false }
        banner = .none
        do {
            let res = try await Amplify.Auth.signIn(username: normalizedPrincipal, password: password)
            guard res.isSignedIn else {
                banner = .error("Additional verification required and not supported here.")
                return
            }
            let session = try await Amplify.Auth.fetchAuthSession()
            guard session.isSignedIn, let p = session as? AuthCognitoTokensProvider else {
                banner = .error("Signed in, but no tokens available.")
                return
            }
            let tokens = try p.getCognitoTokens().get()
            idToken = tokens.idToken
            banner = .success("Signed in")
            onSuccess(idToken)
        } catch {
            banner = .error("SignIn: " + explainAuth(error))
        }
    }
}

// MARK: - View

struct LogInPageView: View
{
    @StateObject private var vm = SignInVM()
    @FocusState private var userFocused: Bool
    @FocusState private var passFocused: Bool

    // Modern NavigationStack with a path + route
    enum Route: Hashable { case map }
    @State private var path = NavigationPath()

    var body: some View
    {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Spacer()
                Image("RangleySticker")
                    .resizable().scaledToFit().frame(width: 80, height: 80)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Principal
                        TextField(
                            "", text: $vm.principalRaw,
                            prompt: Text("Username or mobile number")
                                .foregroundStyle(.white.opacity(0.95))
                        )
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .keyboardType(.default)            // phonePad lacks '+'
                        .foregroundColor(.white)
                        .tint(AppPalette.Brand.neonPink)
                        .focused($userFocused)
                        .darkField(focused: userFocused)

                        // Password
                        SecureField(
                            "", text: $vm.password,
                            prompt: Text("Password").foregroundStyle(.white.opacity(0.95))
                        )
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                        .keyboardType(.default)
                        .foregroundColor(.white)
                        .tint(AppPalette.Brand.neonPink)
                        .focused($passFocused)
                        .darkField(focused: passFocused)

                        // Log in
                        Button {
                            Task {
                                await vm.signIn { _ in
                                    path.append(Route.map)   // navigate on success
                                }
                            }
                        } label: {
                            HStack {
                                if vm.isBusy { ProgressView().progressViewStyle(.circular).tint(.black) }
                                Text(vm.isBusy ? "Logging in…" : "Log In").bold()
                            }
                        }
                        .buttonStyle(PrimaryCapsuleButton(font: FontStyles.headline))
                        .disabled(!vm.canSubmit || vm.isBusy)
                        .opacity((!vm.canSubmit || vm.isBusy) ? 0.45 : 1)

                        Divider().background(Color.white.opacity(0.12)).padding(.vertical, 8)

                        // Create account pill
                        NavigationLink
                        {
                            UserRegisterNoCodeFlow()
                        } label: {
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
            // Destination(s)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .map:
                    PublicMapView()
                        .navigationBarBackButtonHidden(true)
                        .toolbar(.hidden, for: .navigationBar)            // ← hide bar
                        .toolbarBackground(.hidden, for: .navigationBar)  // ← hide its bg
                }
            }
        }
    }
}


// Preview
#Preview { LogInPageView() }
