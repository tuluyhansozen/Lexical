import XCTest
@testable import LexicalCore

final class FSRSPersonalizationServiceTests: XCTestCase {
    func testReturnsNilForFreeTierWithRichSignals() {
        let service = FSRSPersonalizationService()
        let now = Date(timeIntervalSince1970: 1_705_300_000)
        let signals = makeSignals(count: 160, start: now.addingTimeInterval(-40 * 86_400))

        let weights = service.personalizedWeights(
            subscriptionTierRawValue: SubscriptionTier.free.rawValue,
            entitlementExpiresAt: nil,
            fsrsRequestRetention: 0.9,
            lexicalRank: 7_000,
            easyRatingVelocity: 0.7,
            signals: signals,
            now: now
        )

        XCTAssertNil(weights)
    }

    func testReturnsNilWhenPremiumHistoryIsSparse() {
        let service = FSRSPersonalizationService()
        let now = Date(timeIntervalSince1970: 1_705_300_000)
        let sparseSignals = makeSignals(count: 24, start: now.addingTimeInterval(-6 * 86_400))

        let weights = service.personalizedWeights(
            subscriptionTierRawValue: SubscriptionTier.premium.rawValue,
            entitlementExpiresAt: nil,
            fsrsRequestRetention: 0.93,
            lexicalRank: 8_200,
            easyRatingVelocity: 0.75,
            signals: sparseSignals,
            now: now
        )

        XCTAssertNil(weights)
    }

    func testReturnsPersonalizedWeightsForPremiumWithSufficientHistory() {
        let service = FSRSPersonalizationService()
        let now = Date(timeIntervalSince1970: 1_705_300_000)
        let signals = makeSignals(count: 220, start: now.addingTimeInterval(-70 * 86_400))

        let weights = service.personalizedWeights(
            subscriptionTierRawValue: SubscriptionTier.premium.rawValue,
            entitlementExpiresAt: nil,
            fsrsRequestRetention: 0.93,
            lexicalRank: 8_500,
            easyRatingVelocity: 0.72,
            signals: signals,
            now: now
        )

        XCTAssertNotNil(weights)
        guard let weights else { return XCTFail("Expected personalized weights") }
        XCTAssertEqual(weights.count, FSRSV4Engine.defaultWeights.count)
        XCTAssertNotEqual(weights, FSRSV4Engine.defaultWeights)
    }

    func testExpiredEntitlementFallsBackToFreeBehavior() {
        let service = FSRSPersonalizationService()
        let now = Date(timeIntervalSince1970: 1_705_300_000)
        let signals = makeSignals(count: 200, start: now.addingTimeInterval(-80 * 86_400))

        let weights = service.personalizedWeights(
            subscriptionTierRawValue: SubscriptionTier.premium.rawValue,
            entitlementExpiresAt: now.addingTimeInterval(-10),
            fsrsRequestRetention: 0.94,
            lexicalRank: 9_100,
            easyRatingVelocity: 0.8,
            signals: signals,
            now: now
        )

        XCTAssertNil(weights)
    }

    private func makeSignals(count: Int, start: Date) -> [FSRSPersonalizationSignal] {
        var signals: [FSRSPersonalizationSignal] = []
        signals.reserveCapacity(count)

        for index in 0..<count {
            let grade: Int
            switch index % 10 {
            case 0: grade = 1
            case 1, 2: grade = 2
            case 3, 4, 5, 6: grade = 3
            default: grade = 4
            }

            let reviewState = ReviewEvent.reviewState(for: grade)
            let reviewDate = start.addingTimeInterval(TimeInterval(index) * 86_400 / 3)
            let lemma = "lemma-\(index % 40)"

            signals.append(
                FSRSPersonalizationSignal(
                    grade: grade,
                    reviewState: reviewState,
                    reviewDate: reviewDate,
                    lemma: lemma
                )
            )
        }

        return signals
    }
}
