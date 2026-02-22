import Foundation
import SwiftData

public struct ArticleGenerationQuotaSnapshot: Sendable {
    public let tier: SubscriptionTier
    public let isUnlimited: Bool
    public let remaining: Int
    public let limit: Int?
    public let windowStart: Date?
    public let windowEnd: Date?

    public init(
        tier: SubscriptionTier,
        isUnlimited: Bool,
        remaining: Int,
        limit: Int?,
        windowStart: Date?,
        windowEnd: Date?
    ) {
        self.tier = tier
        self.isUnlimited = isUnlimited
        self.remaining = remaining
        self.limit = limit
        self.windowStart = windowStart
        self.windowEnd = windowEnd
    }
}

public struct FeatureGateService {
    public static let freeArticleLimitPerWindow = 1
    public static let freeArticleWindowDays = 7
    public static let freeWidgetProfileLimit = 1
    public static let freeStatsPeriods: [StatsPeriod] = [.week, .month, .year]

    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    @MainActor
    public func activeTier(modelContext: ModelContext) -> SubscriptionTier {
        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        return effectiveTier(for: profile)
    }

    @MainActor
    public func activeFSRSMode(modelContext: ModelContext) -> FSRSParameterMode {
        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        return fsrsParameterMode(for: profile)
    }

    @MainActor
    public func availableStatsPeriods(modelContext: ModelContext) -> [StatsPeriod] {
        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        return availableStatsPeriods(for: profile)
    }

    public func availableStatsPeriods(for profile: UserProfile) -> [StatsPeriod] {
        if effectiveTier(for: profile) == .premium {
            return StatsPeriod.allCases
        }
        return Self.freeStatsPeriods
    }

    @MainActor
    public func canAccessStatsPeriod(
        _ period: StatsPeriod,
        modelContext: ModelContext
    ) -> Bool {
        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        return canAccessStatsPeriod(period, for: profile)
    }

    public func canAccessStatsPeriod(_ period: StatsPeriod, for profile: UserProfile) -> Bool {
        availableStatsPeriods(for: profile).contains(period)
    }

    public func fsrsParameterMode(for profile: UserProfile) -> FSRSParameterMode {
        effectiveTier(for: profile) == .premium ? .personalized : .standard
    }

    @MainActor
    public func fsrsRequestRetention(modelContext: ModelContext) -> Double {
        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        return fsrsRequestRetention(for: profile)
    }

    public func fsrsRequestRetention(for profile: UserProfile) -> Double {
        guard effectiveTier(for: profile) == .premium else {
            return 0.9
        }

        let velocity = max(0.0, min(1.0, profile.easyRatingVelocity))
        let rankFactor = max(0.0, min(1.0, Double(profile.lexicalRank) / 12_000.0))
        let adaptiveTarget = 0.88 + (velocity * 0.04) + (rankFactor * 0.02)
        let configuredTarget = max(0.85, min(0.97, profile.fsrsRequestRetention))
        let blended = (adaptiveTarget + configuredTarget) / 2.0
        return max(0.86, min(0.96, blended))
    }

    @discardableResult
    @MainActor
    public func canGenerateArticle(
        modelContext: ModelContext,
        now: Date = Date()
    ) throws -> Bool {
        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        return try canGenerateArticle(for: profile, modelContext: modelContext, now: now)
    }

    @discardableResult
    public func canGenerateArticle(
        for profile: UserProfile,
        modelContext: ModelContext,
        now: Date = Date()
    ) throws -> Bool {
        let tier = effectiveTier(for: profile)
        if tier == .premium {
            return true
        }

        let ledger = try resolveLedger(userId: profile.userId, modelContext: modelContext, now: now)
        rotateArticleWindowIfNeeded(ledger: ledger, now: now)
        return ledger.articlesGeneratedInWindow < Self.freeArticleLimitPerWindow
    }

    @discardableResult
    @MainActor
    public func recordArticleGeneration(
        modelContext: ModelContext,
        now: Date = Date()
    ) throws -> Bool {
        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        return try recordArticleGeneration(for: profile, modelContext: modelContext, now: now)
    }

    @discardableResult
    public func recordArticleGeneration(
        for profile: UserProfile,
        modelContext: ModelContext,
        now: Date = Date()
    ) throws -> Bool {
        let tier = effectiveTier(for: profile)
        let ledger = try resolveLedger(userId: profile.userId, modelContext: modelContext, now: now)
        rotateArticleWindowIfNeeded(ledger: ledger, now: now)

        if tier == .free && ledger.articlesGeneratedInWindow >= Self.freeArticleLimitPerWindow {
            return false
        }

        if tier == .free {
            ledger.articlesGeneratedInWindow += 1
        }
        ledger.touch(now: now)
        try modelContext.save()
        return true
    }

    @MainActor
    public func articleQuotaSnapshot(
        modelContext: ModelContext,
        now: Date = Date()
    ) throws -> ArticleGenerationQuotaSnapshot {
        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        return try articleQuotaSnapshot(for: profile, modelContext: modelContext, now: now)
    }

    public func articleQuotaSnapshot(
        for profile: UserProfile,
        modelContext: ModelContext,
        now: Date = Date()
    ) throws -> ArticleGenerationQuotaSnapshot {
        let tier = effectiveTier(for: profile)
        if tier == .premium {
            return ArticleGenerationQuotaSnapshot(
                tier: .premium,
                isUnlimited: true,
                remaining: Int.max,
                limit: nil,
                windowStart: nil,
                windowEnd: nil
            )
        }

        let ledger = try resolveLedger(userId: profile.userId, modelContext: modelContext, now: now)
        rotateArticleWindowIfNeeded(ledger: ledger, now: now)

        let limit = Self.freeArticleLimitPerWindow
        let remaining = max(0, limit - ledger.articlesGeneratedInWindow)
        let windowEnd = calendar.date(
            byAdding: .day,
            value: Self.freeArticleWindowDays,
            to: ledger.articleWindowStart
        )

        return ArticleGenerationQuotaSnapshot(
            tier: .free,
            isUnlimited: false,
            remaining: remaining,
            limit: limit,
            windowStart: ledger.articleWindowStart,
            windowEnd: windowEnd
        )
    }

    @MainActor
    public func canCreateAdditionalWidgetProfile(
        modelContext: ModelContext,
        currentCount: Int? = nil,
        now: Date = Date()
    ) throws -> Bool {
        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        return try canCreateAdditionalWidgetProfile(
            for: profile,
            modelContext: modelContext,
            currentCount: currentCount,
            now: now
        )
    }

    public func canCreateAdditionalWidgetProfile(
        for profile: UserProfile,
        modelContext: ModelContext,
        currentCount: Int? = nil,
        now: Date = Date()
    ) throws -> Bool {
        if effectiveTier(for: profile) == .premium {
            return true
        }

        if let currentCount {
            return currentCount < Self.freeWidgetProfileLimit
        }

        let ledger = try resolveLedger(userId: profile.userId, modelContext: modelContext, now: now)
        return ledger.activeWidgetProfileCount < Self.freeWidgetProfileLimit
    }

    @MainActor
    public func setActiveWidgetProfileCount(
        _ count: Int,
        modelContext: ModelContext,
        now: Date = Date()
    ) throws {
        let profile = UserProfile.resolveActiveProfile(modelContext: modelContext)
        let ledger = try resolveLedger(userId: profile.userId, modelContext: modelContext, now: now)
        ledger.activeWidgetProfileCount = max(0, count)
        ledger.touch(now: now)
        try modelContext.save()
    }

    private func effectiveTier(for profile: UserProfile) -> SubscriptionTier {
        if let expiresAt = profile.entitlementExpiresAt, expiresAt < Date() {
            return .free
        }
        return profile.subscriptionTier
    }

    private func rotateArticleWindowIfNeeded(ledger: UsageLedger, now: Date) {
        guard shouldRotateWindow(start: ledger.articleWindowStart, now: now) else { return }
        ledger.resetArticleWindow(startingAt: now)
    }

    private func shouldRotateWindow(start: Date, now: Date) -> Bool {
        if now < start {
            return true
        }
        let elapsed = now.timeIntervalSince(start)
        let threshold = TimeInterval(Self.freeArticleWindowDays * 24 * 60 * 60)
        return elapsed >= threshold
    }

    private func resolveLedger(
        userId: String,
        modelContext: ModelContext,
        now: Date
    ) throws -> UsageLedger {
        let descriptor = FetchDescriptor<UsageLedger>(
            predicate: #Predicate { ledger in
                ledger.userId == userId
            }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let created = UsageLedger(userId: userId, articleWindowStart: now)
        modelContext.insert(created)
        try modelContext.save()
        return created
    }
}
