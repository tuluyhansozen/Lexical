import Foundation
import SwiftData

/// Represents a vocabulary word being learned with FSRS parameters
@Model
final class VocabularyItem {
    /// The lemma (dictionary form) of the word
    @Attribute(.unique) var lemma: String
    
    /// The original form as captured
    var originalWord: String
    
    /// The context sentence where the word was captured
    var contextSentence: String
    
    /// User-added definition (optional)
    var definition: String?
    
    // MARK: - FSRS Parameters
    
    /// Memory stability (higher = more stable memory)
    var stability: Double
    
    /// Item difficulty (0-1, higher = harder)
    var difficulty: Double
    
    /// Current retrievability (probability of recall)
    var retrievability: Double
    
    /// Next scheduled review date
    var nextReviewDate: Date?
    
    /// Number of times this item has been reviewed
    var reviewCount: Int
    
    /// Date when the word was first captured
    var createdAt: Date
    
    /// Date of last review
    var lastReviewedAt: Date?
    
    // MARK: - Relationships
    
    /// Review history for this item
    @Relationship(deleteRule: .cascade, inverse: \ReviewLog.vocabularyItem)
    var reviewLogs: [ReviewLog]
    
    /// Root word connections for morphology matrix
    @Relationship
    var morphologicalRoot: MorphologicalRoot?
    
    init(
        lemma: String,
        originalWord: String? = nil,
        contextSentence: String = "",
        definition: String? = nil
    ) {
        self.lemma = lemma.lowercased()
        self.originalWord = originalWord ?? lemma
        self.contextSentence = contextSentence
        self.definition = definition
        
        // FSRS initial values
        self.stability = 0.0
        self.difficulty = 0.3  // Default starting difficulty
        self.retrievability = 1.0
        self.nextReviewDate = nil
        self.reviewCount = 0
        self.createdAt = Date()
        self.lastReviewedAt = nil
        self.reviewLogs = []
        self.morphologicalRoot = nil
    }
    
    /// Learning state based on FSRS parameters
    var learningState: LearningState {
        if stability > 90.0 {
            return .mastered
        } else if reviewCount > 0 {
            return .learning
        } else {
            return .new
        }
    }
    
    /// Whether the item is due for review
    var isDue: Bool {
        guard let nextReview = nextReviewDate else {
            return reviewCount == 0 // New cards are always "due"
        }
        return Date() >= nextReview
    }
}

/// Learning state for UI display
enum LearningState: String, Codable {
    case new       // Never reviewed
    case learning  // In active learning
    case mastered  // High stability, well-known
}
