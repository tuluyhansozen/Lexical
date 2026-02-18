import XCTest
@testable import Lexical

final class OnboardingProgressGateTests: XCTestCase {
    private let calibrationStep = 2
    private let completionStep = 7

    func testNormalizeSelectedStepPinsToCalibrationWhenNotCompleted() {
        let normalized = OnboardingProgressGate.normalizeSelectedStep(
            6,
            completionStep: completionStep,
            calibrationStep: calibrationStep,
            hasCompletedCalibration: false
        )

        XCTAssertEqual(normalized, calibrationStep)
    }

    func testNormalizeSelectedStepPreservesProgressWhenCompleted() {
        let normalized = OnboardingProgressGate.normalizeSelectedStep(
            6,
            completionStep: completionStep,
            calibrationStep: calibrationStep,
            hasCompletedCalibration: true
        )

        XCTAssertEqual(normalized, 6)
    }

    func testCanSkipRequiresCalibrationCompletion() {
        XCTAssertFalse(
            OnboardingProgressGate.canSkip(
                selectedStep: 1,
                completionStep: completionStep,
                calibrationStep: calibrationStep,
                hasCompletedCalibration: false
            )
        )
        XCTAssertTrue(
            OnboardingProgressGate.canSkip(
                selectedStep: 1,
                completionStep: completionStep,
                calibrationStep: calibrationStep,
                hasCompletedCalibration: true
            )
        )
    }
}
