import Foundation
import SwiftData
import XCTest
@testable import LexicalCore

@MainActor
final class NotificationTriageServiceTests: XCTestCase {
    private let activeUserDefaultsKey = UserProfile.activeUserDefaultsKey

    override func setUp() {
        super.setUp()
        clearActiveUserDefaults()
        clearPendingPromptDefaults()
    }

    override func tearDown() {
        clearActiveUserDefaults()
        clearPendingPromptDefaults()
        super.tearDown()
    }

    func testPayloadParsesLemmaAndRank() {
        let service = NotificationTriageService()

        let payload = service.payload(
            from: [
                "lemma": "  Orbit  ",
                "definition": "The curved path around a body",
                "rank": "1200"
            ]
        )

        XCTAssertEqual(payload.normalizedLemma, "orbit")
        XCTAssertEqual(payload.definition, "The curved path around a body")
        XCTAssertEqual(payload.rank, 1200)
    }

    func testAddToDeckCreatesLexemeAndLearningState() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try seedActiveUser(userID: uniqueUserID(prefix: "triage.add"), context: context)

        let service = NotificationTriageService()
        let payload = NotificationTriagePayload(
            lemma: "  Orbit  ",
            definition: "The curved path around a body",
            rank: 1200
        )

        let storedLemma = try service.addToDeck(payload, modelContext: context)
        XCTAssertEqual(storedLemma, "orbit")

        let lexemeDescriptor = FetchDescriptor<LexemeDefinition>(
            predicate: #Predicate { $0.lemma == "orbit" }
        )
        let lexeme = try XCTUnwrap(context.fetch(lexemeDescriptor).first)
        XCTAssertEqual(lexeme.basicMeaning, "The curved path around a body")

        let activeUser = UserProfile.resolveActiveProfile(modelContext: context)
        let key = UserWordState.makeKey(userId: activeUser.userId, lemma: "orbit")
        let stateDescriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { $0.userLemmaKey == key }
        )
        let state = try XCTUnwrap(context.fetch(stateDescriptor).first)
        XCTAssertEqual(state.status, .learning)
        XCTAssertNotNil(state.nextReviewDate)
    }

    func testIgnoreWordMarksProfileAndStateIgnored() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try seedActiveUser(userID: uniqueUserID(prefix: "triage.ignore"), context: context)

        let service = NotificationTriageService()
        let payload = NotificationTriagePayload(
            lemma: "  Nebula  ",
            definition: "A cloud of gas",
            rank: 4000
        )

        _ = try service.addToDeck(payload, modelContext: context)
        let ignoredLemma = try service.ignoreWord(payload, modelContext: context)
        XCTAssertEqual(ignoredLemma, "nebula")

        let activeUser = UserProfile.resolveActiveProfile(modelContext: context)
        XCTAssertTrue(activeUser.ignoredWords.contains("nebula"))

        let key = UserWordState.makeKey(userId: activeUser.userId, lemma: "nebula")
        let stateDescriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { $0.userLemmaKey == key }
        )
        let state = try XCTUnwrap(context.fetch(stateDescriptor).first)
        XCTAssertEqual(state.status, .ignored)
    }

    func testStagePromptRoutePublishesPendingPrompt() {
        let service = NotificationTriageService()
        let payload = NotificationTriagePayload(
            lemma: "  Aurora  ",
            definition: "Natural light display",
            rank: nil
        )

        let expectation = expectation(description: "Prompt route published")
        let observer = NotificationCenter.default.addObserver(
            forName: .lexicalOpenPromptCard,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertEqual(notification.userInfo?["lemma"] as? String, "aurora")
            XCTAssertEqual(notification.userInfo?["definition"] as? String, "Natural light display")
            expectation.fulfill()
        }

        service.stagePromptRoute(payload)

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)

        XCTAssertEqual(UserDefaults.standard.string(forKey: "lexical.pending_prompt_lemma"), "aurora")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "lexical.pending_prompt_definition"), "Natural light display")
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LexicalSchemaV3.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func seedActiveUser(userID: String, context: ModelContext) throws {
        let profile = UserProfile(userId: userID, lexicalRank: 1_000)
        context.insert(profile)
        try context.save()

        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        defaults.set(userID, forKey: activeUserDefaultsKey)
    }

    private func clearActiveUserDefaults() {
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard
        defaults.removeObject(forKey: activeUserDefaultsKey)
    }

    private func clearPendingPromptDefaults() {
        UserDefaults.standard.removeObject(forKey: "lexical.pending_prompt_lemma")
        UserDefaults.standard.removeObject(forKey: "lexical.pending_prompt_definition")
    }

    private func uniqueUserID(prefix: String) -> String {
        "\(prefix).\(UUID().uuidString)"
    }
}
