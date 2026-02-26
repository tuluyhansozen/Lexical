# Onboarding Repo-First Hybrid Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Lexical onboarding visually and interactively match the reference repo design language, while preserving Lexical logic, gating, storage migration, StoreKit integration, and automation/test contracts.

**Architecture:** Keep `OnboardingFlowModel` and `OnboardingFlowView` as the logic/control layer, and refactor step rendering in `OnboardingStepViews` + shared primitives in `OnboardingComponents` to mirror reference components (`OnboardingCoordinator`, `PrimaryButton`, `SelectableCard`, step modules). Keep premium flow and entitlement behaviors unchanged at the logic layer.

**Tech Stack:** SwiftUI, SwiftData, StoreKit (`SubscriptionStoreView`), UserDefaults/AppStorage, XCTest, shell UI automation (`idb`, `simctl`).

---

### Task 1: Lock Repo-First Visual Tokens in Shared Components

**Files:**
- Modify: `Lexical/Features/Onboarding/OnboardingComponents.swift`
- Test: `LexicalTests/OnboardingFlowModelTests.swift`

**Step 1: Write the failing test**
```swift
func testAccentAndPrimaryLabelsContract() {
    XCTAssertEqual(OnboardingFlowModel.accentHex, "144932")
    XCTAssertEqual(OnboardingFlowModel.primaryButtonTitle(for: .welcome), "Get Started")
}
```

**Step 2: Run test to verify it fails**
Run: `swift test --filter OnboardingFlowModelTests/testAccentAndPrimaryLabelsContract`
Expected: FAIL if token drift exists.

**Step 3: Write minimal implementation**
- Ensure shared components use reference-like sizes/colors:
  - background `#f5f5f7`
  - progress track `#bcbcbc` 4px
  - primary radius 14, height 48
  - selected card accent tint/border

**Step 4: Run test to verify it passes**
Run: `swift test --filter OnboardingFlowModelTests`
Expected: PASS.

**Step 5: Commit**
```bash
git add Lexical/Features/Onboarding/OnboardingComponents.swift LexicalTests/OnboardingFlowModelTests.swift
git commit -m "feat(onboarding): align shared visual tokens with repo-first parity"
```

### Task 2: Welcome Step Repo-First Parity

**Files:**
- Modify: `Lexical/Features/Onboarding/OnboardingStepViews.swift`
- Test: `LexicalTests/OnboardingFlowModelTests.swift`

**Step 1: Write the failing test**
```swift
func testWelcomePrimaryButtonLabel() {
    XCTAssertEqual(OnboardingFlowModel.primaryButtonTitle(for: .welcome), "Get Started")
}
```

**Step 2: Run test to verify it fails**
Run: `swift test --filter OnboardingFlowModelTests/testWelcomePrimaryButtonLabel`
Expected: FAIL if label regressed.

**Step 3: Write minimal implementation**
- Update welcome view layout to match repo rhythm:
  - centered icon block
  - 3 feature pills
  - floating label input treatment
  - short plan subtitle
- Keep `onboarding.welcomeHeadline` and `onboarding.nameField` IDs.

**Step 4: Run test to verify it passes**
Run: `swift test --filter OnboardingFlowModelTests`
Expected: PASS.

**Step 5: Commit**
```bash
git add Lexical/Features/Onboarding/OnboardingStepViews.swift LexicalTests/OnboardingFlowModelTests.swift
git commit -m "feat(onboarding): restyle welcome step to repo-first layout"
```

### Task 3: FSRS Step Interaction Parity

**Files:**
- Modify: `Lexical/Features/Onboarding/OnboardingStepViews.swift`

**Step 1: Write the failing test**
- Add/extend UI contract test for FSRS CTA state progression (disabled before interaction, enabled after interaction).

**Step 2: Run test to verify it fails**
Run: `swift test --filter OnboardingFlowModelTests`
Expected: FAIL on new FSRS interaction assertion.

**Step 3: Write minimal implementation**
- Implement repo-style interactive FSRS card behavior and staged feedback.
- Keep Lexical semantic copy and existing progression logic.

**Step 4: Run test to verify it passes**
Run: `swift test --filter OnboardingFlowModelTests`
Expected: PASS.

**Step 5: Commit**
```bash
git add Lexical/Features/Onboarding/OnboardingStepViews.swift LexicalTests/OnboardingFlowModelTests.swift
git commit -m "feat(onboarding): match repo fsrs interaction choreography"
```

### Task 4: Rank Calibration Visual Parity with Mandatory Gate Preserved

**Files:**
- Modify: `Lexical/Features/Onboarding/OnboardingStepViews.swift`
- Test: `LexicalTests/OnboardingProgressGateTests.swift`

**Step 1: Write the failing test**
```swift
func testCalibrationStillRequiredBeforeSkips() {
    XCTAssertFalse(OnboardingProgressGate.canSkip(selectedStep: 3, completionStep: 8, calibrationStep: 2, hasCompletedCalibration: false))
}
```

**Step 2: Run test to verify it fails**
Run: `swift test --filter OnboardingProgressGateTests/testCalibrationStillRequiredBeforeSkips`
Expected: FAIL if gate broke.

**Step 3: Write minimal implementation**
- Restyle calibration UI to repo stack/progress-chip look.
- Preserve `calibrationQuestionCount == 12` and answer completion gating.
- Preserve `onboarding.calibrationHeadline` ID.

**Step 4: Run test to verify it passes**
Run: `swift test --filter OnboardingProgressGateTests`
Expected: PASS.

**Step 5: Commit**
```bash
git add Lexical/Features/Onboarding/OnboardingStepViews.swift LexicalTests/OnboardingProgressGateTests.swift
git commit -m "feat(onboarding): repo-style calibration UI with existing gate enforcement"
```

### Task 5: Interests and Style Step Repo Card/Chip Parity

**Files:**
- Modify: `Lexical/Features/Onboarding/OnboardingStepViews.swift`

**Step 1: Write the failing test**
- Add assertions for skippable step contract unchanged (`interests`, `articleStyle`).

**Step 2: Run test to verify it fails**
Run: `swift test --filter OnboardingFlowModelTests/testSkippableStepsPolicy`
Expected: FAIL if new assertions expose drift.

**Step 3: Write minimal implementation**
- Interests: repo-like chips with custom topic add interaction.
- Article style: repo-like selectable cards and check indicator.
- Keep persistence wiring unchanged.

**Step 4: Run test to verify it passes**
Run: `swift test --filter OnboardingFlowModelTests`
Expected: PASS.

**Step 5: Commit**
```bash
git add Lexical/Features/Onboarding/OnboardingStepViews.swift LexicalTests/OnboardingFlowModelTests.swift
git commit -m "feat(onboarding): align interests and style steps to repo component patterns"
```

### Task 6: Reading Primer and Notifications Step Parity

**Files:**
- Modify: `Lexical/Features/Onboarding/OnboardingStepViews.swift`
- Modify: `Lexical/Features/Onboarding/OnboardingFlowView.swift`

**Step 1: Write the failing test**
- Add contract test that notification step remains skippable and permission action remains contextual.

**Step 2: Run test to verify it fails**
Run: `swift test --filter OnboardingFlowModelTests`
Expected: FAIL on new contract assertion.

**Step 3: Write minimal implementation**
- Reading step: repo-style tappable highlighted word + info sheet reveal.
- Notifications: repo soft-ask with schedule preview and defer affordance.
- Keep existing permission request call path in flow controller.

**Step 4: Run test to verify it passes**
Run: `swift test --filter OnboardingFlowModelTests`
Expected: PASS.

**Step 5: Commit**
```bash
git add Lexical/Features/Onboarding/OnboardingStepViews.swift Lexical/Features/Onboarding/OnboardingFlowView.swift LexicalTests/OnboardingFlowModelTests.swift
git commit -m "feat(onboarding): repo-style reading and notifications steps with contextual permission"
```

### Task 7: Premium Step Restyle to Repo Language (Logic Fixed)

**Files:**
- Modify: `Lexical/Features/Onboarding/OnboardingStepViews.swift`
- Modify: `Lexical/Features/Onboarding/OnboardingFlowView.swift`
- Modify: `Lexical/Info.plist`

**Step 1: Write the failing test**
```swift
func testPremiumPrimaryButtonContract() {
    XCTAssertEqual(OnboardingFlowModel.primaryButtonTitle(for: .premiumOffer), "Continue with Free")
}
```

**Step 2: Run test to verify it fails**
Run: `swift test --filter OnboardingFlowModelTests/testPremiumPrimaryButtonContract`
Expected: FAIL if label drift exists.

**Step 3: Write minimal implementation**
- Restyle premium step to match repo card hierarchy and spacing.
- Preserve behavior:
  - `SubscriptionStoreView`
  - restore
  - legal links
  - explicit free path
  - auto-advance on entitlement
- Keep `onboarding.premiumHeadline`, `onboarding.continueFreeButton` IDs.

**Step 4: Run test to verify it passes**
Run: `swift test --filter OnboardingFlowModelTests`
Expected: PASS.

**Step 5: Commit**
```bash
git add Lexical/Features/Onboarding/OnboardingStepViews.swift Lexical/Features/Onboarding/OnboardingFlowView.swift Lexical/Info.plist LexicalTests/OnboardingFlowModelTests.swift
git commit -m "feat(onboarding): repo-first premium styling with lexical purchase behavior preserved"
```

### Task 8: Completion Step Repo Summary Styling

**Files:**
- Modify: `Lexical/Features/Onboarding/OnboardingStepViews.swift`

**Step 1: Write the failing test**
- Add completion CTA and index contract test.

**Step 2: Run test to verify it fails**
Run: `swift test --filter OnboardingFlowModelTests`
Expected: FAIL if completion contract mismatch.

**Step 3: Write minimal implementation**
- Restyle completion to repo success motif and summary rows.
- Keep `onboarding.completionHeadline` and `Start Learning` CTA.

**Step 4: Run test to verify it passes**
Run: `swift test --filter OnboardingFlowModelTests`
Expected: PASS.

**Step 5: Commit**
```bash
git add Lexical/Features/Onboarding/OnboardingStepViews.swift LexicalTests/OnboardingFlowModelTests.swift
git commit -m "feat(onboarding): apply repo-style completion summary layout"
```

### Task 9: Canvas Preview Expansion for Visual QA

**Files:**
- Modify: `Lexical/Features/Onboarding/OnboardingFlowView.swift`

**Step 1: Write the failing test**
- N/A (preview-only); document expected preview variants.

**Step 2: Run baseline compile check**
Run: `xcodebuild -scheme Lexical -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: baseline passes before preview changes.

**Step 3: Write minimal implementation**
- Keep and extend previews for:
  - welcome
  - calibration
  - premium
  - completion
- Keep preview guard to avoid entitlement polling drift.

**Step 4: Run compile check**
Run: `xcodebuild -scheme Lexical -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: PASS.

**Step 5: Commit**
```bash
git add Lexical/Features/Onboarding/OnboardingFlowView.swift
git commit -m "chore(onboarding): add repo-parity canvas previews for rapid visual checks"
```

### Task 10: UI Automation Contract Update

**Files:**
- Modify: `scripts/ui_automation/run_true_ui.sh`
- Modify: `Lexical/Services/E2ETestLaunchConfigurator.swift`

**Step 1: Write the failing test/assertion**
- Add/adjust assertions for repo-first parity labels while preserving required IDs.

**Step 2: Run script to verify failure**
Run: `bash scripts/ui_automation/run_true_ui.sh`
Expected: FAIL at first outdated selector/label.

**Step 3: Write minimal implementation**
- Align assertions with final step labels/IDs.
- Keep premium free-path test and prompt-close routing checks current.

**Step 4: Run script to verify pass**
Run: `bash scripts/ui_automation/run_true_ui.sh`
Expected: PASS across all scenarios.

**Step 5: Commit**
```bash
git add scripts/ui_automation/run_true_ui.sh Lexical/Services/E2ETestLaunchConfigurator.swift
git commit -m "test(ui): update onboarding automation for repo-first hybrid parity"
```

### Task 11: Full Verification Before Completion

**Files:**
- Modify: if needed based on failures only

**Step 1: Run unit verification**
Run: `swift test --filter OnboardingProgressGateTests`
Expected: PASS.

**Step 2: Run model flow verification**
Run: `swift test --filter OnboardingFlowModelTests`
Expected: PASS.

**Step 3: Run app build verification**
Run: `xcodebuild -scheme Lexical -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: PASS.

**Step 4: Run UI automation verification**
Run: `bash scripts/ui_automation/run_true_ui.sh`
Expected: PASS.

**Step 5: Commit verification artifacts/log adjustments if needed**
```bash
git add -A
git commit -m "chore(onboarding): finalize repo-first hybrid onboarding parity with green verification"
```
