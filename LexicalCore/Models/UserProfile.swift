import Foundation
import SwiftData

public enum SubscriptionTier: String, Codable, Sendable {
    case free
    case premium
}

public enum EntitlementSource: String, Codable, Sendable {
    case appStore = "app_store"
    case localCache = "local_cache"
}

public enum FSRSParameterMode: String, Codable, Sendable {
    case standard
    case personalized
}

/// Adaptive profile state used by identity, calibration, and recommendation systems.
@Model
public final class UserProfile {
    public static let activeUserDefaultsKey = "lexical.active_user_id"
    public static let fallbackLocalUserID = "local.default.user"

    /// Stable identity from Sign in with Apple (private relay compatible).
    @Attribute(.unique) public var userId: String

    public var displayName: String?
    public var emailRelay: String?

    /// Estimated vocabulary size from lexical calibration.
    public var lexicalRank: Int

    /// Dynamic topic weights used by the content generator.
    public var interestVector: [String: Double]

    /// User-rejected lemmas to keep recommendations hygienic.
    public var ignoredWords: [String]

    /// Rolling "easy" ratio used for difficulty promotion logic.
    public var easyRatingVelocity: Double

    /// Daily matrix cycle progression (e.g. root packs).
    public var cycleCount: Int

    /// Subscription tier used by free/premium feature gates.
    public var subscriptionTierRawValue: String = SubscriptionTier.free.rawValue

    /// Most recent entitlement source (StoreKit or local cache).
    public var entitlementSourceRawValue: String = EntitlementSource.localCache.rawValue

    /// Last time entitlement data changed.
    public var entitlementUpdatedAt: Date = Date()

    /// Optional entitlement expiry marker from subscription state.
    public var entitlementExpiresAt: Date?

    /// Active FSRS parameter mode (`standard` for free, `personalized` for premium).
    public var fsrsParameterModeRawValue: String = FSRSParameterMode.standard.rawValue

    /// Personalized request-retention target used in premium mode.
    public var fsrsRequestRetention: Double = 0.9

    /// LWW merge timestamp for mutable profile fields.
    public var stateUpdatedAt: Date

    public var createdAt: Date

    public init(
        userId: String,
        displayName: String? = nil,
        emailRelay: String? = nil,
        lexicalRank: Int = 2500,
        interestVector: [String: Double] = [:],
        ignoredWords: [String] = [],
        easyRatingVelocity: Double = 0.0,
        cycleCount: Int = 0,
        subscriptionTier: SubscriptionTier = .free,
        entitlementSource: EntitlementSource = .localCache,
        entitlementExpiresAt: Date? = nil,
        fsrsParameterMode: FSRSParameterMode = .standard,
        fsrsRequestRetention: Double = 0.9
    ) {
        self.userId = userId
        self.displayName = displayName
        self.emailRelay = emailRelay
        self.lexicalRank = lexicalRank
        self.interestVector = interestVector
        self.ignoredWords = ignoredWords
        self.easyRatingVelocity = easyRatingVelocity
        self.cycleCount = cycleCount
        self.subscriptionTierRawValue = subscriptionTier.rawValue
        self.entitlementSourceRawValue = entitlementSource.rawValue
        self.entitlementUpdatedAt = Date()
        self.entitlementExpiresAt = entitlementExpiresAt
        self.fsrsParameterModeRawValue = fsrsParameterMode.rawValue
        self.fsrsRequestRetention = max(0.8, min(0.98, fsrsRequestRetention))
        self.stateUpdatedAt = Date()
        self.createdAt = Date()
    }

    public var subscriptionTier: SubscriptionTier {
        get { SubscriptionTier(rawValue: subscriptionTierRawValue) ?? .free }
        set { subscriptionTierRawValue = newValue.rawValue }
    }

    public var entitlementSource: EntitlementSource {
        get { EntitlementSource(rawValue: entitlementSourceRawValue) ?? .localCache }
        set { entitlementSourceRawValue = newValue.rawValue }
    }

    public var fsrsParameterMode: FSRSParameterMode {
        get { FSRSParameterMode(rawValue: fsrsParameterModeRawValue) ?? .standard }
        set { fsrsParameterModeRawValue = newValue.rawValue }
    }

    public func markIgnored(_ lemma: String) {
        let normalized = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty, !ignoredWords.contains(normalized) else { return }
        ignoredWords.append(normalized)
        stateUpdatedAt = Date()
    }

    public func applySubscriptionTier(
        _ tier: SubscriptionTier,
        source: EntitlementSource,
        expiresAt: Date? = nil
    ) {
        subscriptionTier = tier
        entitlementSource = source
        entitlementUpdatedAt = Date()
        entitlementExpiresAt = expiresAt

        if tier == .premium {
            fsrsParameterMode = .personalized
            if fsrsRequestRetention < 0.85 || fsrsRequestRetention > 0.97 {
                fsrsRequestRetention = 0.92
            }
        } else {
            fsrsParameterMode = .standard
            fsrsRequestRetention = 0.9
        }

        stateUpdatedAt = Date()
    }

    public func upsertInterest(_ topic: String, weight: Double) {
        let normalized = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        interestVector[normalized] = max(0.0, min(1.0, weight))
        stateUpdatedAt = Date()
    }

    /// Resolves the active profile and creates a local fallback profile if none exists yet.
    @MainActor
    @discardableResult
    public static func resolveActiveProfile(modelContext: ModelContext) -> UserProfile {
        let defaults = UserDefaults(suiteName: Persistence.appGroupIdentifier) ?? .standard

        if let storedUserID = defaults.string(forKey: activeUserDefaultsKey),
           let profile = fetchProfile(userId: storedUserID, modelContext: modelContext) {
            return profile
        }

        let descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        if let firstProfile = try? modelContext.fetch(descriptor).first {
            defaults.set(firstProfile.userId, forKey: activeUserDefaultsKey)
            return firstProfile
        }

        let fallbackProfile = UserProfile(userId: fallbackLocalUserID)
        modelContext.insert(fallbackProfile)
        do {
            try modelContext.save()
        } catch {
            // Keep going with the in-memory profile; caller still gets a deterministic identity.
            print("UserProfile: failed to save fallback profile: \(error)")
        }
        defaults.set(fallbackProfile.userId, forKey: activeUserDefaultsKey)
        return fallbackProfile
    }

    @MainActor
    private static func fetchProfile(userId: String, modelContext: ModelContext) -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { profile in
                profile.userId == userId
            }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
