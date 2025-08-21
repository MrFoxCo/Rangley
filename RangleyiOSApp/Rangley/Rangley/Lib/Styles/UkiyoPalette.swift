import SwiftUI
import UIKit

public enum UkiyoPalette {
    // MARK: Blues
    public enum Blues {
        public static let prussianBlue = UkiyoPalette.color("#0F4C81")
        public static let indigo       = UkiyoPalette.color("#264653")
        public static let lightSkyBlue = UkiyoPalette.color("#8BBBD9")
        public static let blueGrey     = UkiyoPalette.color("#6B93AA")
    }
    // MARK: Greens
    public enum Greens {
        public static let softLeaf = UkiyoPalette.color("#6A9A1F")
        public static let teal     = UkiyoPalette.color("#3A796F")
        public static let olive    = UkiyoPalette.color("#8A8F3A")
    }
    // MARK: Reds / Pinks
    public enum RedsPinks {
        public static let vermilion = UkiyoPalette.color("#E34234")
        public static let softPink  = UkiyoPalette.color("#F6C4C4")
        public static let crimson   = UkiyoPalette.color("#A63A3A")
    }
    // MARK: Yellows
    public enum Yellows {
        public static let golden   = UkiyoPalette.color("#FFC30B")
        public static let paleStraw = UkiyoPalette.color("#F2E5B3")
    }
    // MARK: Neutrals
    public enum Neutrals {
        public static let sumiInkBlack = UkiyoPalette.color("#1C1C1C")
        public static let warmBeige    = UkiyoPalette.color("#E9DCC9")
        public static let coolGrey     = UkiyoPalette.color("#A6A6A6")
    }
    
    // MARK: Whites
    public enum Whites {
        public static let paperWhite   = UkiyoPalette.color("#FEFEFE")
        public static let creamWhite   = UkiyoPalette.color("#F8F5F0")
        public static let ricePaper    = UkiyoPalette.color("#F5F2E8")
        public static let cloudWhite   = UkiyoPalette.color("#F9F7F4")
    }

    // MARK: Semantic tokens
    public enum Semantic {
        public static let cardDarkBackground   = Neutrals.sumiInkBlack
        public static let cardLightBackground  = Neutrals.warmBeige
        public static let cardGreyBackground   = Neutrals.coolGrey
        public static let cardWhiteBackground  = Whites.cloudWhite
        public static let destroyButtons  = RedsPinks.crimson
        public static let cardBorder      = Yellows.paleStraw.opacity(0.15)
        public static let titleText       = Neutrals.warmBeige
        public static let bodyText        = Neutrals.coolGrey
        public static let metaText        = Blues.lightSkyBlue
        public static let pillBackground  = Blues.indigo.opacity(0.8)
        public static let dangerFill      = RedsPinks.vermilion
        public static let accentPrimary   = Blues.prussianBlue
        public static let accentSecondary = Greens.teal
        public static let highlight       = Yellows.golden
        public static let backdropDim     = Color.black.opacity(0.22)
    }

    // MARK: Gradients
    public enum Gradients {
        public static let noirOverlay = LinearGradient(
            colors: [Blues.indigo.opacity(0.55), Neutrals.sumiInkBlack.opacity(0.8)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        public static let accentBlue = LinearGradient(
            colors: [Blues.prussianBlue, Blues.blueGrey],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: UIKit mirrors
    #if canImport(UIKit)
    public enum UI {
        public enum Blues {
            public static let prussianBlue = UkiyoPalette.uiColor("#0F4C81")
            public static let indigo       = UkiyoPalette.uiColor("#264653")
            public static let lightSkyBlue = UkiyoPalette.uiColor("#8BBBD9")
            public static let blueGrey     = UkiyoPalette.uiColor("#6B93AA")
        }
        public enum Greens {
            public static let softLeaf = UkiyoPalette.uiColor("#6A9A1F")
            public static let teal     = UkiyoPalette.uiColor("#3A796F")
            public static let olive    = UkiyoPalette.uiColor("#8A8F3A")
        }
        public enum RedsPinks {
            public static let vermilion = UkiyoPalette.uiColor("#E34234")
            public static let softPink  = UkiyoPalette.uiColor("#F6C4C4")
            public static let crimson   = UkiyoPalette.uiColor("#A63A3A")
        }
        public enum Yellows {
            public static let golden   = UkiyoPalette.uiColor("#FFC30B")
            public static let paleStraw = UkiyoPalette.uiColor("#F2E5B3")
        }
        public enum Neutrals {
            public static let sumiInkBlack = UkiyoPalette.uiColor("#1C1C1C")
            public static let warmBeige    = UkiyoPalette.uiColor("#E9DCC9")
            public static let coolGrey     = UkiyoPalette.uiColor("#A6A6A6")
        }

        public enum Whites {
            public static let paperWhite   = UkiyoPalette.uiColor("#FEFEFE")
            public static let creamWhite   = UkiyoPalette.uiColor("#F8F5F0")
            public static let ricePaper    = UkiyoPalette.uiColor("#F5F2E8")
            public static let cloudWhite   = UkiyoPalette.uiColor("#F9F7F4")
        }

    }
    #endif
}

// MARK: - Helpers (file-scoped; referenced as UkiyoPalette.color/uiColor)
fileprivate extension UkiyoPalette {
    static func color(_ hex: String) -> Color {
        let (r,g,b,a) = rgba(hex)
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    #if canImport(UIKit)
    static func uiColor(_ hex: String) -> UIColor {
        let (r,g,b,a) = rgba(hex)
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    #endif
    static func rgba(_ hex: String) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        return (CGFloat(r)/255, CGFloat(g)/255, CGFloat(b)/255, CGFloat(a)/255)
    }
}
