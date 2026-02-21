# Explore Figma Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor Explore UI to match the supplied Figma Explore page with 1:1 visual intent while keeping dynamic resolver-driven data and existing interactions.

**Architecture:** Keep current Explore data flow and interaction contracts intact, and isolate this work to presentation/layout layers in `ExploreView` plus design-system glass rendering in `LiquidGlassButton`. Use a deterministic Figma reference spec helper for positions/sizes/styles so tests can validate the refactor. Preserve adaptive dark mode and reduced-transparency fallbacks.

**Tech Stack:** SwiftUI, SwiftData, LexicalCore design system, XCTest, xcodebuild/simulator CLI.

---

### Task 1: Add Figma Layout Spec Test Coverage (TDD Red)

**Files:**
- Modify: `/Users/tuluyhan/projects/Lexical/Lexical/Features/Explore/ExploreView.swift`
- Create: `/Users/tuluyhan/projects/Lexical/LexicalTests/ExploreFigmaSpecTests.swift`

**Step 1: Write the failing test**

Create tests that assert reference values exposed by an internal testable spec helper:
- root label defaults to `spec`
- root node position and diameter match expected constants
- six leaf slots exist with exact labels/positions/diameters

**Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -scheme Lexical -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LexicalTests/ExploreFigmaSpecTests
```
Expected: FAIL because helper/surface for tests does not yet exist.

**Step 3: Write minimal implementation**

Add an internal `ExploreFigmaSpec` type that provides the tested constants and adapt `ExploreView` to consume it.

**Step 4: Run test to verify it passes**

Run:
```bash
xcodebuild test -scheme Lexical -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LexicalTests/ExploreFigmaSpecTests
```
Expected: PASS.

**Step 5: Commit**

```bash
git add /Users/tuluyhan/projects/Lexical/Lexical/Features/Explore/ExploreView.swift /Users/tuluyhan/projects/Lexical/LexicalTests/ExploreFigmaSpecTests.swift
git commit -m "test: add Explore Figma reference spec coverage"
```

---

### Task 2: Refactor Explore Header and Matrix Shell to Figma Fidelity

**Files:**
- Modify: `/Users/tuluyhan/projects/Lexical/Lexical/Features/Explore/ExploreView.swift`

**Step 1: Write the failing test**

Extend tests to validate style-oriented helper outputs for:
- light mode background color token
- header title/subtitle copy defaults
- connector width/opacity constants

**Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -scheme Lexical -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LexicalTests/ExploreFigmaSpecTests
```
Expected: FAIL because helper constants are missing.

**Step 3: Write minimal implementation**

- Build Figma-accurate header block (title/subtitle spacing, typography scale, tracking).
- Tune matrix padding, position scaling, and connector paint.
- Ensure adaptive dark mode styles remain active.

**Step 4: Run test to verify it passes**

Run:
```bash
xcodebuild test -scheme Lexical -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LexicalTests/ExploreFigmaSpecTests
```
Expected: PASS.

**Step 5: Commit**

```bash
git add /Users/tuluyhan/projects/Lexical/Lexical/Features/Explore/ExploreView.swift /Users/tuluyhan/projects/Lexical/LexicalTests/ExploreFigmaSpecTests.swift
git commit -m "feat: refactor Explore shell to Figma parity"
```

---

### Task 3: Rebuild Liquid Glass Styles for Root and Leaf Nodes

**Files:**
- Modify: `/Users/tuluyhan/projects/Lexical/LexicalCore/DesignSystem/LiquidGlassButton.swift`

**Step 1: Write the failing test**

Add assertions in Explore spec tests for expected role-to-style mapping through helper outputs:
- root uses dedicated coral style key
- leaf uses dedicated green glass style key

**Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -scheme Lexical -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LexicalTests/ExploreFigmaSpecTests
```
Expected: FAIL until style mapping helper is introduced.

**Step 3: Write minimal implementation**

- Tune root fill/gradient/specular/border stack.
- Tune leaf fill/overlay/stroke/shadow stack.
- Preserve interaction scale behavior and reduced-transparency safe behavior.

**Step 4: Run test to verify it passes**

Run:
```bash
xcodebuild test -scheme Lexical -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LexicalTests/ExploreFigmaSpecTests
```
Expected: PASS.

**Step 5: Commit**

```bash
git add /Users/tuluyhan/projects/Lexical/LexicalCore/DesignSystem/LiquidGlassButton.swift /Users/tuluyhan/projects/Lexical/Lexical/Features/Explore/ExploreView.swift /Users/tuluyhan/projects/Lexical/LexicalTests/ExploreFigmaSpecTests.swift
git commit -m "feat: align liquid glass buttons with Explore Figma design"
```

---

### Task 4: Validate Integration and Run Boot/Open Simulation

**Files:**
- Modify (if needed): `/Users/tuluyhan/projects/Lexical/Lexical/ContentView.swift`
- Artifacts: `/Users/tuluyhan/projects/Lexical/build/ui_validation/`

**Step 1: Run targeted tests**

Run:
```bash
xcodebuild test -scheme Lexical -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:LexicalTests/ExploreFigmaSpecTests
```
Expected: PASS.

**Step 2: Build app for simulator**

Run:
```bash
xcodebuild -scheme Lexical -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```
Expected: BUILD SUCCEEDED.

**Step 3: Boot/open to Explore and capture screenshot**

Run simulator launch flow with `--lexical-debug-open-explore`, then capture screenshot via `xcrun simctl io ... screenshot` into `/Users/tuluyhan/projects/Lexical/build/ui_validation/`.

**Step 4: Verify artifact and report**

Confirm screenshot exists and summarize result.

**Step 5: Commit**

```bash
git add /Users/tuluyhan/projects/Lexical/Lexical/Features/Explore/ExploreView.swift /Users/tuluyhan/projects/Lexical/LexicalCore/DesignSystem/LiquidGlassButton.swift /Users/tuluyhan/projects/Lexical/LexicalTests/ExploreFigmaSpecTests.swift /Users/tuluyhan/projects/Lexical/docs/plans/2026-02-20-explore-figma-parity-design.md /Users/tuluyhan/projects/Lexical/docs/plans/2026-02-20-explore-figma-parity.md
git commit -m "feat: refactor Explore UI to Figma parity and validate in simulator"
```
