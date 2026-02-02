# Lexical App: Project Implementation Plan

> **Generated:** 2026-01-31
> **Last Updated:** 2026-02-01
> **Status:** Core Features Complete | Completion Phases Pending

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

# 🔲 COMPLETION PHASES

---

## Phase 8: Navigation Restructure & Placeholder Completion

**Status:** 🟡 In Progress

> [!IMPORTANT]
> This phase addresses placeholder UI elements, navigation alignment, and vocabulary seeding; seeding is now in progress while article personalization remains pending.

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
- **VocabularySeedService:** Build service with versioned, idempotent seeding using `UserDefaults.seed_version`
- **Starter Dataset:** Add `vocab_seed.json` containing roots, words, definitions, and example contexts
- **Execution Logic:** Ensure seeding runs on first launch and on version bumps only
- **Collocation Linking:** Logic to link seeded words based on co-occurrence (matrix edges)
- **Verification:** Log/overlay seed counts in DEBUG builds only

#### 8.6 Personalized Articles (Tasks)
- **InterestProfile:** Model for explicit tags + implicit weights from reading history
- **ArticleGenerator:**
  - Select targets from **recently learned** + **due-soon** words
  - Enforce density (1–3 new words per 100) and repetition (2–4x per target)
  - Co-locate related words (matrix connections) in same sentences
- **Templates:** Add `ArticleTemplateBank.json` for structured generation
- **Constraints:** Implement `ArticleConstraintsEvaluator` for density/coverage/readability checks
- **Persistence:** Add `ArticleStore` for file-backed content + SwiftData metadata
- **Triggers:** Refresh generation after review sessions or target set changes

### Section 3: Deliverables
- [x] `ExploreView.swift` - Matrix + Search combined view
- [x] `SettingsView.swift` - Full settings with profile
- [x] `CustomTabBar.swift` - Updated tab icons/labels
- [x] `ContentView.swift` - Uses new views
- [x] `SessionManager.swift` - FSRS bug fix
- [x] `VocabularySeedService.swift` - Versioned seeding logic
- [x] `vocab_seed.json` - Initial dataset
- [ ] `InterestProfile.swift` - User interest model
- [ ] `ArticleGenerator.swift` - Dynamic content generation
- [ ] `ArticleTemplateBank.json` - Structural templates
- [ ] `ArticleConstraintsEvaluator.swift` - Quality assurance logic
- [ ] `ArticleStore.swift` - Content persistence

---

## Phase 9: Authentication & Cloud Sync

**Status:** 🔲 Not Started

### Section 1: Objective
Implement user authentication via Sign in with Apple and enable cross-device synchronization using CloudKit.

### Section 2: Key Activities
- **Sign in with Apple:** Implement `AuthenticationService` using AuthenticationServices framework
- **User Profile:** Create `UserProfile` model with preferences, streak data, and subscription status
- **CloudKit Container:** Configure CKContainer for private database sync
- **CRDT Sync Implementation:** Wire up the existing CRDT logic to CloudKit push/pull
- **Conflict Resolution:** Implement G-Set merge for ReviewLogs and LWW-Set for VocabularyItem states
- **Offline Queue:** Build pending operations queue for offline-first sync

### Section 3: Deliverables
- [ ] `AuthenticationService.swift` - Sign in with Apple flow
- [ ] `UserProfile.swift` - User data model
- [ ] `CloudKitSyncManager.swift` - CKContainer integration
- [ ] `SyncConflictResolver.swift` - CRDT merge logic
- [ ] `OfflineSyncQueue.swift` - Pending operations handler
- [ ] `ProfileView.swift` - User profile UI with stats

---

## Phase 10: Production Polish & App Store Release

**Status:** 🔲 Not Started

### Section 1: Objective
Complete onboarding experience, accessibility compliance, and prepare all assets for App Store submission.

### Section 2: Key Activities
- **Onboarding Flow:** Create 4-screen onboarding with value proposition, permissions, and vocabulary preference
- **Accessibility Audit:** Ensure VoiceOver support, Dynamic Type, and Reduce Motion compliance
- **Performance Optimization:** Profile with Instruments, ensure <150MB memory, 120fps scrolling
- **Privacy Manifests:** Create `PrivacyInfo.xcprivacy` with required disclosures (tracking, data usage)
- **App Store Assets:** Generate screenshots (6.5", 5.5"), app preview video, metadata
- **TestFlight Release:** Create beta build, invite testers, collect feedback

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
| Phase 8 | 🔴 Critical | 1 week | Complete placeholder screens, seed vocab, personalized articles |
| Phase 9 | 🟡 High | 1.5 weeks | User accounts, cloud sync |
| Phase 10 | 🟡 Medium | 1 week | Onboarding, App Store prep |

---

## Current Placeholder Status

| Screen | Current State | Phase to Complete |
|--------|---------------|-------------------|
| Search (Tab 1) | `Text("Search Placeholder")` | Phase 8 |
| Practice (Tab 2) | ✅ Functional | - |
| Stats (Tab 3) | Mock data (hardcoded) | Phase 8 |
| Matrix (Tab 4) | ✅ Functional | - |
| Settings | ❌ Missing entirely | Phase 8 |

---

## Next Steps
