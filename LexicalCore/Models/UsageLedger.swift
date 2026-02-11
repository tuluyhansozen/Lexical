import Foundation
import SwiftData

/// Tracks per-user feature-usage counters for free/premium gate enforcement.
@Model
public final class UsageLedger {
    @Attribute(.unique) public var userId: String

    /// 7-day article window anchor for free-tier quota checks.
    public var articleWindowStart: Date
    public var articlesGeneratedInWindow: Int

    /// Active widget-profile count used for free-tier cap.
    public var activeWidgetProfileCount: Int

    public var updatedAt: Date
    public var createdAt: Date

    public init(
        userId: String,
        articleWindowStart: Date = Date(),
        articlesGeneratedInWindow: Int = 0,
        activeWidgetProfileCount: Int = 0
    ) {
        self.userId = userId
        self.articleWindowStart = articleWindowStart
        self.articlesGeneratedInWindow = max(0, articlesGeneratedInWindow)
        self.activeWidgetProfileCount = max(0, activeWidgetProfileCount)
        self.updatedAt = Date()
        self.createdAt = Date()
    }

    public func resetArticleWindow(startingAt date: Date) {
        articleWindowStart = date
        articlesGeneratedInWindow = 0
        touch(now: date)
    }

    public func touch(now: Date = Date()) {
        updatedAt = now
    }
}
