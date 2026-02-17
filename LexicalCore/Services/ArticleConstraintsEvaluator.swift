import Foundation

public struct ArticleConstraintsEvaluator {
    
    public enum ConstraintViolation: Error {
        case tooShort(actual: Int, min: Int)
        case tooLong(actual: Int, max: Int)
        case vocabularyDensityTooHigh(actual: Double, limit: Double)
        case vocabularyDensityTooLow(actual: Double, limit: Double)
        case unreadable
        case insufficientParagraphs(actual: Int, min: Int)
        case insufficientSentences(actual: Int, min: Int)
        case containsPlaceholderToken
        case possibleFabricatedStatistic
    }
    
    public struct ValidationResult {
        public let isValid: Bool
        public let issues: [ConstraintViolation]
        public let score: Double // 0.0 to 1.0 quality score
    }
    
    public init() {}
    
    /// Evaluates a generated article text against constraints
    /// - Parameters:
    ///   - text: The article body text
    ///   - newWordCount: Number of target "new" words included
    ///   - totalWordCount: Total words in text
    public func evaluate(text: String, newWordCount: Int, totalWordCount: Int) -> ValidationResult {
        var issues: [ConstraintViolation] = []
        let minTargetWords = 220
        let maxTargetWords = 460
        
        // 1. Length Constraints (targeting ~400-word articles)
        if totalWordCount < minTargetWords {
            issues.append(.tooShort(actual: totalWordCount, min: minTargetWords))
        }
        if totalWordCount > maxTargetWords {
            issues.append(.tooLong(actual: totalWordCount, max: maxTargetWords))
        }
        
        // 2. Density Check (Target: 1-3%)
        let density = Double(newWordCount) / Double(max(1, totalWordCount))
        let minDensity = 0.01
        let maxDensity = 0.05 // Slightly loose upper bound for shorter texts
        
        if density < minDensity && totalWordCount > 100 {
             // For very short texts, low density might be unavoidable, so we check > 100 words
            issues.append(.vocabularyDensityTooLow(actual: density, limit: minDensity))
        }
        
        if density > maxDensity {
            issues.append(.vocabularyDensityTooHigh(actual: density, limit: maxDensity))
        }
        
        // 3. Readability Heuristic (Simple paragraph check)
        // A wall of text is unreadable.
        let paragraphs = text.components(separatedBy: "\n\n")
        if totalWordCount > 100 && paragraphs.count < 2 {
            issues.append(.unreadable)
        }
        let nonEmptyParagraphs = paragraphs.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if totalWordCount >= 220 && nonEmptyParagraphs.count < 3 {
            issues.append(.insufficientParagraphs(actual: nonEmptyParagraphs.count, min: 3))
        }

        let sentences = sentenceCount(in: text)
        if totalWordCount >= 220 && sentences < 8 {
            issues.append(.insufficientSentences(actual: sentences, min: 8))
        }

        if containsPlaceholder(in: text) {
            issues.append(.containsPlaceholderToken)
        }

        if hasUnsourcedStatisticSignal(in: text) {
            issues.append(.possibleFabricatedStatistic)
        }
        
        // Calculate Score
        let isValid = issues.isEmpty
        let baseScore = isValid ? 1.0 : 0.5
        let penalty = Double(issues.count) * 0.1
        let finalScore = max(0.0, baseScore - penalty)
        
        return ValidationResult(isValid: isValid, issues: issues, score: finalScore)
    }

    private func sentenceCount(in text: String) -> Int {
        text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
    }

    private func containsPlaceholder(in text: String) -> Bool {
        let placeholderPatterns = [
            #"\b(?:scenario|placeholder|sample|template)_word_\d+\b"#,
            #"\{\{[^}]+\}\}"#,
            #"<[^>]+>"#,
            #"\b(?:lorem ipsum|todo)\b"#
        ]
        return placeholderPatterns.contains {
            text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private func hasUnsourcedStatisticSignal(in text: String) -> Bool {
        let hasPercent = text.range(
            of: #"\b\d{1,3}(?:\.\d+)?\s?(?:%|percent)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        let hasAuthorityClaim = text.range(
            of: #"\b(?:study|research|survey|report|according to)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        return hasPercent && hasAuthorityClaim
    }
}
