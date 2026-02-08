import Foundation
import SwiftData

public struct GeneratedArticle: Codable, Identifiable {
    public var id: UUID
    public var title: String
    public var content: String
    public var targetWords: [String] // Lemmas targeted
    public var category: String
    public var generatedDate: Date
    public var difficultyScore: Double
    public var targetRank: Int?
    public var isSaved: Bool
    
    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        targetWords: [String],
        category: String,
        generatedDate: Date = Date(),
        difficultyScore: Double,
        targetRank: Int? = nil,
        isSaved: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.targetWords = targetWords
        self.category = category
        self.generatedDate = generatedDate
        self.difficultyScore = difficultyScore
        self.targetRank = targetRank
        self.isSaved = isSaved
    }

    init(record: GeneratedContent) {
        self.id = UUID(uuidString: record.articleId) ?? UUID()
        self.title = record.title
        self.content = record.bodyText
        self.targetWords = record.targetWords
        self.category = record.category
        self.generatedDate = record.createdAt
        self.difficultyScore = record.difficultyScore
        self.targetRank = record.targetRank
        self.isSaved = record.isSaved
    }
}

public actor ArticleStore {
    public static let defaultUnsavedTTL: TimeInterval = 72 * 60 * 60
    private let unsavedTTL: TimeInterval
    
    public init(unsavedTTL: TimeInterval = defaultUnsavedTTL) {
        self.unsavedTTL = max(60, unsavedTTL)
    }
    
    @discardableResult
    public func cleanupExpiredUnsavedContent(now: Date = Date()) throws -> Int {
        let context = ModelContext(Persistence.sharedModelContainer)
        return try cleanupExpiredUnsaved(in: context, now: now)
    }
    
    public func save(_ article: GeneratedArticle) throws {
        let context = ModelContext(Persistence.sharedModelContainer)
        let record = try upsertRecord(for: article, modelContext: context)
        record.touch()
        _ = try cleanupExpiredUnsaved(in: context, now: Date())
        try context.save()
    }
    
    public func loadAll() -> [GeneratedArticle] {
        let context = ModelContext(Persistence.sharedModelContainer)
        do {
            _ = try cleanupExpiredUnsaved(in: context, now: Date())
            let descriptor = FetchDescriptor<GeneratedContent>(
                sortBy: [SortDescriptor(\GeneratedContent.createdAt, order: .reverse)]
            )
            let rows = try context.fetch(descriptor)
            return rows.map(GeneratedArticle.init(record:))
        } catch {
            print("ArticleStore: failed to load generated content: \(error)")
            return []
        }
    }
    
    public func delete(_ id: UUID) {
        let context = ModelContext(Persistence.sharedModelContainer)
        guard let row = try? record(for: id.uuidString, in: context) else { return }
        context.delete(row)
        try? context.save()
    }

    public func setSaved(_ id: UUID, isSaved: Bool = true) {
        let context = ModelContext(Persistence.sharedModelContainer)
        guard let row = try? record(for: id.uuidString, in: context) else { return }
        row.isSaved = isSaved
        row.touch()
        try? context.save()
    }

    public func markViewed(_ id: UUID, viewedAt: Date = Date()) {
        let context = ModelContext(Persistence.sharedModelContainer)
        guard let row = try? record(for: id.uuidString, in: context) else { return }
        row.lastViewedAt = viewedAt
        row.touch(now: viewedAt)
        try? context.save()
    }

    private func record(
        for articleId: String,
        in modelContext: ModelContext
    ) throws -> GeneratedContent? {
        let descriptor = FetchDescriptor<GeneratedContent>(
            predicate: #Predicate { row in
                row.articleId == articleId
            }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func upsertRecord(
        for article: GeneratedArticle,
        modelContext: ModelContext
    ) throws -> GeneratedContent {
        let articleId = article.id.uuidString
        if let existing = try record(for: articleId, in: modelContext) {
            existing.title = article.title
            existing.bodyText = article.content
            existing.targetWords = article.targetWords
            existing.category = article.category
            existing.difficultyScore = article.difficultyScore
            existing.targetRank = article.targetRank
            existing.createdAt = article.generatedDate
            existing.isSaved = article.isSaved
            return existing
        }

        let created = GeneratedContent(
            articleId: articleId,
            title: article.title,
            bodyText: article.content,
            targetWords: article.targetWords,
            category: article.category,
            difficultyScore: article.difficultyScore,
            targetRank: article.targetRank,
            createdAt: article.generatedDate,
            isSaved: article.isSaved
        )
        modelContext.insert(created)
        return created
    }

    private func cleanupExpiredUnsaved(
        in modelContext: ModelContext,
        now: Date
    ) throws -> Int {
        let cutoff = now.addingTimeInterval(-unsavedTTL)
        let descriptor = FetchDescriptor<GeneratedContent>(
            predicate: #Predicate { row in
                row.isSaved == false && row.createdAt < cutoff
            }
        )
        let expired = try modelContext.fetch(descriptor)
        for row in expired {
            modelContext.delete(row)
        }
        if !expired.isEmpty {
            try modelContext.save()
        }
        return expired.count
    }
}
