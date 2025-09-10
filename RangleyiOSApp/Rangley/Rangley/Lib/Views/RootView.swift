////
////  RootView.swift
////  Freebird
////
////  Created by Anthony Guzzardo on 7/6/25.
////
//import SwiftUI
//
//struct RootView: View {
//    @EnvironmentObject private var locationManager: LocationManager
//    @State private var showSplash = true
//    private var isAuthorized = false
//    
//    var body: some View {
//        Group {
//            if showSplash {
//                LoadApp()
//                    .onAppear {
//                        // After 2 seconds, hide splash
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                            withAnimation {
//                                showSplash = false
//                            }
//                        }
//                    }
//            } else {
//                if locationManager.isAuthorized {
//                    StartTab()
//                } else {
//                    Text("Need to help user")
//                }
//            }
//        }
//    }
//}
//
