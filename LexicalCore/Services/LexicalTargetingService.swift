import Foundation
import SwiftData

public struct LexicalTargetCandidate: Sendable {
    public let lemma: String
    public let rank: Int?
    public let definition: String?
    public let contextSentence: String?

    public init(lemma: String, rank: Int?, definition: String?, contextSentence: String?) {
        self.lemma = lemma
        self.rank = rank
        self.definition = definition
        self.contextSentence = contextSentence
    }
}

public struct ArticleWordPlan: Sendable {
    public let reinforcementWords: [String]
    public let stretchWords: [String]

    public var allWords: [String] {
        reinforcementWords + stretchWords
    }

    public init(reinforcementWords: [String], stretchWords: [String]) {
        self.reinforcementWords = reinforcementWords
        self.stretchWords = stretchWords
    }
}

@MainActor
public struct LexicalTargetingService {
    private let calibrationEngine: LexicalCalibrationEngine

    public init(calibrationEngine: LexicalCalibrationEngine = .init()) {
        self.calibrationEngine = calibrationEngine
    }

    public func proximalRange(for profile: UserProfile) -> ClosedRange<Int> {
        calibrationEngine.proximalRange(for: profile.lexicalRank)
    }

    public func articleTargets(
        modelContext: ModelContext,
        maxCount: Int = 6
    ) -> [String] {
        let plan = articleWordPlan(
            modelContext: modelContext,
            reinforcementCount: max(1, maxCount - 1),
            stretchCount: 1
        )
        return Array(plan.allWords.prefix(maxCount))
    }

    public func articleWordPlan(
        modelContext: ModelContext,
        reinforcementCount: Int,
        stretchCount: Int
    ) -> ArticleWordPlan {
        let reinforcementLemmas = rankedCandidates(
            modelContext: modelContext,
            limit: max(0, reinforcementCount)
        )
        .map(\.lemma)

        let stretchLemmas = stretchCandidates(
            modelContext: modelContext,
            excludedLemmas: Set(reinforcementLemmas),
            limit: max(0, stretchCount)
        )

        return ArticleWordPlan(
            reinforcementWords: reinforcementLemmas,
            stretchWords: stretchLemmas
        )
    }

    public func notificationCandidate(modelContext: ModelContext) -> LexicalTargetCandidate? {
        rankedCandidates(modelContext: modelContext, limit: 1).first
    }

    public func newWordSuggestionCandidates(
        modelContext: ModelContext,
        limit: Int,
        excludedLemmas: Set<String> = []
    ) -> [LexicalTargetCandidate] {
        guard limit > 0 else { return [] }

        let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let ignored = Set(activeProfile.ignoredWords.map { $0.lowercased() })
        let normalizedExcluded = Set(excludedLemmas.map(normalizeLemma))
        let targetRange = proximalRange(for: activeProfile)

        let states = (try? modelContext.fetch(FetchDescriptor<UserWordState>())) ?? []
        let userStates = states.filter { $0.userId == activeProfile.userId }
        let trackedLemmas = Set(userStates.map(\.lemma))
        let newStateLemmas = Set(
            userStates
                .filter { $0.status == .new }
                .map(\.lemma)
        )

        let lexemes = (try? modelContext.fetch(FetchDescriptor<LexemeDefinition>())) ?? []
        var lexemeByLemma: [String: LexemeDefinition] = [:]
        lexemeByLemma.reserveCapacity(lexemes.count)
        for lexeme in lexemes {
            lexemeByLemma[lexeme.lemma] = lexeme
        }

        struct ScoredCandidate {
            let candidate: LexicalTargetCandidate
            let isInRange: Bool
            let poolPriority: Int
            let distanceScore: Int
        }

        func distanceScore(for rank: Int?) -> Int {
            guard let rank else { return Int.max / 2 }
            return abs(rank - activeProfile.lexicalRank)
        }

        func scoredCandidate(
            lemma: String,
            lexeme: LexemeDefinition,
            poolPriority: Int
        ) -> ScoredCandidate? {
            guard !ignored.contains(lemma) else { return nil }
            guard !normalizedExcluded.contains(lemma) else { return nil }
            guard isPromptEligibleLexeme(
                lemma: lemma,
                rank: lexeme.rank,
                definition: lexeme.basicMeaning
            ) else { return nil }

            let rank = lexeme.rank
            let candidate = LexicalTargetCandidate(
                lemma: lemma,
                rank: rank,
                definition: lexeme.basicMeaning,
                contextSentence: lexeme.sampleSentence
            )

            return ScoredCandidate(
                candidate: candidate,
                isInRange: rank.map { targetRange.contains($0) } ?? false,
                poolPriority: poolPriority,
                distanceScore: distanceScore(for: rank)
            )
        }

        var scored: [ScoredCandidate] = []
        scored.reserveCapacity(newStateLemmas.count + lexemes.count)

        for lemma in newStateLemmas.sorted() {
            guard let lexeme = lexemeByLemma[lemma] else { continue }
            if let candidate = scoredCandidate(lemma: lemma, lexeme: lexeme, poolPriority: 0) {
                scored.append(candidate)
            }
        }

        for lexeme in lexemes where !trackedLemmas.contains(lexeme.lemma) {
            if let candidate = scoredCandidate(lemma: lexeme.lemma, lexeme: lexeme, poolPriority: 1) {
                scored.append(candidate)
            }
        }

        scored.sort { lhs, rhs in
            if lhs.isInRange != rhs.isInRange { return lhs.isInRange && !rhs.isInRange }
            if lhs.poolPriority != rhs.poolPriority { return lhs.poolPriority < rhs.poolPriority }
            if lhs.distanceScore != rhs.distanceScore { return lhs.distanceScore < rhs.distanceScore }
            return lhs.candidate.lemma < rhs.candidate.lemma
        }

        var results: [LexicalTargetCandidate] = []
        var seen = Set<String>()
        results.reserveCapacity(limit)

        for entry in scored {
            let lemma = entry.candidate.lemma
            guard !seen.contains(lemma) else { continue }
            results.append(entry.candidate)
            seen.insert(lemma)
            if results.count >= limit {
                break
            }
        }

        return results
    }

    private func rankedCandidates(
        modelContext: ModelContext,
        limit: Int
    ) -> [LexicalTargetCandidate] {
        guard limit > 0 else { return [] }

        let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let ignored = Set(activeProfile.ignoredWords.map { $0.lowercased() })
        let targetRange = proximalRange(for: activeProfile)
        let now = Date()

        let states = (try? modelContext.fetch(FetchDescriptor<UserWordState>())) ?? []
        let userStates = states.filter { state in
            state.userId == activeProfile.userId &&
            state.status != .ignored &&
            !ignored.contains(state.lemma)
        }

        let lexemes = (try? modelContext.fetch(FetchDescriptor<LexemeDefinition>())) ?? []
        var lexemeByLemma: [String: LexemeDefinition] = [:]
        lexemeByLemma.reserveCapacity(lexemes.count)
        for lexeme in lexemes {
            lexemeByLemma[lexeme.lemma] = lexeme
        }

        struct ScoredCandidate {
            let lemma: String
            let rank: Int?
            let isDue: Bool
            let statusPriority: Int
            let distanceScore: Int
            let definition: String?
            let contextSentence: String?
        }

        func distanceScore(for rank: Int?) -> Int {
            guard let rank else { return Int.max / 2 }
            return abs(rank - activeProfile.lexicalRank)
        }

        func statusPriority(for status: UserWordStatus) -> Int {
            switch status {
            case .learning: return 3
            case .new: return 2
            case .known: return 1
            case .ignored: return 0
            }
        }

        var scored: [ScoredCandidate] = []
        scored.reserveCapacity(userStates.count)

        for state in userStates {
            let lemma = state.lemma
            guard let lexeme = lexemeByLemma[lemma] else { continue }
            let rank = lexeme.rank
            let definition = lexeme.basicMeaning
            guard isPromptEligibleLexeme(lemma: lemma, rank: rank, definition: definition) else { continue }
            guard let rank, targetRange.contains(rank) else { continue }

            let isDue = (state.nextReviewDate ?? now) <= now
            let context = lexeme.sampleSentence

            scored.append(
                ScoredCandidate(
                    lemma: lemma,
                    rank: rank,
                    isDue: isDue,
                    statusPriority: statusPriority(for: state.status),
                    distanceScore: distanceScore(for: rank),
                    definition: definition,
                    contextSentence: context
                )
            )
        }

        scored.sort { lhs, rhs in
            if lhs.isDue != rhs.isDue { return lhs.isDue && !rhs.isDue }
            if lhs.statusPriority != rhs.statusPriority { return lhs.statusPriority > rhs.statusPriority }
            if lhs.distanceScore != rhs.distanceScore { return lhs.distanceScore < rhs.distanceScore }
            return lhs.lemma < rhs.lemma
        }

        var results: [LexicalTargetCandidate] = []
        var seen = Set<String>()

        for candidate in scored {
            guard !seen.contains(candidate.lemma) else { continue }
            results.append(
                LexicalTargetCandidate(
                    lemma: candidate.lemma,
                    rank: candidate.rank,
                    definition: candidate.definition,
                    contextSentence: candidate.contextSentence
                )
            )
            seen.insert(candidate.lemma)
            if results.count >= limit {
                return results
            }
        }

        let eligibleFallbackLexemes = lexemes
            .filter { lexeme in
                guard isPromptEligibleLexeme(
                    lemma: lexeme.lemma,
                    rank: lexeme.rank,
                    definition: lexeme.basicMeaning
                ) else { return false }
                return !ignored.contains(lexeme.lemma) && !seen.contains(lexeme.lemma)
            }

        let inRangeFallback = eligibleFallbackLexemes
            .filter { lexeme in
                guard let rank = lexeme.rank else { return false }
                return targetRange.contains(rank)
            }
            .sorted { lhs, rhs in
                let lhsDistance = distanceScore(for: lhs.rank)
                let rhsDistance = distanceScore(for: rhs.rank)
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
                return lhs.lemma < rhs.lemma
            }

        for lexeme in inRangeFallback {
            results.append(
                LexicalTargetCandidate(
                    lemma: lexeme.lemma,
                    rank: lexeme.rank,
                    definition: lexeme.basicMeaning,
                    contextSentence: lexeme.sampleSentence
                )
            )
            if results.count >= limit {
                return results
            }
        }

        let outOfRangeFallback = eligibleFallbackLexemes
            .filter { lexeme in
                guard let rank = lexeme.rank else { return false }
                return !targetRange.contains(rank)
            }
            .sorted { lhs, rhs in
                let lhsDistance = distanceScore(for: lhs.rank)
                let rhsDistance = distanceScore(for: rhs.rank)
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
                return lhs.lemma < rhs.lemma
            }

        for lexeme in outOfRangeFallback {
            results.append(
                LexicalTargetCandidate(
                    lemma: lexeme.lemma,
                    rank: lexeme.rank,
                    definition: lexeme.basicMeaning,
                    contextSentence: lexeme.sampleSentence
                )
            )
            if results.count >= limit {
                break
            }
        }

        return results
    }

    private func stretchCandidates(
        modelContext: ModelContext,
        excludedLemmas: Set<String>,
        limit: Int
    ) -> [String] {
        guard limit > 0 else { return [] }

        let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let ignored = Set(activeProfile.ignoredWords.map { $0.lowercased() })
        let targetRange = proximalRange(for: activeProfile)

        let states = (try? modelContext.fetch(FetchDescriptor<UserWordState>())) ?? []
        let tracked = Set(
            states
                .filter { $0.userId == activeProfile.userId }
                .map(\.lemma)
        )

        let lexemes = (try? modelContext.fetch(FetchDescriptor<LexemeDefinition>())) ?? []
        let upper = targetRange.upperBound
        let stretchUpperBound = upper + 1_500

        let scored = lexemes
            .compactMap { lexeme -> (lemma: String, distance: Int)? in
                guard isPromptEligibleLexeme(
                    lemma: lexeme.lemma,
                    rank: lexeme.rank,
                    definition: lexeme.basicMeaning
                ) else { return nil }
                guard let rank = lexeme.rank else { return nil }
                guard rank > upper, rank <= stretchUpperBound else { return nil }
                guard !tracked.contains(lexeme.lemma) else { return nil }
                guard !ignored.contains(lexeme.lemma) else { return nil }
                guard !excludedLemmas.contains(lexeme.lemma) else { return nil }
                return (lexeme.lemma, rank - upper)
            }
            .sorted { lhs, rhs in
                if lhs.distance != rhs.distance {
                    return lhs.distance < rhs.distance
                }
                return lhs.lemma < rhs.lemma
            }

        return scored.prefix(limit).map(\.lemma)
    }

    private func isPromptEligibleLexeme(
        lemma: String,
        rank: Int?,
        definition: String?
    ) -> Bool {
        guard let rank else { return false }
        guard (calibrationEngine.minRank...calibrationEngine.maxRank).contains(rank) else { return false }

        let normalizedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedLemma.isEmpty else { return false }
        guard normalizedLemma.range(of: "^[a-z][a-z-]*$", options: .regularExpression) != nil else {
            return false
        }

        let normalizedDefinition = definition?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !normalizedDefinition.isEmpty
    }

    private func normalizeLemma(_ lemma: String) -> String {
        lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
