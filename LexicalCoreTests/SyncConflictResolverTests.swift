import XCTest
@testable import LexicalCore

final class SyncConflictResolverTests: XCTestCase {
    func testMergeReplayDeterminism() async {
        let resolver = SyncConflictResolver()
        let local = makeLocalSnapshot()
        let remote = makeRemoteSnapshot()

        let first = await resolver.merge(local: local, remote: remote).snapshot
        let second = await resolver.merge(local: local, remote: remote).snapshot

        assertEquivalentSnapshots(first, second)
    }

    func testMergeIdempotency() async {
        let resolver = SyncConflictResolver()
        let local = makeLocalSnapshot()
        let remote = makeRemoteSnapshot()

        let first = await resolver.merge(local: local, remote: remote).snapshot
        let second = await resolver.merge(local: first, remote: remote).snapshot

        assertEquivalentSnapshots(first, second)
    }

    func testMergeConvergesAcrossOrder() async {
        let resolver = SyncConflictResolver()
        let local = makeLocalSnapshot()
        let remote = makeRemoteSnapshot()

        let localThenRemote = await resolver.merge(local: local, remote: remote).snapshot
        let remoteThenLocal = await resolver.merge(local: remote, remote: local).snapshot

        assertEquivalentSnapshots(localThenRemote, remoteThenLocal)
    }

    private func assertEquivalentSnapshots(_ lhs: SyncSnapshot, _ rhs: SyncSnapshot, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.reviewEvents, rhs.reviewEvents, file: file, line: line)
        XCTAssertEqual(lhs.userWordStates, rhs.userWordStates, file: file, line: line)
        XCTAssertEqual(lhs.userProfiles, rhs.userProfiles, file: file, line: line)
    }

    private func makeLocalSnapshot() -> SyncSnapshot {
        let t100 = date(100)
        let t200 = date(200)
        let t260 = date(260)
        let t300 = date(300)
        let t400 = date(400)
        let t500 = date(500)
        let t050 = date(50)

        return SyncSnapshot(
            reviewEvents: [
                SyncReviewEvent(
                    eventId: "evt-001",
                    userId: "u1",
                    lemma: "resilient",
                    grade: 4,
                    reviewDate: t100,
                    durationMs: 1200,
                    scheduledDays: 1.5,
                    reviewState: "good",
                    deviceId: "device-a",
                    sourceReviewLogId: nil
                ),
                SyncReviewEvent(
                    eventId: "evt-002",
                    userId: "u1",
                    lemma: "resilient",
                    grade: 2,
                    reviewDate: t200,
                    durationMs: 900,
                    scheduledDays: 2.0,
                    reviewState: "hard",
                    deviceId: "device-a",
                    sourceReviewLogId: nil
                ),
            ],
            userWordStates: [
                SyncUserWordState(
                    userLemmaKey: UserWordState.makeKey(userId: "u1", lemma: "resilient"),
                    userId: "u1",
                    lemma: "resilient",
                    statusRawValue: UserWordStatus.learning.rawValue,
                    stability: 5.0,
                    difficulty: 4.0,
                    retrievability: 0.6,
                    nextReviewDate: t400,
                    lastReviewDate: t200,
                    reviewCount: 2,
                    lapseCount: 1,
                    stateUpdatedAt: t300,
                    createdAt: t050
                )
            ],
            userProfiles: [
                SyncUserProfile(
                    userId: "u1",
                    displayName: "Alice",
                    emailRelay: "relay-a@privaterelay.appleid.com",
                    lexicalRank: 3000,
                    interestVector: ["science": 0.4],
                    ignoredWords: ["ad"],
                    easyRatingVelocity: 0.2,
                    cycleCount: 1,
                    subscriptionTierRawValue: SubscriptionTier.free.rawValue,
                    entitlementSourceRawValue: EntitlementSource.localCache.rawValue,
                    entitlementUpdatedAt: t500,
                    entitlementExpiresAt: nil,
                    fsrsParameterModeRawValue: FSRSParameterMode.standard.rawValue,
                    fsrsRequestRetention: 0.9,
                    stateUpdatedAt: t500,
                    createdAt: t050
                )
            ],
            generatedAt: t260
        )
    }

    private func makeRemoteSnapshot() -> SyncSnapshot {
        let t200 = date(200)
        let t260 = date(260)
        let t300 = date(300)
        let t360 = date(360)
        let t500 = date(500)
        let t070 = date(70)

        return SyncSnapshot(
            reviewEvents: [
                // Duplicate event id should be ignored by G-Set merge.
                SyncReviewEvent(
                    eventId: "evt-002",
                    userId: "u1",
                    lemma: "resilient",
                    grade: 2,
                    reviewDate: t200,
                    durationMs: 900,
                    scheduledDays: 2.0,
                    reviewState: "hard",
                    deviceId: "device-b",
                    sourceReviewLogId: nil
                ),
                SyncReviewEvent(
                    eventId: "evt-003",
                    userId: "u1",
                    lemma: "resilient",
                    grade: 3,
                    reviewDate: t260,
                    durationMs: 800,
                    scheduledDays: 1.0,
                    reviewState: "good",
                    deviceId: "device-b",
                    sourceReviewLogId: nil
                )
            ],
            userWordStates: [
                // Same timestamp conflict to verify deterministic tie merge + replay convergence.
                SyncUserWordState(
                    userLemmaKey: UserWordState.makeKey(userId: "u1", lemma: "resilient"),
                    userId: "u1",
                    lemma: "resilient",
                    statusRawValue: UserWordStatus.known.rawValue,
                    stability: 7.0,
                    difficulty: 3.5,
                    retrievability: 0.8,
                    nextReviewDate: t360,
                    lastReviewDate: t260,
                    reviewCount: 3,
                    lapseCount: 1,
                    stateUpdatedAt: t300,
                    createdAt: t070
                )
            ],
            userProfiles: [
                // Same timestamp conflict to verify deterministic profile merge.
                SyncUserProfile(
                    userId: "u1",
                    displayName: "Bob",
                    emailRelay: "relay-b@privaterelay.appleid.com",
                    lexicalRank: 3200,
                    interestVector: ["science": 0.6, "tech": 0.3],
                    ignoredWords: ["noise"],
                    easyRatingVelocity: 0.4,
                    cycleCount: 2,
                    subscriptionTierRawValue: SubscriptionTier.premium.rawValue,
                    entitlementSourceRawValue: EntitlementSource.appStore.rawValue,
                    entitlementUpdatedAt: t500,
                    entitlementExpiresAt: date(900),
                    fsrsParameterModeRawValue: FSRSParameterMode.personalized.rawValue,
                    fsrsRequestRetention: 0.93,
                    stateUpdatedAt: t500,
                    createdAt: t070
                )
            ],
            generatedAt: t260
        )
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }
}
