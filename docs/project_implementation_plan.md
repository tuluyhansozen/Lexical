# Lexical App: Project Implementation Plan

> **Generated:** 2026-01-31
> **Last Updated:** 2026-02-08
> **Status:** Core Features Complete | Strategic Requirements Merged | Phase 8 Complete | Phase 9 Complete

---

## Overview

This document outlines the complete implementation roadmap for the Lexical App, an agent-first vocabulary acquisition system. Each phase is divided into three sections for clear implementation guidance.

---

# ✅ COMPLETED PHASES

---

## Phase 1: Foundation & Environment Setup

**Status:** ✅ Complete

### Section 1: Objective
Construct the "Digital Shipyard" by initializing the Antigravity IDE, configuring agent personas, and establishing hardware control via MCP.

### Section 2: Key Activities
- Initialize `.agent` directory structure with `rules/`, `skills/`, `memory.md`
- Configure `uv` package manager for PEP 723 inline scripts
- Set up MCP (`ios-simulator-mcp`) for simulator control
- Create agent personas: Architect, Senior Engineer, QA Engineer

### Section 3: Deliverables
- [x] `.agent/` configuration package
- [x] 19 Skill files (FSRS, Liquid Glass, CRDT, etc.)
- [x] `mcp_config.json` with iOS Simulator integration
- [x] `verification_report.md` artifact

---

## Phase 2: Architecture & Core Logic

**Status:** ✅ Complete

### Section 1: Objective
Implement the offline-first data layer (SwiftData), FSRS 4.5 algorithm, and CRDT synchronization engine.

### Section 2: Key Activities
- Design SwiftData schema: `VocabularyItem` (with `collocations`), `ReviewLog`
- Implement `FSRSV4Engine` (Swift Actor) with stability/difficulty calculations
- Build CRDT foundation: G-Set for logs, LWW-Set for state
- Create `BanditScheduler` stub for future engagement optimization

### Section 3: Deliverables
- [x] `Lexical/Models/` - SwiftData entities
- [x] `Lexical/Services/FSRSV4Engine.swift`
- [x] `Lexical/Sync/CRDTLog.swift`
- [x] Unit tests for FSRS math and SwiftData persistence

---

## Phase 3: Core UI Implementation

**Status:** ✅ Complete

### Section 1: Objective
Build the "Liquid Glass" design system and primary navigation structure.

### Section 2: Key Activities
- Create `LexicalTheme` with Midnight/Cloud color palette
- Implement `GlassEffectContainer` using `UIVisualEffectView`
- Build `LiquidBackground` with animated gradients
- Develop `AppTabNavigation` with Home, Library, Profile tabs

### Section 3: Deliverables
- [x] `Lexical/UI/DesignSystem/` - Theme, Glass, Background
- [x] `Lexical/UI/Navigation/AppTabNavigation.swift`
- [x] `Lexical/UI/Screens/Home/HomeDashboardView.swift`
- [x] `Lexical/UI/Screens/Library/LibraryListView.swift`

---

## Phase 4: The Acquisition Engine (Immersive Reader)

**Status:** ✅ Complete

### Section 1: Objective
Build the "Input" interface using TextKit 2 to facilitate contextual vocabulary acquisition with "Blue/Yellow/Known" state visualization.

### Section 2: Key Activities
- **TextKit 2 Integration:** Implemented `ReaderTextView` UIViewRepresentable with vocabulary highlighting
- **NLP Pipeline:** Created `TokenizationActor` for background lemmatization using `NaturalLanguage` framework
- **Tap-to-Capture:** Built capture sheet with sentence boundary extraction
- **SwiftData Models:** Created `VocabularyItem` (w/ collocations), `ReviewLog`

### Section 3: Deliverables
- [x] `ReaderView.swift` - Full reader with highlighting integration
- [x] `ReaderTextView.swift` - UIKit text view with vocabulary coloring
- [x] `TokenizationActor.swift` - Background NLP processing
- [x] `LemmaResolver.swift` - SwiftData batch lookups with caching
- [x] `VocabularyItem.swift`, `ReviewLog.swift`

---

## Phase 5: The Retention Engine (FSRS Review Loop)

**Status:** ✅ Complete

### Section 1: Objective
Build the "Output" interface enforcing "Recall Dominance" with FSRS-driven study sessions and Brain Boost integration.

### Section 2: Key Activities
- **Flashcard UI:** Created `FlashcardView` with 3D flip animation and Cloze Rendering
- **Grading System:** Implemented 4-button FSRS grading (Again/Hard/Good/Easy)
- **Brain Boost:** Implemented re-queueing logic for failed cards in `SessionManager`
- **Dependencies:** Backfilled `FSRSV4Engine`, `GlassEffectContainer`, `LiquidBackground`

### Section 3: Deliverables
- [x] `FlashcardView.swift` with 3D transitions
- [x] `SessionManager.swift` with FSRS queue logic
- [x] `ReviewSessionView.swift` main container
- [x] `FSRSV4Engine.swift` (Backfilled)

---

## Phase 6: Home Screen Offensive (Widgets & Intents)

**Status:** ✅ Complete

### Section 1: Objective
Enable "Micro-Dose" learning via App Intents and Widgets (Preparation).

### Section 2: Key Activities
- **Shared Persistence:** Updated ModelContainer to use App Group storage via `Persistence.sharedModelContainer`.
- **Intents:** Implemented `GradeCardIntent` and `GetDueCountIntent` for Siri/Shortcuts.
- **Widget:** Implemented `MicroDoseWidget` code with Liquid Glass styling and TimelineProvider.

### Section 3: Deliverables
- [x] `Persistence.swift` with App Group support
- [x] `ReviewIntents.swift` (AppIntents)
- [x] `MicroDoseWidget.swift` (Code Verification)
- [x] Build Passed

---

## Phase 7: Intelligent Engagement & Integration

**Status:** ✅ Complete

### Section 1: Objective
Implement adaptive notifications via Bandit Algorithms, Morphology Matrix visualization, and final system integration.

### Section 2: Key Activities
- **Bandit Scheduler:** Implemented Epsilon-Greedy MAB for notification optimization with time slot selection.
- **Collocation Matrix:** Built force-directed graph visualizing semantic word connections (collocations) using SwiftUI Canvas.
- **Final Integration:** Integrated Matrix tab into main navigation, updated CustomTabBar.

### Section 3: Deliverables
- [x] `BanditScheduler.swift` with notification templates
- [x] `ForceDirectedGraph.swift` physics engine
- [x] `WordMatrixView.swift` with Canvas-based graph
- [x] Navigation integration (ContentView, CustomTabBar)

---

## Phase 0: Build Stabilization & Plan Sync

**Status:** ✅ Complete

### Section 1: Objective
Clear compile blockers/warnings and synchronize implementation tracking documents before continuing product feature work.

### Section 2: Key Activities
- **Cross-Platform Imports:** Added conditional UIKit/AppKit imports to keep shared targets buildable (`ReviewLog`, `Colors`).
- **Glass Abstraction:** Reworked `GlassEffectContainer` to use a platform-safe `GlassMaterial` API for iOS/macOS compatibility.
- **Package Cleanup:** Excluded non-source plist/privacy files from SwiftPM executable targets to remove unhandled-file warnings.
- **Concurrency Fix:** Removed actor-isolation warning in `ArticleStore` by moving directory creation to actor-isolated runtime paths.
- **Build Verification:** Rebuilt iOS simulator target using `xcodebuild -scheme Lexical -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e' build` on 2026-02-07.

### Section 3: Deliverables
- [x] `LexicalCore/Models/ReviewLog.swift` - conditional platform imports
- [x] `LexicalCore/DesignSystem/Colors.swift` - UIKit/AppKit adaptive color support
- [x] `LexicalCore/DesignSystem/GlassEffectContainer.swift` - cross-platform glass implementation
- [x] `LexicalCore/Services/ArticleStore.swift` - actor-init warning removed
- [x] `Package.swift` - SwiftPM warning cleanup (`exclude` updates)
- [x] iOS simulator build passes (`BUILD SUCCEEDED`)

---

# 🔲 COMPLETION PHASES

---

## Phase 8: Navigation, Seeding & Personalization

**Status:** ✅ Complete

> [!IMPORTANT]
> Placeholder replacement and hardening are complete. Phase 8 integration tasks are implemented and validated with an iOS simulator build.

### Section 1: Objective
Replace placeholder screens with functional implementations and restructure navigation to match the design spec (Feed, Explore, Practice, Stats, Profile).

### Section 2: Key Activities

#### 8.1 ExploreView (Replaced Search Placeholder)
- **Matrix + Search Combined:** Created `ExploreView.swift` combining Collocation Matrix with vocabulary search
- **Last Learned Word:** Matrix centers on the most recently reviewed word
- **Related Words:** Displays collocated words (semantic context) around the center
- **Search Functionality:** Search bar for filtering vocabulary with results that recenter the matrix

#### 8.2 SettingsView (New Profile Tab)
- **Profile Section:** Avatar, editable name, streak display
- **Learning Settings:** Daily goal slider, dark mode toggle
- **Notification Settings:** Bandit timing preferences
- **Data Management:** Export vocabulary, reset progress options
- **About Section:** Version info, privacy policy link

#### 8.3 Navigation Update
- **CustomTabBar:** Updated icons and labels (Explore, Profile instead of Search, Matrix)
- **ContentView:** Replaced placeholders with actual views

#### 8.4 Bug Fixes
- **SessionManager:** Fixed FSRS stability mutability issue
- **SettingsView:** Fixed reviewDate property reference

#### 8.5 Vocabulary Seeding (Tasks)
- **VocabularySeeder:** Versioned, idempotent seed flow using content hash (`lexical.seed_data.hash`)
- **Starter Dataset:** Added `seed_data.json` and `roots.json` in `Lexical/Resources/Seeds/`
- **Execution Logic:** Ensure seeding runs on first launch and on version bumps only
- **Collocation Linking:** Logic to link seeded words based on co-occurrence (matrix edges)
- **Verification:** Log/overlay seed counts in DEBUG builds only

#### 8.6 Personalized Articles
- **InterestProfile:** Implemented for explicit tags + implicit category weighting from read history.
- **ArticleGenerator Pipeline:** Implemented with template-driven prompt construction, evaluator pass, and persistence.
- **Templates:** `ArticleTemplateBank.json` added and wired into generation prompt selection.
- **Constraints:** `ArticleConstraintsEvaluator` enforces length/density/readability heuristics.
- **Persistence:** `ArticleStore` writes/loads generated article JSON artifacts.
- **UI Integration:** `HomeFeedView` + `ArticlesViewModel` provide user-triggered generation and list display.
- **Targeting + Provider Hardening:** Replaced static target-word list with FSRS/rank-based targeting and added production HTTP provider wiring with retry/fallback strategy.

#### 8.7 Rank-Aware Reader Filtering (Strategic Merge)
- **Lexical Rank Gating:** Add client-side "Proximal Zone" filtering based on `lexicalRank` to separate target words from too-easy and too-hard words.
- **Queue Hygiene:** Restrict Add-to-Deck recommendations to high-value target band; suppress low-value outliers.
- **Ignored Words:** Add rejection/blacklist flow to prevent repeatedly recommending unwanted words.

#### 8.8 Daily Morphology Matrix (Strategic Merge)
- **Deterministic Daily Root:** Compute daily root via epoch-day hashing (`dayID % rootCount`) for offline-consistent rotation.
- **Fixed Topology:** Enforce 1 root + 6 satellites in all daily matrices.
- **Adaptive Satellites:** Select satellites by lexical-rank relevance; fallback to second-degree links when root lacks six direct derivatives.

#### 8.9 Notification Triage Surface (Strategic Merge)
- **Actionable Notification Cards:** Add Reveal / Add to Deck / Ignore actions via App Intents.
- **Deep Link:** Route notification tap directly into single-card prompt mode.
- **Bandit + Rank Integration:** Constrain notification candidates to rank-calibrated target words.

### Section 3: Deliverables
- [x] `ExploreView.swift` - Matrix + Search combined view
- [x] `SettingsView.swift` - Full settings with profile
- [x] `CustomTabBar.swift` - Updated tab icons/labels
- [x] `ContentView.swift` - Uses new views
- [x] `SessionManager.swift` - FSRS bug fix
- [x] `LexicalCore/Services/VocabularySeeder.swift` - Versioned/hash-based seeding logic
- [x] `Lexical/Resources/Seeds/seed_data.json` - Initial vocabulary dataset
- [x] `Lexical/Resources/Seeds/roots.json` - Initial morphology root dataset
- [x] `LexicalCore/Models/InterestProfile.swift` - User interest model
- [x] `LexicalCore/Services/ArticleGenerator.swift` - Dynamic content generation
- [x] `Lexical/Resources/ArticleTemplateBank.json` - Prompt templates
- [x] `LexicalCore/Services/ArticleConstraintsEvaluator.swift` - Quality checks
- [x] `LexicalCore/Services/ArticleStore.swift` - File-backed article persistence
- [x] `Lexical/Features/Home/HomeFeedView.swift` - Personalized feed integration
- [x] Due/target-word selection from FSRS state (replaces static trigger targets)
- [x] Production LLM backend integration + retry/fallback strategy
- [x] Lexical-rank-aware reader filtering and Add-to-Deck gating
- [x] Deterministic daily matrix (1+6 topology) with adaptive satellites
- [x] Actionable push triage (Reveal/Add/Ignore) + deep-link card view

---

## Phase 9: Identity, Calibration & Sync Foundation

**Status:** ✅ Complete

### Section 1: Objective
Implement privacy-first identity, lexical rank calibration, and resilient cross-device synchronization as the foundation for adaptive acquisition.

### Section 2: Key Activities
- **Sign in with Apple:** Implement `AuthenticationService` with private-relay compatibility and Keychain-backed session persistence.
- **Dual-Store Topology:** Separate Static Corpus (read-mostly lexical truth) from User Progress (mutable cognitive state) using dedicated SwiftData configurations.
- **Extended Profile Model:** Add `lexicalRank`, `interestVector`, `ignoredWords`, `easyRatingVelocity`, and matrix `cycleCount`.
- **Lexical Calibration Engine:** Implement adaptive rank-based onboarding test (CAT/IRT-style) to estimate vocabulary size beyond CEFR bands.
- **Warm Start Initialization:** Convert calibration result into seeded user state via synthetic review history for already-known frequency bands.
- **CRDT Sync + Replay:** Apply G-Set strategy for immutable review events and LWW strategy for mutable profile/state fields; replay FSRS deterministically after merges.

### Section 3: Deliverables
- [x] `AuthenticationService.swift` - Sign in with Apple + relay-aware identity handling
- [x] `LexicalCore/Models/UserProfile.swift` - Extended adaptive profile schema
- [x] `LexicalCore/Services/LexicalCalibrationEngine.swift` - Rank estimation and confidence bounds
- [x] `LexicalCore/Services/CalibrationWarmStartService.swift` - Synthetic history/bootstrap logic
- [x] `LexicalCore/Models/LexemeDefinition.swift` - Canonical corpus entity for static lexical truth
- [x] `LexicalCore/Models/UserWordState.swift` - User-scoped mutable lexical progress entity
- [x] `LexicalCore/Models/ReviewEvent.swift` - Append-only review event stream with replay fields
- [x] `LexicalCore/Services/LexicalSchemaMigration.swift` - VersionedSchema + custom migration/backfill stage
- [x] `LexicalCore/Services/VocabularySeeder.swift` - Non-destructive canonical upsert (no user progress reset)
- [x] `LexicalCore/Services/CloudKitSyncManager.swift` - Private DB sync transport
- [x] `LexicalCore/Services/SyncConflictResolver.swift` - G-Set/LWW merge + FSRS replay
- [x] Review/session flows (`SessionManager`, `SingleCardPromptView`, `FlashcardView`) migrated to `UserWordState` + `LexemeDefinition`
- [x] Notification/widget/intent due+grade paths (`BanditScheduler`, `MicroDoseWidget`, `SharedIntents`) migrated to `UserWordState`
- [x] `LexicalSchemaV3` + `Persistence` cutover to canonical entities (`LexemeDefinition`, `UserWordState`, `ReviewEvent`) without runtime legacy table usage
- [x] Legacy fallback cleanup in active services (`StatsService`, settings reset/preview) to remove `VocabularyItem`/`ReviewLog` runtime dependencies
- [x] Sync verification tests (`LexicalCoreTests/SyncConflictResolverTests.swift`) covering replay determinism, merge idempotency, and conflict convergence
- [x] CloudKit environment preflight checks (`CloudKitSyncManager.validateRuntimeEnvironment`) for entitlement + account status validation

---

## Phase 10: Adaptive Acquisition & Engagement Loop

**Status:** 🔲 Not Started

### Section 1: Objective
Operationalize adaptive difficulty loops across articles, matrix, and notifications using lexical-rank feedback from FSRS outcomes.

### Section 2: Key Activities
- **Rank-Constrained Prompting:** Generate articles with lexical difficulty bounded by profile `lexicalRank` and target band constraints.
- **Generated Content Lifecycle:** Keep generated articles ephemeral by default; sync only explicitly saved content.
- **Adaptive Promotion Logic:** Raise/lower lexical-rank target using rolling Easy/Hard/Again distribution and retention metrics.
- **Daily Matrix Adaptation:** Maintain static daily root while dynamically selecting rank-appropriate satellites.
- **Notification Intelligence:** Trigger micro-dose candidates from high-priority rank band with Reveal/Add/Ignore triage.
- **Implicit Exposure Signal:** Write low-weight review events when target words are successfully consumed in generated content.

### Section 3: Deliverables
- [ ] `LexicalCore/Services/RankPromotionEngine.swift` - easy-rating velocity and retention-driven rank adjustment
- [ ] `LexicalCore/Services/AdaptivePromptBuilder.swift` - rank-bounded prompt templates
- [ ] `LexicalCore/Models/GeneratedContent.swift` - ephemeral content metadata (`isSaved`, `targetRank`, `targetWords`)
- [ ] `Lexical/Features/Matrix/DailyRootResolver.swift` - deterministic daily root + satellite strategy
- [ ] `LexicalCore/Services/NotificationTriageService.swift` - candidate selection and triage action routing

---

## Phase 11: Production Polish & App Store Release

**Status:** 🔲 Not Started

### Section 1: Objective
Complete onboarding UX/accessibility hardening and prepare release artifacts for App Store and TestFlight.

### Section 2: Key Activities
- **Onboarding Flow:** Create first-run flow with value proposition, permissions, interest selection, and calibration entry point.
- **Accessibility Audit:** Ensure VoiceOver support, Dynamic Type, and Reduce Motion compliance.
- **Performance Optimization:** Profile with Instruments, keep reader and graph views smooth under realistic dataset size.
- **Privacy/Compliance:** Finalize `PrivacyInfo.xcprivacy` and data collection disclosures.
- **Release Assets:** Generate App Store screenshots, metadata, and TestFlight validation checklist.

### Section 3: Deliverables
- [ ] `OnboardingView.swift` - First-run experience
- [ ] `PrivacyInfo.xcprivacy` - Privacy manifest
- [ ] App Store Connect metadata (description, keywords, categories)
- [ ] Screenshot set for all required device sizes
- [ ] TestFlight build uploaded and distributed

---

## Implementation Priority

| Phase | Priority | Estimated Effort | Key Focus |
|-------|----------|------------------|-----------|
| Phase 8 | 🔴 Critical | 1 week | Harden personalization, matrix/notification triage, and rank-aware filtering |
| Phase 9 | 🔴 Critical | 1.5 weeks | Sign in with Apple, lexical calibration, dual-store migration, CRDT replay |
| Phase 10 | 🟡 High | 1 week | Adaptive acquisition loops and rank-promotion feedback |
| Phase 11 | 🟡 Medium | 1 week | Onboarding/accessibility/release preparation |

---

## Current Placeholder Status

| Screen | Current State | Phase to Complete |
|--------|---------------|-------------------|
| Feed (Tab 1) | ✅ Functional (`HomeFeedView` + article generation UI) | Completed |
| Explore (Tab 2) | ✅ Functional (`ExploreView`) | Completed |
| Practice (Tab 3) | ✅ Functional | - |
| Stats (Tab 4) | ✅ Functional (`StatsService` period snapshots + deterministic heatmap data) | Completed |
| Profile (Tab 5) | ✅ Functional (`SettingsView` + interest management) | Completed |

---

## Next Steps
1. Start Phase 10 adaptive acquisition loop (`RankPromotionEngine`, `AdaptivePromptBuilder`, notification candidate feedback).
