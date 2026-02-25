import SwiftUI

struct ExploreVisualSpec {
    struct LeafSlot {
        let label: String
        let position: CGPoint
        let diameter: CGFloat
    }

    let titleText = "Explore"
    let subtitleText = "Daily word families for you"

    let titleFontSize: CGFloat = 32
    let subtitleFontSize: CGFloat = 16
    let titleKerning: CGFloat = 0.3955
    let subtitleKerning: CGFloat = 0.3955
    let rootPrimaryFontSize: CGFloat = 16
    let rootSecondaryFontSize: CGFloat = 10
    let leafFontSize: CGFloat = 9

    let lightBackgroundHex = "F5F5F7"
    let darkBackgroundHex = "16191D"
    let titleLightHex = "0A0A0A"
    let titleDarkHex = "F4F5F6"
    let subtitleLightHex = "4A4A4A"
    let subtitleDarkHex = "9AA2AB"

    let connectorHexLight = "D1D5DC"
    let connectorHexDark = "5F6975"
    let connectorLineWidth: CGFloat = 0.9
    let connectorOpacityLight: Double = 0.55
    let connectorOpacityDark: Double = 0.62

    let leafFillHexLight = "50605A"
    let leafFillHexDark = "4B5852"
    let rootFillHexLight = "7B0002"
    let rootFillHexDark = "7B0002"
    let rootFillOpacity: Double = 0.60
    let rootGlowHexLight = "FF8D98"
    let rootGlowHexDark = "FF8D98"
    let nodeStrokeHexLight = "F2F3F5"
    let nodeStrokeHexDark = "A0A7AE"

    let designCanvasSize = CGSize(width: 392.99, height: 624.02)

    let rootLabel = "spec"
    let rootMeaning = "A morphological root tied to seeing, looking, and observation."
    let rootPosition = CGPoint(x: 0.5181, y: 0.4666)
    let rootDiameter: CGFloat = 98.409

    let leafSlots: [LeafSlot] = [
        LeafSlot(label: "Spectator", position: CGPoint(x: 0.3472, y: 0.1948), diameter: 73.192),
        LeafSlot(label: "Retrospect", position: CGPoint(x: 0.7009, y: 0.2239), diameter: 87.811),
        LeafSlot(label: "Spectacle", position: CGPoint(x: 0.2152, y: 0.3590), diameter: 73.192),
        LeafSlot(label: "Conspicuous", position: CGPoint(x: 0.7821, y: 0.5754), diameter: 82.464),
        LeafSlot(label: "Perspective", position: CGPoint(x: 0.2525, y: 0.6404), diameter: 89.105),
        LeafSlot(label: "Inspect", position: CGPoint(x: 0.5097, y: 0.7363), diameter: 73.139)
    ]
}

enum ExploreAccessibilityMode: Equatable {
    case graph
    case list

    static func resolve(reduceMotion: Bool, dynamicTypeSize: DynamicTypeSize) -> Self {
        if reduceMotion || dynamicTypeSize.isAccessibilitySize {
            return .list
        }
        return .graph
    }
}

enum ExploreNodeLabelPolicy {
    static func renderedLabel(
        for lemma: String,
        dynamicTypeSize: DynamicTypeSize
    ) -> String {
        let normalized = normalizedWord(lemma)
        guard !dynamicTypeSize.isAccessibilitySize else {
            if normalized.count <= 7 {
                return normalized
            }
            return String(normalized.prefix(7)) + "…"
        }
        return normalized
    }

    static func accessibilityLabel(for lemma: String) -> String {
        normalizedWord(lemma)
    }

    private static func normalizedWord(_ word: String) -> String {
        let cleaned = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = cleaned.first else { return cleaned }
        return first.uppercased() + cleaned.dropFirst()
    }
}
