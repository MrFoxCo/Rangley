////
////  CreateMeetFlow.swift
////  Rangley
////
////  Created by Anthony Guzzardo on 8/29/25.
////
//
//@MainActor
//func createMeetFlow() async {
//    do {
//        // 1) meet-coordinate
//        let coordOut: InsertMeetCoordinateResponse = try await API.post(
//            "/i/meet-coordinate",
//            body: InsertMeetCoordinateRequest(
//                latitude: 41.9484,
//                longitude: -87.6553,
//                region_latitude: 41.9484,
//                region_longitude: -87.6553,
//                region_radius: 250
//            )
//        )
//
//        // 2) meet-id
//        let meetIdOut: InsertMeetIdResponse = try await API.post(
//            "/i/meet-id",
//            body: InsertMeetIdRequest(
//                meet_coordinate_id: coordOut.new_meet_coordinate_id,
//                created_by_user_id: 2 // <-- ensure this user exists
//            )
//        )
//
//        // 3) meet
//        let _: OkResponse = try await API.post(
//            "/i/meet",
//            body: InsertMeetRequest(
//                meet_id: meetIdOut.new_meet_id,
//                change_stamp: nil,
//                name: "Waveland Tennis Doubles",
//                description: "Casual pick-up match",
//                change_reason: "initial create",
//                meet_category_id: 1   // ensure this category exists
//            )
//        )
//
//        print("✅ Meet created (id \(meetIdOut.new_meet_id))")
//
//    } catch {
//        print("❌ createMeetFlow failed:", error.localizedDescription)
//    }
//}
