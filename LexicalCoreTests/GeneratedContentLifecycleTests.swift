import Foundation
import LexicalCore
import SwiftData
import XCTest

@MainActor
final class GeneratedContentLifecycleTests: XCTestCase {
    private let ttlWindow: TimeInterval = 72 * 60 * 60

    func testCRUDGeneratedContentRecord() throws {
        let container = try makeInMemoryV4Container()
        let context = container.mainContext
        let articleID = "generated.article.crud"
        let createdAt = Date(timeIntervalSince1970: 1_705_000_000)

        let record = GeneratedContentSchemaV4.GeneratedContent(
            articleId: articleID,
            title: "Adaptive Reading",
            bodyText: "A short article tailored for lexical growth.",
            targetWords: ["ephemeral", "retention"],
            targetRank: 3_200,
            createdAt: createdAt,
            isSaved: false
        )
        context.insert(record)
        try context.save()

        let fetched = try fetchAllV4Records(in: context)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.articleId, articleID)
        XCTAssertEqual(fetched.first?.targetRank, 3_200)
        XCTAssertEqual(fetched.first?.targetWords, ["ephemeral", "retention"])
        XCTAssertFalse(fetched.first?.isSaved ?? true)

        fetched[0].isSaved = true
        fetched[0].targetRank = 3_450
        try context.save()

        let updated = try XCTUnwrap(try fetchAllV4Records(in: context).first)
        XCTAssertTrue(updated.isSaved)
        XCTAssertEqual(updated.targetRank, 3_450)

        context.delete(updated)
        try context.save()
        XCTAssertTrue(try fetchAllV4Records(in: context).isEmpty)
    }

    func testV4MigrationPreservesRowsAndAddsTargetRankField() throws {
        let fileManager = FileManager.default
        let storeDirectory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("GeneratedContent.sqlite")
        try seedV3Store(at: storeURL)

        let migratedContainer = try makeMigratedV4Container(storeURL: storeURL)
        let migratedRows = try fetchAllV4Records(in: migratedContainer.mainContext)
        let row = try XCTUnwrap(migratedRows.first)

        XCTAssertEqual(migratedRows.count, 1)
        XCTAssertEqual(row.articleId, "generated.article.v3")
        XCTAssertEqual(row.title, "Legacy Cached Content")
        XCTAssertEqual(row.targetWords, ["throttle", "ephemeral"])
        XCTAssertEqual(row.isSaved, false)
        XCTAssertNil(row.targetRank)
    }

    func testCleanupDeletesOnlyUnsavedRowsOlderThan72Hours() throws {
        let container = try makeInMemoryV4Container()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_705_200_000)

        let staleUnsaved = GeneratedContentSchemaV4.GeneratedContent(
            articleId: "generated.stale.unsaved",
            title: "Stale Unsaved",
            bodyText: "Should be removed.",
            targetWords: ["obsolete"],
            targetRank: 2_900,
            createdAt: now.addingTimeInterval(-(ttlWindow + 5)),
            isSaved: false
        )
        let freshUnsaved = GeneratedContentSchemaV4.GeneratedContent(
            articleId: "generated.fresh.unsaved",
            title: "Fresh Unsaved",
            bodyText: "Should remain.",
            targetWords: ["fresh"],
            targetRank: 3_100,
            createdAt: now.addingTimeInterval(-(ttlWindow - 5)),
            isSaved: false
        )
        let staleSaved = GeneratedContentSchemaV4.GeneratedContent(
            articleId: "generated.stale.saved",
            title: "Saved Content",
            bodyText: "Saved content is exempt from TTL.",
            targetWords: ["archive"],
            targetRank: 3_500,
            createdAt: now.addingTimeInterval(-(ttlWindow * 2)),
            isSaved: true
        )

        context.insert(staleUnsaved)
        context.insert(freshUnsaved)
        context.insert(staleSaved)
        try context.save()

        let deletedCount = try cleanupExpiredUnsavedContent(
            in: context,
            now: now,
            ttl: ttlWindow
        )
        XCTAssertEqual(deletedCount, 1)

        let remainingIDs = Set(try fetchAllV4Records(in: context).map(\.articleId))
        XCTAssertEqual(remainingIDs, Set(["generated.fresh.unsaved", "generated.stale.saved"]))
    }

    private func makeInMemoryV4Container() throws -> ModelContainer {
        let schema = Schema(GeneratedContentSchemaV4.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeMigratedV4Container(storeURL: URL) throws -> ModelContainer {
        let schema = Schema(GeneratedContentSchemaV4.models)
        let configuration = ModelConfiguration(url: storeURL, allowsSave: true)
        return try ModelContainer(
            for: schema,
            migrationPlan: GeneratedContentMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private func seedV3Store(at storeURL: URL) throws {
        let schema = Schema(GeneratedContentSchemaV3.models)
        let configuration = ModelConfiguration(url: storeURL, allowsSave: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let legacy = GeneratedContentSchemaV3.GeneratedContent(
            articleId: "generated.article.v3",
            title: "Legacy Cached Content",
            bodyText: "Preserve this body during migration.",
            targetWords: ["throttle", "ephemeral"],
            createdAt: Date(timeIntervalSince1970: 1_705_100_000),
            isSaved: false
        )
        context.insert(legacy)
        try context.save()
    }

    private func fetchAllV4Records(
        in modelContext: ModelContext
    ) throws -> [GeneratedContentSchemaV4.GeneratedContent] {
        var descriptor = FetchDescriptor<GeneratedContentSchemaV4.GeneratedContent>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
        return try modelContext.fetch(descriptor)
    }

    private func cleanupExpiredUnsavedContent(
        in modelContext: ModelContext,
        now: Date,
        ttl: TimeInterval
    ) throws -> Int {
        let cutoff = now.addingTimeInterval(-ttl)
        let descriptor = FetchDescriptor<GeneratedContentSchemaV4.GeneratedContent>(
            predicate: #Predicate { row in
                row.isSaved == false && row.createdAt < cutoff
            }
        )

        let expiredRows = try modelContext.fetch(descriptor)
        for row in expiredRows {
            modelContext.delete(row)
        }
        if !expiredRows.isEmpty {
            try modelContext.save()
        }
        return expiredRows.count
    }
}

private enum GeneratedContentSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(3, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [GeneratedContent.self]
    }

    @Model
    final class GeneratedContent {
        @Attribute(.unique) var articleId: String
        var title: String
        var bodyText: String
        var targetWords: [String]
        var createdAt: Date
        var isSaved: Bool

        init(
            articleId: String,
            title: String,
            bodyText: String,
            targetWords: [String],
            createdAt: Date,
            isSaved: Bool
        ) {
            self.articleId = articleId
            self.title = title
            self.bodyText = bodyText
            self.targetWords = targetWords
            self.createdAt = createdAt
            self.isSaved = isSaved
        }
    }
}

private enum GeneratedContentSchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(4, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [GeneratedContent.self]
    }

    @Model
    final class GeneratedContent {
        @Attribute(.unique) var articleId: String
        var title: String
        var bodyText: String
        var targetWords: [String]
        var targetRank: Int?
        var createdAt: Date
        var isSaved: Bool

        init(
            articleId: String,
            title: String,
            bodyText: String,
            targetWords: [String],
            targetRank: Int?,
            createdAt: Date,
            isSaved: Bool
        ) {
            self.articleId = articleId
            self.title = title
            self.bodyText = bodyText
            self.targetWords = targetWords
            self.targetRank = targetRank
            self.createdAt = createdAt
            self.isSaved = isSaved
        }
    }
}

private enum GeneratedContentMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [GeneratedContentSchemaV3.self, GeneratedContentSchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: GeneratedContentSchemaV3.self,
                toVersion: GeneratedContentSchemaV4.self
            )
        ]
    }
}
