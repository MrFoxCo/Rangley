//
//  AuthStateStore.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/27/25.
//

import Foundation
import Amplify
import AWSPluginsCore

@MainActor
class AuthStateStore: ObservableObject
{
    @Published var isAuthenticated = false
    @Published var currentToken = ""
    @Published var currentUser: ViewUserMeModel?
    @Published var isCheckingAuth = true
    
    private var hubListener: UnsubscribeToken?
    
    init() {
        setupAmplifyHub()
        checkAuthenticationStatus()

        // Listen for account deletion notification
        NotificationCenter.default.addObserver(
            forName: .userAccountDeleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAccountDeletion()
            }
        }
    }
    
    deinit {
        if let token = hubListener {
            Amplify.Hub.removeListener(token)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupAmplifyHub() {
        hubListener = Amplify.Hub.listen(to: .auth) { payload in
            Task { @MainActor in
                switch payload.eventName {
                case HubPayload.EventName.Auth.signedIn:
                    self.isAuthenticated = true
                    await self.updateToken()
                    await self.fetchCurrentUser()
                    
                case HubPayload.EventName.Auth.signedOut:
                    self.isAuthenticated = false
                    self.currentToken = ""
                    self.currentUser = nil
                    
                case HubPayload.EventName.Auth.sessionExpired:
                    self.isAuthenticated = false
                    self.currentToken = ""
                    self.currentUser = nil
                    
                default:
                    break
                }
            }
        }
    }
    
    private func handleAccountDeletion() {
        isAuthenticated = false
        currentToken = ""
        currentUser = nil
    }
    
    func checkAuthenticationStatus()
    {
        Task {
            do {
                let session = try await Amplify.Auth.fetchAuthSession()
                await MainActor.run {
                    isAuthenticated = session.isSignedIn
                    isCheckingAuth = false
                }
                
                if session.isSignedIn {
                    await updateToken()
                    await fetchCurrentUser()
                }
            } catch {
                await MainActor.run {
                    isAuthenticated = false
                    isCheckingAuth = false
                    currentToken = ""
                }
            }
        }
    }
    
    private func fetchCurrentUser() async
    {
        do {
            let user = try await AuthAPI.viewUserMe(baseURL: Env.apiBaseURL, token: currentToken)
            await MainActor.run {
                currentUser = user
            }
        } catch {
            print("Failed to fetch current user: \(error)")
        }
    }
    
    
    func updateToken() async
    {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            guard let provider = session as? AuthCognitoTokensProvider else { return }
            let token = try provider.getCognitoTokens().get().idToken
            
            await MainActor.run {
                currentToken = token
            }
        } catch {
            print("Failed to get token: \(error)")
            await MainActor.run {
                currentToken = ""
            }
        }
    }
    
    func signOut() async
    {
        _ = await Amplify.Auth.signOut()
        await MainActor.run {
            isAuthenticated = false
            currentToken = ""
        }
    }
}

extension Notification.Name
{
    static let userAccountDeleted = Notification.Name("userAccountDeleted")
    static let passwordChangeSuccess = Notification.Name("passwordChangeSuccess")
}
