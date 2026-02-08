import Foundation
import SwiftData

public struct WarmStartLexeme {
    public let lemma: String
    public let rank: Int

    public init(lemma: String, rank: Int) {
        self.lemma = lemma
        self.rank = rank
    }
}

public struct WarmStartSummary {
    public let inserted: Int
    public let knownInitialized: Int
    public let targetInitialized: Int
    public let syntheticReviewsInserted: Int
}

/// Converts calibration output into first-pass lexical state before regular review loops.
public struct CalibrationWarmStartService {
    public let knownOffset: Int
    public let targetLowerOffset: Int
    public let targetUpperOffset: Int

    public init(
        knownOffset: Int = 500,
        targetLowerOffset: Int = 250,
        targetUpperOffset: Int = 600
    ) {
        self.knownOffset = knownOffset
        self.targetLowerOffset = targetLowerOffset
        self.targetUpperOffset = targetUpperOffset
    }

    @MainActor
    public func apply(
        lexicalRank: Int,
        rankedLexemes: [WarmStartLexeme],
        modelContext: ModelContext
    ) throws -> WarmStartSummary {
        let normalizedLexemes = rankedLexemes.map { lexeme in
            WarmStartLexeme(lemma: lexeme.lemma.lowercased(), rank: lexeme.rank)
        }

        let knownCutoff = lexicalRank - knownOffset
        let targetRange = (lexicalRank - targetLowerOffset)...(lexicalRank + targetUpperOffset)
        let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let activeUserId = activeProfile.userId

        let existingStates = try modelContext.fetch(FetchDescriptor<UserWordState>())
        var stateByKey: [String: UserWordState] = [:]
        for state in existingStates where state.userId == activeUserId {
            stateByKey[state.userLemmaKey] = state
        }

        var inserted = 0
        var knownInitialized = 0
        var targetInitialized = 0
        var syntheticReviewsInserted = 0

        for lexeme in normalizedLexemes {
            let userLemmaKey = UserWordState.makeKey(userId: activeUserId, lemma: lexeme.lemma)
            let state: UserWordState
            if let existingState = stateByKey[userLemmaKey] {
                state = existingState
            } else {
                state = UserWordState(userId: activeUserId, lemma: lexeme.lemma)
                modelContext.insert(state)
                stateByKey[userLemmaKey] = state
                inserted += 1
            }

            // Avoid overriding words already in active learning history.
            let hasHistory = state.reviewCount > 0
            if hasHistory { continue }

            if lexeme.rank <= knownCutoff {
                let difficulty = rankToDifficulty(lexeme.rank)
                let now = Date()

                state.stability = 365.0
                state.difficulty = difficulty
                state.retrievability = 1.0
                state.reviewCount = 1
                state.lastReviewDate = now
                state.nextReviewDate = now.addingTimeInterval(180 * 24 * 60 * 60)
                state.status = .known
                state.touch()

                let syntheticEvent = ReviewEvent(
                    userId: activeUserId,
                    lemma: state.lemma,
                    grade: 4,
                    durationMs: 0,
                    scheduledDays: 180,
                    reviewState: ReviewEvent.reviewState(for: 4)
                )
                modelContext.insert(syntheticEvent)
                knownInitialized += 1
                syntheticReviewsInserted += 1
                continue
            }

            if targetRange.contains(lexeme.rank) {
                state.stability = max(0.2, state.stability)
                state.difficulty = rankToDifficulty(lexeme.rank)
                state.retrievability = max(0.25, state.retrievability)
                state.nextReviewDate = Date()
                state.status = .learning
                state.touch()
                targetInitialized += 1
            }
        }

        try modelContext.save()

        return WarmStartSummary(
            inserted: inserted,
            knownInitialized: knownInitialized,
            targetInitialized: targetInitialized,
            syntheticReviewsInserted: syntheticReviewsInserted
        )
    }

    private func rankToDifficulty(_ rank: Int) -> Double {
        // Mirrors seed-system convention while keeping bounds in [1, 10].
        let difficulty = 2.0 + (Double(rank) / 60_000.0) * 8.0
        return min(10.0, max(1.0, difficulty))
    }
}
