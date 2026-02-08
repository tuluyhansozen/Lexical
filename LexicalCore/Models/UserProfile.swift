import Foundation
import SwiftData

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
        cycleCount: Int = 0
    ) {
        self.userId = userId
        self.displayName = displayName
        self.emailRelay = emailRelay
        self.lexicalRank = lexicalRank
        self.interestVector = interestVector
        self.ignoredWords = ignoredWords
        self.easyRatingVelocity = easyRatingVelocity
        self.cycleCount = cycleCount
        self.stateUpdatedAt = Date()
        self.createdAt = Date()
    }

    public func markIgnored(_ lemma: String) {
        let normalized = lemma.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty, !ignoredWords.contains(normalized) else { return }
        ignoredWords.append(normalized)
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
