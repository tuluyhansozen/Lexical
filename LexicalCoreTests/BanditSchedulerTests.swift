import Foundation
import SwiftData
import UserNotifications
import XCTest
@testable import LexicalCore

@MainActor
final class BanditSchedulerTests: XCTestCase {
    private let successCountsKey = "bandit_success_counts_v3"
    private let totalCountsKey = "bandit_total_counts_v3"
    private let legacyTotalRewardsKey = "bandit_total_rewards_v3"
    private let lastEngagedKey = "bandit_last_engaged_date"
    private let ignoreStreakKey = "bandit_ignore_streak"
    private let lastScheduledKey = "bandit_last_scheduled"
    private let pendingPromptLemmaKey = "lexical.pending_prompt_lemma"
    private let pendingPromptDefinitionKey = "lexical.pending_prompt_definition"
    private let activeUserDefaultsKey = UserProfile.activeUserDefaultsKey

    override func setUp() {
        super.setUp()
        clearPersistedStoreFiles()
        clearBanditDefaults()
        clearActiveUserDefaults()
    }

    override func tearDown() {
        clearPersistedStoreFiles()
        clearBanditDefaults()
        clearActiveUserDefaults()
        super.tearDown()
    }

    func testMigratesLegacyIntSuccessCountsToDoubleDictionary() throws {
        let key = makeKey(.morning, .curious)
        let legacySuccess = [key: 3]
        let totals = [key: 5]

        UserDefaults.standard.set(try JSONEncoder().encode(legacySuccess), forKey: successCountsKey)
        UserDefaults.standard.set(try JSONEncoder().encode(totals), forKey: totalCountsKey)

        let scheduler = BanditScheduler()

        XCTAssertEqual(scheduler.successCounts[key], 3.0)
        XCTAssertEqual(scheduler.totalCounts[key], 5)
    }

    func testSelectArmPrefersOnlyUnpulledArm() async throws {
        let originalContainer = Persistence.sharedModelContainer
        defer { Persistence.sharedModelContainer = originalContainer }

        Persistence.sharedModelContainer = try makeInMemoryContainer()
        try seedActiveUser(rank: 1_000, userId: uniqueUserID(prefix: "bandit.unpulled"))

        let expectedKey = makeKey(.night, .quick)
        var totalCounts = Dictionary(uniqueKeysWithValues: allArmKeys().map { ($0, 3) })
        totalCounts[expectedKey] = 0

        seedBanditState(successCounts: [:], totalCounts: totalCounts, ignoreStreak: 0)

        let scheduler = BanditScheduler()
        let baseline = scheduler.totalCounts
        scheduler.scheduleTestNotification()

        let selectedKey = try await waitForSelectedArmKey(scheduler: scheduler, baseline: baseline)
        XCTAssertEqual(selectedKey, expectedKey)
    }

    func testSelectArmPrefersHighestMeanRewardWhenPullsEqual() async throws {
        let originalContainer = Persistence.sharedModelContainer
        defer { Persistence.sharedModelContainer = originalContainer }

        Persistence.sharedModelContainer = try makeInMemoryContainer()
        try seedActiveUser(rank: 1_000, userId: uniqueUserID(prefix: "bandit.exploit"))

        let expectedKey = makeKey(.morning, .curious)
        let totalCounts = Dictionary(uniqueKeysWithValues: allArmKeys().map { ($0, 10) })
        var successCounts = Dictionary(uniqueKeysWithValues: allArmKeys().map { ($0, 1.0) })
        successCounts[expectedKey] = 9.0

        seedBanditState(successCounts: successCounts, totalCounts: totalCounts, ignoreStreak: 0)

        let scheduler = BanditScheduler()
        let baseline = scheduler.totalCounts
        scheduler.scheduleTestNotification()

        let selectedKey = try await waitForSelectedArmKey(scheduler: scheduler, baseline: baseline)
        XCTAssertEqual(selectedKey, expectedKey)
    }

    func testRankAwareRewardBoostsAlignedRankByOnePointFive() async throws {
        let originalContainer = Persistence.sharedModelContainer
        defer { Persistence.sharedModelContainer = originalContainer }

        Persistence.sharedModelContainer = try makeInMemoryContainer()
        try seedActiveUser(rank: 1_000, userId: uniqueUserID(prefix: "bandit.rank"))

        seedBanditState(successCounts: [:], totalCounts: [:], ignoreStreak: 0)

        let scheduler = BanditScheduler()
        let rewardKey = makeKey(.morning, .curious)

        let withinBand = try makeNotificationResponse(
            actionIdentifier: "bandit.test.success",
            userInfo: [
                "bandit_slot": TimeSlot.morning.rawValue,
                "bandit_template": NotificationTemplate.curious.rawValue,
                "lemma": "alpha",
                "definition": "A",
                "rank": 1_200
            ]
        )
        scheduler.handleNotificationResponse(withinBand)
        let withinApplied = await waitUntil { abs((scheduler.successCounts[rewardKey] ?? 0.0) - 1.5) < 0.0001 }
        XCTAssertTrue(withinApplied)

        let outsideBand = try makeNotificationResponse(
            actionIdentifier: "bandit.test.success",
            userInfo: [
                "bandit_slot": TimeSlot.morning.rawValue,
                "bandit_template": NotificationTemplate.curious.rawValue,
                "lemma": "beta",
                "definition": "B",
                "rank": 2_000
            ]
        )
        scheduler.handleNotificationResponse(outsideBand)
        let outsideApplied = await waitUntil { abs((scheduler.successCounts[rewardKey] ?? 0.0) - 2.5) < 0.0001 }
        XCTAssertTrue(outsideApplied)

        XCTAssertEqual(scheduler.successCounts[rewardKey] ?? 0.0, 2.5, accuracy: 0.0001)

        let persistedData = try XCTUnwrap(UserDefaults.standard.data(forKey: successCountsKey))
        let persistedSuccess = try JSONDecoder().decode([String: Double].self, from: persistedData)
        XCTAssertEqual(persistedSuccess[rewardKey] ?? 0.0, 2.5, accuracy: 0.0001)
    }

    func testIgnoreStreakBoostsExplorationFactor() async throws {
        let originalContainer = Persistence.sharedModelContainer
        defer { Persistence.sharedModelContainer = originalContainer }

        Persistence.sharedModelContainer = try makeInMemoryContainer()
        try seedActiveUser(rank: 1_000, userId: uniqueUserID(prefix: "bandit.ignoreboost"))

        let explorationKey = makeKey(.morning, .curious)
        let exploitationKey = makeKey(.afternoon, .streak)

        var totalCounts = Dictionary(uniqueKeysWithValues: allArmKeys().map { ($0, 20) })
        var successCounts = Dictionary(uniqueKeysWithValues: allArmKeys().map { ($0, 2.0) })

        totalCounts[explorationKey] = 5
        successCounts[explorationKey] = 0.0
        successCounts[exploitationKey] = 20.0

        seedBanditState(successCounts: successCounts, totalCounts: totalCounts, ignoreStreak: 0)

        let lowIgnoreScheduler = BanditScheduler()
        let lowIgnoreBaseline = lowIgnoreScheduler.totalCounts
        lowIgnoreScheduler.scheduleTestNotification()
        let lowIgnoreSelected = try await waitForSelectedArmKey(scheduler: lowIgnoreScheduler, baseline: lowIgnoreBaseline)
        XCTAssertEqual(lowIgnoreSelected, exploitationKey)

        seedBanditState(successCounts: successCounts, totalCounts: totalCounts, ignoreStreak: 4)

        let highIgnoreScheduler = BanditScheduler()
        let highIgnoreBaseline = highIgnoreScheduler.totalCounts
        highIgnoreScheduler.scheduleTestNotification()
        let highIgnoreSelected = try await waitForSelectedArmKey(scheduler: highIgnoreScheduler, baseline: highIgnoreBaseline)
        XCTAssertEqual(highIgnoreSelected, explorationKey)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LexicalSchemaV3.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func seedBanditState(
        successCounts: [String: Double],
        totalCounts: [String: Int],
        ignoreStreak: Int
    ) {
        UserDefaults.standard.set(try? JSONEncoder().encode(successCounts), forKey: successCountsKey)
        UserDefaults.standard.set(try? JSONEncoder().encode(totalCounts), forKey: totalCountsKey)
        UserDefaults.standard.set(ignoreStreak, forKey: ignoreStreakKey)
    }

    private func seedActiveUser(rank: Int, userId: String) throws {
        let context = Persistence.sharedModelContainer.mainContext
        let profile = UserProfile(userId: userId, lexicalRank: rank)
        context.insert(profile)
        try context.save()
        setActiveUser(userId)
    }

    private func makeNotificationResponse(
        actionIdentifier: String,
        userInfo: [AnyHashable: Any]
    ) throws -> UNNotificationResponse {
        guard let notificationType = NSClassFromString("UNNotification") as? NSObject.Type,
              let responseType = NSClassFromString("UNNotificationResponse") as? NSObject.Type else {
            throw TestError.runtimeClassUnavailable
        }

        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        let notificationObject = notificationType.init()
        notificationObject.setValue(request, forKey: "request")

        let responseObject = responseType.init()
        responseObject.setValue(actionIdentifier, forKey: "actionIdentifier")
        responseObject.setValue(notificationObject, forKey: "notification")

        guard let response = responseObject as? UNNotificationResponse else {
            throw TestError.responseCastFailed
        }
        return response
    }

    private func waitForSelectedArmKey(
        scheduler: BanditScheduler,
        baseline: [String: Int],
        timeout: TimeInterval = 1.0
    ) async throws -> String {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let selected = selectedArmKey(baseline: baseline, updated: scheduler.totalCounts) {
                return selected
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        if let selected = selectedArmKey(baseline: baseline, updated: scheduler.totalCounts) {
            return selected
        }
        throw TestError.selectionTimedOut
    }

    private func selectedArmKey(baseline: [String: Int], updated: [String: Int]) -> String? {
        let allKeys = Set(baseline.keys).union(updated.keys)
        let deltas = allKeys.compactMap { key -> (String, Int)? in
            let delta = (updated[key] ?? 0) - (baseline[key] ?? 0)
            return delta == 0 ? nil : (key, delta)
        }

        guard deltas.count == 1, deltas[0].1 == 1 else { return nil }
        return deltas[0].0
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollNanoseconds: UInt64 = 20_000_000,
        condition: () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return condition()
    }

    private func allArmKeys() -> [String] {
        TimeSlot.allCases.flatMap { slot in
            NotificationTemplate.allCases.map { template in
                makeKey(slot, template)
            }
        }
    }

    private func makeKey(_ slot: TimeSlot, _ template: NotificationTemplate) -> String {
        "\(slot.rawValue)_\(template.rawValue)"
    }

    private func setActiveUser(_ userId: String) {
        if let suiteDefaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) {
            suiteDefaults.set(userId, forKey: activeUserDefaultsKey)
        }
        UserDefaults.standard.set(userId, forKey: activeUserDefaultsKey)
    }

    private func clearActiveUserDefaults() {
        if let suiteDefaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) {
            suiteDefaults.removeObject(forKey: activeUserDefaultsKey)
        }
        UserDefaults.standard.removeObject(forKey: activeUserDefaultsKey)
    }

    private func clearBanditDefaults() {
        let defaults = UserDefaults.standard
        [
            successCountsKey,
            totalCountsKey,
            legacyTotalRewardsKey,
            lastEngagedKey,
            ignoreStreakKey,
            lastScheduledKey,
            pendingPromptLemmaKey,
            pendingPromptDefinitionKey
        ].forEach { defaults.removeObject(forKey: $0) }
    }

    private func clearPersistedStoreFiles() {
        let fileManager = FileManager.default
        var storeURLs: [URL] = []

        if let sharedURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Persistence.appGroupIdentifier) {
            storeURLs.append(sharedURL.appendingPathComponent("Lexical.sqlite"))
        }
        storeURLs.append(URL.documentsDirectory.appendingPathComponent("Lexical.sqlite"))

        for storeURL in storeURLs {
            let siblings = [
                storeURL,
                URL(fileURLWithPath: storeURL.path + "-shm"),
                URL(fileURLWithPath: storeURL.path + "-wal")
            ]

            for url in siblings where fileManager.fileExists(atPath: url.path) {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private func uniqueUserID(prefix: String) -> String {
        "\(prefix).\(UUID().uuidString.lowercased())"
    }

    private enum TestError: Error {
        case runtimeClassUnavailable
        case responseCastFailed
        case selectionTimedOut
    }
}
