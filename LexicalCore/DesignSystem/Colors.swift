import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

extension Color {
    static public let sonPrimary = Color(hex: "4F735C")
    static public let sonCloud = Color(hex: "F2EDE7")
    static public let sonMidnight = Color(hex: "2F2F2F")
    static public let sonCharcoal = Color(hex: "3E3E42")
    
    // Semantic Colors
    static public let sonBackgroundLight = Color.white
    static public let sonBackgroundDark = Color(hex: "2F2F2F")
    static public let sonSurfaceDark = Color(hex: "3E3E42")
    
    // Adapted for Light/Dark mode
    static public let sonBackground = Color("SonBackground") // In a real app we'd set this up in Assets, but here we can stick to programmatic for simplicity or use system adaptation.
    
    static public var adaptiveBackground: Color {
#if canImport(UIKit)
        Color(uiColor: UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(hex: "2F2F2F") : UIColor.white
        })
#elseif canImport(AppKit)
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(hex: "2F2F2F") : .white
        })
#else
        Color.white
#endif
    }
    
    static public var adaptiveSurface: Color {
#if canImport(UIKit)
        Color(uiColor: UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(hex: "3E3E42") : UIColor(hex: "F2EDE7")
        })
#elseif canImport(AppKit)
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(hex: "3E3E42") : NSColor(hex: "F2EDE7")
        })
#else
        Color(hex: "F2EDE7")
#endif
    }
    
    static public var adaptiveText: Color {
#if canImport(UIKit)
        Color(uiColor: UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(hex: "F2EDE7") : UIColor(hex: "2F2F2F")
        })
#elseif canImport(AppKit)
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(hex: "F2EDE7") : NSColor(hex: "2F2F2F")
        })
#else
        Color(hex: "2F2F2F")
#endif
    }
}

extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Platform Color Extensions
#if canImport(UIKit)
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue:  CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
#endif

#if canImport(AppKit)
extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 255)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
#endif
