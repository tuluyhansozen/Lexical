import Foundation
import SwiftData
import XCTest
@testable import LexicalCore

@MainActor
final class DiscoveredLexemeServiceTests: XCTestCase {
    func testIngestionUpsertsAndMergesPayload() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = "discovered.user"
        let service = DiscoveredLexemeIngestionService()

        let firstInsert = try service.ingest(
            candidates: [
                DiscoveredLexemeCandidate(
                    lemma: "Spectacle",
                    definition: "A visually striking performance.",
                    partOfSpeech: "noun",
                    synonyms: ["show"],
                    exampleSentences: ["The opening ceremony was a spectacle."],
                    confidence: 0.62
                ),
                DiscoveredLexemeCandidate(
                    lemma: "bad candidate",
                    definition: "Should be filtered due to invalid lemma."
                )
            ],
            sourceArticleId: "article-1",
            modelContext: context,
            userId: userId
        )

        XCTAssertEqual(firstInsert, 1)

        let secondInsert = try service.ingest(
            candidates: [
                DiscoveredLexemeCandidate(
                    lemma: "spectacle",
                    definition: "An impressive display or event.",
                    synonyms: ["display", "show"],
                    exampleSentences: ["Fireworks created a bright spectacle."],
                    confidence: 0.91
                )
            ],
            sourceArticleId: "article-2",
            modelContext: context,
            userId: userId
        )

        XCTAssertEqual(secondInsert, 1)

        let rows = try context.fetch(
            FetchDescriptor<DiscoveredLexeme>(
                predicate: #Predicate { $0.userId == userId }
            )
        )
        XCTAssertEqual(rows.count, 1)

        guard let row = rows.first else { return XCTFail("expected discovered row") }
        XCTAssertEqual(row.lemma, "spectacle")
        XCTAssertEqual(row.seenCount, 2)
        XCTAssertEqual(row.sourceArticleId, "article-2")
        XCTAssertGreaterThanOrEqual(row.confidence, 0.91)
        XCTAssertTrue(row.synonyms.contains("show"))
        XCTAssertTrue(row.synonyms.contains("display"))
        XCTAssertFalse(row.exampleSentences.isEmpty)
    }

    func testPromotionCreatesCanonicalLexemeFromDiscoveredPayload() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = "promotion.user"
        let ingestion = DiscoveredLexemeIngestionService()
        let promotion = LexemePromotionService()

        _ = try ingestion.ingest(
            candidates: [
                DiscoveredLexemeCandidate(
                    lemma: "retrospect",
                    definition: "Consideration of past events.",
                    partOfSpeech: "noun",
                    ipa: "/ˈretrəˌspekt/",
                    synonyms: ["hindsight"],
                    exampleSentences: ["In retrospect, the plan was risky."]
                )
            ],
            sourceArticleId: "article-retro",
            modelContext: context,
            userId: userId
        )

        let lexeme = try promotion.upsertCanonicalLexeme(
            lemma: "retrospect",
            userId: userId,
            fallbackDefinition: nil,
            fallbackSentence: nil,
            modelContext: context
        )
        try context.save()

        XCTAssertEqual(lexeme.lemma, "retrospect")
        XCTAssertEqual(lexeme.basicMeaning, "Consideration of past events.")
        XCTAssertEqual(lexeme.partOfSpeech, "noun")
        XCTAssertEqual(lexeme.ipa, "/ˈretrəˌspekt/")
        XCTAssertEqual(lexeme.sampleSentence, "In retrospect, the plan was risky.")

        let discovered = try promotion.discoveredLexeme(
            lemma: "retrospect",
            userId: userId,
            modelContext: context
        )
        XCTAssertNotNil(discovered?.promotedAt)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LexicalSchemaV6.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
