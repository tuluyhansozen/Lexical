import Foundation
import SwiftData

#if canImport(StoreKit)
import StoreKit
#endif

public struct SubscriptionProductDescriptor: Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let displayPrice: String
    public let subscriptionGroupID: String?

    public init(
        id: String,
        displayName: String,
        displayPrice: String,
        subscriptionGroupID: String?
    ) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.subscriptionGroupID = subscriptionGroupID
    }
}

public struct SubscriptionEntitlementRecord: Sendable, Equatable {
    public let transactionID: UInt64
    public let productID: String
    public let purchaseDate: Date
    public let expirationDate: Date?
    public let revocationDate: Date?
    public let isUpgraded: Bool
    public let shouldFinishAfterProcessing: Bool

    public init(
        transactionID: UInt64,
        productID: String,
        purchaseDate: Date,
        expirationDate: Date?,
        revocationDate: Date?,
        isUpgraded: Bool,
        shouldFinishAfterProcessing: Bool
    ) {
        self.transactionID = transactionID
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.revocationDate = revocationDate
        self.isUpgraded = isUpgraded
        self.shouldFinishAfterProcessing = shouldFinishAfterProcessing
    }
}

public enum SubscriptionRenewalState: String, Sendable, Equatable {
    case subscribed
    case expired
    case inBillingRetryPeriod
    case inGracePeriod
    case revoked
    case unknown
}

public struct SubscriptionRenewalStatusSnapshot: Sendable, Equatable {
    public let productID: String
    public let state: SubscriptionRenewalState
    public let isInBillingRetry: Bool
    public let gracePeriodExpirationDate: Date?
    public let expirationDate: Date?
    public let revocationDate: Date?

    public init(
        productID: String,
        state: SubscriptionRenewalState,
        isInBillingRetry: Bool,
        gracePeriodExpirationDate: Date?,
        expirationDate: Date?,
        revocationDate: Date?
    ) {
        self.productID = productID
        self.state = state
        self.isInBillingRetry = isInBillingRetry
        self.gracePeriodExpirationDate = gracePeriodExpirationDate
        self.expirationDate = expirationDate
        self.revocationDate = revocationDate
    }
}

public struct SubscriptionEntitlementSnapshot: Sendable, Equatable {
    public let tier: SubscriptionTier
    public let source: EntitlementSource
    public let entitlementUpdatedAt: Date
    public let entitlementExpiresAt: Date?
    public let activeProductIDs: [String]
    public let isInBillingRetry: Bool
    public let gracePeriodExpirationDate: Date?

    public init(
        tier: SubscriptionTier,
        source: EntitlementSource,
        entitlementUpdatedAt: Date,
        entitlementExpiresAt: Date?,
        activeProductIDs: [String],
        isInBillingRetry: Bool,
        gracePeriodExpirationDate: Date?
    ) {
        self.tier = tier
        self.source = source
        self.entitlementUpdatedAt = entitlementUpdatedAt
        self.entitlementExpiresAt = entitlementExpiresAt
        self.activeProductIDs = activeProductIDs
        self.isInBillingRetry = isInBillingRetry
        self.gracePeriodExpirationDate = gracePeriodExpirationDate
    }
}

public enum SubscriptionStoreKitPurchaseOutcome: Sendable, Equatable {
    case purchased(SubscriptionEntitlementRecord)
    case pending
    case userCancelled
}

public enum SubscriptionPurchaseFlowResult: Sendable, Equatable {
    case purchased(SubscriptionEntitlementSnapshot)
    case pending
    case userCancelled
}

public enum SubscriptionEntitlementServiceError: LocalizedError, Equatable {
    case missingProductConfiguration
    case productIDNotConfigured(String)
    case productNotFound(String)
    case unverifiedTransaction(String)
    case storeKitUnavailable

    public var errorDescription: String? {
        switch self {
        case .missingProductConfiguration:
            return "No premium product identifiers are configured."
        case .productIDNotConfigured(let productID):
            return "Product ID is not configured for this app build: \(productID)."
        case .productNotFound(let productID):
            return "Unable to load product details for \(productID)."
        case .unverifiedTransaction(let details):
            return "StoreKit returned an unverified transaction: \(details)"
        case .storeKitUnavailable:
            return "StoreKit is unavailable in this runtime environment."
        }
    }
}

@MainActor
public protocol SubscriptionStoreKitClient: AnyObject {
    func loadProducts(for productIDs: Set<String>) async throws -> [SubscriptionProductDescriptor]
    func purchase(productID: String) async throws -> SubscriptionStoreKitPurchaseOutcome
    func currentEntitlements(for productIDs: Set<String>) async -> [SubscriptionEntitlementRecord]
    func transactionUpdates(for productIDs: Set<String>) -> AsyncStream<SubscriptionEntitlementRecord>
    func renewalStatuses(for productIDs: Set<String>) async throws -> [SubscriptionRenewalStatusSnapshot]
    func finish(transactionID: UInt64) async
    func sync() async throws
}

@MainActor
public final class SubscriptionEntitlementService {
    public static let shared = SubscriptionEntitlementService()
    public static let premiumProductIDsInfoKey = "LexicalPremiumProductIDs"
    public static let defaultPremiumProductIDs: Set<String> = [
        "com.lexical.premium.monthly",
        "com.lexical.premium.yearly"
    ]

    private let storeKitClient: any SubscriptionStoreKitClient
    private let nowProvider: () -> Date
    private var configuredProductIDs: Set<String>
    private var updatesTask: Task<Void, Never>?

    public init(
        storeKitClient: (any SubscriptionStoreKitClient)? = nil,
        productIDs: Set<String> = [],
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.storeKitClient = storeKitClient ?? Self.makeDefaultStoreKitClient()
        self.nowProvider = nowProvider
        self.configuredProductIDs = Self.normalizeProductIDs(productIDs)
    }

    deinit {
        updatesTask?.cancel()
    }

    public static func configuredProductIDs(from bundle: Bundle = .main) -> Set<String> {
        if let raw = bundle.object(forInfoDictionaryKey: premiumProductIDsInfoKey) as? [String] {
            let normalized = normalizeProductIDs(Set(raw))
            if !normalized.isEmpty {
                return normalized
            }
        }
        return defaultPremiumProductIDs
    }

    public func configure(productIDs: Set<String>) {
        let normalized = Self.normalizeProductIDs(productIDs)
        guard normalized != configuredProductIDs else { return }
        configuredProductIDs = normalized
        stopObservingTransactionUpdates()
    }

    @discardableResult
    public func bootstrap(
        modelContainer: ModelContainer,
        productIDs: Set<String>
    ) async -> SubscriptionEntitlementSnapshot {
        configure(productIDs: productIDs)
        let refresh = await refreshEntitlementsInternal(
            modelContainer: modelContainer,
            now: nowProvider()
        )
        startObservingTransactionUpdatesIfNeeded(modelContainer: modelContainer)
        return refresh.snapshot
    }

    public func loadProducts() async throws -> [SubscriptionProductDescriptor] {
        guard !configuredProductIDs.isEmpty else {
            throw SubscriptionEntitlementServiceError.missingProductConfiguration
        }
        return try await storeKitClient.loadProducts(for: configuredProductIDs)
    }

    public func purchase(
        productID: String,
        modelContainer: ModelContainer
    ) async throws -> SubscriptionPurchaseFlowResult {
        guard configuredProductIDs.contains(productID) else {
            throw SubscriptionEntitlementServiceError.productIDNotConfigured(productID)
        }

        let purchaseOutcome = try await storeKitClient.purchase(productID: productID)
        switch purchaseOutcome {
        case .pending:
            return .pending
        case .userCancelled:
            return .userCancelled
        case .purchased(let transaction):
            let refresh = await refreshEntitlementsInternal(
                modelContainer: modelContainer,
                now: nowProvider()
            )
            if refresh.durableProcessed {
                await storeKitClient.finish(transactionID: transaction.transactionID)
            }
            return .purchased(refresh.snapshot)
        }
    }

    public func restorePurchases(
        modelContainer: ModelContainer,
        productIDs: Set<String>? = nil
    ) async throws -> SubscriptionEntitlementSnapshot {
        if let productIDs {
            configure(productIDs: productIDs)
        }
        guard !configuredProductIDs.isEmpty else {
            throw SubscriptionEntitlementServiceError.missingProductConfiguration
        }
        try await storeKitClient.sync()
        let refresh = await refreshEntitlementsInternal(
            modelContainer: modelContainer,
            now: nowProvider()
        )
        return refresh.snapshot
    }

    public func refreshEntitlements(
        modelContainer: ModelContainer,
        productIDs: Set<String>? = nil
    ) async -> SubscriptionEntitlementSnapshot {
        if let productIDs {
            configure(productIDs: productIDs)
        }
        let refresh = await refreshEntitlementsInternal(
            modelContainer: modelContainer,
            now: nowProvider()
        )
        return refresh.snapshot
    }

    public func stopObservingTransactionUpdates() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    // MARK: - Internals

    private struct RefreshResult: Sendable {
        let snapshot: SubscriptionEntitlementSnapshot
        let durableProcessed: Bool
    }

    internal struct EntitlementEvaluation: Sendable, Equatable {
        let tier: SubscriptionTier
        let expiresAt: Date?
        let activeProductIDs: Set<String>
        let isInBillingRetry: Bool
        let gracePeriodExpirationDate: Date?
    }

    internal static func evaluateEntitlement(
        productIDs: Set<String>,
        entitlements: [SubscriptionEntitlementRecord],
        statuses: [SubscriptionRenewalStatusSnapshot],
        now: Date
    ) -> EntitlementEvaluation {
        let activeTransactionProductIDs = Set<String>(
            entitlements.compactMap { entitlement in
                guard productIDs.contains(entitlement.productID) else { return nil }
                guard entitlement.revocationDate == nil else { return nil }
                guard entitlement.isUpgraded == false else { return nil }
                if let expirationDate = entitlement.expirationDate, expirationDate <= now {
                    return nil
                }
                return entitlement.productID
            }
        )

        var activeStatusProductIDs: Set<String> = []
        var billingRetry = false
        var maxGraceExpiration: Date?

        for status in statuses where productIDs.contains(status.productID) {
            let hasActiveGraceWindow = status.gracePeriodExpirationDate.map { $0 > now } ?? false

            let grantsAccess: Bool
            switch status.state {
            case .subscribed:
                grantsAccess = status.revocationDate == nil
            case .inGracePeriod:
                grantsAccess = status.revocationDate == nil && hasActiveGraceWindow
            case .inBillingRetryPeriod:
                grantsAccess = status.revocationDate == nil && hasActiveGraceWindow
            case .expired, .revoked, .unknown:
                grantsAccess = false
            }

            if grantsAccess {
                activeStatusProductIDs.insert(status.productID)
            }

            if status.state == .inBillingRetryPeriod || status.isInBillingRetry {
                billingRetry = true
            }

            if let graceDate = status.gracePeriodExpirationDate {
                maxGraceExpiration = maxDate(maxGraceExpiration, graceDate)
            }
        }

        let activeProductIDs = activeTransactionProductIDs.union(activeStatusProductIDs)
        let hasPremiumAccess = !activeProductIDs.isEmpty

        let activeTransactionExpiration = entitlements
            .filter { activeProductIDs.contains($0.productID) }
            .compactMap(\.expirationDate)
            .max()

        let activeStatusExpiration = statuses
            .filter { activeProductIDs.contains($0.productID) }
            .compactMap { status in
                status.gracePeriodExpirationDate ?? status.expirationDate
            }
            .max()

        let historicalExpiration = maxDate(
            entitlements.compactMap(\.expirationDate).max(),
            statuses.compactMap { $0.gracePeriodExpirationDate ?? $0.expirationDate }.max()
        )

        return EntitlementEvaluation(
            tier: hasPremiumAccess ? .premium : .free,
            expiresAt: hasPremiumAccess
                ? maxDate(activeTransactionExpiration, activeStatusExpiration)
                : historicalExpiration,
            activeProductIDs: activeProductIDs,
            isInBillingRetry: billingRetry,
            gracePeriodExpirationDate: maxGraceExpiration
        )
    }

    private func refreshEntitlementsInternal(
        modelContainer: ModelContainer,
        now: Date
    ) async -> RefreshResult {
        let context = modelContainer.mainContext
        let profile = UserProfile.resolveActiveProfile(modelContext: context)

        guard !configuredProductIDs.isEmpty else {
            return RefreshResult(
                snapshot: snapshotFromProfile(profile, now: now),
                durableProcessed: true
            )
        }

        let currentEntitlements = await storeKitClient.currentEntitlements(for: configuredProductIDs)

        let renewalStatuses: [SubscriptionRenewalStatusSnapshot]
        do {
            renewalStatuses = try await storeKitClient.renewalStatuses(for: configuredProductIDs)
        } catch {
            print("SubscriptionEntitlementService: failed to load renewal statuses: \(error)")
            renewalStatuses = []
        }

        let evaluation = Self.evaluateEntitlement(
            productIDs: configuredProductIDs,
            entitlements: currentEntitlements,
            statuses: renewalStatuses,
            now: now
        )

        let durableProcessed = persist(
            evaluation: evaluation,
            profile: profile,
            modelContext: context
        )

        let snapshot = SubscriptionEntitlementSnapshot(
            tier: evaluation.tier,
            source: .appStore,
            entitlementUpdatedAt: profile.entitlementUpdatedAt,
            entitlementExpiresAt: evaluation.expiresAt,
            activeProductIDs: evaluation.activeProductIDs.sorted(),
            isInBillingRetry: evaluation.isInBillingRetry,
            gracePeriodExpirationDate: evaluation.gracePeriodExpirationDate
        )

        return RefreshResult(snapshot: snapshot, durableProcessed: durableProcessed)
    }

    private func persist(
        evaluation: EntitlementEvaluation,
        profile: UserProfile,
        modelContext: ModelContext
    ) -> Bool {
        let needsUpdate =
            profile.subscriptionTier != evaluation.tier ||
            profile.entitlementSource != .appStore ||
            profile.entitlementExpiresAt != evaluation.expiresAt

        guard needsUpdate else {
            return true
        }

        profile.applySubscriptionTier(
            evaluation.tier,
            source: .appStore,
            expiresAt: evaluation.expiresAt
        )

        do {
            try modelContext.save()
            return true
        } catch {
            print("SubscriptionEntitlementService: failed to persist entitlement: \(error)")
            return false
        }
    }

    private func snapshotFromProfile(
        _ profile: UserProfile,
        now: Date
    ) -> SubscriptionEntitlementSnapshot {
        let effectiveTier: SubscriptionTier
        if let expiresAt = profile.entitlementExpiresAt, expiresAt < now {
            effectiveTier = .free
        } else {
            effectiveTier = profile.subscriptionTier
        }

        return SubscriptionEntitlementSnapshot(
            tier: effectiveTier,
            source: profile.entitlementSource,
            entitlementUpdatedAt: profile.entitlementUpdatedAt,
            entitlementExpiresAt: profile.entitlementExpiresAt,
            activeProductIDs: [],
            isInBillingRetry: false,
            gracePeriodExpirationDate: nil
        )
    }

    private func startObservingTransactionUpdatesIfNeeded(
        modelContainer: ModelContainer
    ) {
        guard updatesTask == nil else { return }
        guard !configuredProductIDs.isEmpty else { return }

        let productIDs = configuredProductIDs
        updatesTask = Task { [weak self] in
            guard let self else { return }
            let stream = storeKitClient.transactionUpdates(for: productIDs)
            for await record in stream {
                if Task.isCancelled { break }
                await handleTransactionUpdate(record, modelContainer: modelContainer)
            }
        }
    }

    private func handleTransactionUpdate(
        _ transaction: SubscriptionEntitlementRecord,
        modelContainer: ModelContainer
    ) async {
        let refresh = await refreshEntitlementsInternal(
            modelContainer: modelContainer,
            now: nowProvider()
        )

        guard refresh.durableProcessed else { return }
        guard transaction.shouldFinishAfterProcessing else { return }
        await storeKitClient.finish(transactionID: transaction.transactionID)
    }

    private static func normalizeProductIDs(_ productIDs: Set<String>) -> Set<String> {
        Set(
            productIDs
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    private static func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (l?, r?):
            return max(l, r)
        case (let l?, nil):
            return l
        case (nil, let r?):
            return r
        case (nil, nil):
            return nil
        }
    }

    private static func makeDefaultStoreKitClient() -> any SubscriptionStoreKitClient {
        LiveSubscriptionStoreKitClient()
    }
}

#if canImport(StoreKit)
@MainActor
public final class LiveSubscriptionStoreKitClient: SubscriptionStoreKitClient {
    private var cachedProducts: [String: Product] = [:]
    private var pendingTransactions: [UInt64: Transaction] = [:]

    public init() {}

    public func loadProducts(for productIDs: Set<String>) async throws -> [SubscriptionProductDescriptor] {
        let products = try await Product.products(for: Array(productIDs))
        for product in products {
            cachedProducts[product.id] = product
        }

        return products
            .sorted(by: { $0.displayName < $1.displayName })
            .map { product in
                SubscriptionProductDescriptor(
                    id: product.id,
                    displayName: product.displayName,
                    displayPrice: product.displayPrice,
                    subscriptionGroupID: product.subscription?.subscriptionGroupID
                )
            }
    }

    public func purchase(productID: String) async throws -> SubscriptionStoreKitPurchaseOutcome {
        let product = try await resolveProduct(for: productID)
        let result = try await product.purchase()

        switch result {
        case .pending:
            return .pending
        case .userCancelled:
            return .userCancelled
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                pendingTransactions[transaction.id] = transaction
                return .purchased(
                    SubscriptionEntitlementRecord(
                        transactionID: transaction.id,
                        productID: transaction.productID,
                        purchaseDate: transaction.purchaseDate,
                        expirationDate: transaction.expirationDate,
                        revocationDate: transaction.revocationDate,
                        isUpgraded: transaction.isUpgraded,
                        shouldFinishAfterProcessing: true
                    )
                )
            case .unverified(let transaction, let error):
                throw SubscriptionEntitlementServiceError.unverifiedTransaction(
                    "tx=\(transaction.id), reason=\(error.localizedDescription)"
                )
            }
        @unknown default:
            return .userCancelled
        }
    }

    public func currentEntitlements(for productIDs: Set<String>) async -> [SubscriptionEntitlementRecord] {
        guard !productIDs.isEmpty else { return [] }

        var records: [SubscriptionEntitlementRecord] = []

        if #available(iOS 18.4, macOS 15.4, tvOS 18.4, watchOS 11.4, visionOS 2.4, *) {
            for productID in productIDs {
                for await verification in Transaction.currentEntitlements(for: productID) {
                    guard case .verified(let transaction) = verification else { continue }
                    records.append(
                        SubscriptionEntitlementRecord(
                            transactionID: transaction.id,
                            productID: transaction.productID,
                            purchaseDate: transaction.purchaseDate,
                            expirationDate: transaction.expirationDate,
                            revocationDate: transaction.revocationDate,
                            isUpgraded: transaction.isUpgraded,
                            shouldFinishAfterProcessing: false
                        )
                    )
                }
            }
        } else {
            for await verification in Transaction.currentEntitlements {
                guard case .verified(let transaction) = verification else { continue }
                guard productIDs.contains(transaction.productID) else { continue }
                records.append(
                    SubscriptionEntitlementRecord(
                        transactionID: transaction.id,
                        productID: transaction.productID,
                        purchaseDate: transaction.purchaseDate,
                        expirationDate: transaction.expirationDate,
                        revocationDate: transaction.revocationDate,
                        isUpgraded: transaction.isUpgraded,
                        shouldFinishAfterProcessing: false
                    )
                )
            }
        }

        return records
    }

    public func transactionUpdates(for productIDs: Set<String>) -> AsyncStream<SubscriptionEntitlementRecord> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                for await verification in Transaction.updates {
                    if Task.isCancelled { break }
                    guard case .verified(let transaction) = verification else { continue }
                    guard productIDs.contains(transaction.productID) else { continue }

                    pendingTransactions[transaction.id] = transaction
                    continuation.yield(
                        SubscriptionEntitlementRecord(
                            transactionID: transaction.id,
                            productID: transaction.productID,
                            purchaseDate: transaction.purchaseDate,
                            expirationDate: transaction.expirationDate,
                            revocationDate: transaction.revocationDate,
                            isUpgraded: transaction.isUpgraded,
                            shouldFinishAfterProcessing: true
                        )
                    )
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func renewalStatuses(
        for productIDs: Set<String>
    ) async throws -> [SubscriptionRenewalStatusSnapshot] {
        guard !productIDs.isEmpty else { return [] }

        let products = try await Product.products(for: Array(productIDs))
        for product in products {
            cachedProducts[product.id] = product
        }

        var snapshots: [SubscriptionRenewalStatusSnapshot] = []

        for product in products {
            guard let subscriptionInfo = product.subscription else { continue }
            let statuses = try await subscriptionInfo.status

            for status in statuses {
                guard case .verified(let transaction) = status.transaction else { continue }
                guard productIDs.contains(transaction.productID) else { continue }

                let renewalInfo: Product.SubscriptionInfo.RenewalInfo?
                switch status.renewalInfo {
                case .verified(let verifiedInfo):
                    renewalInfo = verifiedInfo
                case .unverified:
                    renewalInfo = nil
                }

                snapshots.append(
                    SubscriptionRenewalStatusSnapshot(
                        productID: transaction.productID,
                        state: mapRenewalState(status.state),
                        isInBillingRetry: renewalInfo?.isInBillingRetry ?? false,
                        gracePeriodExpirationDate: renewalInfo?.gracePeriodExpirationDate,
                        expirationDate: transaction.expirationDate,
                        revocationDate: transaction.revocationDate
                    )
                )
            }
        }

        return snapshots
    }

    public func finish(transactionID: UInt64) async {
        guard let transaction = pendingTransactions.removeValue(forKey: transactionID) else { return }
        await transaction.finish()
    }

    public func sync() async throws {
        try await AppStore.sync()
    }

    private func resolveProduct(for productID: String) async throws -> Product {
        if let cached = cachedProducts[productID] {
            return cached
        }

        let products = try await Product.products(for: [productID])
        guard let product = products.first(where: { $0.id == productID }) else {
            throw SubscriptionEntitlementServiceError.productNotFound(productID)
        }

        cachedProducts[product.id] = product
        return product
    }

    private func mapRenewalState(
        _ state: Product.SubscriptionInfo.RenewalState
    ) -> SubscriptionRenewalState {
        switch state {
        case .subscribed:
            return .subscribed
        case .expired:
            return .expired
        case .inBillingRetryPeriod:
            return .inBillingRetryPeriod
        case .inGracePeriod:
            return .inGracePeriod
        case .revoked:
            return .revoked
        default:
            return .unknown
        }
    }
}
#else
@MainActor
public final class LiveSubscriptionStoreKitClient: SubscriptionStoreKitClient {
    public init() {}

    public func loadProducts(for productIDs: Set<String>) async throws -> [SubscriptionProductDescriptor] {
        throw SubscriptionEntitlementServiceError.storeKitUnavailable
    }

    public func purchase(productID: String) async throws -> SubscriptionStoreKitPurchaseOutcome {
        throw SubscriptionEntitlementServiceError.storeKitUnavailable
    }

    public func currentEntitlements(for productIDs: Set<String>) async -> [SubscriptionEntitlementRecord] {
        []
    }

    public func transactionUpdates(for productIDs: Set<String>) -> AsyncStream<SubscriptionEntitlementRecord> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    public func renewalStatuses(for productIDs: Set<String>) async throws -> [SubscriptionRenewalStatusSnapshot] {
        []
    }

    public func finish(transactionID: UInt64) async {}

    public func sync() async throws {
        throw SubscriptionEntitlementServiceError.storeKitUnavailable
    }
}
#endif
