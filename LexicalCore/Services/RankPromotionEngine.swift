import Foundation
import SwiftData

public struct RankPromotionDecision {
    public let previousRank: Int
    public let updatedRank: Int
    public let easyVelocity: Double
    public let retentionRate: Double
    public let hardAgainRate: Double
    public let sampleCount: Int
    public let appliedDelta: Int
    public let reason: String

    public init(
        previousRank: Int,
        updatedRank: Int,
        easyVelocity: Double,
        retentionRate: Double,
        hardAgainRate: Double,
        sampleCount: Int,
        appliedDelta: Int,
        reason: String
    ) {
        self.previousRank = previousRank
        self.updatedRank = updatedRank
        self.easyVelocity = easyVelocity
        self.retentionRate = retentionRate
        self.hardAgainRate = hardAgainRate
        self.sampleCount = sampleCount
        self.appliedDelta = appliedDelta
        self.reason = reason
    }
}

public struct RankPromotionEngine {
    private static let implicitExposureState = "implicit_exposure"

    private let calibrationEngine: LexicalCalibrationEngine
    private let rollingWindowSize: Int
    private let minSamples: Int
    private let promotionStep: Int
    private let demotionStep: Int
    private let ewmaAlpha: Double
    private let cooldownHours: Int
    private let implicitExposureWeight: Double

    public init(
        calibrationEngine: LexicalCalibrationEngine = .init(),
        rollingWindowSize: Int = 50,
        minSamples: Int = 20,
        promotionStep: Int = 200,
        demotionStep: Int = 150,
        ewmaAlpha: Double = 0.35,
        cooldownHours: Int = 24,
        implicitExposureWeight: Double = 0.2
    ) {
        self.calibrationEngine = calibrationEngine
        self.rollingWindowSize = rollingWindowSize
        self.minSamples = minSamples
        self.promotionStep = promotionStep
        self.demotionStep = demotionStep
        self.ewmaAlpha = ewmaAlpha
        self.cooldownHours = cooldownHours
        self.implicitExposureWeight = min(1.0, max(0.0, implicitExposureWeight))
    }

    public func currentSignal(
        modelContext: ModelContext,
        userId: String? = nil,
        now: Date = Date()
    ) throws -> RankPromotionDecision? {
        try decisionSnapshot(modelContext: modelContext, userId: userId, now: now)?.decision
    }

    public func evaluateAndApply(
        modelContext: ModelContext,
        userId: String? = nil,
        now: Date = Date()
    ) throws -> RankPromotionDecision? {
        guard let snapshot = try decisionSnapshot(modelContext: modelContext, userId: userId, now: now),
              let decision = snapshot.decision else {
            return nil
        }

        let profile = snapshot.profile
        var profileChanged = false

        if profile.easyRatingVelocity != decision.easyVelocity {
            profile.easyRatingVelocity = decision.easyVelocity
            profileChanged = true
        }

        if decision.appliedDelta != 0 {
            if profile.lexicalRank != decision.updatedRank {
                profile.lexicalRank = decision.updatedRank
                profileChanged = true
            }
            persistLastAdjustmentDate(for: profile.userId, date: now)
        }

        if profileChanged {
            profile.stateUpdatedAt = now
            try modelContext.save()
        }

        return decision
    }

    private func decisionSnapshot(
        modelContext: ModelContext,
        userId: String?,
        now: Date
    ) throws -> (profile: UserProfile, decision: RankPromotionDecision?)? {
        guard let profile = try resolveProfile(modelContext: modelContext, userId: userId) else {
            return nil
        }

        let events = try fetchRecentEvents(modelContext: modelContext, userId: profile.userId)
        let sampleCount = explicitSampleCount(from: events)
        guard sampleCount >= minSamples else {
            return (profile, nil)
        }

        let rates = calculateRates(from: events)
        let easyVelocity = (ewmaAlpha * rates.easyRate) + ((1.0 - ewmaAlpha) * profile.easyRatingVelocity)
        let candidate = candidateDelta(
            retentionRate: rates.retentionRate,
            hardAgainRate: rates.hardAgainRate,
            easyVelocity: easyVelocity
        )

        let previousRank = profile.lexicalRank
        let clampedRank = clamp(previousRank + candidate)
        let clampedDelta = clampedRank - previousRank

        let isCooldownActive: Bool = {
            guard clampedDelta != 0 else { return false }
            return cooldownActive(userId: profile.userId, now: now)
        }()

        let appliedDelta = isCooldownActive ? 0 : clampedDelta
        let updatedRank = isCooldownActive ? previousRank : clampedRank
        let reason = decisionReason(
            candidateDelta: candidate,
            clampedDelta: clampedDelta,
            appliedDelta: appliedDelta,
            isCooldownActive: isCooldownActive
        )

        return (
            profile,
            RankPromotionDecision(
                previousRank: previousRank,
                updatedRank: updatedRank,
                easyVelocity: easyVelocity,
                retentionRate: rates.retentionRate,
                hardAgainRate: rates.hardAgainRate,
                sampleCount: sampleCount,
                appliedDelta: appliedDelta,
                reason: reason
            )
        )
    }

    private func resolveProfile(
        modelContext: ModelContext,
        userId: String?
    ) throws -> UserProfile? {
        if let providedUserId = userId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !providedUserId.isEmpty {
            let descriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { profile in
                    profile.userId == providedUserId
                }
            )
            return try modelContext.fetch(descriptor).first
        }

        return MainActor.assumeIsolated {
            UserProfile.resolveActiveProfile(modelContext: modelContext)
        }
    }

    private func fetchRecentEvents(
        modelContext: ModelContext,
        userId: String
    ) throws -> [ReviewEvent] {
        let predicate = #Predicate<ReviewEvent> { event in
            event.userId == userId
        }
        let sort = SortDescriptor(\ReviewEvent.reviewDate, order: .reverse)
        var descriptor = FetchDescriptor<ReviewEvent>(
            predicate: predicate,
            sortBy: [sort]
        )
        descriptor.fetchLimit = rollingWindowSize
        return try modelContext.fetch(descriptor)
    }

    private func calculateRates(
        from events: [ReviewEvent]
    ) -> (easyRate: Double, retentionRate: Double, hardAgainRate: Double) {
        guard !events.isEmpty else {
            return (0.0, 0.0, 0.0)
        }

        var weightedTotal = 0.0
        var easyCount = 0.0
        var retentionCount = 0.0
        var hardAgainCount = 0.0

        for event in events {
            let weight = weight(for: event)
            weightedTotal += weight
            if event.grade == 4 { easyCount += weight }
            if event.grade >= 3 { retentionCount += weight }
            if event.grade <= 2 { hardAgainCount += weight }
        }

        guard weightedTotal > 0 else {
            return (0.0, 0.0, 0.0)
        }

        return (
            easyRate: easyCount / weightedTotal,
            retentionRate: retentionCount / weightedTotal,
            hardAgainRate: hardAgainCount / weightedTotal
        )
    }

    private func explicitSampleCount(from events: [ReviewEvent]) -> Int {
        events.reduce(into: 0) { count, event in
            if event.reviewState != Self.implicitExposureState {
                count += 1
            }
        }
    }

    private func weight(for event: ReviewEvent) -> Double {
        if event.reviewState == Self.implicitExposureState {
            return implicitExposureWeight
        }
        return 1.0
    }

    private func candidateDelta(
        retentionRate: Double,
        hardAgainRate: Double,
        easyVelocity: Double
    ) -> Int {
        if easyVelocity >= 0.6, retentionRate >= 0.9, hardAgainRate <= 0.2 {
            return promotionStep
        }

        if retentionRate < 0.75 || hardAgainRate > 0.45 {
            return -demotionStep
        }

        return 0
    }

    private func clamp(_ rank: Int) -> Int {
        min(calibrationEngine.maxRank, max(calibrationEngine.minRank, rank))
    }

    private func cooldownActive(userId: String, now: Date) -> Bool {
        guard let lastAdjustment = loadLastAdjustmentDate(for: userId) else {
            return false
        }

        let elapsed = now.timeIntervalSince(lastAdjustment)
        guard elapsed >= 0 else {
            return false
        }

        return elapsed < (Double(cooldownHours) * 3_600.0)
    }

    private func decisionReason(
        candidateDelta: Int,
        clampedDelta: Int,
        appliedDelta: Int,
        isCooldownActive: Bool
    ) -> String {
        if isCooldownActive {
            return "cooldown_active"
        }

        if candidateDelta > 0 {
            if clampedDelta == 0 { return "at_max_rank" }
            if clampedDelta == candidateDelta, appliedDelta > 0 { return "promoted" }
            return "promoted_clamped"
        }

        if candidateDelta < 0 {
            if clampedDelta == 0 { return "at_min_rank" }
            if clampedDelta == candidateDelta, appliedDelta < 0 { return "demoted" }
            return "demoted_clamped"
        }

        return "no_rank_change"
    }

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
    }

    private func adjustmentDefaultsKey(for userId: String) -> String {
        "lexical.rank_promotion.last_adjustment.\(userId)"
    }

    private func loadLastAdjustmentDate(for userId: String) -> Date? {
        defaults().object(forKey: adjustmentDefaultsKey(for: userId)) as? Date
    }

    private func persistLastAdjustmentDate(for userId: String, date: Date) {
        defaults().set(date, forKey: adjustmentDefaultsKey(for: userId))
    }
}
