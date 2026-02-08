import Foundation
import SwiftData

/// Persisted generated-article metadata with ephemeral lifecycle controls.
@Model
public final class GeneratedContent {
    @Attribute(.unique) public var articleId: String

    public var title: String
    public var bodyText: String
    public var targetWords: [String]
    public var category: String
    public var difficultyScore: Double
    public var targetRank: Int?
    public var createdAt: Date
    public var isSaved: Bool
    public var lastViewedAt: Date?
    public var updatedAt: Date

    public init(
        articleId: String,
        title: String,
        bodyText: String,
        targetWords: [String],
        category: String,
        difficultyScore: Double,
        targetRank: Int? = nil,
        createdAt: Date = Date(),
        isSaved: Bool = false,
        lastViewedAt: Date? = nil
    ) {
        self.articleId = articleId
        self.title = title
        self.bodyText = bodyText
        self.targetWords = targetWords
        self.category = category
        self.difficultyScore = difficultyScore
        self.targetRank = targetRank
        self.createdAt = createdAt
        self.isSaved = isSaved
        self.lastViewedAt = lastViewedAt
        self.updatedAt = Date()
    }

    public func touch(now: Date = Date()) {
        updatedAt = now
    }
}
