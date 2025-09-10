//
//  RangleApp.swift
//
//  Created by Anthony Guzzardo on 7/1/25.
//


import SwiftUI
import Amplify
import AWSCognitoAuthPlugin
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool
    {
        Amplify.Logging.logLevel = .verbose
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.configure()
            print("Amplify configured")
        } catch {
            print("Amplify configure failed:", error)
        }
        return true
    }
}

@main
struct RangleyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup { RootGate() }   // ← was UserRegisterFlow()
    }
}





// V1
//import SwiftUI
//import Amplify
//import AWSCognitoAuthPlugin
//
//@main
//struct RangleyApp: App {
//    init() {
//        configureAmplify()
//    }
//
//    @StateObject private var locationManager = LocationManager()
//
//    var body: some Scene {
//        WindowGroup {
//            RootView()
//                .environmentObject(locationManager)
//        }
//    }
//}
//
//func configureAmplify() {
//    do {
//        try Amplify.add(plugin: AWSCognitoAuthPlugin())
//        try Amplify.configure()
//        print("Amplify configured")
//    } catch {
//        print("Amplify configure failed: \(error)")
//    }
//}
