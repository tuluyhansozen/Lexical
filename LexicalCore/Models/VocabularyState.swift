import Foundation

/// State of a word in the user's vocabulary for highlighting purposes
public enum VocabularyState: Sendable {
    case new       // New word, can be learned
    case learning  // Currently being learned
    case known     // Already mastered/known
    case unknown   // Unknown status
}
