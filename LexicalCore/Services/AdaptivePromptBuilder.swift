import Foundation

public struct AdaptivePromptContext: Sendable {
    public let lexicalRank: Int
    public let easyRatingVelocity: Double

    public init(lexicalRank: Int, easyRatingVelocity: Double) {
        self.lexicalRank = lexicalRank
        self.easyRatingVelocity = easyRatingVelocity
    }
}

public struct AdaptivePrompt: Sendable {
    public let body: String
    public let centerRank: Int
    public let targetRange: ClosedRange<Int>
    public let velocityBias: Int

    public init(
        body: String,
        centerRank: Int,
        targetRange: ClosedRange<Int>,
        velocityBias: Int
    ) {
        self.body = body
        self.centerRank = centerRank
        self.targetRange = targetRange
        self.velocityBias = velocityBias
    }
}

/// Builds lexical-rank-aware prompt envelopes used by article generation.
public struct AdaptivePromptBuilder {
    private let minRank: Int
    private let maxRank: Int
    private let halfWindow: Int
    private let maxVelocityBias: Int

    public init(
        minRank: Int = 500,
        maxRank: Int = 20_000,
        halfWindow: Int = 500,
        maxVelocityBias: Int = 250
    ) {
        self.minRank = minRank
        self.maxRank = maxRank
        self.halfWindow = halfWindow
        self.maxVelocityBias = maxVelocityBias
    }

    public func buildPrompt(
        context: AdaptivePromptContext,
        focusLemmas: [String],
        topic: String,
        baseTemplate: String
    ) -> AdaptivePrompt {
        let clampedVelocity = max(-1.0, min(1.0, context.easyRatingVelocity))
        let velocityBias = Int((Double(maxVelocityBias) * clampedVelocity).rounded())
        let centerRank = clampRank(context.lexicalRank + velocityBias)
        let lower = max(minRank, centerRank - halfWindow)
        let upper = min(maxRank, centerRank + halfWindow)
        let normalizedFocus = normalizedLemmas(from: focusLemmas)
        let focusText = normalizedFocus.isEmpty ? "none" : normalizedFocus.joined(separator: ", ")

        let prompt = """
        \(baseTemplate)

        Lexical calibration constraints:
        - Topic focus: \(topic)
        - Target lexical center rank: \(centerRank)
        - Allowed lexical rank band: \(lower)-\(upper)
        - Velocity bias applied: \(velocityBias)
        - Required focus lemmas: \(focusText)
        - Use vocabulary mostly inside the target band and keep out-of-band terms minimal.
        """

        return AdaptivePrompt(
            body: prompt,
            centerRank: centerRank,
            targetRange: lower...upper,
            velocityBias: velocityBias
        )
    }

    private func clampRank(_ value: Int) -> Int {
        min(maxRank, max(minRank, value))
    }

    private func normalizedLemmas(from lemmas: [String]) -> [String] {
        let normalized = lemmas
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Array(Set(normalized)).sorted()
    }
}
