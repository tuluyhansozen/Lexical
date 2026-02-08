import Foundation
import LexicalCore
import XCTest

final class AdaptivePromptBuilderTests: XCTestCase {
    private let builder = AdaptivePromptBuilder(
        minRank: 500,
        maxRank: 20_000,
        halfWindow: 500,
        maxVelocityBias: 250
    )

    func testRankWindowUsesPlusMinusFiveHundredAtNeutralVelocity() {
        let context = AdaptivePromptContext(
            lexicalRank: 6_000,
            easyRatingVelocity: 0.0
        )

        let prompt = builder.buildPrompt(
            context: context,
            focusLemmas: ["ephemeral", "retention"],
            topic: "technology",
            baseTemplate: "Write a short article."
        )

        XCTAssertEqual(prompt.centerRank, 6_000)
        XCTAssertEqual(prompt.targetRange, 5_500...6_500)
        XCTAssertEqual(prompt.velocityBias, 0)
    }

    func testPositiveVelocityBiasesWindowUpward() {
        let context = AdaptivePromptContext(
            lexicalRank: 6_000,
            easyRatingVelocity: 0.8
        )

        let prompt = builder.buildPrompt(
            context: context,
            focusLemmas: ["signal"],
            topic: "science",
            baseTemplate: "Write a short article."
        )

        XCTAssertEqual(prompt.velocityBias, 200)
        XCTAssertEqual(prompt.centerRank, 6_200)
        XCTAssertEqual(prompt.targetRange, 5_700...6_700)
    }

    func testNegativeVelocityBiasesWindowDownward() {
        let context = AdaptivePromptContext(
            lexicalRank: 6_000,
            easyRatingVelocity: -0.6
        )

        let prompt = builder.buildPrompt(
            context: context,
            focusLemmas: ["anchor"],
            topic: "history",
            baseTemplate: "Write a short article."
        )

        XCTAssertEqual(prompt.velocityBias, -150)
        XCTAssertEqual(prompt.centerRank, 5_850)
        XCTAssertEqual(prompt.targetRange, 5_350...6_350)
    }

    func testWindowClampsAtGlobalRankBounds() {
        let lowContext = AdaptivePromptContext(
            lexicalRank: 520,
            easyRatingVelocity: -1.0
        )
        let highContext = AdaptivePromptContext(
            lexicalRank: 19_980,
            easyRatingVelocity: 1.0
        )

        let lowPrompt = builder.buildPrompt(
            context: lowContext,
            focusLemmas: ["base"],
            topic: "starter",
            baseTemplate: "Write a short article."
        )
        let highPrompt = builder.buildPrompt(
            context: highContext,
            focusLemmas: ["advanced"],
            topic: "expert",
            baseTemplate: "Write a short article."
        )

        XCTAssertEqual(lowPrompt.centerRank, 500)
        XCTAssertEqual(lowPrompt.targetRange, 500...1_000)
        XCTAssertEqual(highPrompt.centerRank, 20_000)
        XCTAssertEqual(highPrompt.targetRange, 19_500...20_000)
    }

    func testPromptBodyContainsTopicRangeAndFocusWords() {
        let context = AdaptivePromptContext(
            lexicalRank: 3_500,
            easyRatingVelocity: 0.0
        )

        let prompt = builder.buildPrompt(
            context: context,
            focusLemmas: ["throttle", "contextual"],
            topic: "productivity",
            baseTemplate: "Write a short article."
        )

        XCTAssertTrue(prompt.body.contains("productivity"))
        XCTAssertTrue(prompt.body.contains("3000"))
        XCTAssertTrue(prompt.body.contains("4000"))
        XCTAssertTrue(prompt.body.contains("throttle"))
        XCTAssertTrue(prompt.body.contains("contextual"))
    }
}
