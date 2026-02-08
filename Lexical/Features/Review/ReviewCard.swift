import Foundation
import LexicalCore

/// Lightweight review payload decoupled from legacy `VocabularyItem` storage.
struct ReviewCard: Identifiable, Equatable {
    let lemma: String
    var originalWord: String
    var contextSentence: String
    var definition: String?

    var stability: Double
    var difficulty: Double
    var retrievability: Double
    var nextReviewDate: Date?
    var lastReviewDate: Date?
    var reviewCount: Int
    var createdAt: Date
    var status: UserWordStatus

    var id: String { lemma }
}
