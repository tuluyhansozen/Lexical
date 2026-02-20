import Foundation
import SwiftData
import XCTest
@testable import LexicalCore

@MainActor
final class LexicalTargetingServiceTests: XCTestCase {
    private let activeUserDefaultsKey = UserProfile.activeUserDefaultsKey

    override func setUp() {
        super.setUp()
        clearActiveUserDefaults()
    }

    override func tearDown() {
        clearActiveUserDefaults()
        super.tearDown()
    }

    func testSuggestionCandidatesPreferNewStatesNearRank() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "targeting.new-first")
        try seedActiveUser(
            userId: userId,
            lexicalRank: 2_000,
            ignoredWords: [],
            context: context
        )

        context.insert(
            LexemeDefinition(
                lemma: "orbit",
                rank: 2_400,
                basicMeaning: "Path around a body"
            )
        )
        context.insert(
            LexemeDefinition(
                lemma: "anchor",
                rank: 2_001,
                basicMeaning: "Heavy object used to moor a ship"
            )
        )
        context.insert(UserWordState(userId: userId, lemma: "orbit", status: .new))
        try context.save()

        let service = LexicalTargetingService()
        let candidates = service.newWordSuggestionCandidates(
            modelContext: context,
            limit: 2
        )

        XCTAssertEqual(candidates.first?.lemma, "orbit")
        XCTAssertTrue(candidates.contains(where: { $0.lemma == "anchor" }))
    }

    func testSuggestionCandidatesIncludeUnseenWhenNewPoolEmpty() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "targeting.unseen-fallback")
        try seedActiveUser(
            userId: userId,
            lexicalRank: 2_000,
            ignoredWords: [],
            context: context
        )

        context.insert(
            LexemeDefinition(
                lemma: "aurora",
                rank: 1_980,
                basicMeaning: "Natural light in the sky"
            )
        )
        try context.save()

        let service = LexicalTargetingService()
        let candidates = service.newWordSuggestionCandidates(
            modelContext: context,
            limit: 1
        )

        XCTAssertEqual(candidates.map(\.lemma), ["aurora"])
    }

    func testSuggestionCandidatesFallbackToNearestOutOfRange() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "targeting.nearest")
        try seedActiveUser(
            userId: userId,
            lexicalRank: 2_000,
            ignoredWords: [],
            context: context
        )

        context.insert(
            LexemeDefinition(
                lemma: "nearone",
                rank: 2_700,
                basicMeaning: "Closest out-of-range option"
            )
        )
        context.insert(
            LexemeDefinition(
                lemma: "neartwo",
                rank: 2_800,
                basicMeaning: "Second closest out-of-range option"
            )
        )
        context.insert(
            LexemeDefinition(
                lemma: "farone",
                rank: 5_000,
                basicMeaning: "Far out-of-range option"
            )
        )
        try context.save()

        let service = LexicalTargetingService()
        let candidates = service.newWordSuggestionCandidates(
            modelContext: context,
            limit: 1
        )

        XCTAssertEqual(candidates.map(\.lemma), ["nearone"])
    }

    func testSuggestionCandidatesExcludeIgnoredAndInvalidLexemes() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "targeting.exclude")
        try seedActiveUser(
            userId: userId,
            lexicalRank: 2_000,
            ignoredWords: ["orbit"],
            context: context
        )

        context.insert(
            LexemeDefinition(
                lemma: "orbit",
                rank: 2_100,
                basicMeaning: "Path around a body"
            )
        )
        context.insert(
            LexemeDefinition(
                lemma: "123bad",
                rank: 2_050,
                basicMeaning: "Invalid lemma format"
            )
        )
        context.insert(
            LexemeDefinition(
                lemma: "anchor",
                rank: 2_050,
                basicMeaning: "Heavy object used to moor a ship"
            )
        )
        context.insert(UserWordState(userId: userId, lemma: "orbit", status: .new))
        try context.save()

        let service = LexicalTargetingService()
        let candidates = service.newWordSuggestionCandidates(
            modelContext: context,
            limit: 3
        )

        XCTAssertEqual(candidates.map(\.lemma), ["anchor"])
    }

    func testSuggestionCandidatesDeterministicOrdering() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let userId = uniqueUserID(prefix: "targeting.order")
        try seedActiveUser(
            userId: userId,
            lexicalRank: 2_000,
            ignoredWords: [],
            context: context
        )

        context.insert(
            LexemeDefinition(
                lemma: "badge",
                rank: 2_200,
                basicMeaning: "Small badge"
            )
        )
        context.insert(
            LexemeDefinition(
                lemma: "alpha",
                rank: 2_200,
                basicMeaning: "First letter"
            )
        )
        context.insert(
            LexemeDefinition(
                lemma: "apple",
                rank: 2_200,
                basicMeaning: "Fruit"
            )
        )
        try context.save()

        let service = LexicalTargetingService()
        let candidates = service.newWordSuggestionCandidates(
            modelContext: context,
            limit: 3
        )

        XCTAssertEqual(candidates.map(\.lemma), ["alpha", "apple", "badge"])
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LexicalSchemaV6.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func seedActiveUser(
        userId: String,
        lexicalRank: Int,
        ignoredWords: [String],
        context: ModelContext
    ) throws {
        let profile = UserProfile(
            userId: userId,
            lexicalRank: lexicalRank,
            ignoredWords: ignoredWords
        )
        context.insert(profile)
        try context.save()

        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        defaults.set(userId, forKey: activeUserDefaultsKey)
    }

    private func clearActiveUserDefaults() {
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        defaults.removeObject(forKey: activeUserDefaultsKey)
    }

    private func uniqueUserID(prefix: String) -> String {
        "\(prefix).\(UUID().uuidString)"
    }
}
