//
//  FontStyles.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/13/25.
//

import SwiftUI

struct FontStyles {
    // Headers & Titles
    static let largeTitle = Font.custom("Avenir Next", size: 34).weight(.bold)
    static let title1 = Font.custom("Futura", size: 25).weight(.medium)
    static let title2 = Font.custom("Helvetica Neue", size: 22).weight(.semibold)
    static let title3 = Font.custom("SF Pro Display", size: 20).weight(.semibold)
    
    // Body Text
    static let body = Font.custom("SF Pro Text", size: 17).weight(.regular)
    static let bodyBold = Font.custom("SF Pro Text", size: 17).weight(.semibold)
    static let callout = Font.custom("Avenir Next", size: 25).weight(.medium)
    
    // UI Elements
    static let buttonPrimary = Font.custom("SF Pro Display", size: 18).weight(.semibold)
    static let buttonSecondary = Font.custom("Helvetica Neue", size: 16).weight(.medium)
    static let caption = Font.custom("SF Compact", size: 12).weight(.medium)
    
    // Special/Accent
    static let headline = Font.custom("Futura", size: 17).weight(.bold)
    static let subheadline = Font.custom("Avenir Next", size: 15).weight(.medium)
    
    // Branding
    static let brandTitle = Font.custom("SF Pro Display", size: 24).weight(.black)
    static let brandSubtitle = Font.custom("Helvetica Neue", size: 14).weight(.light)
}
