import Foundation

public enum OnboardingCalibrationAnswer: String, CaseIterable, Codable, Sendable {
    case know
    case unsure
    case dontKnow

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
        questionCount: Int = 10
    ) -> [OnboardingCalibrationQuestion] {
        let normalizedCount = max(4, questionCount)
        let distractorCount = min(2, max(1, normalizedCount / 5))
        let realCount = max(2, normalizedCount - distractorCount)

        let realQuestions = buildRealQuestions(from: lexemes, desiredCount: realCount)
        let distractors = buildDistractors(desiredCount: distractorCount)

        return interleave(realQuestions: realQuestions, distractors: distractors)
    }

    public func evaluate(
        questions: [OnboardingCalibrationQuestion],
        answers: [String: OnboardingCalibrationAnswer]
    ) -> LexicalCalibrationResult? {
        guard !questions.isEmpty else { return nil }

        let responses = questions.compactMap { question -> CalibrationResponse? in
            guard let answer = answers[question.id] else { return nil }
            return CalibrationResponse(
                lemma: question.lemma,
                rank: question.rank,
                recognized: answer.recognized,
                isDistractor: question.isDistractor
            )
        }

        guard responses.count == questions.count else { return nil }
        return calibrationEngine.estimate(from: responses)
    }

    private func buildRealQuestions(
        from lexemes: [LexemeDefinition],
        desiredCount: Int
    ) -> [OnboardingCalibrationQuestion] {
        let candidatePool = lexemes.compactMap(Candidate.init)
        let targetRanks = makeTargetRanks(count: desiredCount)
        var usedLemmas: Set<String> = []
        var picked: [OnboardingCalibrationQuestion] = []

        picked.reserveCapacity(desiredCount)

        for target in targetRanks {
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
        let anchors = [1_000, 2_500, 4_500, 7_000, 10_000]
        guard count > 0 else { return [] }

        var targets: [Int] = []
        targets.reserveCapacity(count)
        var anchorIndex = 0

        while targets.count < count {
            let anchor = anchors[anchorIndex % anchors.count]
            targets.append(anchor)
            if targets.count < count {
                targets.append(anchor)
            }
            anchorIndex += 1
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
            ("maintain", 1_000, "to keep something at the same level or condition"),
            ("resource", 1_200, "a useful source of support, knowledge, or supply"),
            ("resilient", 2_400, "able to recover quickly from stress or change"),
            ("coherent", 2_700, "clear, logical, and consistent"),
            ("nuance", 4_400, "a subtle difference in meaning or feeling"),
            ("meticulous", 4_700, "showing careful attention to detail"),
            ("ubiquitous", 6_900, "present everywhere or very widespread"),
            ("detrimental", 7_200, "causing harm or damage"),
            ("pragmatic", 9_700, "focused on practical outcomes"),
            ("synthesize", 10_200, "to combine ideas into a coherent whole")
        ]
    }

    var distractorPool: [(lemma: String, rank: Int, hint: String)] {
        [
            ("dravicle", 4_000, "Control item: choose this only if you are fully sure."),
            ("sornity", 7_500, "Control item: choose this only if you are fully sure.")
        ]
    }
}
