//
//  RussianVioletBlackPalette.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/10/25.
//

//2E003E

import SwiftUI

struct AppPalette
{
    struct Brand
    {
        static let neonPink         = Color(hex: "#FF007D")
        static let russianViolet    = Color(hex: "#2E003E") // Russian violet Phtalo #1A002A Gunmetal Plum #1C0B1C
        static let gunmetalPlum     = Color(hex: "#1C0B1C")
        static let phthaloViolet    = Color(hex: "#1A002A")
        static let obsidianViolet   = Color(hex: "#120017")
        static let japPurple        = Color(hex: "#452A83")
        static let japDarkerPurple  = Color(hex: "#3C177B")
        static let formBlack        = Color(hex: "#141416")
        static let nearBlack        = Color(hex: "#0A0A0A")
        
        static let electricViolet   = Color(hex: "#4B0082")
        static let violetMid        = Color(hex: "#23003E")
        static let blueMid          = Color(hex: "#0F4C81") // figure out what color this is
        static let pigNeonPink      = Color(hex: "#FF007D")
        static let coolBlue         = Color(hex: "#0A719D")
        static let warmPurple       = Color(hex: "#4A1A4A")
        static let brightTeal       = Color(hex: "#00CED1")
        static let vibrantBlue      = Color(hex: "#1E90FF")
        static let neonPurple       = Color(hex: "#6A0DAD")
        static let electricBlue     = Color(hex: "#0080FF")
        
        
        // Yellows (work great on Russian Violet)
        static let sunflowerYellow = Color(hex: "#FFC300") // bright, punchy
        static let amberYellow     = Color(hex: "#FFB300") // strong warning (matches Action.warning)
        static let honeyYellow     = Color(hex: "#FFC107") // rich amber (Material vibe)
        static let saffronYellow   = Color(hex: "#F4C430") // warmer, a bit earthy
        static let lemonZest       = Color(hex: "#FFD52E") // vivid, high-energy
        static let butterYellow    = Color(hex: "#FFE380") // soft pill/background
        static let goldenrod       = Color(hex: "#DAA520") // muted/gold, good for icons

        

        static let brightViolet     = Color(hex: "#8A2BE2")
        static let neonBlue         = Color(hex: "#0066FF")
        static let aquaBlue         = Color(hex: "#00BFFF")
        static let hotPurple        = Color(hex: "#7B68EE")
        static let royalBlue        = Color(hex: "#4169E1")
        static let brightCyan       = Color(hex: "#00FFFF")
        
        // Green colors for active meets
         static let neonGreen        = Color(hex: "#00FF41")
         static let brightGreen      = Color(hex: "#32CD32")
         static let electricGreen    = Color(hex: "#00FF00")
         static let emeraldGreen     = Color(hex: "#50C878")
         static let springGreen      = Color(hex: "#00FF7F")
         static let spearmintGreen = Color(hex: "#2EE6A6") // minty, slightly blue-leaning

    }
    
    struct Action
    {
           // Destructive
       static let delete  = Color(hex: "#FF3B30")     // iOS red (clear “Delete”)

       // Negative / cancel
       static let decline = Brand.neonPink            // your neon pink

       // Positive / create
       static let insert  = Brand.spearmintGreen      // minty confirm/create
       static let accept  = Brand.spearmintGreen

       // Edit / change
       static let modify  = Brand.brightTeal          // teal reads “edit”
       static let update  = Brand.electricBlue        // blue = “save/update”

       // Caution / warning
       static let warning = Color(hex: "#FFB300")     // vivid amber
   }
    
    struct Text
    {
        static let primary      = Color.white
        static let secondary    = Color.white.opacity(0.72)
        static let tertiary     = Color.white.opacity(0.56)
        static let quaternary   = Color.white.opacity(0.2)
        
        static let nearByBadgeFillPrimary   = Color.black
        static let nearByBadgeFillSecondary   = Color.black.opacity(0.9)
        static let nearByBadgeFillTertiary  = Color.black.opacity(0.56)
    }
    
    struct Surface
    {
        static let primary           = Color.white.opacity(0.9)
        static let fieldFill         = Color.white.opacity(0.08)
        static let nearByBadgeFill   = Color.white.opacity(0.9)
        static let fieldStroke       = Color.white.opacity(0.16)
        //static let recenterField     = Color.white.opacity(0.96)
        static let recenterField = AppPalette.Brand.japDarkerPurple
        static let focusStroke       = Brand.neonPink
        
        static let meetSearch = AppPalette.Brand.japDarkerPurple
        static let userSearch = AppPalette.Brand.japDarkerPurple
  
        static let invitationCard   = AppPalette.Brand.japPurple
        static let myMeetsCard      = AppPalette.Brand.japDarkerPurple
        static let joinedMeetsCard  = AppPalette.Brand.japDarkerPurple

    }

    // Solid – Russian Violet (darkest; avoid edge crush if too dim)
    static let bgGradient = LinearGradient(
        colors: [Brand.japDarkerPurple],
        startPoint: .top, endPoint: .bottom
    )
}

