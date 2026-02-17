import Foundation

/// Lightweight lexical content safety filters for seed and fallback payloads.
public enum ContentSafetyService {
    private static let blockedRegexes: [NSRegularExpression] = {
        let patterns = [
            "\\bmasturbat(?:e|ion|ing)?\\b",
            "\\bstriptease\\b",
            "\\bsex(?:ual|ually)?\\s+intercourse\\b",
            "\\bsex\\s+offender\\b",
            "\\bsodom(?:y|ise|ize|ised|ized|ising|izing)\\b",
            "\\bkill\\s+myself\\b",
            "\\bcommit\\s+suicide\\b",
            "\\bsuicide\\s+bomber\\b",
            "\\bkill\\s+you\\b",
            "\\bnazi\\b",
            "\\bselected\\s+to\\s+receive\\s+a\\s+free\\s+cruise\\b",
            "\\bfuck(?:ed|ing|s)?\\b",
            "\\bshit(?:ty|ton)?\\b",
            "\\bbitch(?:es)?\\b",
            "\\bbastard(?:s)?\\b",
            "\\basshole(?:s)?\\b",
            "\\bcunt(?:s)?\\b",
            "\\bslut(?:s)?\\b",
            "\\bwhore(?:s)?\\b",
            "\\brape\\b",
            "\\bsuicide\\b",
            "\\bterrorist(?:s)?\\b"
        ]

        return patterns.compactMap { pattern in
            try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        }
    }()

    public static func isSafeText(_ raw: String?) -> Bool {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return false
        }
        let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        return !blockedRegexes.contains { regex in
            regex.firstMatch(in: trimmed, options: [], range: nsRange) != nil
        }
    }

    public static func sanitizeSentences(
        _ values: [String],
        maxCount: Int? = nil
    ) -> [String] {
        sanitizeTerms(values, maxCount: maxCount)
    }

    public static func sanitizeTerms(
        _ values: [String],
        maxCount: Int? = nil
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        let limit = maxCount.map { max(1, $0) } ?? Int.max

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isSafeText(trimmed) else { continue }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { continue }
            result.append(trimmed)
            if result.count >= limit {
                break
            }
        }
        return result
    }
}
