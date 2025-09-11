//
//  RussianVioletBlackPalette.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/10/25.
//

//2E003E

import SwiftUI

struct AppPalette {
    struct Brand {
        static let neonPink   = Color(hex: "#FF007D")
        static let russianViolet     = Color(hex: "#2E003E") // Russian violet
        static let violetMid  = Color(hex: "#23003E")
        static let nearBlack  = Color(hex: "#0A0A0A")
        static let blueMid = Color(hex: "#0F4C81") // figure out what color this is
        static let pigNeonPink = Color(hex: "#FF007D")
        static let coolBlue   = Color(hex: "#0A719D")
    }
    struct Text {
        static let primary   = Color.white
        static let secondary = Color.white.opacity(0.72)
        static let tertiary  = Color.white.opacity(0.56)
    }
    struct Surface {
        static let fieldFill   = Color.white.opacity(0.08)
        static let fieldStroke = Color.white.opacity(0.16)
        static let focusStroke = Brand.neonPink
    }
    static let bgGradient = LinearGradient(
        colors: [Brand.russianViolet, Brand.coolBlue],
        startPoint: .top, endPoint: .bottom
    )
}
