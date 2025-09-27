////
////  AppShellView.swift
////  Rangley
////
////  Created by Anthony Guzzardo on 9/22/25.
////
//
//// AppShellView.swift
//import SwiftUI
//
//struct AppShellView: View {
//    @StateObject private var auth = AuthStateStore()   // you already have this
//
//    var body: some View {
//        Group {
//            if auth.isCheckingAuth {
//                // optional splash
//                ZStack {
//                    Color.black.ignoresSafeArea()
//                    VStack {
//                        ProgressView().scaleEffect(1.4)
//                        Text("Checking authentication…").foregroundStyle(.white).padding(.top, 8)
//                    }
//                }
//            } else if auth.isAuthenticated {
//                PublicMapView()
//                    .environmentObject(auth)
//            } else {
//                LogInPageView()
//                    .environmentObject(auth)
//            }
//        }
//        // keep auth fresh when app foregrounds
//        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
//            auth.checkAuthenticationStatus()
//        }
//    }
//}
