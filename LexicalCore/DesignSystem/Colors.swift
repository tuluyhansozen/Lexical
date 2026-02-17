import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

extension Color {
    public static let sonPrimary = Color(hex: "4F735C")
    public static let sonCloud = Color(hex: "F2EDE7")
    public static let sonMidnight = Color(hex: "2F2F2F")
    public static let sonCharcoal = Color(hex: "3E3E42")

    public static let sonSuccess = Color(hex: "2FB55D")
    public static let sonWarning = Color(hex: "E58A2B")
    public static let sonDanger = Color(hex: "C14A4A")

    public static let stateNew = Color(hex: "E7F2FF")
    public static let stateLearning = Color(hex: "FFF3D6")
    public static let stateKnown = Color(hex: "E6F6EB")
    public static let stateUnknown = Color(hex: "E7EAED")

    public static var sonBackgroundLight: Color { .white }
    public static var sonBackgroundDark: Color { Color(hex: "2F2F2F") }
    public static var sonSurfaceDark: Color { Color(hex: "3E3E42") }

    public static var sonBackground: Color { adaptiveBackground }

    public static var adaptiveBackground: Color {
#if canImport(UIKit)
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(hex: "2F2F2F") : UIColor.white
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
    
    public static var adaptiveSurface: Color {
#if canImport(UIKit)
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(hex: "3E3E42") : UIColor(hex: "F2EDE7")
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
    
    public static var adaptiveSurfaceElevated: Color {
#if canImport(UIKit)
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(hex: "4A4B50") : UIColor.white
        })
#elseif canImport(AppKit)
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(hex: "4A4B50") : .white
        })
#else
        .white
#endif
    }

    public static var adaptiveText: Color {
#if canImport(UIKit)
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(hex: "F2EDE7") : UIColor(hex: "2F2F2F")
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

    public static var adaptiveTextSecondary: Color {
#if canImport(UIKit)
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(hex: "C8C8CC") : UIColor(hex: "5A5F66")
        })
#elseif canImport(AppKit)
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(hex: "C8C8CC") : NSColor(hex: "5A5F66")
        })
#else
        Color(hex: "5A5F66")
#endif
    }

    public static var adaptiveBorder: Color {
#if canImport(UIKit)
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.10) : UIColor.black.withAlphaComponent(0.08)
        })
#elseif canImport(AppKit)
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor.white.withAlphaComponent(0.10) : NSColor.black.withAlphaComponent(0.08)
        })
#else
        Color.black.opacity(0.08)
#endif
    }

    public static var cardShadow: Color {
        Color.black.opacity(0.12)
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
