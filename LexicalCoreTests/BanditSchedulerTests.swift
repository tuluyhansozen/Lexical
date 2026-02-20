import Foundation
import SwiftData
import UserNotifications
import XCTest
@testable import LexicalCore

@MainActor
final class BanditSchedulerTests: XCTestCase {
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

    func testReminderSlotsForInactivityDayZeroAreThree() {
        let scheduler = BanditScheduler()
        let slots = scheduler.reminderSlots(forInactiveDay: 0)
        XCTAssertEqual(slots, [.nineAM, .twoPM, .eightPM])
    }

    func testReminderSlotsForInactivityDayThreeAreTwo() {
        let scheduler = BanditScheduler()
        let slots = scheduler.reminderSlots(forInactiveDay: 3)
        XCTAssertEqual(slots, [.twoPM, .eightPM])
    }

    func testReminderSlotsForInactivityDaySevenIsOne() {
        let scheduler = BanditScheduler()
        let slots = scheduler.reminderSlots(forInactiveDay: 7)
        XCTAssertEqual(slots, [.eightPM])
    }

    func testReminderSlotsForInactivityDayTwelveUsesWeeklyPattern() {
        let scheduler = BanditScheduler()
        let calendar = Calendar(identifier: .gregorian)

        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 2, day: 24))!
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 2, day: 25))!
        let thursday = calendar.date(from: DateComponents(year: 2026, month: 2, day: 26))!
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!

        XCTAssertTrue(scheduler.shouldScheduleWeeklyNudge(forDate: tuesday))
        XCTAssertFalse(scheduler.shouldScheduleWeeklyNudge(forDate: wednesday))
        XCTAssertTrue(scheduler.shouldScheduleWeeklyNudge(forDate: thursday))
        XCTAssertTrue(scheduler.shouldScheduleWeeklyNudge(forDate: sunday))
    }

    func testSlotIntentMappingNineAndTwoAreSuggestionsEightIsReview() {
        XCTAssertEqual(BanditScheduler.ReminderSlot.nineAM.deliveryKind, .suggestion)
        XCTAssertEqual(BanditScheduler.ReminderSlot.twoPM.deliveryKind, .suggestion)
        XCTAssertEqual(BanditScheduler.ReminderSlot.eightPM.deliveryKind, .reviewReminder)
    }

    func testBuildRollingRemindersGeneratesExpectedCountForActiveUser() {
        let scheduler = BanditScheduler()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 20, hour: 0, minute: 1))!

        let plan = scheduler.buildReminderPlan(
            now: now,
            lastInteractiveDate: now,
            horizonDays: 2,
            calendar: calendar
        )

        XCTAssertEqual(plan.count, 6)
    }

    func testBuildRollingRemindersTapersAcrossFutureDays() {
        let scheduler = BanditScheduler()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 20, hour: 0, minute: 1))!
        let lastInteractive = calendar.date(byAdding: .day, value: -1, to: now)!

        let plan = scheduler.buildReminderPlan(
            now: now,
            lastInteractiveDate: lastInteractive,
            horizonDays: 5,
            calendar: calendar
        )

        XCTAssertEqual(plan.count, 10)
    }

    func testReminderIdentifiersAreDeterministicByDateAndSlot() {
        let scheduler = BanditScheduler()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 20, hour: 0, minute: 1))!

        let plan = scheduler.buildReminderPlan(
            now: now,
            lastInteractiveDate: now,
            horizonDays: 1,
            calendar: calendar
        )

        XCTAssertEqual(plan.map(\.identifier), [
            "LEXICAL_REMINDER_20260220_0900",
            "LEXICAL_REMINDER_20260220_1400",
            "LEXICAL_REMINDER_20260220_2000"
        ])
    }

    func testReviewedDaySkipsReviewReminderButKeepsSuggestionSlots() {
        let scheduler = BanditScheduler()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 20, hour: 0, minute: 1))!
        let reviewedDay = Set([calendar.startOfDay(for: now)])

        let plan = scheduler.buildReminderPlan(
            now: now,
            lastInteractiveDate: now,
            reviewedInteractiveDays: reviewedDay,
            horizonDays: 1,
            calendar: calendar
        )

        XCTAssertEqual(plan.map(\.slot), [.nineAM, .twoPM])
        XCTAssertTrue(plan.allSatisfy { $0.deliveryKind == .suggestion })
    }

    func testLastInteractiveReviewDateIgnoresImplicitExposure() throws {
        let originalContainer = Persistence.sharedModelContainer
        defer { Persistence.sharedModelContainer = originalContainer }

        Persistence.sharedModelContainer = try makeInMemoryContainer()
        let scheduler = BanditScheduler()
        let context = Persistence.sharedModelContainer.mainContext
        let userId = uniqueUserID(prefix: "bandit.interactive")
        let active = UserProfile(userId: userId, lexicalRank: 1_200)
        context.insert(active)
        try context.save()
        setActiveUser(userId)

        let now = Date()
        let interactiveDate = Calendar.current.date(byAdding: .day, value: -5, to: now)!
        let implicitDate = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        context.insert(
            ReviewEvent(
                userId: userId,
                lemma: "alpha",
                grade: 3,
                reviewDate: interactiveDate,
                durationMs: 600,
                scheduledDays: 1.0,
                reviewState: "good"
            )
        )
        context.insert(
            ReviewEvent(
                userId: userId,
                lemma: "beta",
                grade: 3,
                reviewDate: implicitDate,
                durationMs: 600,
                scheduledDays: 1.0,
                reviewState: ReviewEvent.implicitExposureState
            )
        )
        try context.save()

        let latest = scheduler.latestInteractiveReviewDate(userId: userId, modelContext: context)
        XCTAssertEqual(latest, interactiveDate)
    }

    func testNoInteractiveHistoryDefaultsToDayZeroInactivity() {
        let scheduler = BanditScheduler()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 20, hour: 0, minute: 1))!

        let plan = scheduler.buildReminderPlan(
            now: now,
            lastInteractiveDate: nil,
            horizonDays: 14,
            calendar: calendar
        )

        XCTAssertEqual(plan.count, 20)
    }

    func testInactivityDaysComputedFromLatestInteractiveEvent() {
        let scheduler = BanditScheduler()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 20, hour: 0, minute: 1))!
        let lastInteractive = calendar.date(byAdding: .day, value: -5, to: now)!

        let plan = scheduler.buildReminderPlan(
            now: now,
            lastInteractiveDate: lastInteractive,
            horizonDays: 1,
            calendar: calendar
        )

        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan.first?.identifier, "LEXICAL_REMINDER_20260220_2000")
    }

    func testSyncSchedulesRollingReminderRequestsInsteadOfRepeatingFixedThree() {
        let scheduler = BanditScheduler()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 20, hour: 0, minute: 1))!

        scheduler.syncOutOfAppReminderNotifications(
            notificationsEnabled: true,
            authorizationStatusOverride: .authorized,
            nowOverride: now,
            lastInteractiveDateOverride: now,
            calendar: calendar
        )

        let scheduled = scheduler.debugReminderIdentifiersForTesting()
        XCTAssertEqual(scheduled.count, 20)
        XCTAssertTrue(scheduled.allSatisfy { $0.hasPrefix("LEXICAL_REMINDER_") })
    }

    func testSyncIsIdempotentForRollingIdentifiers() {
        let scheduler = BanditScheduler()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 20, hour: 0, minute: 1))!

        scheduler.syncOutOfAppReminderNotifications(
            notificationsEnabled: true,
            authorizationStatusOverride: .authorized,
            nowOverride: now,
            lastInteractiveDateOverride: now,
            calendar: calendar
        )
        scheduler.syncOutOfAppReminderNotifications(
            notificationsEnabled: true,
            authorizationStatusOverride: .authorized,
            nowOverride: now,
            lastInteractiveDateOverride: now,
            calendar: calendar
        )

        let identifiers = scheduler.debugReminderIdentifiersForTesting()
        XCTAssertEqual(identifiers.count, Set(identifiers).count)
        XCTAssertEqual(identifiers.count, 20)
    }

    func testSyncRemovesLegacyReminderIdentifiers() {
        let scheduler = BanditScheduler()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 20, hour: 0, minute: 1))!

        UserDefaults.standard.set([
            "LEXICAL_REMINDER_0900",
            "LEXICAL_REMINDER_1400",
            "LEXICAL_REMINDER_2000"
        ], forKey: "bandit_test_reminder_ids_v1")

        scheduler.syncOutOfAppReminderNotifications(
            notificationsEnabled: true,
            authorizationStatusOverride: .authorized,
            nowOverride: now,
            lastInteractiveDateOverride: now,
            calendar: calendar
        )

        let identifiers = scheduler.debugReminderIdentifiersForTesting()
        XCTAssertFalse(identifiers.contains("LEXICAL_REMINDER_0900"))
        XCTAssertFalse(identifiers.contains("LEXICAL_REMINDER_1400"))
        XCTAssertFalse(identifiers.contains("LEXICAL_REMINDER_2000"))
    }

    func testToggleOffCancelsAllFixedReminderRequests() {
        let scheduler = BanditScheduler()
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 2, day: 20, hour: 0, minute: 1))!

        scheduler.syncOutOfAppReminderNotifications(
            notificationsEnabled: true,
            authorizationStatusOverride: .authorized,
            nowOverride: now,
            lastInteractiveDateOverride: now,
            calendar: calendar
        )
        scheduler.syncOutOfAppReminderNotifications(
            notificationsEnabled: false,
            authorizationStatusOverride: .authorized,
            nowOverride: now,
            lastInteractiveDateOverride: now,
            calendar: calendar
        )

        XCTAssertTrue(scheduler.debugReminderIdentifiersForTesting().isEmpty)
    }

    func testDeniedAuthorizationSkipsReminderScheduling() {
        let scheduler = BanditScheduler()

        scheduler.syncOutOfAppReminderNotifications(
            notificationsEnabled: true,
            authorizationStatusOverride: .denied,
            nowOverride: Date(),
            lastInteractiveDateOverride: Date()
        )

        XCTAssertTrue(scheduler.debugReminderIdentifiersForTesting().isEmpty)
    }

    func testReminderTapRoutesToReviewSessionEvent() throws {
        let scheduler = BanditScheduler()
        let expectation = expectation(description: "Routes to review session")

        let observer = NotificationCenter.default.addObserver(
            forName: .lexicalOpenReviewSession,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        let response = try makeNotificationResponse(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            userInfo: [
                "route": BanditScheduler.routeReviewSession
            ]
        )

        scheduler.handleNotificationResponse(response)
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testSuggestionTapRoutesToPromptCardPendingPayload() throws {
        let scheduler = BanditScheduler()
        let expectation = expectation(description: "Routes to prompt card")

        let observer = NotificationCenter.default.addObserver(
            forName: .lexicalOpenPromptCard,
            object: nil,
            queue: .main
        ) { notification in
            XCTAssertEqual(notification.userInfo?["lemma"] as? String, "orbit")
            expectation.fulfill()
        }

        let response = try makeNotificationResponse(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            userInfo: [
                "route": BanditScheduler.routePromptCard,
                "lemma": "Orbit",
                "definition": "Path around a body",
                "rank": 1200
            ]
        )

        scheduler.handleNotificationResponse(response)
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)

        XCTAssertEqual(UserDefaults.standard.string(forKey: "lexical.pending_prompt_lemma"), "orbit")
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "lexical.pending_prompt_definition"),
            "Path around a body"
        )
    }

    func testForegroundSuppressionIncludesSuggestionCategory() {
        XCTAssertTrue(
            BanditScheduler.foregroundSuppressedCategories.contains(
                BanditScheduler.suggestionCategoryIdentifier
            )
        )
    }

    func testArticleReadyScheduledWhenGenerationCompletesOutOfApp() {
        let scheduler = BanditScheduler()

        scheduler.scheduleArticleReadyNotificationIfNeeded(
            articleId: "article-1",
            title: "Fresh Lexical Article",
            notificationsEnabled: true,
            appIsActive: false
        )

        XCTAssertEqual(
            scheduler.debugArticleReadyIdentifiersForTesting(),
            ["LEXICAL_ARTICLE_READY_article-1"]
        )
    }

    func testArticleReadyNotScheduledWhenAppActive() {
        let scheduler = BanditScheduler()

        scheduler.scheduleArticleReadyNotificationIfNeeded(
            articleId: "article-1",
            title: "Fresh Lexical Article",
            notificationsEnabled: true,
            appIsActive: true
        )

        XCTAssertTrue(scheduler.debugArticleReadyIdentifiersForTesting().isEmpty)
    }

    func testArticleReadyIdentifierDedupesPerArticleId() {
        let scheduler = BanditScheduler()

        scheduler.scheduleArticleReadyNotificationIfNeeded(
            articleId: "article-1",
            title: "Fresh Lexical Article",
            notificationsEnabled: true,
            appIsActive: false
        )
        scheduler.scheduleArticleReadyNotificationIfNeeded(
            articleId: "article-1",
            title: "Fresh Lexical Article",
            notificationsEnabled: true,
            appIsActive: false
        )

        XCTAssertEqual(
            scheduler.debugArticleReadyIdentifiersForTesting(),
            ["LEXICAL_ARTICLE_READY_article-1"]
        )
    }

    func testArticleReadyTapRoutesToReadingTabEvent() throws {
        let scheduler = BanditScheduler()
        let expectation = expectation(description: "Routes to reading tab")

        let observer = NotificationCenter.default.addObserver(
            forName: .lexicalOpenReadingTab,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        let response = try makeNotificationResponse(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            userInfo: [
                "route": BanditScheduler.routeReadingTab
            ]
        )

        scheduler.handleNotificationResponse(response)
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LexicalSchemaV3.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
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
            "bandit_test_reminder_ids_v1",
            "bandit_test_article_ready_ids_v1",
            "lexical.pending_notification_route",
            "lexical.pending_prompt_lemma",
            "lexical.pending_prompt_definition"
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
    }
}
