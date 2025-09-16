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
        static let neonPink         = Color(hex: "#FF007D")
        static let russianViolet    = Color(hex: "#2E003E") // Russian violet
        static let violetMid        = Color(hex: "#23003E")
        static let nearBlack        = Color(hex: "#0A0A0A")
        static let blueMid          = Color(hex: "#0F4C81") // figure out what color this is
        static let pigNeonPink      = Color(hex: "#FF007D")
        static let coolBlue         = Color(hex: "#0A719D")
        static let warmPurple       = Color(hex: "#4A1A4A")
        static let electricViolet   = Color(hex: "#4B0082")
        static let vibrantBlue      = Color(hex: "#1E90FF")
        static let deepCyan         = Color(hex: "#008B8B")
        static let neonPurple       = Color(hex: "#6A0DAD")
        static let electricBlue     = Color(hex: "#0080FF")
        static let brightTeal       = Color(hex: "#00CED1")
        static let brightViolet     = Color(hex: "#8A2BE2")
        static let neonBlue         = Color(hex: "#0066FF")
        static let aquaBlue         = Color(hex: "#00BFFF")
        static let hotPurple        = Color(hex: "#7B68EE")
        static let royalBlue        = Color(hex: "#4169E1")
        static let brightCyan       = Color(hex: "#00FFFF")
    }
    
    struct Text {
        static let primary   = Color.white
        static let secondary = Color.white.opacity(0.72)
        static let tertiary  = Color.white.opacity(0.56)
        
        static let nearByBadgeFillPrimary   = Color.black
        static let nearByBadgeFillSecondary   = Color.black.opacity(0.9)
        static let nearByBadgeFillTertiary  = Color.black.opacity(0.56)
    }
    
    struct Surface {
        static let fieldFill        = Color.white.opacity(0.08)
        static let nearByBadgeFill   = Color.white.opacity(0.9)
        static let fieldStroke = Color.white.opacity(0.16)
        static let focusStroke = Brand.neonPink
    }

    // Solid – Russian Violet (darkest; avoid edge crush if too dim)
    static let bgGradient = LinearGradient(
        colors: [Brand.russianViolet],
        startPoint: .top, endPoint: .bottom
    )
}
