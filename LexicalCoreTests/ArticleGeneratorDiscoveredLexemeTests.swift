import Foundation
import SwiftData
import XCTest
@testable import LexicalCore

@MainActor
final class ArticleGeneratorDiscoveredLexemeTests: XCTestCase {
    private let activeUserDefaultsKey = UserProfile.activeUserDefaultsKey

    override func tearDown() {
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        defaults.removeObject(forKey: activeUserDefaultsKey)
        super.tearDown()
    }

    func testGenerateArticlePersistsGlossaryCandidates() async throws {
        let originalContainer = Persistence.sharedModelContainer
        defer { Persistence.sharedModelContainer = originalContainer }

        let container = try makeInMemoryContainer()
        Persistence.sharedModelContainer = container

        let context = ModelContext(container)
        let userId = "article.discovered.\(UUID().uuidString)"
        context.insert(UserProfile(userId: userId))
        try context.save()

        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        defaults.set(userId, forKey: activeUserDefaultsKey)

        let provider = StaticJSONLLMProvider(
            response: """
            {
              "title": "Sound in Cities",
              "body_text": "Urban sound design is not only about reducing noise; it is about shaping attention and comfort in real places where people work, learn, and recover. A city can feel calm or chaotic depending on how transit lines, building materials, and public spaces interact. In this context, a single spectacle can attract attention quickly, but sustained clarity depends on repeated small design choices that guide behavior over time.\\n\\nWhen planners evaluate a district in retrospect, they often discover that short-term convenience created long-term friction for pedestrians and residents. Better outcomes appear when teams compare trade-offs openly, test ideas at small scale, and refine layout decisions before full rollout. This process makes communication clearer, improves collaboration across stakeholders, and helps communities adapt without losing usability.",
              "used_reinforcement_words": ["spectacle"],
              "used_stretch_words": ["retrospect"],
              "glossary": [
                {
                  "lemma": "spectacle",
                  "definition": "A striking display that attracts attention.",
                  "part_of_speech": "noun",
                  "ipa": "/ˈspɛktəkəl/",
                  "synonyms": ["display", "show"],
                  "examples": ["The parade was a spectacle."],
                  "confidence": 0.9
                },
                {
                  "lemma": "retrospect",
                  "definition": "Consideration of events after they happen.",
                  "part_of_speech": "noun",
                  "synonyms": ["hindsight"],
                  "examples": ["In retrospect, the plan was obvious."]
                }
              ]
            }
            """
        )

        let generator = ArticleGenerator(
            store: ArticleStore(),
            llmProvider: provider
        )
        let profile = InterestProfile(selectedTags: ["Technology"])

        let article = try await generator.generateArticle(
            profile: profile,
            targetWords: ["spectacle", "retrospect"],
            reinforcementWords: ["spectacle"],
            stretchWords: ["retrospect"]
        )

        XCTAssertEqual(article.title, "Sound in Cities")
        XCTAssertTrue(article.targetWords.contains("spectacle"))
        XCTAssertTrue(article.targetWords.contains("retrospect"))

        let discoveredRows = try context.fetch(
            FetchDescriptor<DiscoveredLexeme>(
                predicate: #Predicate { row in
                    row.userId == userId
                }
            )
        )
        XCTAssertEqual(discoveredRows.count, 2)

        let spectacle = try XCTUnwrap(discoveredRows.first(where: { $0.lemma == "spectacle" }))
        XCTAssertEqual(spectacle.partOfSpeech, "noun")
        XCTAssertEqual(spectacle.definition, "A striking display that attracts attention.")
        XCTAssertTrue(spectacle.synonyms.contains("display"))
        XCTAssertEqual(spectacle.sourceArticleId?.isEmpty, false)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LexicalSchemaV6.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

private final class StaticJSONLLMProvider: ArticleLLMProvider {
    private let response: String

    init(response: String) {
        self.response = response
    }

    func generateContent(prompt: String) async throws -> String {
        _ = prompt
        return response
    }
}
