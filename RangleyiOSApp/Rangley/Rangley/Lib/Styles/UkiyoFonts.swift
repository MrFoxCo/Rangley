//
//  UkiyoFonts.swift
//  Rangle
//
//  Created by Anthony Guzzardo on 8/11/25.
//

import SwiftUI

public enum UkiyoFonts {
    public static let hiraginoSansW3 = "HiraginoSans-W3"
    public static let hiraginoSansW6 = "HiraginoSans-W6"
    public static let hiraginoSansW7 = "HiraginoSans-W7"
    
    // System font alternatives for Ukiyo-e style
    public static func ukiyoTitle(size: CGFloat = 24) -> Font {
        return .system(size: size, weight: .bold, design: .rounded)
    }
    
    public static func ukiyoHeadline(size: CGFloat = 20) -> Font {
        return .system(size: size, weight: .semibold, design: .rounded)
    }
    
    public static func ukiyoBody(size: CGFloat = 16) -> Font {
        return .system(size: size, weight: .medium, design: .rounded)
    }
    
    public static func ukiyoCaption(size: CGFloat = 12) -> Font {
        return .system(size: size, weight: .medium, design: .rounded)
    }
    
    // Custom font helpers
    public static func hiraginoSans(size: CGFloat, weight: HiraginoWeight = .w3) -> Font {
        return .custom(weight.rawValue, size: size)
    }
    
    public enum HiraginoWeight: String {
        case w3 = "HiraginoSans-W3"
        case w6 = "HiraginoSans-W6"
        case w7 = "HiraginoSans-W7"
    }
}
