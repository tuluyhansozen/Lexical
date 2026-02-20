import Foundation

public struct CalibrationResponse: Sendable {
    public let lemma: String
    public let rank: Int
    public let recognitionScore: Double
    public let isDistractor: Bool

    public var recognized: Bool {
        recognitionScore >= 0.999
    }

    public init(
        lemma: String,
        rank: Int,
        recognitionScore: Double,
        isDistractor: Bool = false
    ) {
        self.lemma = lemma
        self.rank = rank
        self.recognitionScore = min(1.0, max(0.0, recognitionScore))
        self.isDistractor = isDistractor
    }

    public init(
        lemma: String,
        rank: Int,
        recognized: Bool,
        isDistractor: Bool = false
    ) {
        self.lemma = lemma
        self.rank = rank
        self.recognitionScore = recognized ? 1.0 : 0.0
        self.isDistractor = isDistractor
    }
}

public struct LexicalCalibrationResult: Sendable {
    public let estimatedRank: Int
    public let lowerBound: Int
    public let upperBound: Int
    public let confidence: Double
    public let realItemCount: Int
    public let distractorOverclaimRate: Double
}

/// Rank-oriented calibration engine used to bootstrap user lexical level.
public struct LexicalCalibrationEngine {
    public let minRank: Int
    public let maxRank: Int
    public let bandSize: Int
    public let masteryThreshold: Double
    public let logisticScale: Double
    public let priorRegularizationWeight: Double
    public let controlPenaltyScale: Double
    public let controlPenaltyExponent: Double
    public let controlPenaltyCap: Double
    public let coarseSearchStep: Int

    public init(
        minRank: Int = 500,
        maxRank: Int = 20_000,
        bandSize: Int = 500,
        masteryThreshold: Double = 0.7,
        logisticScale: Double = 5_000,
        priorRegularizationWeight: Double = 0.28,
        controlPenaltyScale: Double = 2_500,
        controlPenaltyExponent: Double = 1.3,
        controlPenaltyCap: Double = 3_500,
        coarseSearchStep: Int = 25
    ) {
        self.minRank = minRank
        self.maxRank = maxRank
        self.bandSize = bandSize
        self.masteryThreshold = masteryThreshold
        self.logisticScale = max(1_500, logisticScale)
        self.priorRegularizationWeight = max(0.0, priorRegularizationWeight)
        self.controlPenaltyScale = max(0.0, controlPenaltyScale)
        self.controlPenaltyExponent = max(1.0, controlPenaltyExponent)
        self.controlPenaltyCap = max(0.0, controlPenaltyCap)
        self.coarseSearchStep = max(1, coarseSearchStep)
    }

    public func estimate(
        from responses: [CalibrationResponse],
        priorRank: Int? = nil
    ) -> LexicalCalibrationResult {
        let realResponses = responses.filter { !$0.isDistractor }
        let distractorResponses = responses.filter(\.isDistractor)

        guard !realResponses.isEmpty else {
            let fallback = clamp(priorRank ?? minRank)
            return LexicalCalibrationResult(
                estimatedRank: fallback,
                lowerBound: max(minRank, fallback - 1_500),
                upperBound: min(maxRank, fallback + 1_500),
                confidence: 0.25,
                realItemCount: 0,
                distractorOverclaimRate: 0.0
            )
        }

        let normalizedPrior = clamp(priorRank ?? inferredPriorRank(from: realResponses))
        let observedRank = bestFitRank(
            from: realResponses,
            priorRank: normalizedPrior
        )
        let overclaimRate: Double = {
            guard !distractorResponses.isEmpty else { return 0.0 }
            let overclaims = distractorResponses.filter { $0.recognitionScore >= 0.999 }.count
            return Double(overclaims) / Double(distractorResponses.count)
        }()

        let controlPenalty = min(
            controlPenaltyCap,
            controlPenaltyScale * pow(overclaimRate, controlPenaltyExponent)
        )
        let penalizedObservedRank = clamp(
            observedRank - Int(controlPenalty.rounded())
        )

        let fitMSE = meanSquaredResidual(
            from: realResponses,
            estimatedRank: observedRank
        )
        let residualScore = 1.0 - min(1.0, fitMSE)
        let sampleCoverage = min(1.0, Double(realResponses.count) / 8.0)
        let confidence = min(
            0.93,
            max(
                0.35,
                0.35 +
                (0.4 * residualScore) +
                (0.2 * sampleCoverage) -
                (0.17 * overclaimRate)
            )
        )

        let estimated: Int = {
            guard priorRank != nil else { return penalizedObservedRank }

            let priorWeight = confidence >= 0.85 ? 0.5 : 0.7
            let observedWeight = 1.0 - priorWeight
            let blended = (priorWeight * Double(normalizedPrior)) + (observedWeight * Double(penalizedObservedRank))
            return clamp(Int(blended.rounded()))
        }()

        let halfWidth = Int((Double(5_400) * (1.0 - confidence)).rounded()) + 800
        let lower = max(minRank, estimated - halfWidth)
        let upper = min(maxRank, estimated + halfWidth)

        return LexicalCalibrationResult(
            estimatedRank: estimated,
            lowerBound: lower,
            upperBound: upper,
            confidence: confidence,
            realItemCount: realResponses.count,
            distractorOverclaimRate: overclaimRate
        )
    }

    public func proximalRange(
        for lexicalRank: Int,
        lowerOffset: Int = 250,
        upperOffset: Int = 600
    ) -> ClosedRange<Int> {
        let lower = max(minRank, lexicalRank - lowerOffset)
        let upper = min(maxRank, lexicalRank + upperOffset)
        return lower...max(lower, upper)
    }

    private func bestFitRank(
        from responses: [CalibrationResponse],
        priorRank: Int
    ) -> Int {
        var bestRank = priorRank
        var bestScore = Double.greatestFiniteMagnitude

        for candidate in stride(from: minRank, through: maxRank, by: coarseSearchStep) {
            let score = objectiveScore(
                for: responses,
                candidateRank: candidate,
                priorRank: priorRank
            )
            if score < bestScore {
                bestScore = score
                bestRank = candidate
            }
        }

        let refineLower = max(minRank, bestRank - coarseSearchStep)
        let refineUpper = min(maxRank, bestRank + coarseSearchStep)
        for candidate in refineLower...refineUpper {
            let score = objectiveScore(
                for: responses,
                candidateRank: candidate,
                priorRank: priorRank
            )
            if score < bestScore {
                bestScore = score
                bestRank = candidate
            }
        }

        return clamp(bestRank)
    }

    private func objectiveScore(
        for responses: [CalibrationResponse],
        candidateRank: Int,
        priorRank: Int
    ) -> Double {
        let dataLoss = responses.reduce(into: 0.0) { loss, response in
            let probability = recognitionProbability(wordRank: response.rank, estimateRank: candidateRank)
            let residual = response.recognitionScore - probability
            loss += residual * residual
        }
        let priorDelta = Double(candidateRank - priorRank) / logisticScale
        let priorPenalty = priorRegularizationWeight * priorDelta * priorDelta
        return dataLoss + priorPenalty
    }

    private func meanSquaredResidual(
        from responses: [CalibrationResponse],
        estimatedRank: Int
    ) -> Double {
        guard !responses.isEmpty else { return 1.0 }
        let total = responses.reduce(into: 0.0) { sum, response in
            let probability = recognitionProbability(wordRank: response.rank, estimateRank: estimatedRank)
            let residual = response.recognitionScore - probability
            sum += residual * residual
        }
        return total / Double(responses.count)
    }

    private func recognitionProbability(
        wordRank: Int,
        estimateRank: Int
    ) -> Double {
        let exponent = Double(wordRank - estimateRank) / logisticScale
        return 1.0 / (1.0 + exp(exponent))
    }

    private func inferredPriorRank(from responses: [CalibrationResponse]) -> Int {
        let sortedRanks = responses.map(\.rank).sorted()
        guard !sortedRanks.isEmpty else { return minRank }
        return sortedRanks[sortedRanks.count / 2]
    }

    private func clamp(_ rank: Int) -> Int {
        min(maxRank, max(minRank, rank))
    }
}
