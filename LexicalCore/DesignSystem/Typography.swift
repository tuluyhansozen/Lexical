import SwiftUI

extension Font {
    // Lexend Equivalent (Display)
    public static func display(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Using Rounded system font as a proxy for Lexend's friendly geometric feel
        return .system(size: size, weight: weight, design: .rounded)
    }
    
    // Lora/New York Equivalent (Serif)
    public static func serif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .serif)
    }
    
    // Preset Styles
    public static let articleTitle = display(size: 34, weight: .bold)
    public static let cardTitle = display(size: 24, weight: .bold)
    public static let bodyText = serif(size: 18, weight: .regular)
    public static let captionText = display(size: 12, weight: .medium)
}
