////
////  AuthRegisterTests.swift
////  Rangley
////
////  Created by Anthony Guzzardo on 9/2/25.
////
//
//// AuthRegisterTests.swift
//import XCTest
//@testable import YourAppModule
//
//final class AuthRegisterTests: XCTestCase {
//    func testAuthRegister() async throws {
//        let token = ProcessInfo.processInfo.environment["COGNITO_ACCESS_TOKEN"] ?? ""
//        try XCTSkipIf(token.isEmpty, "Set COGNITO_ACCESS_TOKEN in scheme env vars")
//
//        let req = AuthRegisterRequest(
//            username: "test\(Int.random(in: 1000...9999))",
//            display_name: "Test User",
//            cellphone: nil,
//            email: "test\(Int.random(in: 1000...9999))@example.com",
//            dob: "1995-01-10",
//            first_name: nil,
//            last_name: nil
//        )
//
//        let res = try await AuthAPI.register(
//            baseURL: URL(string: "http://127.0.0.1:8080")!,
//            token: token,
//            payload: req
//        )
//        XCTAssertNotNil(res.is_success)
//        XCTAssertEqual(res.is_success, true)
//    }
//}
//#if !os(macOS)
//extension AuthRegisterTests {
//    static var allTests: [(String, (AuthRegisterTests) -> () throws -> Void)] {
//        return [
//            ("testAuthRegister", testAuthRegister),
//        ]
//    }
//}
//#endif