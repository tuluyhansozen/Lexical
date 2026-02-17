import Foundation

/// Scores topical novelty using lightweight embedding-style vectors and cosine similarity.
public struct ArticleNoveltyScorer: Sendable {
    private static let embeddingDimensions = 128

    public init() {}

    /// Cosine similarity over hashed semantic vectors (0.0 = unrelated, 1.0 = nearly identical).
    public func semanticSimilarity(of candidate: String, against corpus: [String]) -> Double {
        let source = embedding(for: candidate)
        guard source.contains(where: { $0 != 0 }) else { return 0 }

        var best = 0.0
        for item in corpus {
            let target = embedding(for: item)
            let score = dot(source, target)
            if score > best {
                best = score
            }
        }
        return max(0.0, min(1.0, best))
    }

    /// Jaccard overlap on normalized lexical tokens.
    public func lexicalSimilarity(of candidate: String, against corpus: [String]) -> Double {
        let source = Set(tokenize(candidate))
        guard !source.isEmpty else { return 0 }

        var best = 0.0
        for item in corpus {
            let target = Set(tokenize(item))
            guard !target.isEmpty else { continue }
            let intersection = source.intersection(target).count
            let union = source.union(target).count
            guard union > 0 else { continue }
            best = max(best, Double(intersection) / Double(union))
        }
        return best
    }

    /// Blend semantic and lexical similarity into one novelty score.
    public func blendedSimilarity(of candidate: String, against corpus: [String]) -> Double {
        let semantic = semanticSimilarity(of: candidate, against: corpus)
        let lexical = lexicalSimilarity(of: candidate, against: corpus)
        return min(1.0, (semantic * 0.82) + (lexical * 0.18))
    }

    private func embedding(for raw: String) -> [Double] {
        let tokens = tokenize(raw)
        guard !tokens.isEmpty else {
            return Array(repeating: 0, count: Self.embeddingDimensions)
        }

        var vector = Array(repeating: 0.0, count: Self.embeddingDimensions)
        accumulate(features: tokens.map { "tok:\($0)" }, weight: 1.0, into: &vector)

        let bigrams = zip(tokens, tokens.dropFirst()).map { "\($0.0)_\($0.1)" }
        accumulate(features: bigrams.map { "bi:\($0)" }, weight: 0.75, into: &vector)

        for token in tokens {
            let trigrams = characterTrigrams(token).map { "tri:\($0)" }
            accumulate(features: trigrams, weight: 0.32, into: &vector)
        }

        let magnitude = sqrt(vector.reduce(0) { $0 + ($1 * $1) })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }

    private func accumulate(features: [String], weight: Double, into vector: inout [Double]) {
        guard !features.isEmpty else { return }
        for feature in features {
            let hash = fnv1a64(feature)
            let bucket = Int(hash % UInt64(vector.count))
            let sign = ((hash >> 63) & 1) == 0 ? 1.0 : -1.0
            vector[bucket] += weight * sign
        }
    }

    private func dot(_ lhs: [Double], _ rhs: [Double]) -> Double {
        zip(lhs, rhs).reduce(0.0) { partial, pair in
            partial + (pair.0 * pair.1)
        }
    }

    private func tokenize(_ raw: String) -> [String] {
        raw.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
            .map(stem)
            .filter { !Self.stopWords.contains($0) }
    }

    private func stem(_ token: String) -> String {
        var value = token
        let suffixes = ["ingly", "edly", "ation", "ments", "ment", "ing", "ers", "ies", "ied", "ed", "ly", "es", "s"]
        for suffix in suffixes where value.count > suffix.count + 2 && value.hasSuffix(suffix) {
            value.removeLast(suffix.count)
            if suffix == "ies" {
                value.append("y")
            } else if suffix == "ied" {
                value.append("y")
            }
            break
        }
        return value
    }

    private func characterTrigrams(_ token: String) -> [String] {
        let chars = Array(token)
        guard chars.count >= 3 else { return [token] }
        var grams: [String] = []
        for index in 0...(chars.count - 3) {
            grams.append(String(chars[index...index + 2]))
        }
        return grams
    }

    private func fnv1a64(_ text: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "from", "that", "this", "into", "your",
        "about", "over", "under", "after", "before", "when", "where", "what",
        "why", "how", "are", "was", "were", "their", "them", "they", "you",
        "have", "has", "will", "would", "could", "should", "than", "then",
        "very", "just", "also", "more", "most", "some", "such"
    ]
}
