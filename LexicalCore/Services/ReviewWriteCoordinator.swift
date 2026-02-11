import Foundation
import SwiftData

public enum ReviewWriteCoordinatorError: LocalizedError {
    case invalidGrade(Int)
    case emptyLemma

    public var errorDescription: String? {
        switch self {
        case .invalidGrade(let grade):
            return "Grade must be between 1 and 4. Received \(grade)."
        case .emptyLemma:
            return "Lemma must not be empty."
        }
    }
}

private struct ExplicitTransition {
    let stability: Double
    let difficulty: Double
    let retrievability: Double
    let intervalDays: Double
}

public struct ReviewWriteCoordinator {
    private static let implicitExposureReviewState = "implicit_exposure"

    private let promotionEngine: RankPromotionEngine
    private let fsrsEngine: FSRSV4Engine
    private let featureGateService: FeatureGateService
    private let calendar: Calendar

    public init(
        promotionEngine: RankPromotionEngine = .init(),
        fsrsEngine: FSRSV4Engine = .init(),
        featureGateService: FeatureGateService = .init(),
        calendar: Calendar = .current
    ) {
        self.promotionEngine = promotionEngine
        self.fsrsEngine = fsrsEngine
        self.featureGateService = featureGateService
        self.calendar = calendar
    }

    @MainActor
    public func recordExplicitReview(
        grade: Int,
        lemma: String,
        durationMs: Int,
        modelContext: ModelContext
    ) async throws -> RankPromotionDecision? {
        try await recordExplicitReview(
            grade: grade,
            lemma: lemma,
            durationMs: durationMs,
            modelContext: modelContext,
            now: Date()
        )
    }

    @MainActor
    public func recordExplicitReview(
        grade: Int,
        lemma: String,
        durationMs: Int,
        modelContext: ModelContext,
        now: Date
    ) async throws -> RankPromotionDecision? {
        guard (1...4).contains(grade) else {
            throw ReviewWriteCoordinatorError.invalidGrade(grade)
        }

        let normalizedLemma = normalizeLemma(lemma)
        guard !normalizedLemma.isEmpty else {
            throw ReviewWriteCoordinatorError.emptyLemma
        }

        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let userId = profile.userId
        let state = try resolveState(userId: userId, lemma: normalizedLemma, modelContext: modelContext)
        let requestRetention = featureGateService.fsrsRequestRetention(for: profile)
        let transition = await explicitTransition(
            grade: grade,
            state: state,
            now: now,
            requestRetention: requestRetention
        )

        let explicitEvent = ReviewEvent(
            userId: userId,
            lemma: normalizedLemma,
            grade: grade,
            reviewDate: now,
            durationMs: max(durationMs, 0),
            scheduledDays: transition.intervalDays,
            reviewState: ReviewEvent.reviewState(for: grade),
            deviceId: nil,
            sourceReviewLogId: nil
        )
        modelContext.insert(explicitEvent)

        applyExplicitTransition(transition, to: state, grade: grade, reviewDate: now)
        try modelContext.save()

        return try promotionEngine.evaluateAndApply(
            modelContext: modelContext,
            userId: userId,
            now: now
        )
    }

    @MainActor
    public static func submitExplicitReview(
        grade: Int,
        lemma: String,
        durationMs: Int = 0,
        modelContext: ModelContext
    ) async throws -> RankPromotionDecision? {
        try await submitExplicitReview(
            grade: grade,
            lemma: lemma,
            durationMs: durationMs,
            modelContext: modelContext,
            coordinator: .init()
        )
    }

    @MainActor
    public static func submitExplicitReview(
        grade: Int,
        lemma: String,
        durationMs: Int = 0,
        modelContext: ModelContext,
        coordinator: ReviewWriteCoordinator
    ) async throws -> RankPromotionDecision? {
        try await coordinator.recordExplicitReview(
            grade: grade,
            lemma: lemma,
            durationMs: durationMs,
            modelContext: modelContext
        )
    }

    @MainActor
    public func recordImplicitExposure(
        lemma: String,
        modelContext: ModelContext
    ) throws -> Bool {
        try recordImplicitExposure(lemma: lemma, modelContext: modelContext, now: Date())
    }

    @MainActor
    public func recordImplicitExposure(
        lemma: String,
        modelContext: ModelContext,
        now: Date
    ) throws -> Bool {
        let normalizedLemma = normalizeLemma(lemma)
        guard !normalizedLemma.isEmpty else {
            throw ReviewWriteCoordinatorError.emptyLemma
        }

        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let userId = profile.userId
        let implicitReviewState = Self.implicitExposureReviewState

        let predicate = #Predicate<ReviewEvent> { event in
            event.userId == userId &&
            event.lemma == normalizedLemma &&
            event.reviewState == implicitReviewState
        }
        let sortBy = [SortDescriptor(\ReviewEvent.reviewDate, order: .reverse)]
        let descriptor = FetchDescriptor<ReviewEvent>(predicate: predicate, sortBy: sortBy)
        let existingExposures = try modelContext.fetch(descriptor)

        let alreadyRecordedToday = existingExposures.contains { event in
            calendar.isDate(event.reviewDate, inSameDayAs: now)
        }
        if alreadyRecordedToday {
            return false
        }

        let exposureEvent = ReviewEvent(
            userId: userId,
            lemma: normalizedLemma,
            grade: 3,
            reviewDate: now,
            durationMs: 250,
            scheduledDays: 0.2,
            reviewState: Self.implicitExposureReviewState,
            deviceId: nil,
            sourceReviewLogId: nil
        )
        modelContext.insert(exposureEvent)
        try modelContext.save()
        return true
    }

    @MainActor
    public static func submitImplicitExposure(
        lemma: String,
        modelContext: ModelContext
    ) throws -> Bool {
        try submitImplicitExposure(lemma: lemma, modelContext: modelContext, coordinator: .init())
    }

    @MainActor
    public static func submitImplicitExposure(
        lemma: String,
        modelContext: ModelContext,
        coordinator: ReviewWriteCoordinator
    ) throws -> Bool {
        try coordinator.recordImplicitExposure(lemma: lemma, modelContext: modelContext)
    }

    @MainActor
    public func recordSessionAttempt(
        grade: Int,
        lemma: String,
        durationMs: Int,
        scheduledDays: Double,
        modelContext: ModelContext
    ) throws {
        guard (1...4).contains(grade) else {
            throw ReviewWriteCoordinatorError.invalidGrade(grade)
        }

        let normalizedLemma = normalizeLemma(lemma)
        guard !normalizedLemma.isEmpty else {
            throw ReviewWriteCoordinatorError.emptyLemma
        }

        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)

        let event = ReviewEvent(
            userId: profile.userId,
            lemma: normalizedLemma,
            grade: grade,
            reviewDate: Date(),
            durationMs: max(durationMs, 0),
            scheduledDays: max(0.0, scheduledDays),
            reviewState: ReviewEvent.reviewState(for: grade),
            deviceId: nil,
            sourceReviewLogId: nil
        )
        modelContext.insert(event)
        try modelContext.save()
    }

    @MainActor
    public static func submitSessionAttempt(
        grade: Int,
        lemma: String,
        durationMs: Int = 0,
        scheduledDays: Double,
        modelContext: ModelContext
    ) throws {
        try submitSessionAttempt(
            grade: grade,
            lemma: lemma,
            durationMs: durationMs,
            scheduledDays: scheduledDays,
            modelContext: modelContext,
            coordinator: .init()
        )
    }

    @MainActor
    public static func submitSessionAttempt(
        grade: Int,
        lemma: String,
        durationMs: Int = 0,
        scheduledDays: Double,
        modelContext: ModelContext,
        coordinator: ReviewWriteCoordinator
    ) throws {
        try coordinator.recordSessionAttempt(
            grade: grade,
            lemma: lemma,
            durationMs: durationMs,
            scheduledDays: scheduledDays,
            modelContext: modelContext
        )
    }

    private func normalizeLemma(_ lemma: String) -> String {
        lemma
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func resolveState(
        userId: String,
        lemma: String,
        modelContext: ModelContext
    ) throws -> UserWordState {
        let key = UserWordState.makeKey(userId: userId, lemma: lemma)
        let descriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { state in
                state.userLemmaKey == key
            }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let state = UserWordState(userId: userId, lemma: lemma)
        modelContext.insert(state)
        return state
    }

    private func explicitTransition(
        grade: Int,
        state: UserWordState,
        now: Date,
        requestRetention: Double
    ) async -> ExplicitTransition {
        let baseDate = state.lastReviewDate ?? state.createdAt
        let daysElapsed = max(0.1, now.timeIntervalSince(baseDate) / 86_400.0)
        let currentStability = max(state.stability, 0.1)
        let currentDifficulty = max(state.difficulty, 0.3)

        let fsrsState = await fsrsEngine.nextState(
            currentStability: currentStability,
            currentDifficulty: currentDifficulty,
            recalled: grade >= 3,
            grade: grade,
            daysElapsed: daysElapsed
        )

        let stability = max(fsrsState.stability, 0.1)
        let intervalDays = max(
            await fsrsEngine.nextInterval(
                stability: stability,
                requestRetention: max(0.8, min(0.98, requestRetention))
            ),
            0.1
        )

        return ExplicitTransition(
            stability: stability,
            difficulty: fsrsState.difficulty,
            retrievability: fsrsState.retrievability,
            intervalDays: intervalDays
        )
    }

    private func applyExplicitTransition(
        _ transition: ExplicitTransition,
        to state: UserWordState,
        grade: Int,
        reviewDate: Date
    ) {
        state.stability = transition.stability
        state.difficulty = transition.difficulty
        state.retrievability = transition.retrievability
        state.lastReviewDate = reviewDate
        state.nextReviewDate = reviewDate.addingTimeInterval(transition.intervalDays * 86_400.0)
        state.reviewCount += 1

        if grade == 1 {
            state.lapseCount += 1
        }

        state.status = statusFor(stability: state.stability, reviewCount: state.reviewCount)
        state.touch()
    }

    private func statusFor(stability: Double, reviewCount: Int) -> UserWordStatus {
        if stability >= 90.0 {
            return .known
        }
        if reviewCount > 0 {
            return .learning
        }
        return .new
    }
}
