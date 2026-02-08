import Foundation
import UserNotifications
import CoreMotion
import SwiftData
import LexicalCore

public extension Notification.Name {
    static let lexicalOpenPromptCard = Notification.Name("LexicalOpenPromptCard")
}

/// Time slots for notification scheduling.
public enum TimeSlot: String, CaseIterable, Codable {
    case morning = "morning"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"

    var hour: Int {
        switch self {
        case .morning: return 8
        case .afternoon: return 14
        case .evening: return 18
        case .night: return 21
        }
    }

    var displayName: String {
        switch self {
        case .morning: return "Morning (8 AM)"
        case .afternoon: return "Afternoon (2 PM)"
        case .evening: return "Evening (6 PM)"
        case .night: return "Night (9 PM)"
        }
    }
}

/// Notification templates (bandit arms).
public enum NotificationTemplate: String, CaseIterable, Codable {
    case curious = "curious"
    case streak = "streak"
    case value = "value"
    case quick = "quick"

    var title: String {
        switch self {
        case .curious: return "Time for a challenge?"
        case .streak: return "Streak check"
        case .value: return "Micro-dose ready"
        case .quick: return "Quick review?"
        }
    }

    var body: String {
        switch self {
        case .curious: return "Try recalling this target word."
        case .streak: return "Keep your momentum going with one card."
        case .value: return "A useful word is waiting for you."
        case .quick: return "Two minutes is enough for one prompt."
        }
    }
}

public final class BanditScheduler: NSObject, ObservableObject {
    public static let shared = BanditScheduler()

    public static let notificationCategoryIdentifier = "LEXICAL_MICRODOSE_CATEGORY"
    public static let actionRevealIdentifier = "LEXICAL_ACTION_REVEAL"
    public static let actionAddIdentifier = "LEXICAL_ACTION_ADD"
    public static let actionIgnoreIdentifier = "LEXICAL_ACTION_IGNORE"

    private let epsilon: Double = 0.2

    private let successCountsKey = "bandit_success_counts_v3"
    private let totalCountsKey = "bandit_total_counts_v3"
    private let lastEngagedKey = "bandit_last_engaged_date"
    private let ignoreStreakKey = "bandit_ignore_streak"

    @Published private(set) var successCounts: [String: Int]
    @Published private(set) var totalCounts: [String: Int]

    private let motionActivityManager = CMMotionActivityManager()

    private struct NotificationCandidate {
        let lemma: String
        let definition: String?
        let rank: Int?
        let context: String?
    }

    public override init() {
        if let successData = UserDefaults.standard.data(forKey: successCountsKey),
           let totalData = UserDefaults.standard.data(forKey: totalCountsKey),
           let success = try? JSONDecoder().decode([String: Int].self, from: successData),
           let total = try? JSONDecoder().decode([String: Int].self, from: totalData) {
            self.successCounts = success
            self.totalCounts = total
        } else {
            self.successCounts = [:]
            self.totalCounts = [:]
        }

        super.init()
        setupNotifications()
    }

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                print("BanditScheduler: notifications authorized.")
            } else {
                print("BanditScheduler: notifications denied.")
            }
        }

        let reveal = UNNotificationAction(
            identifier: Self.actionRevealIdentifier,
            title: "Reveal",
            options: []
        )
        let add = UNNotificationAction(
            identifier: Self.actionAddIdentifier,
            title: "Add to Deck",
            options: []
        )
        let ignore = UNNotificationAction(
            identifier: Self.actionIgnoreIdentifier,
            title: "Ignore",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: Self.notificationCategoryIdentifier,
            actions: [reveal, add, ignore],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    public func scheduleNextNotification() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            if !requests.isEmpty { return }
            self.performSchedule()
        }
    }

    public func scheduleTestNotification() {
        Task { @MainActor in
            let (slot, template) = selectArm()
            let candidate = selectNotificationCandidate()
            scheduleNotification(
                slot: slot,
                template: template,
                candidate: candidate,
                delay: 2,
                isTest: true
            )
        }
    }

    private func checkInterruptibility(completion: @escaping (Bool) -> Void) {
        guard CMMotionActivityManager.isActivityAvailable() else {
            completion(true)
            return
        }

        motionActivityManager.queryActivityStarting(
            from: Date().addingTimeInterval(-60),
            to: Date(),
            to: .main
        ) { activities, _ in
            guard let activity = activities?.last else {
                completion(true)
                return
            }

            completion(!(activity.running || activity.automotive))
        }
    }

    private func performSchedule() {
        let ignoreStreak = UserDefaults.standard.integer(forKey: ignoreStreakKey)
        if ignoreStreak > 3 {
            let lastScheduled = UserDefaults.standard.object(forKey: "bandit_last_scheduled") as? Date ?? .distantPast
            if Date().timeIntervalSince(lastScheduled) < 48 * 3600 {
                print("BanditScheduler: cooldown active.")
                return
            }
        }

        checkInterruptibility { [weak self] interruptible in
            guard let self, interruptible else { return }

            Task { @MainActor in
                let (slot, template) = self.selectArm()
                let candidate = self.selectNotificationCandidate()
                self.scheduleNotification(
                    slot: slot,
                    template: template,
                    candidate: candidate,
                    delay: nil,
                    isTest: false
                )
            }
        }
    }

    @MainActor
    private func selectNotificationCandidate() -> NotificationCandidate? {
        let context = ModelContext(Persistence.sharedModelContainer)
        let targetService = LexicalTargetingService()
        if let candidate = targetService.notificationCandidate(modelContext: context) {
            return NotificationCandidate(
                lemma: candidate.lemma,
                definition: candidate.definition,
                rank: candidate.rank,
                context: candidate.contextSentence
            )
        }

        let activeProfile = UserProfile.resolveActiveProfile(modelContext: context)
        let now = Date()
        let dueState = (try? context.fetch(FetchDescriptor<UserWordState>()))?
            .filter { state in
                state.userId == activeProfile.userId &&
                state.status != .ignored &&
                (state.nextReviewDate ?? now) <= now
            }
            .sorted { ($0.nextReviewDate ?? now) < ($1.nextReviewDate ?? now) }
            .first

        guard let dueState else { return nil }
        let dueLemma = dueState.lemma
        let lexemeDescriptor = FetchDescriptor<LexemeDefinition>(
            predicate: #Predicate { $0.lemma == dueLemma }
        )
        let lexeme = try? context.fetch(lexemeDescriptor).first
        return NotificationCandidate(
            lemma: dueState.lemma,
            definition: lexeme?.basicMeaning,
            rank: lexeme?.rank,
            context: lexeme?.sampleSentence
        )
    }

    private func scheduleNotification(
        slot: TimeSlot,
        template: NotificationTemplate,
        candidate: NotificationCandidate?,
        delay: TimeInterval?,
        isTest: Bool
    ) {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = Self.notificationCategoryIdentifier
        content.sound = .default

        if let candidate {
            let rankText = candidate.rank.map { " (r\($0))" } ?? ""
            content.title = isTest ? "[TEST] \(template.title)" : template.title
            content.body = "\(candidate.lemma.capitalized)\(rankText): \(template.body)"
            content.userInfo = [
                "lemma": candidate.lemma,
                "definition": candidate.definition ?? "",
                "rank": candidate.rank ?? -1,
                "context": candidate.context ?? "",
                "bandit_slot": slot.rawValue,
                "bandit_template": template.rawValue,
                "timestamp": Date().timeIntervalSince1970
            ]
        } else {
            content.title = isTest ? "[TEST] \(template.title)" : template.title
            content.body = template.body
            content.userInfo = [
                "lemma": "",
                "definition": "",
                "rank": -1,
                "context": "",
                "bandit_slot": slot.rawValue,
                "bandit_template": template.rawValue,
                "timestamp": Date().timeIntervalSince1970
            ]
        }

        let trigger: UNNotificationTrigger
        if let delay {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        } else {
            var dateComponents = DateComponents()
            dateComponents.hour = slot.hour
            dateComponents.minute = Int.random(in: 0...30)
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("BanditScheduler: failed to schedule notification: \(error)")
            } else {
                UserDefaults.standard.set(Date(), forKey: "bandit_last_scheduled")
            }
        }

        let key = makeKey(slot, template)
        DispatchQueue.main.async {
            self.totalCounts[key, default: 0] += 1
            self.persist()
        }
    }

    private func selectArm() -> (TimeSlot, NotificationTemplate) {
        let arms = product(TimeSlot.allCases, NotificationTemplate.allCases)
        if Double.random(in: 0...1) < epsilon {
            return arms.randomElement() ?? (.morning, .curious)
        }
        return bestArm(from: arms)
    }

    private func bestArm(from arms: [(TimeSlot, NotificationTemplate)]) -> (TimeSlot, NotificationTemplate) {
        var best = arms.first ?? (.morning, .curious)
        var bestRate = -1.0

        for arm in arms {
            let key = makeKey(arm.0, arm.1)
            let total = totalCounts[key] ?? 0
            if total == 0 {
                return arm
            }

            let success = successCounts[key] ?? 0
            let rate = Double(success) / Double(total)
            if rate > bestRate {
                bestRate = rate
                best = arm
            }
        }
        return best
    }

    public func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo

        let slot = (userInfo["bandit_slot"] as? String).flatMap(TimeSlot.init(rawValue:))
        let template = (userInfo["bandit_template"] as? String).flatMap(NotificationTemplate.init(rawValue:))
        let lemma = (userInfo["lemma"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let definition = userInfo["definition"] as? String

        if let slot, let template,
           response.actionIdentifier != Self.actionIgnoreIdentifier &&
           response.actionIdentifier != UNNotificationDismissActionIdentifier {
            recordSuccess(slot: slot, template: template)
        }

        switch response.actionIdentifier {
        case Self.actionRevealIdentifier:
            if let lemma, !lemma.isEmpty {
                scheduleRevealNotification(lemma: lemma, definition: definition)
            }
        case Self.actionAddIdentifier:
            guard let lemma, !lemma.isEmpty else { return }
            Task { @MainActor in
                self.addToDeck(lemma: lemma, definition: definition)
            }
        case Self.actionIgnoreIdentifier:
            guard let lemma, !lemma.isEmpty else { return }
            Task { @MainActor in
                self.ignoreWord(lemma: lemma)
            }
            incrementIgnoreStreak()
        case UNNotificationDismissActionIdentifier:
            incrementIgnoreStreak()
        case UNNotificationDefaultActionIdentifier:
            guard let lemma, !lemma.isEmpty else { return }
            UserDefaults.standard.set(lemma, forKey: "lexical.pending_prompt_lemma")
            UserDefaults.standard.set(definition ?? "", forKey: "lexical.pending_prompt_definition")
            NotificationCenter.default.post(
                name: .lexicalOpenPromptCard,
                object: nil,
                userInfo: [
                    "lemma": lemma,
                    "definition": definition ?? ""
                ]
            )
        default:
            break
        }
    }

    private func recordSuccess(slot: TimeSlot, template: NotificationTemplate) {
        let key = makeKey(slot, template)
        DispatchQueue.main.async {
            self.successCounts[key, default: 0] += 1
            UserDefaults.standard.set(Date(), forKey: self.lastEngagedKey)
            UserDefaults.standard.set(0, forKey: self.ignoreStreakKey)
            self.persist()
        }
    }

    private func scheduleRevealNotification(lemma: String, definition: String?) {
        let content = UNMutableNotificationContent()
        content.title = "\(lemma.capitalized)"
        content.body = definition?.isEmpty == false ? (definition ?? "") : "No definition available yet."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    @MainActor
    private func addToDeck(lemma: String, definition: String?) {
        let modelContext = ModelContext(Persistence.sharedModelContainer)
        let activeUser = UserProfile.resolveActiveProfile(modelContext: modelContext)

        let normalizedLemma = lemma.lowercased()

        let lexemeDescriptor = FetchDescriptor<LexemeDefinition>(
            predicate: #Predicate { $0.lemma == normalizedLemma }
        )
        let lexeme = (try? modelContext.fetch(lexemeDescriptor).first) ?? {
            let created = LexemeDefinition(
                lemma: normalizedLemma,
                basicMeaning: definition
            )
            modelContext.insert(created)
            return created
        }()

        if lexeme.basicMeaning?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true,
           let definition, !definition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lexeme.basicMeaning = definition
        }

        let key = UserWordState.makeKey(userId: activeUser.userId, lemma: normalizedLemma)
        let stateDescriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { $0.userLemmaKey == key }
        )
        let state = (try? modelContext.fetch(stateDescriptor).first) ?? {
            let created = UserWordState(userId: activeUser.userId, lemma: normalizedLemma, status: .learning)
            modelContext.insert(created)
            return created
        }()

        state.status = .learning
        state.nextReviewDate = Date()
        if state.reviewCount == 0 {
            state.stability = max(0.2, state.stability)
            state.difficulty = max(0.3, state.difficulty)
            state.retrievability = max(0.25, state.retrievability)
        }
        state.touch()

        do {
            try modelContext.save()
        } catch {
            print("BanditScheduler: failed to add '\(normalizedLemma)' to deck: \(error)")
        }
    }

    @MainActor
    private func ignoreWord(lemma: String) {
        let modelContext = ModelContext(Persistence.sharedModelContainer)
        let activeUser = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let normalizedLemma = lemma.lowercased()

        activeUser.markIgnored(normalizedLemma)

        let key = UserWordState.makeKey(userId: activeUser.userId, lemma: normalizedLemma)
        let descriptor = FetchDescriptor<UserWordState>(
            predicate: #Predicate { $0.userLemmaKey == key }
        )
        let state = (try? modelContext.fetch(descriptor).first) ?? {
            let created = UserWordState(userId: activeUser.userId, lemma: normalizedLemma, status: .ignored)
            modelContext.insert(created)
            return created
        }()
        state.status = .ignored
        state.touch()

        do {
            try modelContext.save()
        } catch {
            print("BanditScheduler: failed to ignore '\(normalizedLemma)': \(error)")
        }
    }

    private func incrementIgnoreStreak() {
        let current = UserDefaults.standard.integer(forKey: ignoreStreakKey)
        UserDefaults.standard.set(current + 1, forKey: ignoreStreakKey)
    }

    private func makeKey(_ slot: TimeSlot, _ template: NotificationTemplate) -> String {
        "\(slot.rawValue)_\(template.rawValue)"
    }

    private func product<A, B>(_ a: [A], _ b: [B]) -> [(A, B)] {
        var result: [(A, B)] = []
        for elementA in a {
            for elementB in b {
                result.append((elementA, elementB))
            }
        }
        return result
    }

    private func persist() {
        if let successData = try? JSONEncoder().encode(successCounts),
           let totalData = try? JSONEncoder().encode(totalCounts) {
            UserDefaults.standard.set(successData, forKey: successCountsKey)
            UserDefaults.standard.set(totalData, forKey: totalCountsKey)
        }
    }
}
