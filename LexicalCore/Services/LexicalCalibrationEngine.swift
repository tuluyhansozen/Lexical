import Foundation

public struct CalibrationResponse: Sendable {
    public let lemma: String
    public let rank: Int
    public let recognized: Bool
    public let isDistractor: Bool

    public init(
        lemma: String,
        rank: Int,
        recognized: Bool,
        isDistractor: Bool = false
    ) {
        self.lemma = lemma
        self.rank = rank
        self.recognized = recognized
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

    public init(
        minRank: Int = 500,
        maxRank: Int = 20_000,
        bandSize: Int = 500,
        masteryThreshold: Double = 0.7
    ) {
        self.minRank = minRank
        self.maxRank = maxRank
        self.bandSize = bandSize
        self.masteryThreshold = masteryThreshold
    }

    public func estimate(from responses: [CalibrationResponse]) -> LexicalCalibrationResult {
        let realResponses = responses.filter { !$0.isDistractor }
        let distractorResponses = responses.filter(\.isDistractor)

        guard !realResponses.isEmpty else {
            return LexicalCalibrationResult(
                estimatedRank: minRank,
                lowerBound: minRank,
                upperBound: min(maxRank, minRank + 1500),
                confidence: 0.25,
                realItemCount: 0,
                distractorOverclaimRate: 0.0
            )
        }

        var buckets: [Int: (recognized: Int, total: Int)] = [:]
        for response in realResponses {
            let band = bandFloor(for: response.rank)
            var bucket = buckets[band, default: (0, 0)]
            if response.recognized { bucket.recognized += 1 }
            bucket.total += 1
            buckets[band] = bucket
        }

        let sortedBands = buckets.keys.sorted()
        var masteredBand = minRank
        for band in sortedBands {
            guard let bucket = buckets[band], bucket.total > 0 else { continue }
            let rate = Double(bucket.recognized) / Double(bucket.total)
            // Require at least two samples in a band before allowing promotion.
            if bucket.total >= 2 && rate >= masteryThreshold {
                masteredBand = band
            }
        }

        let overclaimRate: Double = {
            guard !distractorResponses.isEmpty else { return 0.0 }
            let overclaims = distractorResponses.filter(\.recognized).count
            return Double(overclaims) / Double(distractorResponses.count)
        }()

        var estimated = min(maxRank, max(minRank, masteredBand + bandSize / 2))
        // Penalize aggressive self-claims on distractors.
        if overclaimRate > 0.25 {
            estimated -= Int(Double(bandSize) * 1.5)
        } else if overclaimRate > 0.1 {
            estimated -= bandSize / 2
        }
        estimated = min(maxRank, max(minRank, estimated))

        let sampleCoverage = min(1.0, Double(realResponses.count) / 40.0)
        let confidence = max(
            0.25,
            min(0.95, 0.35 + (0.5 * sampleCoverage) - (0.25 * overclaimRate))
        )

        let halfWidth = Int(Double(4000) * (1.0 - confidence)) + 250
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

    private func bandFloor(for rank: Int) -> Int {
        let clamped = min(maxRank, max(minRank, rank))
        return (clamped / bandSize) * bandSize
    }
}
