import SwiftData
import XCTest
import LexicalCore
@testable import Lexical

@MainActor
final class WordInfoSheetUXTests: XCTestCase {
    private var defaults: UserDefaults {
        UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
    }

    override func tearDown() {
        defaults.removeObject(forKey: UserProfile.activeUserDefaultsKey)
        super.tearDown()
    }

    func testShortPayloadUsesDynamicFractionDetent() {
        let data = WordDetailData(
            lemma: "brief",
            partOfSpeech: "noun",
            definition: "A short definition.",
            synonyms: ["outline", "summary"],
            sentences: ["A brief sentence."]
        )

        let fraction = WordInfoSheetPresentation.initialFraction(for: data)
        XCTAssertGreaterThanOrEqual(fraction, WordInfoSheetPresentation.minimumFraction)
        XCTAssertLessThanOrEqual(fraction, WordInfoSheetPresentation.maximumFraction)
        XCTAssertEqual(
            WordInfoSheetPresentation.detents(for: data),
            Set([.fraction(fraction)])
        )
    }

    func testLongPayloadUsesDynamicFractionAndDoesNotForceLargeDetent() {
        let longSentence = String(repeating: "long ", count: 30).trimmingCharacters(in: .whitespaces)
        let data = WordDetailData(
            lemma: "extensive",
            partOfSpeech: "adjective",
            definition: String(repeating: "detailed ", count: 45),
            synonyms: (1...10).map { "synonym-\($0)" },
            sentences: Array(repeating: longSentence, count: 5)
        )

        let fraction = WordInfoSheetPresentation.initialFraction(for: data)
        XCTAssertEqual(fraction, WordInfoSheetPresentation.maximumFraction)
        XCTAssertEqual(WordInfoSheetPresentation.detents(for: data), Set([.fraction(fraction)]))
    }

    func testTypicalPayloadRemainsDynamicAndNotFullscreen() {
        let data = WordDetailData(
            lemma: "spectacle",
            partOfSpeech: "noun",
            definition: "A visually striking performance or display.",
            synonyms: ["glasses", "eyeglasses", "specs"],
            sentences: [
                "If the rollout derails overnight, what spectacle helps everyone recover without blame?",
                "\"Better spectacle starts now,\" she said, \"or this client will walk by Friday.\"",
                "While the team had enough talent, poor spectacle kept small issues from being resolved quickly."
            ]
        )

        let fraction = WordInfoSheetPresentation.initialFraction(for: data)
        XCTAssertGreaterThan(fraction, WordInfoSheetPresentation.minimumFraction)
        XCTAssertLessThanOrEqual(fraction, WordInfoSheetPresentation.maximumFraction)
        XCTAssertEqual(WordInfoSheetPresentation.detents(for: data), Set([.fraction(fraction)]))
    }

    func testPrimaryActionDetentUsesExtraHeight() {
        let data = WordDetailData(
            lemma: "spectacle",
            partOfSpeech: "noun",
            definition: "A visually striking performance or display.",
            synonyms: ["glasses", "eyeglasses", "specs"],
            sentences: [
                "Use spectacle in a sentence.",
                "The show became a spectacle.",
                "What spectacle helps everyone recover?"
            ]
        )

        let withoutCTA = WordInfoSheetPresentation.initialFraction(for: data)
        let withCTA = WordInfoSheetPresentation.initialFraction(for: data, includesPrimaryAction: true)

        XCTAssertGreaterThan(withCTA, withoutCTA)
        XCTAssertEqual(
            WordInfoSheetPresentation.detents(for: data, includesPrimaryAction: true),
            Set([.fraction(withCTA)])
        )
    }

    func testBuildDoesNotTruncateDiscoveredSynonyms() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let lemma = "uxlongsynonymsword"
        let userId = "ux.test.user"
        defaults.set(userId, forKey: UserProfile.activeUserDefaultsKey)

        let synonyms = (1...10).map { "synonym\($0)" }
        context.insert(
            DiscoveredLexeme(
                userId: userId,
                lemma: lemma,
                definition: "Definition",
                synonyms: synonyms,
                exampleSentences: []
            )
        )
        try context.save()

        let data = WordDetailDataBuilder.build(
            for: makeCard(lemma: lemma),
            modelContext: context
        )

        XCTAssertEqual(data.synonyms.count, 10)
        XCTAssertEqual(data.synonyms, synonyms)
    }

    func testBuildDoesNotTruncateDiscoveredExampleSentences() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let lemma = "uxlongsentenceword"
        let userId = "ux.test.user.sentences"
        defaults.set(userId, forKey: UserProfile.activeUserDefaultsKey)

        let examples = [
            "Sentence one for this word.",
            "Sentence two for this word.",
            "Sentence three for this word.",
            "Sentence four for this word.",
            "Sentence five for this word."
        ]
        context.insert(
            DiscoveredLexeme(
                userId: userId,
                lemma: lemma,
                definition: "Definition",
                synonyms: [],
                exampleSentences: examples
            )
        )
        try context.save()

        let card = ReviewCard(
            lemma: lemma,
            originalWord: lemma,
            contextSentence: "",
            definition: nil,
            stability: 0.2,
            difficulty: 0.3,
            retrievability: 0.2,
            nextReviewDate: nil,
            lastReviewDate: nil,
            reviewCount: 0,
            createdAt: Date(),
            status: .new
        )

        let data = WordDetailDataBuilder.build(for: card, modelContext: context)
        XCTAssertEqual(data.sentences.count, 5)
        XCTAssertEqual(data.sentences, examples)
    }

    func testIngestionDoesNotTruncateSynonymsOrExamples() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let userId = "ux.ingest.user"
        let lemma = "uxingestword"
        let synonyms = (1...10).map { "ingest-synonym-\($0)" }
        let examples = (1...5).map { "Ingest example sentence \($0)." }

        let service = DiscoveredLexemeIngestionService()
        _ = try service.ingest(
            candidates: [
                DiscoveredLexemeCandidate(
                    lemma: lemma,
                    definition: "Definition",
                    synonyms: synonyms,
                    exampleSentences: examples
                )
            ],
            sourceArticleId: "article.test",
            modelContext: context,
            userId: userId
        )

        let key = DiscoveredLexeme.makeKey(userId: userId, lemma: lemma)
        let descriptor = FetchDescriptor<DiscoveredLexeme>(
            predicate: #Predicate { $0.userLemmaKey == key }
        )
        let row = try XCTUnwrap(try context.fetch(descriptor).first)
        XCTAssertEqual(row.synonyms.count, 10)
        XCTAssertEqual(row.synonyms, synonyms)
        XCTAssertEqual(row.exampleSentences.count, 5)
        XCTAssertEqual(row.exampleSentences, examples)
    }

    func testBuildEnsuringSeedDataHydratesWhenInitialLookupIsEmpty() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let lemma = "spectacle"
        let snapshot = SeedLexemeIndex.Snapshot(
            ipa: nil,
            definition: "A visually striking performance or display.",
            synonyms: ["show", "display", "production"],
            sentences: [
                "The opening ceremony was a spectacle.",
                "Everyone watched the spectacle unfold."
            ]
        )

        var seedLoaded = false
        var ensureCallCount = 0

        let data = await WordDetailDataBuilder.buildEnsuringSeedData(
            for: makeCard(lemma: lemma),
            modelContext: context,
            seedLookup: { _ in
                seedLoaded ? snapshot : nil
            },
            ensureSeedLoaded: {
                ensureCallCount += 1
                seedLoaded = true
            }
        )

        XCTAssertEqual(ensureCallCount, 1)
        XCTAssertEqual(data.definition, snapshot.definition)
        XCTAssertEqual(data.synonyms, snapshot.synonyms)
        XCTAssertEqual(data.sentences, snapshot.sentences)
    }

    func testBuildEnsuringSeedDataAttemptsHydrationWhenAnySectionIsMissing() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let card = ReviewCard(
            lemma: "present",
            originalWord: "present",
            contextSentence: "Present content sentence.",
            definition: "Already defined.",
            stability: 0.2,
            difficulty: 0.3,
            retrievability: 0.2,
            nextReviewDate: nil,
            lastReviewDate: nil,
            reviewCount: 0,
            createdAt: Date(),
            status: .new
        )

        var ensureCalled = false

        let data = await WordDetailDataBuilder.buildEnsuringSeedData(
            for: card,
            modelContext: context,
            seedLookup: { _ in nil },
            ensureSeedLoaded: {
                ensureCalled = true
            }
        )

        XCTAssertTrue(ensureCalled)
        XCTAssertEqual(data.definition, "Already defined.")
        XCTAssertEqual(data.sentences, ["Present content sentence."])
    }

    func testBuildEnsuringSeedDataHydratesWhenOnlyContextSentenceExistsInitially() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let lemma = "contextonly"
        let card = ReviewCard(
            lemma: lemma,
            originalWord: lemma,
            contextSentence: "Context-only sentence.",
            definition: nil,
            stability: 0.2,
            difficulty: 0.3,
            retrievability: 0.2,
            nextReviewDate: nil,
            lastReviewDate: nil,
            reviewCount: 0,
            createdAt: Date(),
            status: .new
        )
        let snapshot = SeedLexemeIndex.Snapshot(
            ipa: nil,
            definition: "Seed definition",
            synonyms: ["seed synonym"],
            sentences: ["Seed example sentence."]
        )

        var seedLoaded = false
        var ensureCallCount = 0

        let data = await WordDetailDataBuilder.buildEnsuringSeedData(
            for: card,
            modelContext: context,
            seedLookup: { _ in
                seedLoaded ? snapshot : nil
            },
            ensureSeedLoaded: {
                ensureCallCount += 1
                seedLoaded = true
            }
        )

        XCTAssertEqual(ensureCallCount, 1)
        XCTAssertEqual(data.definition, "Seed definition")
        XCTAssertEqual(data.synonyms, ["seed synonym"])
        XCTAssertEqual(data.sentences, ["Context-only sentence.", "Seed example sentence."])
    }

    func testSeedLexemeIndexCanLoadSpectacleFromBundledSeedData() async {
        await SeedLexemeIndex.ensureLoaded()
        let snapshot = SeedLexemeIndex.lookup(lemma: "spectacle")

        XCTAssertNotNil(snapshot)
        XCTAssertFalse(snapshot?.definition?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LexicalSchemaV6.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: schema,
            migrationPlan: LexicalMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private func makeCard(lemma: String) -> ReviewCard {
        ReviewCard(
            lemma: lemma,
            originalWord: lemma,
            contextSentence: "",
            definition: nil,
            stability: 0.2,
            difficulty: 0.3,
            retrievability: 0.2,
            nextReviewDate: nil,
            lastReviewDate: nil,
            reviewCount: 0,
            createdAt: Date(),
            status: .new
        )
    }
}
