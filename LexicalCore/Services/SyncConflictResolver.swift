import Foundation
import SwiftData

public struct SyncReviewEvent: Codable, Hashable, Sendable {
    public var eventId: String
    public var userId: String
    public var lemma: String
    public var grade: Int
    public var reviewDate: Date
    public var durationMs: Int
    public var scheduledDays: Double
    public var reviewState: String
    public var deviceId: String
    public var sourceReviewLogId: UUID?

    public init(
        eventId: String,
        userId: String,
        lemma: String,
        grade: Int,
        reviewDate: Date,
        durationMs: Int,
        scheduledDays: Double,
        reviewState: String,
        deviceId: String,
        sourceReviewLogId: UUID?
    ) {
        self.eventId = eventId
        self.userId = userId
        self.lemma = lemma
        self.grade = grade
        self.reviewDate = reviewDate
        self.durationMs = durationMs
        self.scheduledDays = scheduledDays
        self.reviewState = reviewState
        self.deviceId = deviceId
        self.sourceReviewLogId = sourceReviewLogId
    }

    public init(from event: ReviewEvent) {
        self.eventId = event.eventId
        self.userId = event.userId
        self.lemma = event.lemma
        self.grade = event.grade
        self.reviewDate = event.reviewDate
        self.durationMs = event.durationMs
        self.scheduledDays = event.scheduledDays
        self.reviewState = event.reviewState
        self.deviceId = event.deviceId
        self.sourceReviewLogId = event.sourceReviewLogId
    }
}

public struct SyncUserWordState: Codable, Hashable, Sendable {
    public var userLemmaKey: String
    public var userId: String
    public var lemma: String
    public var statusRawValue: String
    public var stability: Double
    public var difficulty: Double
    public var retrievability: Double
    public var nextReviewDate: Date?
    public var lastReviewDate: Date?
    public var reviewCount: Int
    public var lapseCount: Int
    public var stateUpdatedAt: Date
    public var createdAt: Date

    public init(
        userLemmaKey: String,
        userId: String,
        lemma: String,
        statusRawValue: String,
        stability: Double,
        difficulty: Double,
        retrievability: Double,
        nextReviewDate: Date?,
        lastReviewDate: Date?,
        reviewCount: Int,
        lapseCount: Int,
        stateUpdatedAt: Date,
        createdAt: Date
    ) {
        self.userLemmaKey = userLemmaKey
        self.userId = userId
        self.lemma = lemma
        self.statusRawValue = statusRawValue
        self.stability = stability
        self.difficulty = difficulty
        self.retrievability = retrievability
        self.nextReviewDate = nextReviewDate
        self.lastReviewDate = lastReviewDate
        self.reviewCount = reviewCount
        self.lapseCount = lapseCount
        self.stateUpdatedAt = stateUpdatedAt
        self.createdAt = createdAt
    }

    public init(from state: UserWordState) {
        self.userLemmaKey = state.userLemmaKey
        self.userId = state.userId
        self.lemma = state.lemma
        self.statusRawValue = state.statusRawValue
        self.stability = state.stability
        self.difficulty = state.difficulty
        self.retrievability = state.retrievability
        self.nextReviewDate = state.nextReviewDate
        self.lastReviewDate = state.lastReviewDate
        self.reviewCount = state.reviewCount
        self.lapseCount = state.lapseCount
        self.stateUpdatedAt = state.stateUpdatedAt
        self.createdAt = state.createdAt
    }

    public var status: UserWordStatus {
        UserWordStatus(rawValue: statusRawValue) ?? .new
    }
}

public struct SyncUserProfile: Codable, Hashable, Sendable {
    public var userId: String
    public var displayName: String?
    public var emailRelay: String?
    public var lexicalRank: Int
    public var interestVector: [String: Double]
    public var ignoredWords: [String]
    public var easyRatingVelocity: Double
    public var cycleCount: Int
    public var subscriptionTierRawValue: String
    public var entitlementSourceRawValue: String
    public var entitlementUpdatedAt: Date
    public var entitlementExpiresAt: Date?
    public var fsrsParameterModeRawValue: String
    public var fsrsRequestRetention: Double
    public var stateUpdatedAt: Date
    public var createdAt: Date

    public init(
        userId: String,
        displayName: String?,
        emailRelay: String?,
        lexicalRank: Int,
        interestVector: [String: Double],
        ignoredWords: [String],
        easyRatingVelocity: Double,
        cycleCount: Int,
        subscriptionTierRawValue: String,
        entitlementSourceRawValue: String,
        entitlementUpdatedAt: Date,
        entitlementExpiresAt: Date?,
        fsrsParameterModeRawValue: String,
        fsrsRequestRetention: Double,
        stateUpdatedAt: Date,
        createdAt: Date
    ) {
        self.userId = userId
        self.displayName = displayName
        self.emailRelay = emailRelay
        self.lexicalRank = lexicalRank
        self.interestVector = interestVector
        self.ignoredWords = ignoredWords
        self.easyRatingVelocity = easyRatingVelocity
        self.cycleCount = cycleCount
        self.subscriptionTierRawValue = subscriptionTierRawValue
        self.entitlementSourceRawValue = entitlementSourceRawValue
        self.entitlementUpdatedAt = entitlementUpdatedAt
        self.entitlementExpiresAt = entitlementExpiresAt
        self.fsrsParameterModeRawValue = fsrsParameterModeRawValue
        self.fsrsRequestRetention = fsrsRequestRetention
        self.stateUpdatedAt = stateUpdatedAt
        self.createdAt = createdAt
    }

    public init(from profile: UserProfile) {
        self.userId = profile.userId
        self.displayName = profile.displayName
        self.emailRelay = profile.emailRelay
        self.lexicalRank = profile.lexicalRank
        self.interestVector = profile.interestVector
        self.ignoredWords = profile.ignoredWords
        self.easyRatingVelocity = profile.easyRatingVelocity
        self.cycleCount = profile.cycleCount
        self.subscriptionTierRawValue = profile.subscriptionTierRawValue
        self.entitlementSourceRawValue = profile.entitlementSourceRawValue
        self.entitlementUpdatedAt = profile.entitlementUpdatedAt
        self.entitlementExpiresAt = profile.entitlementExpiresAt
        self.fsrsParameterModeRawValue = profile.fsrsParameterModeRawValue
        self.fsrsRequestRetention = profile.fsrsRequestRetention
        self.stateUpdatedAt = profile.stateUpdatedAt
        self.createdAt = profile.createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case userId
        case displayName
        case emailRelay
        case lexicalRank
        case interestVector
        case ignoredWords
        case easyRatingVelocity
        case cycleCount
        case subscriptionTierRawValue
        case entitlementSourceRawValue
        case entitlementUpdatedAt
        case entitlementExpiresAt
        case fsrsParameterModeRawValue
        case fsrsRequestRetention
        case stateUpdatedAt
        case createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.userId = try container.decode(String.self, forKey: .userId)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        self.emailRelay = try container.decodeIfPresent(String.self, forKey: .emailRelay)
        self.lexicalRank = try container.decode(Int.self, forKey: .lexicalRank)
        self.interestVector = try container.decodeIfPresent([String: Double].self, forKey: .interestVector) ?? [:]
        self.ignoredWords = try container.decodeIfPresent([String].self, forKey: .ignoredWords) ?? []
        self.easyRatingVelocity = try container.decodeIfPresent(Double.self, forKey: .easyRatingVelocity) ?? 0.0
        self.cycleCount = try container.decodeIfPresent(Int.self, forKey: .cycleCount) ?? 0
        self.stateUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .stateUpdatedAt) ?? Date()
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? stateUpdatedAt

        // Backward-compatible defaults for payloads written before monetization fields existed.
        self.subscriptionTierRawValue = try container.decodeIfPresent(String.self, forKey: .subscriptionTierRawValue)
            ?? SubscriptionTier.free.rawValue
        self.entitlementSourceRawValue = try container.decodeIfPresent(String.self, forKey: .entitlementSourceRawValue)
            ?? EntitlementSource.localCache.rawValue
        self.entitlementUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .entitlementUpdatedAt)
            ?? stateUpdatedAt
        self.entitlementExpiresAt = try container.decodeIfPresent(Date.self, forKey: .entitlementExpiresAt)
        self.fsrsParameterModeRawValue = try container.decodeIfPresent(String.self, forKey: .fsrsParameterModeRawValue)
            ?? FSRSParameterMode.standard.rawValue
        self.fsrsRequestRetention = try container.decodeIfPresent(Double.self, forKey: .fsrsRequestRetention)
            ?? 0.9
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(emailRelay, forKey: .emailRelay)
        try container.encode(lexicalRank, forKey: .lexicalRank)
        try container.encode(interestVector, forKey: .interestVector)
        try container.encode(ignoredWords, forKey: .ignoredWords)
        try container.encode(easyRatingVelocity, forKey: .easyRatingVelocity)
        try container.encode(cycleCount, forKey: .cycleCount)
        try container.encode(subscriptionTierRawValue, forKey: .subscriptionTierRawValue)
        try container.encode(entitlementSourceRawValue, forKey: .entitlementSourceRawValue)
        try container.encode(entitlementUpdatedAt, forKey: .entitlementUpdatedAt)
        try container.encodeIfPresent(entitlementExpiresAt, forKey: .entitlementExpiresAt)
        try container.encode(fsrsParameterModeRawValue, forKey: .fsrsParameterModeRawValue)
        try container.encode(fsrsRequestRetention, forKey: .fsrsRequestRetention)
        try container.encode(stateUpdatedAt, forKey: .stateUpdatedAt)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

public struct SyncSnapshot: Codable, Sendable {
    public var reviewEvents: [SyncReviewEvent]
    public var userWordStates: [SyncUserWordState]
    public var userProfiles: [SyncUserProfile]
    public var generatedAt: Date

    public init(
        reviewEvents: [SyncReviewEvent] = [],
        userWordStates: [SyncUserWordState] = [],
        userProfiles: [SyncUserProfile] = [],
        generatedAt: Date = Date()
    ) {
        self.reviewEvents = reviewEvents
        self.userWordStates = userWordStates
        self.userProfiles = userProfiles
        self.generatedAt = generatedAt
    }
}

public struct SyncMergeReport: Sendable {
    public var mergedEventCount: Int
    public var mergedStateCount: Int
    public var mergedProfileCount: Int

    public init(mergedEventCount: Int, mergedStateCount: Int, mergedProfileCount: Int) {
        self.mergedEventCount = mergedEventCount
        self.mergedStateCount = mergedStateCount
        self.mergedProfileCount = mergedProfileCount
    }
}

public actor SyncConflictResolver {
    private let fsrsEngine: FSRSV4Engine
    private let fsrsPersonalizationService: FSRSPersonalizationService

    public init(
        fsrsEngine: FSRSV4Engine = .init(),
        fsrsPersonalizationService: FSRSPersonalizationService = .init()
    ) {
        self.fsrsEngine = fsrsEngine
        self.fsrsPersonalizationService = fsrsPersonalizationService
    }

    public func merge(local: SyncSnapshot, remote: SyncSnapshot) async -> (snapshot: SyncSnapshot, report: SyncMergeReport) {
        let mergedEvents = mergeEvents(local.reviewEvents, remote.reviewEvents)
        let mergedProfiles = mergeProfiles(local.userProfiles, remote.userProfiles)
        let mergedStatesLWW = mergeStates(local.userWordStates, remote.userWordStates)
        let profileByUserId = Dictionary(
            uniqueKeysWithValues: mergedProfiles.map { profile in
                (profile.userId, profile)
            }
        )
        let replayedStates = await replayStates(
            baseStates: mergedStatesLWW,
            events: mergedEvents,
            profilesByUserId: profileByUserId
        )

        let snapshot = SyncSnapshot(
            reviewEvents: mergedEvents.sorted(by: sortEvents),
            userWordStates: replayedStates.sorted(by: { $0.userLemmaKey < $1.userLemmaKey }),
            userProfiles: mergedProfiles.sorted(by: { $0.userId < $1.userId }),
            generatedAt: Date()
        )
        let report = SyncMergeReport(
            mergedEventCount: mergedEvents.count,
            mergedStateCount: replayedStates.count,
            mergedProfileCount: mergedProfiles.count
        )
        return (snapshot, report)
    }

    private func mergeEvents(_ local: [SyncReviewEvent], _ remote: [SyncReviewEvent]) -> [SyncReviewEvent] {
        var byId: [String: SyncReviewEvent] = [:]
        byId.reserveCapacity(local.count + remote.count)

        // G-Set semantics: union by immutable event ID.
        for event in local {
            byId[event.eventId] = event
        }
        for event in remote {
            if let existing = byId[event.eventId] {
                byId[event.eventId] = mergeEvent(existing, event)
            } else {
                byId[event.eventId] = event
            }
        }
        return Array(byId.values)
    }

    private func mergeEvent(_ lhs: SyncReviewEvent, _ rhs: SyncReviewEvent) -> SyncReviewEvent {
        // Deterministic winner selection keeps merge commutative when duplicate event payloads diverge.
        if lhs.reviewDate != rhs.reviewDate {
            return lhs.reviewDate > rhs.reviewDate ? lhs : rhs
        }
        if lhs.grade != rhs.grade {
            return lhs.grade > rhs.grade ? lhs : rhs
        }
        if lhs.durationMs != rhs.durationMs {
            return lhs.durationMs > rhs.durationMs ? lhs : rhs
        }
        if lhs.scheduledDays != rhs.scheduledDays {
            return lhs.scheduledDays > rhs.scheduledDays ? lhs : rhs
        }
        if lhs.reviewState != rhs.reviewState {
            return lhs.reviewState > rhs.reviewState ? lhs : rhs
        }
        if lhs.deviceId != rhs.deviceId {
            return lhs.deviceId > rhs.deviceId ? lhs : rhs
        }
        let lhsSource = lhs.sourceReviewLogId?.uuidString ?? ""
        let rhsSource = rhs.sourceReviewLogId?.uuidString ?? ""
        return lhsSource >= rhsSource ? lhs : rhs
    }

    private func mergeProfiles(_ local: [SyncUserProfile], _ remote: [SyncUserProfile]) -> [SyncUserProfile] {
        var byUserId: [String: SyncUserProfile] = [:]
        for profile in local {
            byUserId[profile.userId] = profile
        }

        for remoteProfile in remote {
            guard let localProfile = byUserId[remoteProfile.userId] else {
                byUserId[remoteProfile.userId] = remoteProfile
                continue
            }
            byUserId[remoteProfile.userId] = mergeProfile(local: localProfile, remote: remoteProfile)
        }

        return Array(byUserId.values)
    }

    private func mergeProfile(local: SyncUserProfile, remote: SyncUserProfile) -> SyncUserProfile {
        if local.stateUpdatedAt == remote.stateUpdatedAt {
            var mergedInterest = local.interestVector
            for (topic, weight) in remote.interestVector {
                mergedInterest[topic] = max(weight, mergedInterest[topic] ?? 0)
            }

            let mergedIgnored = Array(
                Set(local.ignoredWords.map { $0.lowercased() } + remote.ignoredWords.map { $0.lowercased() })
            ).sorted()

            return SyncUserProfile(
                userId: local.userId,
                displayName: maxString(local.displayName, remote.displayName),
                emailRelay: maxString(local.emailRelay, remote.emailRelay),
                lexicalRank: max(local.lexicalRank, remote.lexicalRank),
                interestVector: mergedInterest,
                ignoredWords: mergedIgnored,
                easyRatingVelocity: max(local.easyRatingVelocity, remote.easyRatingVelocity),
                cycleCount: max(local.cycleCount, remote.cycleCount),
                subscriptionTierRawValue: mergedSubscriptionTierRawValue(local: local, remote: remote),
                entitlementSourceRawValue: maxString(local.entitlementSourceRawValue, remote.entitlementSourceRawValue) ?? EntitlementSource.localCache.rawValue,
                entitlementUpdatedAt: max(local.entitlementUpdatedAt, remote.entitlementUpdatedAt),
                entitlementExpiresAt: maxDate(local.entitlementExpiresAt, remote.entitlementExpiresAt),
                fsrsParameterModeRawValue: mergedFSRSParameterModeRawValue(local: local, remote: remote),
                fsrsRequestRetention: max(local.fsrsRequestRetention, remote.fsrsRequestRetention),
                stateUpdatedAt: local.stateUpdatedAt,
                createdAt: min(local.createdAt, remote.createdAt)
            )
        }

        let remoteIsNewer = remote.stateUpdatedAt >= local.stateUpdatedAt
        let winner = remoteIsNewer ? remote : local
        let loser = remoteIsNewer ? local : remote

        var mergedInterest = winner.interestVector
        for (topic, weight) in loser.interestVector {
            mergedInterest[topic] = max(weight, mergedInterest[topic] ?? 0)
        }

        let mergedIgnored = Array(Set(local.ignoredWords.map { $0.lowercased() } + remote.ignoredWords.map { $0.lowercased() })).sorted()

        return SyncUserProfile(
            userId: winner.userId,
            displayName: winner.displayName ?? loser.displayName,
            emailRelay: winner.emailRelay ?? loser.emailRelay,
            lexicalRank: winner.lexicalRank,
            interestVector: mergedInterest,
            ignoredWords: mergedIgnored,
            easyRatingVelocity: winner.easyRatingVelocity,
            cycleCount: winner.cycleCount,
            subscriptionTierRawValue: winner.subscriptionTierRawValue,
            entitlementSourceRawValue: winner.entitlementSourceRawValue,
            entitlementUpdatedAt: winner.entitlementUpdatedAt,
            entitlementExpiresAt: winner.entitlementExpiresAt,
            fsrsParameterModeRawValue: winner.fsrsParameterModeRawValue,
            fsrsRequestRetention: winner.fsrsRequestRetention,
            stateUpdatedAt: max(local.stateUpdatedAt, remote.stateUpdatedAt),
            createdAt: min(local.createdAt, remote.createdAt)
        )
    }

    private func mergeStates(_ local: [SyncUserWordState], _ remote: [SyncUserWordState]) -> [SyncUserWordState] {
        var byKey: [String: SyncUserWordState] = [:]
        for state in local {
            byKey[state.userLemmaKey] = state
        }

        for remoteState in remote {
            guard let localState = byKey[remoteState.userLemmaKey] else {
                byKey[remoteState.userLemmaKey] = remoteState
                continue
            }
            byKey[remoteState.userLemmaKey] = mergeState(local: localState, remote: remoteState)
        }

        return Array(byKey.values)
    }

    private func mergeState(local: SyncUserWordState, remote: SyncUserWordState) -> SyncUserWordState {
        let remoteIsNewer = remote.stateUpdatedAt > local.stateUpdatedAt
        if local.stateUpdatedAt == remote.stateUpdatedAt {
            return SyncUserWordState(
                userLemmaKey: local.userLemmaKey,
                userId: local.userId,
                lemma: local.lemma,
                statusRawValue: mergedStatusRawValue(local.statusRawValue, remote.statusRawValue),
                stability: max(local.stability, remote.stability),
                difficulty: max(local.difficulty, remote.difficulty),
                retrievability: max(local.retrievability, remote.retrievability),
                nextReviewDate: minDate(local.nextReviewDate, remote.nextReviewDate),
                lastReviewDate: maxDate(local.lastReviewDate, remote.lastReviewDate),
                reviewCount: max(local.reviewCount, remote.reviewCount),
                lapseCount: max(local.lapseCount, remote.lapseCount),
                stateUpdatedAt: local.stateUpdatedAt,
                createdAt: min(local.createdAt, remote.createdAt)
            )
        }
        let winner = remoteIsNewer ? remote : local
        return SyncUserWordState(
            userLemmaKey: winner.userLemmaKey,
            userId: winner.userId,
            lemma: winner.lemma,
            statusRawValue: winner.statusRawValue,
            stability: winner.stability,
            difficulty: winner.difficulty,
            retrievability: winner.retrievability,
            nextReviewDate: winner.nextReviewDate,
            lastReviewDate: winner.lastReviewDate,
            reviewCount: winner.reviewCount,
            lapseCount: winner.lapseCount,
            stateUpdatedAt: winner.stateUpdatedAt,
            createdAt: min(local.createdAt, remote.createdAt)
        )
    }

    private func replayStates(
        baseStates: [SyncUserWordState],
        events: [SyncReviewEvent],
        profilesByUserId: [String: SyncUserProfile]
    ) async -> [SyncUserWordState] {
        var stateByKey: [String: SyncUserWordState] = [:]
        stateByKey.reserveCapacity(baseStates.count)
        for state in baseStates {
            stateByKey[state.userLemmaKey] = state
        }

        let eventsByUser = Dictionary(grouping: events, by: \.userId)
        var weightsByUserId: [String: [Double]?] = [:]
        weightsByUserId.reserveCapacity(eventsByUser.count)
        for (userId, userEvents) in eventsByUser {
            guard let profile = profilesByUserId[userId] else {
                weightsByUserId[userId] = nil
                continue
            }
            weightsByUserId[userId] = fsrsPersonalizationService.personalizedWeights(
                for: profile,
                events: userEvents
            )
        }

        let groupedEvents = Dictionary(grouping: events, by: { UserWordState.makeKey(userId: $0.userId, lemma: $0.lemma) })
        for (key, value) in groupedEvents {
            let ordered = value.sorted(by: sortEvents)
            let localState = stateByKey[key]
            let userId = ordered.first?.userId ?? localState?.userId ?? ""
            let personalizedWeights = weightsByUserId[userId] ?? nil

            if localState?.status == .ignored {
                continue
            }

            let replayed = await replayState(
                for: key,
                seedState: localState,
                events: ordered,
                personalizedWeights: personalizedWeights
            )
            stateByKey[key] = replayed
        }

        return Array(stateByKey.values)
    }

    private func replayState(
        for userLemmaKey: String,
        seedState: SyncUserWordState?,
        events: [SyncReviewEvent],
        personalizedWeights: [Double]?
    ) async -> SyncUserWordState {
        let components = userLemmaKey.split(separator: "|", maxSplits: 1).map(String.init)
        let userId = components.first ?? seedState?.userId ?? ""
        let lemma = components.count > 1 ? components[1] : (seedState?.lemma ?? "")

        // Replay must start from baseline to remain deterministic and idempotent.
        var stability = 0.0
        var difficulty = 0.3
        var retrievability = 1.0
        var reviewCount = 0
        var lapseCount = 0
        var lastReviewDate: Date?
        var nextReviewDate: Date?

        for event in events {
            let daysElapsed: Double = {
                if let lastReviewDate {
                    return max(0, event.reviewDate.timeIntervalSince(lastReviewDate) / 86_400.0)
                }
                if event.scheduledDays > 0 {
                    return event.scheduledDays
                }
                return 0
            }()

            let newState = await fsrsEngine.nextState(
                currentStability: stability,
                currentDifficulty: difficulty,
                recalled: event.grade > 1,
                grade: event.grade,
                daysElapsed: daysElapsed,
                weights: personalizedWeights
            )
            let interval = await fsrsEngine.nextInterval(
                stability: max(newState.stability, 0.1),
                requestRetention: 0.9
            )

            stability = newState.stability
            difficulty = newState.difficulty
            retrievability = newState.retrievability
            reviewCount += 1
            if event.grade == 1 {
                lapseCount += 1
            }
            lastReviewDate = event.reviewDate
            nextReviewDate = event.reviewDate.addingTimeInterval(interval * 86_400)
        }

        let statusRawValue: String
        if seedState?.status == .ignored {
            statusRawValue = UserWordStatus.ignored.rawValue
        } else if stability >= 90 {
            statusRawValue = UserWordStatus.known.rawValue
        } else if reviewCount > 0 {
            statusRawValue = UserWordStatus.learning.rawValue
        } else {
            statusRawValue = UserWordStatus.new.rawValue
        }

        return SyncUserWordState(
            userLemmaKey: userLemmaKey,
            userId: userId,
            lemma: lemma,
            statusRawValue: statusRawValue,
            stability: stability,
            difficulty: difficulty,
            retrievability: retrievability,
            nextReviewDate: nextReviewDate,
            lastReviewDate: lastReviewDate,
            reviewCount: reviewCount,
            lapseCount: lapseCount,
            stateUpdatedAt: lastReviewDate ?? seedState?.stateUpdatedAt ?? Date(),
            createdAt: seedState?.createdAt ?? Date()
        )
    }

    private func sortEvents(_ lhs: SyncReviewEvent, _ rhs: SyncReviewEvent) -> Bool {
        if lhs.reviewDate != rhs.reviewDate {
            return lhs.reviewDate < rhs.reviewDate
        }
        return lhs.eventId < rhs.eventId
    }

    private func minDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case (nil, nil): return nil
        case let (value?, nil), let (nil, value?): return value
        case let (left?, right?): return min(left, right)
        }
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case (nil, nil): return nil
        case let (value?, nil), let (nil, value?): return value
        case let (left?, right?): return max(left, right)
        }
    }

    private func maxString(_ lhs: String?, _ rhs: String?) -> String? {
        switch (lhs, rhs) {
        case (nil, nil): return nil
        case let (value?, nil), let (nil, value?): return value
        case let (left?, right?): return max(left, right)
        }
    }

    private func mergedStatusRawValue(_ lhs: String, _ rhs: String) -> String {
        if lhs == UserWordStatus.ignored.rawValue || rhs == UserWordStatus.ignored.rawValue {
            return UserWordStatus.ignored.rawValue
        }
        let lhsStatus = UserWordStatus(rawValue: lhs) ?? .new
        let rhsStatus = UserWordStatus(rawValue: rhs) ?? .new
        return statusPriority(lhsStatus) >= statusPriority(rhsStatus) ? lhsStatus.rawValue : rhsStatus.rawValue
    }

    private func statusPriority(_ status: UserWordStatus) -> Int {
        switch status {
        case .new: return 0
        case .learning: return 1
        case .known: return 2
        case .ignored: return 3
        }
    }

    private func mergedSubscriptionTierRawValue(local: SyncUserProfile, remote: SyncUserProfile) -> String {
        let localTier = SubscriptionTier(rawValue: local.subscriptionTierRawValue) ?? .free
        let remoteTier = SubscriptionTier(rawValue: remote.subscriptionTierRawValue) ?? .free
        return tierPriority(localTier) >= tierPriority(remoteTier) ? localTier.rawValue : remoteTier.rawValue
    }

    private func tierPriority(_ tier: SubscriptionTier) -> Int {
        switch tier {
        case .free: return 0
        case .premium: return 1
        }
    }

    private func mergedFSRSParameterModeRawValue(local: SyncUserProfile, remote: SyncUserProfile) -> String {
        let localMode = FSRSParameterMode(rawValue: local.fsrsParameterModeRawValue) ?? .standard
        let remoteMode = FSRSParameterMode(rawValue: remote.fsrsParameterModeRawValue) ?? .standard
        return fsrsModePriority(localMode) >= fsrsModePriority(remoteMode) ? localMode.rawValue : remoteMode.rawValue
    }

    private func fsrsModePriority(_ mode: FSRSParameterMode) -> Int {
        switch mode {
        case .standard: return 0
        case .personalized: return 1
        }
    }
}
