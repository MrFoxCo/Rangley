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
        static let warmPurple           = Color(hex: "#4A1A4A")
        static let softMauve            = Color(hex: "#6B4C7A")
        static let deepPlum             = Color(hex: "#3D1A4A")
        static let softLavender         = Color(hex: "#5D4E6D")
        static let lightPurple      = Color(hex: "#7A6B8A")
        static let techPurple       = Color(hex: "#3A2A4A")
        static let modernGray       = Color(hex: "#4A4A5A")
        static let lightSlate       = Color(hex: "#6A6A7A")
        static let deepRose         = Color(hex: "#4A1A3D")
        static let dustyRose         = Color(hex: "#6B3A5D")
        static let warmCoral        = Color(red: 0.98, green: 0.45, blue: 0.42)      // #FA7367
        static let sunsetOrange        = Color(red: 0.95, green: 0.35, blue: 0.25)   // #F25940
        static let peachGlow       = Color(red: 1.0, green: 0.55, blue: 0.45)       // #FF8C73
        static let softRose        = Color(red: 0.96, green: 0.52, blue: 0.58)       // #F58594
        static let electricViolet       = Color(hex: "#4B0082")
        static let vibrantBlue      = Color(hex: "#1E90FF")
        static let deepCyan         = Color(hex: "#008B8B")
        static let neonPurple       = Color(hex: "#6A0DAD")
        static let electricBlue         = Color(hex: "#0080FF")
        static let brightTeal       = Color(hex: "#00CED1")
        static let brightViolet         = Color(hex: "#8A2BE2")
        static let neonBlue      = Color(hex: "#0066FF")
        static let aquaBlue         = Color(hex: "#00BFFF")
        static let hotPurple        = Color(hex: "#7B68EE")
        static let royalBlue             = Color(hex: "#4169E1")
        static let brightCyan        = Color(hex: "#00FFFF")
        static let charcoal          = Color(hex: "#2C3E50")
        static let professionalBlue     = Color(hex: "#3498DB")
        static let darkGray             = Color(hex: "#34495E")
        static let mutedGold            = Color(hex: "#F39C12")
        static let trueBlack            = Color(hex: "#000000")
        static let mediumGray           = Color(hex: "#7F8C8D")
        static let deepNavy                 = Color(hex: "#1E3A8A")
        static let corporateBlue         = Color(hex: "#3B82F6")

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


//    static let bgGradient = LinearGradient(
//        colors: [Brand.russianViolet, Brand.electricViolet, Brand.vibrantBlue, Brand.deepCyan],
//        startPoint: .top, endPoint: .bottom
//    )

    // Add these gradient options to your AppPalette struct

    // Option 1: Professional Gradient (Charcoal to Blue)
//    static let bgGradient = LinearGradient(
//        colors: [Brand.nearBlack, Brand.blueMid, Brand.coolBlue],
//        startPoint: .top, endPoint: .bottom
//    )

    // Option 2: Monochrome Depth (Black to Gray)
    static let bgGradient = LinearGradient(
        colors: [Brand.nearBlack, Brand.modernGray, Brand.lightSlate],
        startPoint: .top, endPoint: .bottom
    )
//
//    // Option 3: Subtle Warm Corporate
//    static let bgGradient = LinearGradient(
//        colors: [Brand.nearBlack, Brand.modernGray, Brand.warmCoral],
//        startPoint: .top, endPoint: .bottom
//    )
//
//    // Option 4: Deep Navy Professional
//    static let bgGradient = LinearGradient(
//        colors: [Brand.nearBlack, Brand.blueMid, Brand.royalBlue],
//        startPoint: .top, endPoint: .bottom
//    )
//
//    // Option 5: Sophisticated Purple-Gray
//    static let bgGradient = LinearGradient(
//        colors: [Brand.nearBlack, Brand.techPurple, Brand.modernGray],
//        startPoint: .top, endPoint: .bottom
//    )
//
//    // Option 6: Clean Corporate Blue
//    static let bgGradient = LinearGradient(
//        colors: [Brand.modernGray, Brand.blueMid, Brand.vibrantBlue],
//        startPoint: .top, endPoint: .bottom
//    )
//
//    // Option 7: Minimal Dark (Very subtle)
//    static let bgGradient = LinearGradient(
//        colors: [Brand.nearBlack, Brand.modernGray],
//        startPoint: .top, endPoint: .bottom
//    )
//
//    // Option 8: Warm Professional (Sunset-inspired but muted)
//    static let bgGradient = LinearGradient(
//        colors: [Brand.modernGray, Brand.warmCoral, Brand.sunsetOrange],
//        startPoint: .top, endPoint: .bottom
//    )
//
//    
    
}
