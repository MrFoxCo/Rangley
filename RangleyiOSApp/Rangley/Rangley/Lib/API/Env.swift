//
//  Env.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/12/25.
//

// Env.swift
import Foundation

enum Env {
    static let apiBaseURL: URL = {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: s) else {
            fatalError("Missing or invalid API_BASE_URL in Info.plist")
        }
        print("API_BASE_URL =", Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as Any)

        return url
    }()
}
