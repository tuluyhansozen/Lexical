import Foundation

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case fsrsPrimer
    case rankCalibration
    case interests
    case articleStyle
    case readingPrimer
    case notifications
    case premiumOffer
    case completion
}

enum OnboardingFlowModel {
    static let currentFlowVersion = 2
    static let legacyCompletionStep = 7
    static let accentHex = "144932"
    static let backgroundHex = "F5F5F7"
    static let progressTrackHex = "BCBCBC"

    static let skippableSteps: Set<OnboardingStep> = [
        .interests,
        .articleStyle,
        .notifications,
        .premiumOffer
    ]

    private static let allowedInterestTitles: Set<String> = Set(InterestCatalog.all.map(\.title))

    static func primaryButtonTitle(for step: OnboardingStep) -> String {
        switch step {
        case .welcome:
            return "Get Started"
        case .premiumOffer:
            return "Continue with Free"
        case .completion:
            return "Start Learning"
        default:
            return "Continue"
        }
    }

    static func migratePersistedStep(
        _ step: Int,
        fromFlowVersion: Int,
        toFlowVersion: Int = currentFlowVersion
    ) -> Int {
        guard fromFlowVersion < toFlowVersion else {
            return clampStep(step)
        }

        var migrated = step
        if fromFlowVersion < currentFlowVersion,
           migrated >= legacyCompletionStep {
            migrated += 1
        }

        return clampStep(migrated)
    }

    static func clampStep(_ raw: Int) -> Int {
        min(max(raw, 0), OnboardingStep.completion.rawValue)
    }

    static func sanitizeInterests(_ selectedInterests: Set<String>) -> Set<String> {
        selectedInterests.intersection(allowedInterestTitles)
    }
}

enum OnboardingProgressGate {
    static func normalizeSelectedStep(
        _ selectedStep: Int,
        completionStep: Int,
        calibrationStep: Int,
        hasCompletedCalibration: Bool
    ) -> Int {
        let guardrailStep = min(max(0, calibrationStep), completionStep)
        guard !hasCompletedCalibration, selectedStep > guardrailStep else { return selectedStep }
        return guardrailStep
    }

    static func canSkip(
        selectedStep: Int,
        completionStep: Int,
        calibrationStep: Int,
        hasCompletedCalibration: Bool
    ) -> Bool {
        guard hasCompletedCalibration else { return false }
        let normalizedStep = normalizeSelectedStep(
            selectedStep,
            completionStep: completionStep,
            calibrationStep: calibrationStep,
            hasCompletedCalibration: hasCompletedCalibration
        )
        return normalizedStep < completionStep
    }
}
