//
//  AuthRegisterView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/2/25.
//

// AuthRegisterView.swift

import SwiftUI

@MainActor
final class AuthRegisterVM: ObservableObject
{
    @Published var username = ""
    @Published var display_name = ""
    @Published var cellphone = ""
    @Published var email = ""
    @Published var dobDate = Date()          // pick a date, we’ll format as "yyyy-MM-dd"
    @Published var first_name = ""
    @Published var last_name = ""
    
    @Published var isSubmitting = false
    @Published var resultText: String = ""
    @Published var errorText: String = ""
    
    // Configure these for your env
    var baseURL = URL(string: "https://api.mrfoxco.com")!
    var accessTokenProvider: () -> String = { "" } // inject your Cognito access token here
    
    private let df: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .init(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    func submit() async
    {
        errorText = ""
        resultText = ""
        
        // Enforce "email or cellphone" client-side (server will also enforce)
        if (email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
           (cellphone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            errorText = "Provide at least one of email or cellphone."
            return
        }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        let payload = AuthRegisterRequest(
            username    : username,
            display_name: display_name,
            cellphone   : cellphone.isEmpty ? nil : cellphone,
            email       : email.isEmpty ? nil : email,
            dob         : df.string(from: dobDate),
            first_name  : first_name.isEmpty ? nil : first_name,
            last_name   : last_name.isEmpty ? nil : last_name
        )
        
        do {
            let token = accessTokenProvider()
            let res = try await AuthAPI.register(baseURL: baseURL, token: token, payload: payload)
            resultText = res.is_success == true ? "Success" : "Registered (is_success = \(String(describing: res.is_success)))"
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct AuthRegisterView: View
{
    @StateObject private var vm = AuthRegisterVM()
    
    var body: some View
    {
        Form {
            Section("Account") {
                TextField("Username", text: $vm.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Display Name", text: $vm.display_name)
            }
            Section("Contact (one required)") {
                TextField("Cellphone (+13125550123)", text: $vm.cellphone)
                    .keyboardType(.phonePad)
                TextField("Email (name@example.com)", text: $vm.email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
            }
            Section("Profile") {
                DatePicker("DOB (≥ 13 yrs)", selection: $vm.dobDate, displayedComponents: .date)
                TextField("First Name (optional)", text: $vm.first_name)
                TextField("Last Name (optional)", text: $vm.last_name)
            }
            Section {
                Button {
                    Task { await vm.submit() }
                } label: {
                    if vm.isSubmitting { ProgressView() } else { Text("Register") }
                }
                .disabled(vm.isSubmitting)
            }
            if !vm.resultText.isEmpty {
                Section("Result") { Text(vm.resultText) }
            }
            if !vm.errorText.isEmpty {
                Section("Error") { Text(vm.errorText).foregroundColor(.red) }
            }
        }
        .navigationTitle("Auth Register")
        .onAppear {
            // Inject your real values here:
            vm.baseURL = URL(string: "https://api.mrfoxco.com")!
            vm.accessTokenProvider = {
                // Return the Cognito **access token** string ("Bearer" value) from your auth layer.
                // e.g., Amplify.Auth.fetchAuthSession → session.userPoolTokens?.accessToken
                return "<AUTH_TOKEN>" // ? what is the actual return suppsoed to be
            }
        }
    }
}

//########################################################################################################
//  CAN PREVIEW THE REGISTRATION FORM HERE
//########################################################################################################

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Auth Register") {
                    AuthRegisterView()
                }
            }
            .navigationTitle("Dev Tools")
        }
    }
}
#Preview {
    ContentView()
}
//########################################################################################################
//  CAN PREVIEW THE REGISTRATION FORM HERE ^^^^^^^^^^^^^^^^^^^^^^^^
//########################################################################################################
