import Foundation
import SwiftData

/// Represents a vocabulary word being learned with FSRS parameters
@Model
public final class VocabularyItem {
    /// The lemma (dictionary form) of the word
    @Attribute(.unique) public var lemma: String
    
    /// The original form as captured
    public var originalWord: String
    
    /// The context sentence where the word was captured
    public var contextSentence: String
    
    /// User-added definition (optional)
    public var definition: String?
    
    // MARK: - FSRS Parameters
    
    /// Memory stability (higher = more stable memory)
    public var stability: Double
    
    /// Item difficulty (0-1, higher = harder)
    public var difficulty: Double
    
    /// Current retrievability (probability of recall)
    public var retrievability: Double
    
    /// Next scheduled review date
    public var nextReviewDate: Date?
    
    /// Number of times this item has been reviewed
    public var reviewCount: Int
    
    /// Date when the word was first captured
    public var createdAt: Date
    
    /// Date of last review
    public var lastReviewedAt: Date?
    
    // MARK: - Relationships
    
    /// Review history for this item
    @Relationship(deleteRule: .cascade, inverse: \ReviewLog.vocabularyItem)
    public var reviewLogs: [ReviewLog]
    
    /// Connected words (Matrix Graph)
    @Relationship
    public var collocations: [VocabularyItem]
    
    public init(
        lemma: String,
        originalWord: String? = nil,
        contextSentence: String = "",
        definition: String? = nil
    ) {
        self.lemma = lemma.lowercased()
        self.originalWord = originalWord ?? lemma
        self.contextSentence = contextSentence
        self.definition = definition
        self.collocations = []
        
        // FSRS initial values
        self.stability = 0.0
        self.difficulty = 0.3  // Default starting difficulty
        self.retrievability = 1.0
        self.nextReviewDate = nil
        self.reviewCount = 0
        self.createdAt = Date()
        self.lastReviewedAt = nil
        self.reviewLogs = []
    }
    
    /// Learning state based on FSRS parameters
    public var learningState: LearningState {
        if stability > 90.0 {
            return .mastered
        } else if reviewCount > 0 {
            return .learning
        } else {
            return .new
        }
    }
    
    /// Whether the item is due for review
    public var isDue: Bool {
        guard let nextReview = nextReviewDate else {
            return reviewCount == 0 // New cards are always "due"
        }
        return Date() >= nextReview
    }
}

/// Learning state for UI display
public enum LearningState: String, Codable {
    case new       // Never reviewed
    case learning  // In active learning
    case mastered  // High stability, well-known
}
