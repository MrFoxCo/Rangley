//
//  RangleApp.swift
//
//  Created by Anthony Guzzardo on 7/1/25.
//

import SwiftUI

@main
struct RangleyApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var userManager = UserManager()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(locationManager)
                .environmentObject(userManager)
                .onAppear {
                    // Initialize database after the app loads
                    _ = DbManager.shared
                    userManager.loadUser()
                }
        }
    }
}

class UserManager: ObservableObject {
    @Published var anthony: User?
    @Published var error: Error?
    
    func loadUser() {
        let result = DbRangle.tryViewUser(DbManager.shared.database!, userId: 2)
        anthony = result.0
        error = result.1
    }
}

/**
 let allViews = [
     
     // lookups
      Views.vwMeetCategory
     ,Views.vwParticpantStatus
     ,Views.vwMeetStatus
     ,Views.vwNotificationType
     ,Views.vwSubCategory
     ,Views.vwFeatures
     ,Views.vwVersionFeatures
     
     // mains
     ,Views.vwMeetIcon
     ,Views.vwMeetParticipants
     ,Views.vwMeetIDs
     ,Views.vwMeetAddresses
     ,Views.vwMeets
     ,Views.vwMeetChangeStamps
     ,Views.vwNotifications
     ,Views.vwUserInboxes
     ,Views.vwUsers

     // subs
     ,Views.vwLatestMeetVersions
     ,Views.vwMeetDisplays
     ,Views.vwLatestVisibleMeets
     ,Views.vwMeetCategoryIDAndName
     ,Views.vwMeetChangeStampsPartitioned

 ]
 */
