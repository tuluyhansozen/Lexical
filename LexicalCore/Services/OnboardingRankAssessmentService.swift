import Foundation

public enum OnboardingCalibrationAnswer: String, CaseIterable, Codable, Sendable {
    case know
    case unsure
    case dontKnow

    public var recognitionScore: Double {
        switch self {
        case .know:
            return 1.0
        case .unsure:
            return 0.5
        case .dontKnow:
            return 0.0
        }
    }

    public var recognized: Bool {
        self == .know
    }
}

public struct OnboardingCalibrationQuestion: Identifiable, Hashable, Sendable {
    public let id: String
    public let lemma: String
    public let rank: Int
    public let promptHint: String
    public let isDistractor: Bool

    public init(
        id: String,
        lemma: String,
        rank: Int,
        promptHint: String,
        isDistractor: Bool
    ) {
        self.id = id
        self.lemma = lemma
        self.rank = rank
        self.promptHint = promptHint
        self.isDistractor = isDistractor
    }
}

/// Builds a practical, fixed-size onboarding calibration packet and converts answers into lexical-rank estimates.
public struct OnboardingRankAssessmentService {
    private let calibrationEngine: LexicalCalibrationEngine

    public init(calibrationEngine: LexicalCalibrationEngine = .init()) {
        self.calibrationEngine = calibrationEngine
    }

    public func buildQuestions(
        from lexemes: [LexemeDefinition],
        questionCount: Int = 12
    ) -> [OnboardingCalibrationQuestion] {
        let normalizedCount = max(4, questionCount)
        let distractorCount = min(2, max(1, normalizedCount / 5))
        let realCount = max(2, normalizedCount - distractorCount)

        let realQuestions = buildRealQuestions(from: lexemes, desiredCount: realCount)
        let distractors = buildDistractors(desiredCount: distractorCount)

        // Keep the primary onboarding packet deterministic so simulation and UX remain aligned.
        if normalizedCount == 12, distractorCount == 2, realQuestions.count >= 10, distractors.count == 2 {
            return Array(realQuestions.prefix(10)) + distractors
        }

        return interleave(realQuestions: realQuestions, distractors: distractors)
    }

    public func evaluate(
        questions: [OnboardingCalibrationQuestion],
        answers: [String: OnboardingCalibrationAnswer],
        priorRank: Int? = nil
    ) -> LexicalCalibrationResult? {
        guard !questions.isEmpty else { return nil }

        let responses = questions.compactMap { question -> CalibrationResponse? in
            guard let answer = answers[question.id] else { return nil }
            return CalibrationResponse(
                lemma: question.lemma,
                rank: question.rank,
                recognitionScore: answer.recognitionScore,
                isDistractor: question.isDistractor
            )
        }

        guard responses.count == questions.count else { return nil }
        return calibrationEngine.estimate(from: responses, priorRank: priorRank)
    }

    private func buildRealQuestions(
        from lexemes: [LexemeDefinition],
        desiredCount: Int
    ) -> [OnboardingCalibrationQuestion] {
        let candidatePool = lexemes.compactMap(Candidate.init)
        var candidateByLemma: [String: Candidate] = [:]
        for candidate in candidatePool where candidateByLemma[candidate.lemma] == nil {
            candidateByLemma[candidate.lemma] = candidate
        }
        let targetRanks = makeTargetRanks(count: desiredCount)
        var usedLemmas: Set<String> = []
        var picked: [OnboardingCalibrationQuestion] = []

        picked.reserveCapacity(desiredCount)

        for preferred in preferredRealQuestions where picked.count < desiredCount {
            guard !usedLemmas.contains(preferred.lemma) else { continue }
            let hint = candidateByLemma[preferred.lemma]?.hint ?? preferred.hint
            usedLemmas.insert(preferred.lemma)
            picked.append(
                OnboardingCalibrationQuestion(
                    id: "real.\(preferred.lemma).\(preferred.rank)",
                    lemma: preferred.lemma,
                    rank: preferred.rank,
                    promptHint: hint,
                    isDistractor: false
                )
            )
        }

        for target in targetRanks {
            guard picked.count < desiredCount else { break }
            if let candidate = bestCandidate(
                near: target,
                from: candidatePool,
                usedLemmas: usedLemmas
            ) {
                usedLemmas.insert(candidate.lemma)
                picked.append(
                    OnboardingCalibrationQuestion(
                        id: "real.\(candidate.lemma).\(target)",
                        lemma: candidate.lemma,
                        rank: target,
                        promptHint: candidate.hint,
                        isDistractor: false
                    )
                )
            }
        }

        if picked.count < desiredCount {
            for fallback in fallbackRealQuestions where picked.count < desiredCount {
                guard !usedLemmas.contains(fallback.lemma) else { continue }
                usedLemmas.insert(fallback.lemma)
                picked.append(
                    OnboardingCalibrationQuestion(
                        id: "real.\(fallback.lemma).\(fallback.rank)",
                        lemma: fallback.lemma,
                        rank: fallback.rank,
                        promptHint: fallback.hint,
                        isDistractor: false
                    )
                )
            }
        }

        return Array(picked.prefix(desiredCount))
    }

    private func buildDistractors(desiredCount: Int) -> [OnboardingCalibrationQuestion] {
        guard desiredCount > 0 else { return [] }

        return distractorPool
            .prefix(desiredCount)
            .map { item in
                OnboardingCalibrationQuestion(
                    id: "distractor.\(item.lemma)",
                    lemma: item.lemma,
                    rank: item.rank,
                    promptHint: item.hint,
                    isDistractor: true
                )
            }
    }

    private func interleave(
        realQuestions: [OnboardingCalibrationQuestion],
        distractors: [OnboardingCalibrationQuestion]
    ) -> [OnboardingCalibrationQuestion] {
        guard !realQuestions.isEmpty else { return distractors }
        guard !distractors.isEmpty else { return realQuestions }

        var merged: [OnboardingCalibrationQuestion] = []
        merged.reserveCapacity(realQuestions.count + distractors.count)

        let interval = max(2, realQuestions.count / distractors.count)
        var realIndex = 0
        var distractorIndex = 0

        while realIndex < realQuestions.count {
            merged.append(realQuestions[realIndex])
            realIndex += 1

            if realIndex % interval == 0, distractorIndex < distractors.count {
                merged.append(distractors[distractorIndex])
                distractorIndex += 1
            }
        }

        while distractorIndex < distractors.count {
            merged.append(distractors[distractorIndex])
            distractorIndex += 1
        }

        return merged
    }

    private func makeTargetRanks(count: Int) -> [Int] {
        let anchors = [2_500, 3_800, 7_000, 9_500, 14_500, 16_500, 18_500, 19_800]
        guard count > 0 else { return [] }

        var targets: [Int] = []
        targets.reserveCapacity(count)
        while targets.count < count {
            let anchor = anchors[targets.count % anchors.count]
            targets.append(anchor)
        }

        return Array(targets.prefix(count))
    }

    private func bestCandidate(
        near targetRank: Int,
        from candidates: [Candidate],
        usedLemmas: Set<String>
    ) -> Candidate? {
        candidates
            .lazy
            .filter { !usedLemmas.contains($0.lemma) }
            .min(by: { lhs, rhs in
                candidateScore(lhs, targetRank: targetRank) < candidateScore(rhs, targetRank: targetRank)
            })
    }

    private func candidateScore(_ candidate: Candidate, targetRank: Int) -> Int {
        let distance = abs(candidate.rank - targetRank)
        let hintPenalty = candidate.hint.count < 8 ? 500 : 0
        let lemmaPenalty = candidate.lemma.count < 4 ? 120 : 0
        return distance + hintPenalty + lemmaPenalty
    }
}

private extension OnboardingRankAssessmentService {
    struct Candidate {
        let lemma: String
        let rank: Int
        let hint: String

        init?(lexeme: LexemeDefinition) {
            let lemma = lexeme.lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard lemma.count >= 3 else { return nil }
            guard lemma.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }) else { return nil }
            guard let rank = lexeme.rank else { return nil }
            guard rank >= 500 else { return nil }

            let hintSource = lexeme.basicMeaning?.trimmingCharacters(in: .whitespacesAndNewlines)
            let hintFallback = lexeme.sampleSentence?.trimmingCharacters(in: .whitespacesAndNewlines)
            let hint = [hintSource, hintFallback]
                .compactMap { $0 }
                .first(where: { !$0.isEmpty }) ?? "Common usage in context."

            self.lemma = lemma
            self.rank = rank
            self.hint = hint
        }
    }

    var fallbackRealQuestions: [(lemma: String, rank: Int, hint: String)] {
        [
            ("cogent", 19_800, "clear, convincing, and logically strong"),
            ("egregious", 20_000, "remarkably bad and obvious"),
            ("protocol", 2_547, "an official process or set of rules"),
            ("infrastructure", 2_738, "the underlying systems that support society"),
            ("perception", 7_094, "the way something is understood or interpreted"),
            ("hypothetical", 9_438, "based on a possible idea rather than a fact"),
            ("tenacious", 16_946, "persistent and difficult to discourage"),
            ("nostalgia", 16_975, "a longing feeling for the past"),
            ("prognosis", 19_019, "a forecast of likely development"),
            ("pervasive", 19_080, "spread throughout a place or group"),
            ("enigma", 20_043, "a puzzle that is hard to explain"),
            ("intricate", 20_086, "very detailed and complex")
        ]
    }

    var preferredRealQuestions: [(lemma: String, rank: Int, hint: String)] {
        [
            ("predict", 8_692, "say in advance what is likely to happen"),
            ("suggest", 2_199, "offer an idea or possible action"),
            ("consequence", 8_419, "a result that follows from an action"),
            ("efficient", 3_315, "achieving results with minimal waste"),
            ("constraint", 9_968, "a limit that restricts choices"),
            ("nuance", 15_400, "a subtle but important difference"),
            ("meticulous", 17_000, "showing very careful attention to detail"),
            ("ubiquitous", 19_403, "present or found everywhere"),
            ("cogent", 19_800, "clear, convincing, and logically strong"),
            ("egregious", 20_000, "remarkably bad and obvious")
        ]
    }

    var distractorPool: [(lemma: String, rank: Int, hint: String)] {
        [
            ("sornity", 18_000, "Control item: choose this only if you are fully sure."),
            ("dravicle", 6_500, "Control item: choose this only if you are fully sure.")
        ]
    }
}
