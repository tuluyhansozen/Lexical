import SwiftUI

extension Font {
    // Lexend Equivalent (Display)
    static func display(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Using Rounded system font as a proxy for Lexend's friendly geometric feel
        return .system(size: size, weight: weight, design: .rounded)
    }
    
    // Lora/New York Equivalent (Serif)
    static func serif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .serif)
    }
    
    // Preset Styles
    static let articleTitle = display(size: 34, weight: .bold)
    static let cardTitle = display(size: 24, weight: .bold)
    static let bodyText = serif(size: 18, weight: .regular)
    static let captionText = display(size: 12, weight: .medium)
}
