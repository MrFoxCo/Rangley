////
////  SignUpModel.swift
////  Rangley
////
////  Created by Anthony Guzzardo on 9/3/25.
////
//
//import Amplify
//
//func devSignUp(username: String, email: String, password: String) async {
//    do {
//        _ = try await Amplify.Auth.signUp(
//            username: username,
//            password: password,
//            options: .init(userAttributes: [.email(email)])
//        )
//        print("SignUp initiated. Check email for code.")
//    } catch { print("signUp error:", error) }
//}
//
//func devConfirm(username: String, code: String) async {
//    do {
//        let res = try await Amplify.Auth.confirmSignUp(for: username, confirmationCode: code)
//        print("Confirm:", res.isSignupComplete)
//    } catch { print("confirm error:", error) }
//}
//
//func devSignIn(username: String, password: String) async {
//    do {
//        let res = try await Amplify.Auth.signIn(username: username, password: password)
//        print("SignIn:", res.isSignedIn)
//    } catch { print("signIn error:", error) }
//}
//
//func devPrintIDToken() async {
//    do {
//        // Your CognitoTokens.idToken() helper
//        let jwt = try await CognitoTokens.idToken()
//        print("ID token:", jwt.prefix(40), "…")
//    } catch { print("token error:", error) }
//}
//Button("SignUp") {
//    Task { await devSignUp(username: "devuser", email: "dev@mrfoxco.com", password: "DevPass123!") }
//}
//Button("Confirm") {
//    Task { await devConfirm(username: "devuser", code: "<CODE_FROM_EMAIL>") }
//}
//Button("SignIn") {
//    Task { await devSignIn(username: "devuser", password: "DevPass123!") }
//}
//Button("Print ID Token") {
//    Task { await devPrintIDToken() }
//}
