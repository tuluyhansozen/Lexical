import Foundation

public struct ArticleConstraintsEvaluator {
    
    public enum ConstraintViolation: Error {
        case tooShort(actual: Int, min: Int)
        case tooLong(actual: Int, max: Int)
        case vocabularyDensityTooHigh(actual: Double, limit: Double)
        case vocabularyDensityTooLow(actual: Double, limit: Double)
        case unreadable
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
        
        // 1. Length Constraints (Soft limits)
        if totalWordCount < 50 {
            issues.append(.tooShort(actual: totalWordCount, min: 50))
        }
        if totalWordCount > 2000 {
            issues.append(.tooLong(actual: totalWordCount, max: 2000))
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
        
        // Calculate Score
        let isValid = issues.isEmpty
        let baseScore = isValid ? 1.0 : 0.5
        let penalty = Double(issues.count) * 0.1
        let finalScore = max(0.0, baseScore - penalty)
        
        return ValidationResult(isValid: isValid, issues: issues, score: finalScore)
    }
}
