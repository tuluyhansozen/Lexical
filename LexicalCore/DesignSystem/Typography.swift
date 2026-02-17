import SwiftUI

extension Font {
    // Lexend-like display typography
    public static func display(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    public static func display(_ textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(textStyle, design: .rounded).weight(weight)
    }

    // Lora/New York-like body typography
    public static func serif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    public static func serif(_ textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(textStyle, design: .serif).weight(weight)
    }

    // Semantic presets with Dynamic Type
    public static let screenTitle = display(.largeTitle, weight: .bold)
    public static let sectionTitle = display(.title3, weight: .bold)
    public static let cardTitle = display(.title2, weight: .bold)
    public static let cardSubtitle = display(.footnote, weight: .medium)
    public static let bodyText = serif(.body, weight: .regular)
    public static let bodyStrong = serif(.body, weight: .semibold)
    public static let captionText = display(.caption, weight: .medium)
    public static let metricValue = display(.title2, weight: .bold)
    public static let metricLabel = display(.caption2, weight: .semibold)

    // Legacy aliases kept for compatibility
    public static let articleTitle = display(.largeTitle, weight: .bold)
}
