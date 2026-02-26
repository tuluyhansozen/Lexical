import XCTest
@testable import Lexical

final class OnboardingFlowModelTests: XCTestCase {
    func testStepOrderIncludesPremiumBeforeCompletion() {
        XCTAssertEqual(OnboardingStep.allCases.count, 9)
        XCTAssertEqual(OnboardingStep.premiumOffer.rawValue, 7)
        XCTAssertEqual(OnboardingStep.completion.rawValue, 8)
    }

    func testPrimaryButtonTitleForPremiumStep() {
        XCTAssertEqual(
            OnboardingFlowModel.primaryButtonTitle(for: .premiumOffer),
            "Continue with Free"
        )
    }

    func testRepoFirstVisualTokens() {
        XCTAssertEqual(OnboardingFlowModel.accentHex, "144932")
        XCTAssertEqual(OnboardingFlowModel.backgroundHex, "F5F5F7")
        XCTAssertEqual(OnboardingFlowModel.progressTrackHex, "BCBCBC")
    }

    func testSkippableStepsPolicy() {
        XCTAssertTrue(OnboardingFlowModel.skippableSteps.contains(.interests))
        XCTAssertTrue(OnboardingFlowModel.skippableSteps.contains(.articleStyle))
        XCTAssertTrue(OnboardingFlowModel.skippableSteps.contains(.notifications))
        XCTAssertTrue(OnboardingFlowModel.skippableSteps.contains(.premiumOffer))
        XCTAssertFalse(OnboardingFlowModel.skippableSteps.contains(.rankCalibration))
    }

    func testLegacyCompletionStepMigration() {
        let migrated = OnboardingFlowModel.migratePersistedStep(
            7,
            fromFlowVersion: 1,
            toFlowVersion: OnboardingFlowModel.currentFlowVersion
        )

        XCTAssertEqual(migrated, OnboardingStep.completion.rawValue)
    }

    func testLegacyIntermediateStepMigrationLeavesIndexUntouched() {
        let migrated = OnboardingFlowModel.migratePersistedStep(
            6,
            fromFlowVersion: 1,
            toFlowVersion: OnboardingFlowModel.currentFlowVersion
        )

        XCTAssertEqual(migrated, 6)
    }

    func testSanitizeInterestsRemovesCustomTopics() {
        let sanitized = OnboardingFlowModel.sanitizeInterests([
            "Technology",
            "Science",
            "My Custom Topic"
        ])

        XCTAssertEqual(sanitized, Set(["Technology", "Science"]))
        XCTAssertFalse(sanitized.contains("My Custom Topic"))
    }
}
