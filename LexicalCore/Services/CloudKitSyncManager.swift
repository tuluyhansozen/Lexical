import Foundation
import SwiftData
import CloudKit
import Security

public struct CloudKitSyncReport: Sendable {
    public let success: Bool
    public let userId: String
    public let pulledEvents: Int
    public let mergedStates: Int
    public let mergedProfiles: Int
    public let message: String

    public init(
        success: Bool,
        userId: String,
        pulledEvents: Int,
        mergedStates: Int,
        mergedProfiles: Int,
        message: String
    ) {
        self.success = success
        self.userId = userId
        self.pulledEvents = pulledEvents
        self.mergedStates = mergedStates
        self.mergedProfiles = mergedProfiles
        self.message = message
    }
}

public struct CloudKitEnvironmentReport: Sendable {
    public let canSync: Bool
    public let isSimulator: Bool
    public let hasEntitlement: Bool
    public let accountStatus: CKAccountStatus?
    public let message: String

    public init(
        canSync: Bool,
        isSimulator: Bool,
        hasEntitlement: Bool,
        accountStatus: CKAccountStatus?,
        message: String
    ) {
        self.canSync = canSync
        self.isSimulator = isSimulator
        self.hasEntitlement = hasEntitlement
        self.accountStatus = accountStatus
        self.message = message
    }
}

public enum CloudKitSyncError: Error, LocalizedError {
    case payloadEncodingFailed
    case payloadDecodingFailed
    case invalidRecord

    public var errorDescription: String? {
        switch self {
        case .payloadEncodingFailed:
            return "Unable to encode sync payload for CloudKit."
        case .payloadDecodingFailed:
            return "Unable to decode CloudKit sync payload."
        case .invalidRecord:
            return "CloudKit returned an invalid sync record."
        }
    }
}

public actor CloudKitSyncManager {
    public static let shared = CloudKitSyncManager()

    private let resolver: SyncConflictResolver
    private let database: CKDatabase?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let recordType = "LexicalSyncSnapshotV1"
    private let payloadKey = "payload"
    private let userIdKey = "userId"
    private let updatedAtKey = "updatedAt"

    public init(
        resolver: SyncConflictResolver = .init()
    ) {
        self.database = Self.makeDatabaseIfAvailable()
        self.resolver = resolver
    }

    @MainActor
    @discardableResult
    public func synchronize(modelContainer: ModelContainer) async -> CloudKitSyncReport {
        let context = modelContainer.mainContext
        let activeProfile = UserProfile.resolveActiveProfile(modelContext: context)
        let userId = activeProfile.userId

        let environment = await validateRuntimeEnvironment()
        guard environment.canSync, database != nil else {
            return CloudKitSyncReport(
                success: false,
                userId: userId,
                pulledEvents: 0,
                mergedStates: 0,
                mergedProfiles: 0,
                message: "Sync skipped: \(environment.message)"
            )
        }

        do {
            let localSnapshot = try localSnapshot(modelContext: context, userId: userId)
            let remote = try await fetchRemoteSnapshot(for: userId)
            let merged = await resolver.merge(local: localSnapshot, remote: remote.snapshot)

            try applyMergedSnapshot(merged.snapshot, to: context, userId: userId)

            do {
                try await saveSnapshot(
                    merged.snapshot,
                    for: userId,
                    existingRecord: remote.record
                )
            } catch let ckError as CKError where ckError.code == .serverRecordChanged {
                // One retry with latest server payload to preserve eventual consistency.
                let latestRemote = try await fetchRemoteSnapshot(for: userId)
                let mergedRetry = await resolver.merge(local: merged.snapshot, remote: latestRemote.snapshot)
                try applyMergedSnapshot(mergedRetry.snapshot, to: context, userId: userId)
                try await saveSnapshot(
                    mergedRetry.snapshot,
                    for: userId,
                    existingRecord: latestRemote.record
                )
                return CloudKitSyncReport(
                    success: true,
                    userId: userId,
                    pulledEvents: mergedRetry.report.mergedEventCount,
                    mergedStates: mergedRetry.report.mergedStateCount,
                    mergedProfiles: mergedRetry.report.mergedProfileCount,
                    message: "Sync completed after server-change retry."
                )
            }

            return CloudKitSyncReport(
                success: true,
                userId: userId,
                pulledEvents: merged.report.mergedEventCount,
                mergedStates: merged.report.mergedStateCount,
                mergedProfiles: merged.report.mergedProfileCount,
                message: "Sync completed."
            )
        } catch {
            return CloudKitSyncReport(
                success: false,
                userId: userId,
                pulledEvents: 0,
                mergedStates: 0,
                mergedProfiles: 0,
                message: "Sync skipped: \(error.localizedDescription)"
            )
        }
    }

    public func validateRuntimeEnvironment() async -> CloudKitEnvironmentReport {
        #if targetEnvironment(simulator)
        return CloudKitEnvironmentReport(
            canSync: false,
            isSimulator: true,
            hasEntitlement: false,
            accountStatus: nil,
            message: "CloudKit sync is unavailable on Simulator builds."
        )
        #else
        guard Self.hasCloudKitEntitlement() else {
            return CloudKitEnvironmentReport(
                canSync: false,
                isSimulator: false,
                hasEntitlement: false,
                accountStatus: nil,
                message: "CloudKit entitlement is missing from this build."
            )
        }

        do {
            let status = try await fetchAccountStatus()
            if status == .available {
                return CloudKitEnvironmentReport(
                    canSync: true,
                    isSimulator: false,
                    hasEntitlement: true,
                    accountStatus: status,
                    message: "CloudKit environment validated."
                )
            }
            return CloudKitEnvironmentReport(
                canSync: false,
                isSimulator: false,
                hasEntitlement: true,
                accountStatus: status,
                message: "CloudKit account status is \(statusDescription(status))."
            )
        } catch {
            return CloudKitEnvironmentReport(
                canSync: false,
                isSimulator: false,
                hasEntitlement: true,
                accountStatus: nil,
                message: "CloudKit account status check failed: \(error.localizedDescription)"
            )
        }
        #endif
    }

    // MARK: - Local Snapshot

    @MainActor
    private func localSnapshot(modelContext: ModelContext, userId: String) throws -> SyncSnapshot {
        let events = try modelContext.fetch(FetchDescriptor<ReviewEvent>())
            .filter { $0.userId == userId }
            .map(SyncReviewEvent.init(from:))

        let states = try modelContext.fetch(FetchDescriptor<UserWordState>())
            .filter { $0.userId == userId }
            .map(SyncUserWordState.init(from:))

        let profileDescriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.userId == userId }
        )
        let profiles = try modelContext.fetch(profileDescriptor).map(SyncUserProfile.init(from:))

        return SyncSnapshot(
            reviewEvents: events,
            userWordStates: states,
            userProfiles: profiles,
            generatedAt: Date()
        )
    }

    // MARK: - CloudKit Transport

    private struct RemoteSnapshot {
        let snapshot: SyncSnapshot
        let record: CKRecord?
    }

    private func fetchRemoteSnapshot(for userId: String) async throws -> RemoteSnapshot {
        let recordID = CKRecord.ID(recordName: recordName(for: userId))

        do {
            guard let record = try await fetchRecord(recordID: recordID) else {
                return RemoteSnapshot(snapshot: SyncSnapshot(), record: nil)
            }

            guard let payloadData = record[payloadKey] as? Data else {
                return RemoteSnapshot(snapshot: SyncSnapshot(), record: record)
            }

            let payload = try decoder.decode(SyncSnapshot.self, from: payloadData)
            return RemoteSnapshot(snapshot: payload, record: record)
        } catch let error as CKError where error.code == .unknownItem {
            return RemoteSnapshot(snapshot: SyncSnapshot(), record: nil)
        }
    }

    private func saveSnapshot(
        _ snapshot: SyncSnapshot,
        for userId: String,
        existingRecord: CKRecord?
    ) async throws {
        let record: CKRecord = existingRecord ?? CKRecord(
            recordType: recordType,
            recordID: CKRecord.ID(recordName: recordName(for: userId))
        )

        guard let data = try? encoder.encode(snapshot) else {
            throw CloudKitSyncError.payloadEncodingFailed
        }

        record[userIdKey] = userId as CKRecordValue
        record[payloadKey] = data as CKRecordValue
        record[updatedAtKey] = Date() as CKRecordValue
        _ = try await saveRecord(record)
    }

    private func fetchRecord(recordID: CKRecord.ID) async throws -> CKRecord? {
        guard let database else {
            return nil
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord?, Error>) in
            database.fetch(withRecordID: recordID) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: record)
            }
        }
    }

    private func saveRecord(_ record: CKRecord) async throws -> CKRecord {
        guard let database else {
            throw CKError(.notAuthenticated)
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
            database.save(record) { saved, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let saved else {
                    continuation.resume(throwing: CloudKitSyncError.invalidRecord)
                    return
                }
                continuation.resume(returning: saved)
            }
        }
    }

    private func recordName(for userId: String) -> String {
        let encoded = Data(userId.utf8).base64EncodedString()
        let safe = encoded
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
        return "sync_\(safe)"
    }

    private static func makeDatabaseIfAvailable() -> CKDatabase? {
        guard hasCloudKitEntitlement() else {
            print("CloudKitSyncManager: CloudKit entitlement missing. Sync disabled.")
            return nil
        }
        return CKContainer.default().privateCloudDatabase
    }

    private static func hasCloudKitEntitlement() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        guard let task = SecTaskCreateFromSelf(nil) else {
            return false
        }
        let cloudKitServices = SecTaskCopyValueForEntitlement(
            task,
            "com.apple.developer.icloud-services" as CFString,
            nil
        ) as? [String]
        let containers = SecTaskCopyValueForEntitlement(
            task,
            "com.apple.developer.icloud-container-identifiers" as CFString,
            nil
        ) as? [String]

        let hasCloudKitService = cloudKitServices?.contains("CloudKit") ?? false
        let hasContainer = !(containers?.isEmpty ?? true)
        return hasCloudKitService && hasContainer
        #endif
    }

    private func fetchAccountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKAccountStatus, Error>) in
            CKContainer.default().accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: status)
            }
        }
    }

    private func statusDescription(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "available"
        case .noAccount:
            return "noAccount"
        case .restricted:
            return "restricted"
        case .couldNotDetermine:
            return "couldNotDetermine"
        case .temporarilyUnavailable:
            return "temporarilyUnavailable"
        @unknown default:
            return "unknown"
        }
    }

    // MARK: - Apply Merged Snapshot

    @MainActor
    private func applyMergedSnapshot(
        _ snapshot: SyncSnapshot,
        to modelContext: ModelContext,
        userId: String
    ) throws {
        try upsertProfiles(snapshot.userProfiles.filter { $0.userId == userId }, modelContext: modelContext)
        try upsertReviewEvents(snapshot.reviewEvents.filter { $0.userId == userId }, modelContext: modelContext)
        try upsertStates(snapshot.userWordStates.filter { $0.userId == userId }, modelContext: modelContext)
        try modelContext.save()
    }

    @MainActor
    private func upsertProfiles(_ profiles: [SyncUserProfile], modelContext: ModelContext) throws {
        for payload in profiles {
            let descriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { $0.userId == payload.userId }
            )
            let profile = try modelContext.fetch(descriptor).first ?? {
                let created = UserProfile(userId: payload.userId)
                modelContext.insert(created)
                return created
            }()

            profile.displayName = payload.displayName
            profile.emailRelay = payload.emailRelay
            profile.lexicalRank = payload.lexicalRank
            profile.interestVector = payload.interestVector
            profile.ignoredWords = payload.ignoredWords
            profile.easyRatingVelocity = payload.easyRatingVelocity
            profile.cycleCount = payload.cycleCount
            profile.subscriptionTierRawValue = payload.subscriptionTierRawValue
            profile.entitlementSourceRawValue = payload.entitlementSourceRawValue
            profile.entitlementUpdatedAt = payload.entitlementUpdatedAt
            profile.entitlementExpiresAt = payload.entitlementExpiresAt
            profile.fsrsParameterModeRawValue = payload.fsrsParameterModeRawValue
            profile.fsrsRequestRetention = payload.fsrsRequestRetention
            profile.stateUpdatedAt = payload.stateUpdatedAt
        }
    }

    @MainActor
    private func upsertReviewEvents(_ events: [SyncReviewEvent], modelContext: ModelContext) throws {
        let existing = try modelContext.fetch(FetchDescriptor<ReviewEvent>())
        var existingIDs = Set(existing.map(\.eventId))

        for payload in events {
            guard !existingIDs.contains(payload.eventId) else { continue }
            let event = ReviewEvent(
                eventId: payload.eventId,
                userId: payload.userId,
                lemma: payload.lemma,
                grade: payload.grade,
                reviewDate: payload.reviewDate,
                durationMs: payload.durationMs,
                scheduledDays: payload.scheduledDays,
                reviewState: payload.reviewState,
                deviceId: payload.deviceId,
                sourceReviewLogId: payload.sourceReviewLogId
            )
            modelContext.insert(event)
            existingIDs.insert(payload.eventId)
        }
    }

    @MainActor
    private func upsertStates(_ states: [SyncUserWordState], modelContext: ModelContext) throws {
        let existing = try modelContext.fetch(FetchDescriptor<UserWordState>())
        var byKey: [String: UserWordState] = [:]
        byKey.reserveCapacity(existing.count)
        for state in existing {
            byKey[state.userLemmaKey] = state
        }

        for payload in states {
            let state = byKey[payload.userLemmaKey] ?? {
                let created = UserWordState(
                    userId: payload.userId,
                    lemma: payload.lemma,
                    status: payload.status
                )
                modelContext.insert(created)
                byKey[payload.userLemmaKey] = created
                return created
            }()

            state.statusRawValue = payload.statusRawValue
            state.stability = payload.stability
            state.difficulty = payload.difficulty
            state.retrievability = payload.retrievability
            state.nextReviewDate = payload.nextReviewDate
            state.lastReviewDate = payload.lastReviewDate
            state.reviewCount = payload.reviewCount
            state.lapseCount = payload.lapseCount
            state.stateUpdatedAt = payload.stateUpdatedAt
        }
    }

}
