import Foundation
import SwiftData

public enum UserWordStatus: String, Codable, CaseIterable {
    case new
    case learning
    case known
    case ignored
    
    public var isLearned: Bool {
        self == .known
    }
}

/// Mutable per-user lexical state (FSRS shadow) separated from canonical lexeme data.
@Model
public final class UserWordState {
    /// Composite uniqueness key: "\(userId)|\(lemma)"
    @Attribute(.unique) public var userLemmaKey: String

    public var userId: String
    public var lemma: String
    public var statusRawValue: String

    public var stability: Double
    public var difficulty: Double
    public var retrievability: Double

    public var nextReviewDate: Date?
    public var lastReviewDate: Date?
    public var reviewCount: Int
    public var lapseCount: Int

    /// LWW merge timestamp for mutable state fields.
    public var stateUpdatedAt: Date
    public var createdAt: Date

    public var status: UserWordStatus {
        get { UserWordStatus(rawValue: statusRawValue) ?? .new }
        set {
            statusRawValue = newValue.rawValue
            stateUpdatedAt = Date()
        }
    }

    public init(
        userId: String,
        lemma: String,
        status: UserWordStatus = .new,
        stability: Double = 0.0,
        difficulty: Double = 0.3,
        retrievability: Double = 1.0,
        nextReviewDate: Date? = nil,
        lastReviewDate: Date? = nil,
        reviewCount: Int = 0,
        lapseCount: Int = 0
    ) {
        let normalizedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.userId = normalizedUserId
        self.lemma = normalizedLemma
        self.userLemmaKey = Self.makeKey(userId: normalizedUserId, lemma: normalizedLemma)
        self.statusRawValue = status.rawValue
        self.stability = stability
        self.difficulty = difficulty
        self.retrievability = retrievability
        self.nextReviewDate = nextReviewDate
        self.lastReviewDate = lastReviewDate
        self.reviewCount = reviewCount
        self.lapseCount = lapseCount
        self.stateUpdatedAt = Date()
        self.createdAt = Date()
    }

    public static func makeKey(userId: String, lemma: String) -> String {
        let normalizedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedUserId)|\(normalizedLemma)"
    }

    public func touch() {
        stateUpdatedAt = Date()
    }
}
