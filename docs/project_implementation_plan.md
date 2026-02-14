# Lexical App: Project Implementation Plan

> **Generated:** 2026-01-31
> **Last Updated:** 2026-02-11
> **Status:** Core Features Complete | Strategic Requirements Merged | Phase 8 Complete | Phase 9 Complete | Post-Review Hardening Complete | Phase 10 Complete | UI Refinement Phase Active | Monetization Phase Active

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
- **Persistence:** `ArticleStore` now uses SwiftData-backed `GeneratedContent` rows with TTL cleanup for unsaved generated content.
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
- [x] `LexicalCore/Services/ArticleStore.swift` - SwiftData-backed generated-content persistence
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

## Phase 9A: Post-Review Verification & Hardening

**Status:** ✅ Complete

### Section 1: Objective
Resolve review-verified documentation drift, expose runtime sync readiness in-product, and close critical test-coverage gaps for Phase 8/9 deliverables.

### Section 2: Key Activities
- **Tracking Sync:** Align `.agent/tasks.json` and `.agent/memory.md` with implemented Phase 8/9 reality.
- **Plan Alignment:** Keep this implementation plan in sync with verified repository state.
- **Sync Visibility:** Surface `CloudKitSyncManager.validateRuntimeEnvironment()` status in Settings instead of static "Local Only".
- **Test Coverage:** Add focused tests for seeding idempotency, article constraints, and stats calculations.
- **Runtime Validation:** Run sync resolver tests on iOS simulator toolchain (not host `swift test`) and record outcomes.

### Section 3: Deliverables
- [x] `.agent/tasks.json` status alignment for completed Phase 8/9 subtasks
- [x] `.agent/memory.md` refreshed for dual-store + sync completion
- [x] `SettingsView.swift` sync status bound to runtime environment report
- [x] `LexicalCoreTests/*` coverage expansion for seeding, article constraints, and stats snapshots
- [x] iOS simulator test run evidence for sync conflict resolution suite

---

## Phase 10: Adaptive Acquisition & Engagement Loop

**Status:** ✅ Complete (Phase 10A Service Closure + Simulator Verification)

### Section 1: Objective
Operationalize adaptive difficulty loops across articles, matrix, and notifications using lexical-rank feedback from FSRS outcomes.

### Section 2: Key Activities
- **Adaptive Promotion Logic (Implemented):** `RankPromotionEngine` computes EWMA-derived easy velocity and retention/hard-again signals, then applies cooldown-gated lexical-rank promotion/demotion within calibration bounds.
- **Review Write Orchestration (Implemented):** `ReviewWriteCoordinator` now centralizes explicit writes across prompt/intents/session flows and logs short-term Brain Boost attempts via coordinator APIs.
- **Notification Intelligence (Implemented):** Bandit scheduling includes rank-aware reward boosts and actionable Reveal/Add/Ignore triage with prompt deep-link payloads.
- **Word Detail Triage Surface (Implemented):** After `Reveal`, prompt/review flows now expose `Info` and `Remove from Deck` actions per requirements (`SingleCardPromptView`, `ReviewSessionView`).
- **Info Content Contract (Implemented):** Shared `WordDetailSheet` now includes definition, sentence/context examples, synonyms, and pronunciation playback controls.
- **Adaptive Prompting (Implemented):** `AdaptivePromptBuilder` is wired into `ArticleGenerator` with lexical-rank windows (`lexicalRank` + `easyRatingVelocity`) passed from Home feed generation.
- **Generated Content Lifecycle (Implemented):** `GeneratedContent` SwiftData model + schema `V4` migration are live; `ArticleStore` now enforces 72h TTL cleanup on unsaved generated rows.
- **Implicit Exposure Loop (Implemented):** Opening generated articles writes daily-throttled implicit exposure events for article target lemmas; `RankPromotionEngine` now weights implicit exposure signals lower than explicit review events.
- **Daily Root Service Closure (Implemented):** Extracted deterministic root + adaptive satellite selection into dedicated `DailyRootResolver` service and wired Explore to the resolver.
- **Notification Triage Service Closure (Implemented):** Added `NotificationTriageService` and integrated Bandit action handling (`Reveal` / `Add to Deck` / `Ignore`) via service APIs.
- **Verification (Completed):** `xcodebuild -scheme Lexical-Package -destination 'platform=iOS Simulator,name=iPhone 16e' test` passes (28 tests). Packaged simulator smoke launch with `--lexical-debug-autocycle` succeeded.

### Section 3: Deliverables
- [x] `LexicalCore/Services/RankPromotionEngine.swift` - easy-rating velocity and retention-driven rank adjustment with cooldown + clamping
- [x] `LexicalCore/Services/ReviewWriteCoordinator.swift` - explicit and implicit review-write APIs with per-day implicit throttling
- [x] `Lexical/Services/BanditScheduler.swift` - rank-aware notification policy tuning and actionable triage
- [x] `LexicalCore/Services/BanditScheduler.swift` - mirrored core implementation for test targeting
- [x] Post-reveal word detail surface with `Info` and `Remove from Deck` actions wired into prompt/review flows (`SingleCardPromptView`, `ReviewSessionView`)
- [x] `Info` metadata surface containing definition, sentence/context, synonyms, and pronunciation (IPA + TTS/audio action where available)
- [x] `LexicalCore/Services/AdaptivePromptBuilder.swift` - rank-bounded prompt templates wired into `ArticleGenerator`
- [x] `LexicalCore/Models/GeneratedContent.swift` + schema wiring - ephemeral content metadata lifecycle (`LexicalSchemaV4`)
- [x] App-wide adoption of `ReviewWriteCoordinator` across review/intent flows (`SessionManager`, `SingleCardPromptView`, `SharedIntents`)
- [x] Low-weight implicit exposure write path wired from generated-content consumption with weighted promotion contribution
- [x] `Lexical/Features/Matrix/DailyRootResolver.swift` - extracted deterministic daily-root + adaptive-satellite resolver used by Explore matrix
- [x] `LexicalCore/Services/NotificationTriageService.swift` - centralized actionable-notification triage behaviors
- [x] `LexicalCoreTests/NotificationTriageServiceTests.swift` - payload parsing + add/ignore/prompt-route coverage
- [x] Green simulator test baseline via `xcodebuild` scheme tests (`Lexical-Package`, iPhone 16e)
- [x] Packaged simulator smoke launch (`com.lexical.Lexical`, debug autocycle argument)

---

## Phase 10B: UI Refinement & Experience Cohesion

**Status:** 🟡 In Progress (Explore iPhone 16-3 redesign parity pass completed on 2026-02-10)

### Section 1: Objective
Refine end-to-end interface quality and interaction ergonomics using the Liquid Glass style guide, accessibility mandates, and thumb-zone-first interaction rules across all primary screens.

### Section 2: Key Activities
- **Design Token Hardening:** Align semantic color/typography tokens with `New`, `Learning`, `Known`, high-contrast text, and Dynamic Type scaling across app surfaces.
- **Glass System Pass:** Normalize glass materials, tint behavior, corner radii, and shadow depth using shared containers with Reduce Transparency fallbacks.
- **Thumb-Zone Ergonomics:** Keep high-frequency actions (capture, reveal, grade, confirm) in the bottom interaction zone and standardize bottom-sheet detents.
- **Reader UI Refinement:** Improve vocabulary highlight clarity, line-height/readability, and tap responsiveness in long-form reading flows.
- **Review UI Refinement:** Polish prompt-to-reveal transitions, grading hierarchy, Brain Boost visual mode, and post-reveal metadata density.
- **Cross-Screen Consistency:** Unify spacing, card treatments, and navigation affordances across Home, Explore, Stats, and Settings.
- **Explore Matrix Refinement (Completed):** Reworked `ExploreView` with stable normalized node coordinates, centered `Word Matrix` header/search affordance, right-side map controls, higher-contrast node labels/icons, and Liquid Glass card treatments.
- **Explore Figma Redesign Pass (Completed):** Rebuilt Explore to match Figma file `explore-screen` (`https://www.figma.com/design/nXNpgm6nKODYjL16rP5UwN/explore-screen?node-id=1-2`) with exact iPhone 16-3 topology constants (root/satellite diameters + coordinates), Figma-aligned `Word Matrix` heading scale/letter-spacing, darker Liquid Glass bubble treatment, and a rounded-top 5-icon bottom navigation treatment; live daily root/satellite content remains dynamic (not hard-locked).
- **Accessibility + Device QA:** Validate VoiceOver labeling, color-differentiation cues, Dynamic Type breakpoints, Reduce Motion/Transparency behavior, and small-screen layout stability.

### Section 3: Deliverables
- [ ] `LexicalCore/DesignSystem/Colors.swift` + `LexicalCore/DesignSystem/Typography.swift` - semantic token and scalable typography alignment
- [ ] `LexicalCore/DesignSystem/GlassEffectContainer.swift` + `LexicalCore/DesignSystem/LiquidBackground.swift` - glass consistency and accessibility fallbacks
- [x] `Lexical/Features/Common/CustomTabBar.swift` + `Lexical/ContentView.swift` - Explore-focused bottom navigation parity pass (5-icon shell, selected glass ring, rounded top rail)
- [ ] `Lexical/Features/Reader/ReaderView.swift`, `Lexical/Features/Reader/ReaderTextView.swift`, `Lexical/Features/Reader/WordCaptureSheet.swift` - reader and capture-flow refinement
- [ ] `Lexical/Features/Review/FlashcardView.swift`, `Lexical/Features/Review/ReviewSessionView.swift`, `Lexical/Features/Review/SingleCardPromptView.swift`, `Lexical/Features/Review/WordDetailSheet.swift` - recall-loop and reveal-state UI polish
- [x] `Lexical/Features/Explore/ExploreView.swift` - iPhone 16-3 redesign implementation (Figma node `1:2` parity pass: centered radial matrix, six satellite bubbles, root emphasis treatment, accessibility labeling/pattern cues)
- [x] Explore word interaction update (2026-02-10): tap any matrix word to open an action sheet with `Word Info` and `Add to Deck`, reusing `WordDetailSheet` + `NotificationTriageService` for consistency with notification triage flows.
- [ ] `Lexical/Features/Home/ArticleCardView.swift`, `Lexical/Features/Dashboard/StatsView.swift`, `Lexical/Features/Settings/SettingsView.swift` - remaining cross-screen visual consistency pass
- [x] Explore-focused simulator verification (2026-02-10): `xcodebuild -scheme Lexical -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/derived_data build` (`BUILD SUCCEEDED`) + packaged app launch on simulator (`--lexical-debug-open-explore`) + screenshot capture (`/tmp/explore_redesign_elite_v3.png`) for visual parity check.
- [ ] Full Phase 10B simulator verification notes for iPhone 16e covering portrait/landscape + accessibility configuration checks

---

## Phase 10C: Free & Premium Monetization (StoreKit 2)

**Status:** 🟡 In Progress (tier policy ratified on 2026-02-11)

### Section 1: Objective
Ship a production-ready Free/Premium model that follows StoreKit 2 best practices, preserves offline-first behavior, and keeps the core learning loop usable for free users while clearly monetizing premium value.

### Section 2: Key Activities
- **10C.1 Tier Contract + Product Catalog**
Define a canonical Free vs Premium capability matrix and map each premium capability to explicit StoreKit product IDs (single subscription group, intro/trial policy, upgrade/downgrade behavior).
- **10C.1A Ratified Baseline Limits (2026-02-11)**
Enforce Free = 1 generated article per 7-day window, 1 active widget profile, and standard/global FSRS parameters; Premium = unlimited article generation, unlimited widget profiles, and personalized FSRS parameters.
- **10C.2 Entitlement Engine (StoreKit 2, Context7-aligned)**
Implement a single entitlement service that loads products with `Product.products(for:)`, handles purchase results (`success`, `pending`, `userCancelled`), observes `Transaction.updates` for live changes, bootstraps access from current entitlements on app launch, processes only verified transactions, and calls `transaction.finish()` after durable processing.
- **10C.3 Subscription Lifecycle Handling**
Evaluate entitlement state with transaction + subscription metadata (`revocationDate`, `expirationDate`, `Product.SubscriptionInfo.Status`, renewal info including billing-retry/expiration signals) so the app correctly handles expired, revoked, grace-period, and billing-retry scenarios.
- **10C.4 Restore + Account Recovery Flow**
Provide a visible `Restore Purchases` action that calls `AppStore.sync()` only as a user-initiated operation; avoid background/automatic sync abuse and keep normal entitlement refresh passive.
- **10C.5 Offline Persistence + Cross-Device Consistency**
Persist a last-known entitlement snapshot locally for offline reads, add premium fields to `UserProfile`, migrate schema safely, and sync entitlement state with existing LWW merge strategy in CloudKit/CRDT flows.
- **10C.6 Centralized Feature Gating**
Add a single gate resolver used by Home generation quotas, Stats depth, and premium settings/tools so access logic is deterministic, testable, and not scattered across views.
- **10C.7 Upgrade Surfaces + Merchandising**
Use StoreKit views (`SubscriptionStoreView`/`SubscriptionOfferView`) for compliant subscription merchandising, and add contextual upgrade intercepts at premium entry points with graceful fallback UI.
- **10C.8 Test, Telemetry, and Rollout Safety**
Create deterministic StoreKit test scenarios (`.storekit` + `SKTestSession`) for purchase/renewal/expire/revoke/restore paths, add entitlement telemetry events, and gate release behind simulator + device verification checklist.

### Section 3: Deliverables
- [x] `docs/free_premium_matrix.md` - canonical Free vs Premium capability matrix and gating rules
- [ ] `LexicalCore/Services/SubscriptionEntitlementService.swift` - single source of truth for product load, purchase, `Transaction.updates`, verification, entitlement computation, and restore orchestration
- [ ] `LexicalCore/Models/UserProfile.swift` + `LexicalCore/Services/LexicalSchemaMigration.swift` - premium entitlement fields (`tier`, entitlement timestamp/source, expiration marker) with non-destructive migration
- [ ] `LexicalCore/Services/CloudKitSyncManager.swift` + `LexicalCore/Services/SyncConflictResolver.swift` - entitlement payload sync and LWW merge rules for cross-device convergence
- [x] `LexicalCore/Services/FeatureGateService.swift` - centralized free/premium capability resolver consumed by app features
- [ ] `Lexical/Features/Settings/SettingsView.swift` + `Lexical/Features/Home/HomeFeedView.swift` + `Lexical/Features/Dashboard/StatsView.swift` - gated experiences, usage limits, and upgrade entry points
- [ ] `Lexical/Features/Monetization/PremiumOfferView.swift` - dedicated upgrade surface using StoreKit subscription merchandising views
- [ ] `Lexical/Resources/StoreKit/Lexical.storekit` - local StoreKit configuration for deterministic simulator testing
- [x] `LexicalCoreTests/FeatureGateServiceTests.swift` - weekly article limit, widget cap, and premium FSRS mode coverage
- [ ] `LexicalCoreTests/SubscriptionEntitlementServiceTests.swift` + `LexicalCoreTests/SyncConflictResolverTests.swift` + `LexicalCoreTests/FeatureGateServiceTests.swift` - entitlement lifecycle, merge determinism, and gate enforcement coverage
- [ ] Phase exit checks documented: verified purchase flow, pending flow, cancel flow, restore flow, expiration/revocation handling, billing-retry behavior, and offline entitlement continuity

---

## Phase 11: Production Polish & App Store Release

**Status:** 🟡 In Progress (Onboarding v1 integrated on 2026-02-14)

### Section 1: Objective
Complete onboarding UX/accessibility hardening and prepare release artifacts for App Store and TestFlight.

### Section 2: Key Activities
- **Onboarding Flow (Implemented v1):** Ship first-run, phase-gated flow with value proposition, FSRS/forgetting-curve primer, interest selection, reading-loop primer, contextual notification opt-in, and completion handoff.
- **Onboarding State Persistence (Implemented):** Persist onboarding completion and resumable step index with `AppStorage` keys; wire root app gate to onboarding completion state.
- **Contextual Notification Permission (Implemented):** Move notification authorization out of app-launch init and trigger from onboarding "Enable Smart Nudges" action only.
- **Replay Support (Implemented):** Add profile/settings action to replay onboarding for QA, iteration, and user re-entry.
- **Onboarding Flow:** Continue with permission hardening (motion/extension/widget coaching) and calibration entry point when those in-app setup surfaces are available.
- **Accessibility Audit:** Ensure VoiceOver support, Dynamic Type, and Reduce Motion compliance.
- **E2E Harness (Implemented):** Add simulator black-box automation (`simctl` + sqlite/plist assertions + screenshots) for first-run onboarding, free/premium gate state checks, and pending prompt deep-link consumption.
- **True UI Automation (Implemented):** Add `idb ui`-driven interaction tests (real taps + accessibility assertions) covering onboarding, free/premium feed states, and prompt-route open/close behavior.
- **Performance Optimization:** Profile with Instruments, keep reader and graph views smooth under realistic dataset size.
- **Privacy/Compliance:** Finalize `PrivacyInfo.xcprivacy` and data collection disclosures.
- **Release Assets:** Generate App Store screenshots, metadata, and TestFlight validation checklist.

### Section 3: Deliverables
- [x] `Lexical/Features/Onboarding/OnboardingFlowView.swift` - First-run phase-gated onboarding experience
- [x] `Lexical/Features/Onboarding/OnboardingStorage.swift` - Onboarding completion/progress key contract
- [x] `Lexical/LexicalApp.swift` - Root-level onboarding gate integration
- [x] `Lexical/Services/BanditScheduler.swift` - Explicit notification authorization API (no launch-time permission prompt)
- [x] `Lexical/Features/Settings/SettingsView.swift` - Replay onboarding entry point
- [ ] `PrivacyInfo.xcprivacy` - Privacy manifest
- [ ] App Store Connect metadata (description, keywords, categories)
- [ ] Screenshot set for all required device sizes
- [ ] TestFlight build uploaded and distributed
- [x] `scripts/e2e/run.sh` - deterministic simulator E2E harness with screenshot artifacts and state assertions
- [x] `scripts/ui_automation/run_true_ui.sh` - true simulator UI automation with interactive taps and accessibility assertions across 5 core flows
- [x] `docs/e2e_testing.md` - E2E harness usage and artifact contract

---

## Implementation Priority

| Phase | Priority | Estimated Effort | Key Focus |
|-------|----------|------------------|-----------|
| Phase 8 | ✅ Complete | - | Personalization, matrix/notification triage, and rank-aware filtering complete |
| Phase 9 | ✅ Complete | - | Identity, calibration, dual-store migration, and CRDT replay complete |
| Phase 10 | ✅ Complete | - | Adaptive acquisition loop finalized with dedicated daily-root + notification triage services and simulator verification |
| Phase 10B | 🔴 Critical (Active) | 1 week | UI refinement across design system, reader/review flows, and accessibility ergonomics |
| Phase 10C | 🔴 Critical (Active) | 1 week | Free/Premium monetization rollout with StoreKit 2, entitlement sync, and feature gates |
| Phase 11 | 🔴 Critical (Active) | 1 week | Onboarding hardening + compliance/release packaging after UI + monetization baselines |

---

## Current Placeholder Status

| Screen | Current State | Phase to Complete |
|--------|---------------|-------------------|
| Feed (Tab 1) | ✅ Functional (`HomeFeedView` + article generation UI) | Completed |
| Explore (Tab 2) | ✅ Functional (`ExploreView`) | Completed |
| Practice (Tab 3) | ✅ Functional with post-reveal `Info` + `Remove from Deck` detail surface | Phase 10 hardening complete |
| Stats (Tab 4) | ✅ Functional (`StatsService` period snapshots + deterministic heatmap data) | Completed |
| Profile (Tab 5) | ✅ Functional (`SettingsView` + interest management) | Completed |

---

## Next Steps
1. Start Phase 10B UI refinement in this order: design tokens/glass system, Reader/Review flows, then cross-screen consistency pass.
2. Run simulator QA sweeps (iPhone 16e portrait/landscape, Dynamic Type, VoiceOver, Reduce Motion/Transparency) and fold fixes into Phase 10B.
3. Continue Phase 10C monetization implementation: StoreKit service integration, entitlement sync model updates, and feature-gate wiring.
4. Continue Phase 11 onboarding hardening: add guided widget/extension setup and motion permission priming, then complete compliance/release packaging.
