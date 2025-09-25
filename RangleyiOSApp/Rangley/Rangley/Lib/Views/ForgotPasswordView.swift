//
//  ForgotPasswordView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/25/25.
//

struct ForgotPasswordView: View {
    @State private var phoneOrEmail = ""
    @State private var resetCode = ""
    @State private var newPassword = ""
    @State private var step: ForgotPasswordStep = .enterContact
    @State private var isBusy = false
    @State private var banner: BannerState = .none
    
    enum ForgotPasswordStep {
        case enterContact
        case enterCode
        case enterNewPassword
    }
    
    var body: some View {
        // Implementation similar to your registration flow
        // Use Amplify.Auth.resetPassword() and confirmResetPassword()
    }
}
