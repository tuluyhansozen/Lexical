import Foundation
import SwiftData
import XCTest
@testable import LexicalCore

@MainActor
final class SubscriptionEntitlementServiceTests: XCTestCase {
    private let activeUserDefaultsKey = UserProfile.activeUserDefaultsKey

    override func setUp() {
        super.setUp()
        clearActiveUserDefaults()
    }

    override func tearDown() {
        clearActiveUserDefaults()
        super.tearDown()
    }

    func testRefreshPromotesUserToPremiumFromVerifiedEntitlement() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = uniqueUserID(prefix: "entitlement.promote")
        let profile = UserProfile(userId: userId)
        context.insert(profile)
        try context.save()
        setActiveUser(userId)

        let now = Date(timeIntervalSince1970: 1_000)
        let fakeClient = FakeSubscriptionStoreKitClient()
        fakeClient.currentEntitlementRecords = [
            SubscriptionEntitlementRecord(
                transactionID: 11,
                productID: "com.lexical.premium.monthly",
                purchaseDate: now.addingTimeInterval(-3_600),
                expirationDate: now.addingTimeInterval(86_400),
                revocationDate: nil,
                isUpgraded: false,
                shouldFinishAfterProcessing: false
            )
        ]

        let service = SubscriptionEntitlementService(
            storeKitClient: fakeClient,
            productIDs: ["com.lexical.premium.monthly"],
            nowProvider: { now }
        )

        let snapshot = await service.refreshEntitlements(modelContainer: container)
        XCTAssertEqual(snapshot.tier, .premium)
        XCTAssertEqual(snapshot.source, .appStore)
        XCTAssertEqual(snapshot.activeProductIDs, ["com.lexical.premium.monthly"])

        XCTAssertEqual(profile.subscriptionTier, .premium)
        XCTAssertEqual(profile.entitlementSource, .appStore)
        XCTAssertEqual(profile.fsrsParameterMode, .personalized)
    }

    func testRefreshDowngradesUserWhenEntitlementExpired() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = uniqueUserID(prefix: "entitlement.expired")
        let profile = UserProfile(userId: userId)
        profile.applySubscriptionTier(.premium, source: .localCache)
        context.insert(profile)
        try context.save()
        setActiveUser(userId)

        let now = Date(timeIntervalSince1970: 2_000)
        let fakeClient = FakeSubscriptionStoreKitClient()
        fakeClient.currentEntitlementRecords = [
            SubscriptionEntitlementRecord(
                transactionID: 12,
                productID: "com.lexical.premium.monthly",
                purchaseDate: now.addingTimeInterval(-100_000),
                expirationDate: now.addingTimeInterval(-60),
                revocationDate: nil,
                isUpgraded: false,
                shouldFinishAfterProcessing: false
            )
        ]
        fakeClient.renewalStatusSnapshots = [
            SubscriptionRenewalStatusSnapshot(
                productID: "com.lexical.premium.monthly",
                state: .expired,
                isInBillingRetry: false,
                gracePeriodExpirationDate: nil,
                expirationDate: now.addingTimeInterval(-60),
                revocationDate: nil
            )
        ]

        let service = SubscriptionEntitlementService(
            storeKitClient: fakeClient,
            productIDs: ["com.lexical.premium.monthly"],
            nowProvider: { now }
        )

        let snapshot = await service.refreshEntitlements(modelContainer: container)
        XCTAssertEqual(snapshot.tier, .free)

        XCTAssertEqual(profile.subscriptionTier, .free)
        XCTAssertEqual(profile.entitlementSource, .appStore)
        XCTAssertEqual(profile.fsrsParameterMode, .standard)
    }

    func testBillingRetryWithActiveGraceKeepsPremium() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = uniqueUserID(prefix: "entitlement.grace")
        let profile = UserProfile(userId: userId)
        context.insert(profile)
        try context.save()
        setActiveUser(userId)

        let now = Date(timeIntervalSince1970: 3_000)
        let graceExpiry = now.addingTimeInterval(12 * 60 * 60)

        let fakeClient = FakeSubscriptionStoreKitClient()
        fakeClient.renewalStatusSnapshots = [
            SubscriptionRenewalStatusSnapshot(
                productID: "com.lexical.premium.monthly",
                state: .inBillingRetryPeriod,
                isInBillingRetry: true,
                gracePeriodExpirationDate: graceExpiry,
                expirationDate: now.addingTimeInterval(-120),
                revocationDate: nil
            )
        ]

        let service = SubscriptionEntitlementService(
            storeKitClient: fakeClient,
            productIDs: ["com.lexical.premium.monthly"],
            nowProvider: { now }
        )

        let snapshot = await service.refreshEntitlements(modelContainer: container)
        XCTAssertEqual(snapshot.tier, .premium)
        XCTAssertTrue(snapshot.isInBillingRetry)
        XCTAssertEqual(snapshot.gracePeriodExpirationDate, graceExpiry)
        XCTAssertEqual(profile.subscriptionTier, .premium)
    }

    func testPurchaseFinishesTransactionAfterEntitlementPersistence() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = uniqueUserID(prefix: "entitlement.purchase")
        let profile = UserProfile(userId: userId)
        context.insert(profile)
        try context.save()
        setActiveUser(userId)

        let now = Date(timeIntervalSince1970: 4_000)
        let purchasedRecord = SubscriptionEntitlementRecord(
            transactionID: 99,
            productID: "com.lexical.premium.monthly",
            purchaseDate: now,
            expirationDate: now.addingTimeInterval(86_400),
            revocationDate: nil,
            isUpgraded: false,
            shouldFinishAfterProcessing: true
        )

        let fakeClient = FakeSubscriptionStoreKitClient()
        fakeClient.purchaseOutcome = .purchased(purchasedRecord)
        fakeClient.currentEntitlementRecords = [purchasedRecord]

        let service = SubscriptionEntitlementService(
            storeKitClient: fakeClient,
            productIDs: ["com.lexical.premium.monthly"],
            nowProvider: { now }
        )

        let result = try await service.purchase(
            productID: "com.lexical.premium.monthly",
            modelContainer: container
        )

        guard case .purchased(let snapshot) = result else {
            return XCTFail("Expected purchased result")
        }
        XCTAssertEqual(snapshot.tier, .premium)
        XCTAssertEqual(fakeClient.finishedTransactionIDs, [99])
    }

    func testRestorePurchasesCallsAppStoreSync() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = uniqueUserID(prefix: "entitlement.restore")
        context.insert(UserProfile(userId: userId))
        try context.save()
        setActiveUser(userId)

        let fakeClient = FakeSubscriptionStoreKitClient()
        let service = SubscriptionEntitlementService(
            storeKitClient: fakeClient,
            productIDs: ["com.lexical.premium.monthly"]
        )

        _ = try await service.restorePurchases(modelContainer: container)
        XCTAssertEqual(fakeClient.syncCallCount, 1)
    }

    func testPurchasePendingReturnsPendingWithoutTierMutation() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = uniqueUserID(prefix: "entitlement.pending")
        let profile = UserProfile(userId: userId)
        context.insert(profile)
        try context.save()
        setActiveUser(userId)

        let fakeClient = FakeSubscriptionStoreKitClient()
        fakeClient.purchaseOutcome = .pending

        let service = SubscriptionEntitlementService(
            storeKitClient: fakeClient,
            productIDs: ["com.lexical.premium.monthly"]
        )

        let result = try await service.purchase(
            productID: "com.lexical.premium.monthly",
            modelContainer: container
        )

        XCTAssertEqual(result, .pending)
        XCTAssertEqual(profile.subscriptionTier, .free)
        XCTAssertTrue(fakeClient.finishedTransactionIDs.isEmpty)
    }

    func testPurchaseUserCancelledReturnsCancelledWithoutTierMutation() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = uniqueUserID(prefix: "entitlement.cancelled")
        let profile = UserProfile(userId: userId)
        context.insert(profile)
        try context.save()
        setActiveUser(userId)

        let fakeClient = FakeSubscriptionStoreKitClient()
        fakeClient.purchaseOutcome = .userCancelled

        let service = SubscriptionEntitlementService(
            storeKitClient: fakeClient,
            productIDs: ["com.lexical.premium.monthly"]
        )

        let result = try await service.purchase(
            productID: "com.lexical.premium.monthly",
            modelContainer: container
        )

        XCTAssertEqual(result, .userCancelled)
        XCTAssertEqual(profile.subscriptionTier, .free)
        XCTAssertTrue(fakeClient.finishedTransactionIDs.isEmpty)
    }

    func testOfflineRefreshFallsBackToCachedPremiumEntitlement() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let userId = uniqueUserID(prefix: "entitlement.offline")
        let expiresAt = Date().addingTimeInterval(24 * 60 * 60)
        let profile = UserProfile(userId: userId)
        profile.applySubscriptionTier(.premium, source: .localCache, expiresAt: expiresAt)
        context.insert(profile)
        try context.save()
        setActiveUser(userId)

        let fakeClient = FakeSubscriptionStoreKitClient()
        let service = SubscriptionEntitlementService(
            storeKitClient: fakeClient,
            productIDs: []
        )

        let snapshot = await service.refreshEntitlements(modelContainer: container)
        XCTAssertEqual(snapshot.tier, .premium)
        XCTAssertEqual(snapshot.source, .localCache)
        XCTAssertEqual(snapshot.entitlementExpiresAt, expiresAt)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(LexicalSchemaV6.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func setActiveUser(_ userId: String) {
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

@MainActor
private final class FakeSubscriptionStoreKitClient: SubscriptionStoreKitClient {
    var availableProducts: [SubscriptionProductDescriptor] = []
    var purchaseOutcome: SubscriptionStoreKitPurchaseOutcome = .userCancelled
    var currentEntitlementRecords: [SubscriptionEntitlementRecord] = []
    var renewalStatusSnapshots: [SubscriptionRenewalStatusSnapshot] = []
    var syncCallCount: Int = 0
    var finishedTransactionIDs: [UInt64] = []
    var updatesStream: AsyncStream<SubscriptionEntitlementRecord> = AsyncStream { continuation in
        continuation.finish()
    }

    func loadProducts(for productIDs: Set<String>) async throws -> [SubscriptionProductDescriptor] {
        availableProducts.filter { productIDs.contains($0.id) }
    }

    func purchase(productID: String) async throws -> SubscriptionStoreKitPurchaseOutcome {
        purchaseOutcome
    }

    func currentEntitlements(for productIDs: Set<String>) async -> [SubscriptionEntitlementRecord] {
        currentEntitlementRecords.filter { productIDs.contains($0.productID) }
    }

    func transactionUpdates(for productIDs: Set<String>) -> AsyncStream<SubscriptionEntitlementRecord> {
        updatesStream
    }

    func renewalStatuses(for productIDs: Set<String>) async throws -> [SubscriptionRenewalStatusSnapshot] {
        renewalStatusSnapshots.filter { productIDs.contains($0.productID) }
    }

    func finish(transactionID: UInt64) async {
        finishedTransactionIDs.append(transactionID)
    }

    func sync() async throws {
        syncCallCount += 1
    }
}
