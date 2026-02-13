import Foundation
import SwiftData

public struct FSRSPersonalizationSignal: Sendable {
    public let grade: Int
    public let reviewState: String
    public let reviewDate: Date
    public let lemma: String

    public init(
        grade: Int,
        reviewState: String,
        reviewDate: Date,
        lemma: String
    ) {
        self.grade = grade
        self.reviewState = reviewState
        self.reviewDate = reviewDate
        self.lemma = lemma
    }
}

public struct FSRSPersonalizationService {
    public static let explicitReviewStates: Set<String> = ["again", "hard", "good", "easy"]
    public static let minimumExplicitReviewCount = 120
    public static let minimumDistinctLemmaCount = 20
    public static let minimumHistorySpanDays = 14.0
    public static let lookbackWindowDays = 180.0
    public static let maxSignals = 2_000

    public init() {}

    @MainActor
    public func personalizedWeights(
        for profile: UserProfile,
        modelContext: ModelContext,
        now: Date = Date()
    ) throws -> [Double]? {
        guard effectiveTier(
            subscriptionTierRawValue: profile.subscriptionTierRawValue,
            entitlementExpiresAt: profile.entitlementExpiresAt,
            now: now
        ) == .premium else {
            return nil
        }

        let userId = profile.userId
        let descriptor = FetchDescriptor<ReviewEvent>(
            predicate: #Predicate { event in
                event.userId == userId
            },
            sortBy: [SortDescriptor(\ReviewEvent.reviewDate, order: .reverse)]
        )
        let events = try modelContext.fetch(descriptor)
        let signals = eventsToSignals(
            events: events,
            now: now,
            maxSignals: Self.maxSignals
        )

        return personalizedWeights(
            subscriptionTierRawValue: profile.subscriptionTierRawValue,
            entitlementExpiresAt: profile.entitlementExpiresAt,
            fsrsRequestRetention: profile.fsrsRequestRetention,
            lexicalRank: profile.lexicalRank,
            easyRatingVelocity: profile.easyRatingVelocity,
            signals: signals,
            now: now
        )
    }

    public func personalizedWeights(
        for profile: SyncUserProfile,
        events: [SyncReviewEvent],
        now: Date = Date()
    ) -> [Double]? {
        let signals = eventsToSignals(
            events: events,
            now: now,
            maxSignals: Self.maxSignals
        )

        return personalizedWeights(
            subscriptionTierRawValue: profile.subscriptionTierRawValue,
            entitlementExpiresAt: profile.entitlementExpiresAt,
            fsrsRequestRetention: profile.fsrsRequestRetention,
            lexicalRank: profile.lexicalRank,
            easyRatingVelocity: profile.easyRatingVelocity,
            signals: signals,
            now: now
        )
    }

    public func personalizedWeights(
        subscriptionTierRawValue: String,
        entitlementExpiresAt: Date?,
        fsrsRequestRetention: Double,
        lexicalRank: Int,
        easyRatingVelocity: Double,
        signals: [FSRSPersonalizationSignal],
        now: Date = Date()
    ) -> [Double]? {
        guard effectiveTier(
            subscriptionTierRawValue: subscriptionTierRawValue,
            entitlementExpiresAt: entitlementExpiresAt,
            now: now
        ) == .premium else {
            return nil
        }

        let explicitSignals = signals.filter { signal in
            Self.explicitReviewStates.contains(signal.reviewState.lowercased()) &&
            (1...4).contains(signal.grade)
        }

        guard explicitSignals.count >= Self.minimumExplicitReviewCount else {
            return nil
        }

        let distinctLemmaCount = Set(explicitSignals.map(\.lemma)).count
        guard distinctLemmaCount >= Self.minimumDistinctLemmaCount else {
            return nil
        }

        let sortedByDate = explicitSignals.sorted(by: { $0.reviewDate < $1.reviewDate })
        guard let firstReviewDate = sortedByDate.first?.reviewDate,
              let lastReviewDate = sortedByDate.last?.reviewDate else {
            return nil
        }

        let historySpanDays = lastReviewDate.timeIntervalSince(firstReviewDate) / 86_400.0
        guard historySpanDays >= Self.minimumHistorySpanDays else {
            return nil
        }

        let total = Double(sortedByDate.count)
        let recallRate = Double(sortedByDate.filter { $0.grade >= 3 }.count) / total
        let againRate = Double(sortedByDate.filter { $0.grade == 1 }.count) / total
        let hardRate = Double(sortedByDate.filter { $0.grade == 2 }.count) / total
        let easyRate = Double(sortedByDate.filter { $0.grade == 4 }.count) / total

        let targetRetention = clamp(fsrsRequestRetention, min: 0.85, max: 0.97)
        let recallBias = normalizedBias(targetRetention - recallRate, baseline: 0.25)
        let lapseBias = normalizedBias(againRate - 0.10, baseline: 0.18)
        let hardBias = normalizedBias(hardRate - 0.20, baseline: 0.20)
        let easyBias = normalizedBias(easyRate - 0.18, baseline: 0.22)

        let velocityFactor = normalizedUnit(clamp(easyRatingVelocity, min: 0, max: 1))
        let rankFactor = normalizedUnit(
            clamp(Double(lexicalRank) / 12_000.0, min: 0, max: 1)
        )

        let reviewConfidence = clamp(total / 400.0, min: 0, max: 1)
        let lemmaConfidence = clamp(Double(distinctLemmaCount) / 120.0, min: 0, max: 1)
        let spanConfidence = clamp(historySpanDays / 90.0, min: 0, max: 1)
        let confidence = clamp(
            (reviewConfidence * 0.50) + (lemmaConfidence * 0.25) + (spanConfidence * 0.25),
            min: 0.2,
            max: 1.0
        )

        let personalizedEasyBias = clamp(
            (easyBias * 0.7) + (velocityFactor * 0.2) + (rankFactor * 0.1),
            min: -1,
            max: 1
        )

        let base = FSRSV4Engine.defaultWeights
        var adjusted = base
        adjusted[9] = scaled(
            base[9],
            delta: (0.14 * recallBias) + (0.06 * hardBias) - (0.05 * personalizedEasyBias),
            confidence: confidence,
            minFactor: 0.80,
            maxFactor: 1.25
        )
        adjusted[10] = scaled(
            base[10],
            delta: (0.16 * recallBias) + (0.05 * hardBias),
            confidence: confidence,
            minFactor: 0.82,
            maxFactor: 1.30
        )
        adjusted[11] = scaled(
            base[11],
            delta: (-0.12 * lapseBias) + (0.05 * personalizedEasyBias),
            confidence: confidence,
            minFactor: 0.75,
            maxFactor: 1.20
        )
        adjusted[12] = scaled(
            base[12],
            delta: (0.10 * lapseBias) + (0.04 * hardBias),
            confidence: confidence,
            minFactor: 0.80,
            maxFactor: 1.25
        )
        adjusted[13] = scaled(
            base[13],
            delta: (0.18 * personalizedEasyBias) - (0.12 * hardBias) - (0.08 * lapseBias),
            confidence: confidence,
            minFactor: 0.70,
            maxFactor: 1.35
        )
        adjusted[14] = scaled(
            base[14],
            delta: (0.10 * lapseBias) + (0.06 * recallBias),
            confidence: confidence,
            minFactor: 0.80,
            maxFactor: 1.30
        )
        adjusted[15] = scaled(
            base[15],
            delta: (0.18 * hardBias) + (0.10 * lapseBias) - (0.06 * personalizedEasyBias),
            confidence: confidence,
            minFactor: 0.75,
            maxFactor: 1.35
        )

        return FSRSV4Engine.resolvedWeights(adjusted)
    }

    private func effectiveTier(
        subscriptionTierRawValue: String,
        entitlementExpiresAt: Date?,
        now: Date
    ) -> SubscriptionTier {
        if let entitlementExpiresAt, entitlementExpiresAt < now {
            return .free
        }
        return SubscriptionTier(rawValue: subscriptionTierRawValue) ?? .free
    }

    private func eventsToSignals(
        events: [ReviewEvent],
        now: Date,
        maxSignals: Int
    ) -> [FSRSPersonalizationSignal] {
        let cutoffDate = now.addingTimeInterval(-(Self.lookbackWindowDays * 86_400.0))
        var signals: [FSRSPersonalizationSignal] = []
        signals.reserveCapacity(min(events.count, maxSignals))

        for event in events {
            if event.reviewDate < cutoffDate {
                break
            }
            signals.append(
                FSRSPersonalizationSignal(
                    grade: event.grade,
                    reviewState: event.reviewState,
                    reviewDate: event.reviewDate,
                    lemma: event.lemma
                )
            )

            if signals.count >= maxSignals {
                break
            }
        }

        return signals
    }

    private func eventsToSignals(
        events: [SyncReviewEvent],
        now: Date,
        maxSignals: Int
    ) -> [FSRSPersonalizationSignal] {
        let cutoffDate = now.addingTimeInterval(-(Self.lookbackWindowDays * 86_400.0))
        var signals: [FSRSPersonalizationSignal] = []
        signals.reserveCapacity(min(events.count, maxSignals))

        for event in events.sorted(by: { $0.reviewDate > $1.reviewDate }) {
            guard event.reviewDate >= cutoffDate else {
                break
            }
            signals.append(
                FSRSPersonalizationSignal(
                    grade: event.grade,
                    reviewState: event.reviewState,
                    reviewDate: event.reviewDate,
                    lemma: event.lemma
                )
            )

            if signals.count >= maxSignals {
                break
            }
        }

        return signals
    }

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }

    private func normalizedUnit(_ unitValue: Double) -> Double {
        clamp((unitValue * 2.0) - 1.0, min: -1.0, max: 1.0)
    }

    private func normalizedBias(_ value: Double, baseline: Double) -> Double {
        guard baseline > 0 else { return 0 }
        return clamp(value / baseline, min: -1, max: 1)
    }

    private func scaled(
        _ base: Double,
        delta: Double,
        confidence: Double,
        minFactor: Double,
        maxFactor: Double
    ) -> Double {
        let boundedDelta = clamp(delta, min: -0.35, max: 0.35) * confidence
        let factor = clamp(1.0 + boundedDelta, min: minFactor, max: maxFactor)
        return base * factor
    }
}
