import SwiftUI
import Foundation
import LexicalCore

struct RecallHeaderView: View {
    let spec: RecallFigmaSpec
    let colorScheme: ColorScheme
    let scale: CGFloat
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * scale) {
            Text(title)
                .font(.system(size: spec.headerTitleFontSize * scale, weight: .semibold))
                .foregroundStyle(spec.titleColor(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(.system(size: spec.headerSubtitleFontSize * scale, weight: .regular))
                .foregroundStyle(spec.subtitleColor(for: colorScheme))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RecallProgressTrackView: View {
    let spec: RecallFigmaSpec
    let colorScheme: ColorScheme
    let value: Double
    let total: Double

    var body: some View {
        GeometryReader { geometry in
            let progress = total > 0 ? min(max(value / total, 0), 1) : 0
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: spec.progressCornerRadius)
                    .fill(spec.progressTrackColor(for: colorScheme))
                RoundedRectangle(cornerRadius: spec.progressCornerRadius)
                    .fill(spec.progressFillColor(for: colorScheme))
                    .frame(width: max(0, geometry.size.width * progress))
            }
        }
        .frame(height: spec.progressHeight)
        .accessibilityElement()
        .accessibilityLabel("Session progress")
        .accessibilityValue("\(Int(value)) of \(Int(total))")
    }
}


struct RecallCardSurface<Content: View>: View {
    let spec: RecallFigmaSpec
    let colorScheme: ColorScheme
    let scale: CGFloat
    private let content: Content

    init(
        spec: RecallFigmaSpec,
        colorScheme: ColorScheme,
        scale: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.spec = spec
        self.colorScheme = colorScheme
        self.scale = scale
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 20 * scale)
            .padding(.vertical, 22 * scale)
            .frame(maxWidth: .infinity, minHeight: spec.cardMinHeight * scale, alignment: .topLeading)
            .background(spec.cardFill(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: spec.cardCornerRadius * scale, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: spec.cardCornerRadius * scale, style: .continuous)
                    .stroke(spec.cardStroke(for: colorScheme), lineWidth: max(1, 1.1 * scale))
            )
            .shadow(
                color: spec.cardShadow(for: colorScheme),
                radius: spec.cardShadowRadius * scale,
                x: 0,
                y: spec.cardShadowYOffset * scale
            )
    }
}

struct RecallPrimaryActionButton: View {
    let spec: RecallFigmaSpec
    let colorScheme: ColorScheme
    let scale: CGFloat
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18 * scale, weight: .semibold))
                .foregroundStyle(spec.primaryTextColor)
                .frame(maxWidth: .infinity, minHeight: spec.primaryActionHeight * scale)
                .background(spec.primaryFill(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: spec.primaryActionCornerRadius * scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct RecallNeutralActionButton: View {
    let spec: RecallFigmaSpec
    let colorScheme: ColorScheme
    let scale: CGFloat
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15 * scale, weight: .semibold))
                .foregroundStyle(spec.neutralActionText(for: colorScheme))
                .frame(maxWidth: .infinity, minHeight: spec.neutralActionHeight * scale)
                .background(spec.neutralActionFill(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: spec.neutralActionCornerRadius * scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct RecallGradeActionButton: View {
    let spec: RecallFigmaSpec
    let colorScheme: ColorScheme
    let scale: CGFloat
    let grade: Int
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 11 * scale, weight: .medium))
                .tracking(1.16 * scale)
                .foregroundStyle(Color.white)
                .frame(
                    width: spec.figmaGradeButtonSize * scale,
                    height: spec.figmaGradeButtonSize * scale
                )
                .background(spec.gradeFill(for: grade, colorScheme: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: spec.figmaGradeButtonCornerRadius * scale, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: spec.figmaGradeButtonCornerRadius * scale, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: max(1, spec.figmaGradeButtonBorderWidth * scale))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Grade \(title)")
    }
}

func displayWord(_ lemma: String) -> String {
    let trimmed = lemma.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = trimmed.first else { return lemma }
    return first.uppercased() + trimmed.dropFirst()
}

func normalizedDefinition(_ definition: String?) -> String? {
    guard let definition else { return nil }
    let trimmed = definition.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

func maskedSentence(_ sentence: String, lemma: String) -> String {
    let cleanLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanLemma.isEmpty else { return sentence }

    let escapedLemma = NSRegularExpression.escapedPattern(for: cleanLemma)
    let pattern = "(?i)\\b\(escapedLemma)\\b"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return sentence
    }
    let range = NSRange(sentence.startIndex..<sentence.endIndex, in: sentence)
    guard let firstMatch = regex.firstMatch(in: sentence, options: [], range: range),
          let swiftRange = Range(firstMatch.range, in: sentence) else {
        return sentence
    }

    var result = sentence
    result.replaceSubrange(swiftRange, with: "[_____]")
    return result
}
