import Foundation
import LexicalCore
import SwiftData
import XCTest

final class RankPromotionEngineTests: XCTestCase {
    func testEasyVelocityEWMAUsesConfiguredAlpha() {
        let engine = RankPromotionEngineContract(alpha: 0.25)
        let output = engine.apply(
            .init(
                currentRank: 3_000,
                currentEasyVelocity: 0.20,
                currentRetentionEWMA: 0.80,
                observedEasyRatio: 1.0,
                observedRetention: 0.80
            )
        )

        XCTAssertEqual(output.easyVelocityEWMA, 0.40, accuracy: 0.0001)
        XCTAssertEqual(output.retentionEWMA, 0.80, accuracy: 0.0001)
    }

    func testRetentionEWMAUsesConfiguredAlpha() {
        let engine = RankPromotionEngineContract(alpha: 0.25)
        let output = engine.apply(
            .init(
                currentRank: 3_000,
                currentEasyVelocity: 0.50,
                currentRetentionEWMA: 0.60,
                observedEasyRatio: 0.50,
                observedRetention: 0.90
            )
        )

        XCTAssertEqual(output.easyVelocityEWMA, 0.50, accuracy: 0.0001)
        XCTAssertEqual(output.retentionEWMA, 0.675, accuracy: 0.0001)
    }

    func testStrongSignalsPromoteRank() {
        let engine = RankPromotionEngineContract(alpha: 0.25, maxStep: 150)
        let output = engine.apply(
            .init(
                currentRank: 3_000,
                currentEasyVelocity: 0.45,
                currentRetentionEWMA: 0.84,
                observedEasyRatio: 0.95,
                observedRetention: 0.93
            )
        )

        XCTAssertGreaterThan(output.updatedRank, 3_000)
        XCTAssertEqual(output.rankDelta, 20)
    }

    func testWeakSignalsDemoteRank() {
        let engine = RankPromotionEngineContract(alpha: 0.25, maxStep: 150)
        let output = engine.apply(
            .init(
                currentRank: 3_000,
                currentEasyVelocity: 0.60,
                currentRetentionEWMA: 0.85,
                observedEasyRatio: 0.10,
                observedRetention: 0.60
            )
        )

        XCTAssertLessThan(output.updatedRank, 3_000)
        XCTAssertEqual(output.rankDelta, -24)
    }

    func testRankDeltaIsClampedByMaxStep() {
        let engine = RankPromotionEngineContract(alpha: 1.0, maxStep: 100)
        let boosted = engine.apply(
            .init(
                currentRank: 3_000,
                currentEasyVelocity: 0.0,
                currentRetentionEWMA: 0.0,
                observedEasyRatio: 1.0,
                observedRetention: 1.0
            )
        )
        let reduced = engine.apply(
            .init(
                currentRank: 3_000,
                currentEasyVelocity: 1.0,
                currentRetentionEWMA: 1.0,
                observedEasyRatio: 0.0,
                observedRetention: 0.0
            )
        )

        XCTAssertEqual(boosted.rankDelta, 100)
        XCTAssertEqual(reduced.rankDelta, -100)
    }
}

private struct RankPromotionEngineContract {
    struct Input {
        let currentRank: Int
        let currentEasyVelocity: Double
        let currentRetentionEWMA: Double
        let observedEasyRatio: Double
        let observedRetention: Double
    }

    struct Output {
        let updatedRank: Int
        let easyVelocityEWMA: Double
        let retentionEWMA: Double
        let rankDelta: Int
    }

    let alpha: Double
    let retentionTarget: Double
    let maxStep: Int
    let minRank: Int
    let maxRank: Int

    init(
        alpha: Double = 0.25,
        retentionTarget: Double = 0.85,
        maxStep: Int = 150,
        minRank: Int = 500,
        maxRank: Int = 20_000
    ) {
        self.alpha = alpha
        self.retentionTarget = retentionTarget
        self.maxStep = maxStep
        self.minRank = minRank
        self.maxRank = maxRank
    }

    func apply(_ input: Input) -> Output {
        let observedEasy = clampUnit(input.observedEasyRatio)
        let observedRetention = clampUnit(input.observedRetention)

        let easyVelocityEWMA = (alpha * observedEasy) + ((1 - alpha) * clampUnit(input.currentEasyVelocity))
        let retentionEWMA = (alpha * observedRetention) + ((1 - alpha) * clampUnit(input.currentRetentionEWMA))

        let easySignal = (easyVelocityEWMA - 0.5) * 2.0
        let retentionSignal = (retentionEWMA - retentionTarget) / max(0.0001, (1.0 - retentionTarget))
        let blendedSignal = (0.7 * easySignal) + (0.3 * retentionSignal)

        let unclampedDelta = Int((Double(maxStep) * blendedSignal).rounded())
        let rankDelta = min(maxStep, max(-maxStep, unclampedDelta))
        let updatedRank = min(maxRank, max(minRank, input.currentRank + rankDelta))

        return Output(
            updatedRank: updatedRank,
            easyVelocityEWMA: easyVelocityEWMA,
            retentionEWMA: retentionEWMA,
            rankDelta: rankDelta
        )
    }

    private func clampUnit(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}
