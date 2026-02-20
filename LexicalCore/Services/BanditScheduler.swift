import Foundation
import UserNotifications
import SwiftData

public extension Notification.Name {
    // Kept for compatibility with existing prompt-card flow outside notification scheduling.
    static let lexicalOpenPromptCard = Notification.Name("LexicalOpenPromptCard")
    static let lexicalOpenReviewSession = Notification.Name("LexicalOpenReviewSession")
    static let lexicalOpenReadingTab = Notification.Name("LexicalOpenReadingTab")
}

public final class BanditScheduler: NSObject, ObservableObject {
    public static let shared = BanditScheduler()

    public static let reminderCategoryIdentifier = "LEXICAL_REMINDER_CATEGORY"
    public static let suggestionCategoryIdentifier = "LEXICAL_SUGGESTION_CATEGORY"
    public static let articleReadyCategoryIdentifier = "LEXICAL_ARTICLE_READY_CATEGORY"

    public static let routeReviewSession = "review_session"
    public static let routePromptCard = "prompt_card"
    public static let routeReadingTab = "reading_tab"

    public static let foregroundSuppressedCategories: Set<String> = [
        reminderCategoryIdentifier,
        suggestionCategoryIdentifier,
        articleReadyCategoryIdentifier
    ]

    private let reminderIdentifierPrefix = "LEXICAL_REMINDER_"
    private let pendingRouteKey = "lexical.pending_notification_route"
    private let testReminderIDsKey = "bandit_test_reminder_ids_v1"
    private let testArticleReadyIDsKey = "bandit_test_article_ready_ids_v1"

    enum ReminderDeliveryKind: Equatable {
        case suggestion
        case reviewReminder
    }

    enum ReminderSlot: String, CaseIterable {
        case nineAM = "0900"
        case twoPM = "1400"
        case eightPM = "2000"

        var hour: Int {
            switch self {
            case .nineAM: return 9
            case .twoPM: return 14
            case .eightPM: return 20
            }
        }

        var minute: Int { 0 }

        var deliveryKind: ReminderDeliveryKind {
            switch self {
            case .nineAM, .twoPM:
                return .suggestion
            case .eightPM:
                return .reviewReminder
            }
        }
    }

    struct ReminderRequestPlan: Equatable {
        let identifier: String
        let dateComponents: DateComponents
        let slot: ReminderSlot
        let deliveryKind: ReminderDeliveryKind
    }

    public override init() {
        super.init()
        setupNotifications()
    }

    private func setupNotifications() {
        if isRunningTests {
            return
        }

        let center = UNUserNotificationCenter.current()
        let reminderCategory = UNNotificationCategory(
            identifier: Self.reminderCategoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let suggestionCategory = UNNotificationCategory(
            identifier: Self.suggestionCategoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let articleReadyCategory = UNNotificationCategory(
            identifier: Self.articleReadyCategoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([reminderCategory, suggestionCategory, articleReadyCategory])
    }

    private var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil {
            return true
        }

        return ProcessInfo.processInfo.arguments.contains { argument in
            argument.localizedCaseInsensitiveContains("xctest")
        }
    }

    public func requestNotificationAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            print("BanditScheduler: notification authorization granted=\(granted)")
            return granted
        } catch {
            print("BanditScheduler: notification authorization request failed: \(error)")
            return false
        }
    }

    public func notificationAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    @MainActor
    public func syncOutOfAppReminderNotifications(notificationsEnabled: Bool) {
        if isRunningTests {
            syncOutOfAppReminderNotifications(
                notificationsEnabled: notificationsEnabled,
                authorizationStatusOverride: .authorized,
                nowOverride: Date(),
                lastInteractiveDateOverride: Date()
            )
            return
        }

        Task { @MainActor in
            let status = await notificationAuthorizationStatus()
            syncOutOfAppReminderNotifications(
                notificationsEnabled: notificationsEnabled,
                authorizationStatusOverride: status,
                nowOverride: Date()
            )
        }
    }

    @MainActor
    public func cancelOutOfAppReminderNotifications() {
        if isRunningTests {
            UserDefaults.standard.removeObject(forKey: testReminderIDsKey)
            return
        }

        removeAppOwnedReminderRequests()
    }

    @MainActor
    func syncOutOfAppReminderNotifications(
        notificationsEnabled: Bool,
        authorizationStatusOverride: UNAuthorizationStatus? = nil,
        nowOverride: Date? = nil,
        lastInteractiveDateOverride: Date? = nil,
        interactiveReviewDatesOverride: [Date]? = nil,
        calendar: Calendar = .current
    ) {
        let referenceDate = nowOverride ?? Date()

        if isRunningTests {
            let status = authorizationStatusOverride ?? .authorized
            if notificationsEnabled && authorizationAllowsDelivery(status) {
                let reviewedInteractiveDays = normalizedDaySet(
                    from: interactiveReviewDatesOverride ?? [],
                    calendar: calendar
                )
                let plans = buildReminderPlan(
                    now: referenceDate,
                    lastInteractiveDate: lastInteractiveDateOverride,
                    reviewedInteractiveDays: reviewedInteractiveDays,
                    horizonDays: 14,
                    calendar: calendar
                )
                UserDefaults.standard.set(plans.map(\.identifier), forKey: testReminderIDsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: testReminderIDsKey)
            }
            return
        }

        guard notificationsEnabled else {
            cancelOutOfAppReminderNotifications()
            return
        }

        let status = authorizationStatusOverride ?? .notDetermined
        guard authorizationAllowsDelivery(status) else {
            cancelOutOfAppReminderNotifications()
            return
        }

        let modelContext = ModelContext(Persistence.sharedModelContainer)
        let activeProfile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let lastInteractiveDate = lastInteractiveDateOverride ?? latestInteractiveReviewDate(
            userId: activeProfile.userId,
            modelContext: modelContext
        )
        let reviewedInteractiveDays = normalizedDaySet(
            from: interactiveReviewDatesOverride ?? interactiveReviewDates(
                userId: activeProfile.userId,
                modelContext: modelContext
            ),
            calendar: calendar
        )

        let plans = buildReminderPlan(
            now: referenceDate,
            lastInteractiveDate: lastInteractiveDate,
            reviewedInteractiveDays: reviewedInteractiveDays,
            horizonDays: 14,
            calendar: calendar
        )
        let suggestionPayloadByIdentifier = suggestionPayloadByPlanIdentifier(
            plans: plans,
            modelContext: modelContext,
            calendar: calendar
        )
        scheduleReminderPlans(
            plans,
            suggestionPayloadByIdentifier: suggestionPayloadByIdentifier
        )
    }

    @MainActor
    public func scheduleArticleReadyNotificationIfNeeded(
        articleId: String,
        title: String,
        notificationsEnabled: Bool,
        appIsActive: Bool
    ) {
        if isRunningTests {
            scheduleArticleReadyNotificationIfNeeded(
                articleId: articleId,
                title: title,
                notificationsEnabled: notificationsEnabled,
                appIsActive: appIsActive,
                authorizationStatusOverride: .authorized
            )
            return
        }

        Task { @MainActor in
            let status = await notificationAuthorizationStatus()
            scheduleArticleReadyNotificationIfNeeded(
                articleId: articleId,
                title: title,
                notificationsEnabled: notificationsEnabled,
                appIsActive: appIsActive,
                authorizationStatusOverride: status
            )
        }
    }

    @MainActor
    func scheduleArticleReadyNotificationIfNeeded(
        articleId: String,
        title: String,
        notificationsEnabled: Bool,
        appIsActive: Bool,
        authorizationStatusOverride: UNAuthorizationStatus? = nil
    ) {
        guard notificationsEnabled else { return }
        guard !appIsActive else { return }

        let normalizedArticleId = articleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedArticleId.isEmpty else { return }

        let status = authorizationStatusOverride ?? .notDetermined
        guard authorizationAllowsDelivery(status) else { return }

        let identifier = "LEXICAL_ARTICLE_READY_\(normalizedArticleId)"

        if isRunningTests {
            var ids = debugArticleReadyIdentifiersForTesting()
            if !ids.contains(identifier) {
                ids.append(identifier)
                UserDefaults.standard.set(ids, forKey: testArticleReadyIDsKey)
            }
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = UNMutableNotificationContent()
        content.title = "New article is ready"
        content.body = trimmedTitle.isEmpty ? "Your latest reading article is ready." : trimmedTitle
        content.sound = .default
        content.categoryIdentifier = Self.articleReadyCategoryIdentifier
        content.userInfo = [
            "route": Self.routeReadingTab,
            "article_id": normalizedArticleId
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("BanditScheduler: failed to schedule article-ready notification: \(error)")
            }
        }
    }

    func debugReminderIdentifiersForTesting() -> [String] {
        UserDefaults.standard.stringArray(forKey: testReminderIDsKey) ?? []
    }

    func debugArticleReadyIdentifiersForTesting() -> [String] {
        UserDefaults.standard.stringArray(forKey: testArticleReadyIDsKey) ?? []
    }

    public func consumePendingNotificationRoute() -> String? {
        let defaults = UserDefaults.standard
        guard let route = defaults.string(forKey: pendingRouteKey) else {
            return nil
        }
        defaults.removeObject(forKey: pendingRouteKey)
        return route
    }

    public func handleNotificationResponse(_ response: UNNotificationResponse) {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            return
        }

        let userInfo = response.notification.request.content.userInfo
        let route = userInfo["route"] as? String

        if route == Self.routeReviewSession {
            stageRoute(Self.routeReviewSession, event: .lexicalOpenReviewSession)
            return
        }

        if route == Self.routePromptCard {
            let triageService = NotificationTriageService()
            let payload = triageService.payload(from: userInfo)
            triageService.stagePromptRoute(payload)
            return
        }

        if route == Self.routeReadingTab {
            stageRoute(Self.routeReadingTab, event: .lexicalOpenReadingTab)
        }
    }

    func reminderSlots(forInactiveDay inactiveDay: Int) -> [ReminderSlot] {
        if inactiveDay <= 1 {
            return [.nineAM, .twoPM, .eightPM]
        }
        if inactiveDay <= 4 {
            return [.twoPM, .eightPM]
        }
        if inactiveDay <= 10 {
            return [.eightPM]
        }
        return []
    }

    func shouldScheduleWeeklyNudge(
        forDate date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 3 || weekday == 5 || weekday == 1
    }

    func buildReminderPlan(
        now: Date = Date(),
        lastInteractiveDate: Date?,
        reviewedInteractiveDays: Set<Date> = [],
        horizonDays: Int = 14,
        calendar: Calendar = .current
    ) -> [ReminderRequestPlan] {
        let effectiveHorizon = max(0, horizonDays)
        guard effectiveHorizon > 0 else { return [] }

        let startOfToday = calendar.startOfDay(for: now)
        let lastInteractiveDay = lastInteractiveDate.map { calendar.startOfDay(for: $0) } ?? startOfToday

        var plans: [ReminderRequestPlan] = []
        for dayOffset in 0..<effectiveHorizon {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else {
                continue
            }

            let inactiveDay = inactiveDayCount(
                for: dayDate,
                lastInteractiveDay: lastInteractiveDay,
                calendar: calendar
            )

            let slots: [ReminderSlot] = {
                if inactiveDay >= 11 {
                    return shouldScheduleWeeklyNudge(forDate: dayDate, calendar: calendar) ? [.eightPM] : []
                }
                return reminderSlots(forInactiveDay: inactiveDay)
            }()

            for slot in slots {
                let dayStart = calendar.startOfDay(for: dayDate)
                let deliveryKind = slot.deliveryKind
                if deliveryKind == .reviewReminder && reviewedInteractiveDays.contains(dayStart) {
                    continue
                }

                var components = calendar.dateComponents([.year, .month, .day], from: dayDate)
                components.hour = slot.hour
                components.minute = slot.minute
                components.second = 0

                guard let fireDate = calendar.date(from: components), fireDate > now else {
                    continue
                }

                let year = components.year ?? 0
                let month = components.month ?? 0
                let day = components.day ?? 0
                let identifier = String(
                    format: "LEXICAL_REMINDER_%04d%02d%02d_%@",
                    year,
                    month,
                    day,
                    slot.rawValue
                )

                plans.append(
                    ReminderRequestPlan(
                        identifier: identifier,
                        dateComponents: components,
                        slot: slot,
                        deliveryKind: deliveryKind
                    )
                )
            }
        }

        return plans
    }

    @MainActor
    func latestInteractiveReviewDate(userId: String, modelContext: ModelContext) -> Date? {
        let descriptor = FetchDescriptor<ReviewEvent>(
            predicate: #Predicate { event in
                event.userId == userId
            },
            sortBy: [SortDescriptor(\ReviewEvent.reviewDate, order: .reverse)]
        )
        let events = (try? modelContext.fetch(descriptor)) ?? []
        return events.first(where: { event in
            isInteractiveReviewEvent(event)
        })?.reviewDate
    }

    @MainActor
    func interactiveReviewDates(userId: String, modelContext: ModelContext) -> [Date] {
        let descriptor = FetchDescriptor<ReviewEvent>(
            predicate: #Predicate { event in
                event.userId == userId
            }
        )
        let events = (try? modelContext.fetch(descriptor)) ?? []
        return events
            .filter(isInteractiveReviewEvent)
            .map(\.reviewDate)
    }

    private func inactiveDayCount(
        for scheduleDay: Date,
        lastInteractiveDay: Date,
        calendar: Calendar
    ) -> Int {
        let components = calendar.dateComponents([.day], from: lastInteractiveDay, to: scheduleDay)
        return max(0, components.day ?? 0)
    }

    @MainActor
    private func suggestionPayloadByPlanIdentifier(
        plans: [ReminderRequestPlan],
        modelContext: ModelContext,
        calendar: Calendar
    ) -> [String: LexicalTargetCandidate] {
        let suggestionPlans = plans
            .filter { $0.deliveryKind == .suggestion }
            .sorted { lhs, rhs in
                let lhsDate = reminderFireDate(for: lhs, calendar: calendar) ?? Date.distantFuture
                let rhsDate = reminderFireDate(for: rhs, calendar: calendar) ?? Date.distantFuture
                if lhsDate != rhsDate { return lhsDate < rhsDate }
                return lhs.identifier < rhs.identifier
            }

        guard !suggestionPlans.isEmpty else { return [:] }

        let targetingService = LexicalTargetingService()
        let candidates = targetingService.newWordSuggestionCandidates(
            modelContext: modelContext,
            limit: max(suggestionPlans.count * 3, 12),
            excludedLemmas: []
        )
        guard !candidates.isEmpty else { return [:] }

        var plansByDay: [Date: [ReminderRequestPlan]] = [:]
        for plan in suggestionPlans {
            guard let fireDate = reminderFireDate(for: plan, calendar: calendar) else { continue }
            let day = calendar.startOfDay(for: fireDate)
            plansByDay[day, default: []].append(plan)
        }

        let sortedDays = plansByDay.keys.sorted()
        var assigned: [String: LexicalTargetCandidate] = [:]
        for day in sortedDays {
            guard var dayPlans = plansByDay[day] else { continue }
            dayPlans.sort { lhs, rhs in
                if lhs.slot.hour != rhs.slot.hour { return lhs.slot.hour < rhs.slot.hour }
                return lhs.identifier < rhs.identifier
            }

            var usedToday = Set<String>()
            for plan in dayPlans {
                let preferred = candidates.first { !usedToday.contains($0.lemma) }
                let fallback = candidates.first
                guard let chosen = preferred ?? fallback else { continue }
                assigned[plan.identifier] = chosen
                usedToday.insert(chosen.lemma)
            }
        }

        return assigned
    }

    private func scheduleReminderPlans(
        _ plans: [ReminderRequestPlan],
        suggestionPayloadByIdentifier: [String: LexicalTargetCandidate]
    ) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { [plans, suggestionPayloadByIdentifier] requests in
            let existingAppReminderIDs = requests.compactMap { request in
                if self.isAppOwnedReminderRequest(request) {
                    return request.identifier
                }
                return nil
            }

            if !existingAppReminderIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: existingAppReminderIDs)
                center.removeDeliveredNotifications(withIdentifiers: existingAppReminderIDs)
            }

            for plan in plans {
                let content = UNMutableNotificationContent()
                content.sound = .default

                switch plan.deliveryKind {
                case .reviewReminder:
                    content.title = "Time to practice"
                    content.body = "Open Lexical and run a quick review session."
                    content.categoryIdentifier = Self.reminderCategoryIdentifier
                    content.userInfo = [
                        "route": Self.routeReviewSession,
                        "reminder_id": plan.identifier
                    ]

                case .suggestion:
                    guard let payload = suggestionPayloadByIdentifier[plan.identifier] else {
                        continue
                    }

                    let trimmedDefinition = payload.definition?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let titleLemma = payload.lemma.capitalized

                    content.title = "New word suggestion"
                    content.body = trimmedDefinition.isEmpty
                        ? "Try \(titleLemma) now."
                        : "\(titleLemma): \(trimmedDefinition)"
                    content.categoryIdentifier = Self.suggestionCategoryIdentifier

                    var userInfo: [String: Any] = [
                        "route": Self.routePromptCard,
                        "lemma": payload.lemma,
                        "reminder_id": plan.identifier
                    ]
                    if !trimmedDefinition.isEmpty {
                        userInfo["definition"] = trimmedDefinition
                    }
                    if let rank = payload.rank {
                        userInfo["rank"] = rank
                    }
                    content.userInfo = userInfo
                }

                let trigger = UNCalendarNotificationTrigger(dateMatching: plan.dateComponents, repeats: false)
                let request = UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger)
                center.add(request) { error in
                    if let error {
                        print("BanditScheduler: failed to schedule reminder \(plan.identifier): \(error)")
                    }
                }
            }
        }
    }

    private func removeAppOwnedReminderRequests() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let reminderIDs = requests.compactMap { request in
                if self.isAppOwnedReminderRequest(request) {
                    return request.identifier
                }
                return nil
            }
            guard !reminderIDs.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: reminderIDs)
            center.removeDeliveredNotifications(withIdentifiers: reminderIDs)
        }
    }

    private func authorizationAllowsDelivery(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional
    }

    private func isInteractiveReviewEvent(_ event: ReviewEvent) -> Bool {
        ReviewEvent.isInteractiveReviewState(event.reviewState) &&
        !ReviewEvent.isImplicitExposureState(event.reviewState)
    }

    private func normalizedDaySet(from dates: [Date], calendar: Calendar) -> Set<Date> {
        Set(dates.map { calendar.startOfDay(for: $0) })
    }

    private func reminderFireDate(
        for plan: ReminderRequestPlan,
        calendar: Calendar
    ) -> Date? {
        calendar.date(from: plan.dateComponents)
    }

    private func isAppOwnedReminderRequest(_ request: UNNotificationRequest) -> Bool {
        if request.content.categoryIdentifier == Self.reminderCategoryIdentifier {
            return true
        }
        if request.content.categoryIdentifier == Self.suggestionCategoryIdentifier {
            return true
        }
        return request.identifier.hasPrefix(reminderIdentifierPrefix)
    }

    private func stageRoute(_ route: String, event: Notification.Name) {
        UserDefaults.standard.set(route, forKey: pendingRouteKey)
        NotificationCenter.default.post(name: event, object: nil)
    }
}
